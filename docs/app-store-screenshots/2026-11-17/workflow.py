"""Resumable ASC registration for the 1.4.15 six-screen set. No binary upload here."""

import argparse
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
import hashlib
from io import BytesIO
import json
from pathlib import Path
import subprocess
import threading
import time
from urllib.parse import urlparse

from PIL import Image, ImageChops
import requests

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[2]
ASSETS = REPO / "iOS/build/screenshots-2026-11-17/final"
APP = "6478449537"
LIVE = "d5217d7f-8f97-4c91-b74d-1fe9258419e4"
VERSION = json.loads((ROOT / "version-1.4.15.json").read_text())["id"]
GROUPS = {"IPHONE_69": "IPHONE_DYNAMIC_ISLAND_LARGE_PROFILE", "IPAD_PRO_3GEN_129": "IPAD_13_PROFILE"}
LOCK = threading.RLock()
HEADERS, TOKEN_TIME = None, 0
LOCAL = threading.local()


def clean(value):
    if isinstance(value, dict):
        return {key: clean(item) for key, item in value.items() if key != "uploadOperations"}
    if isinstance(value, list):
        return [clean(item) for item in value]
    return value


def save(name, value):
    with LOCK:
        path = ROOT / (name + ".json")
        temp = path.with_suffix(".tmp")
        temp.write_text(json.dumps(clean(value), ensure_ascii=False, indent=2) + "\n")
        temp.replace(path)


def read(name):
    return json.loads((ROOT / (name + ".json")).read_text())


def headers():
    global HEADERS, TOKEN_TIME
    with LOCK:
        if HEADERS is None or time.monotonic() - TOKEN_TIME > 600:
            code = "Dotenv.load(ARGV.fetch(0)); print Spaceship::ConnectAPI::Token.create(key_id: ENV.fetch('APP_STORE_CONNECT_API_KEY_KEY_ID'), issuer_id: ENV.fetch('APP_STORE_CONNECT_API_KEY_ISSUER_ID'), key: ENV.fetch('APP_STORE_CONNECT_API_KEY_CONTENT')).text"
            token = subprocess.check_output(["/Users/entaku/.rbenv/shims/ruby", "-rspaceship", "-rdotenv", "-e", code, str(REPO / ".env")], text=True).strip()
            HEADERS = {"Authorization": "Bearer " + token, "Content-Type": "application/json"}
            TOKEN_TIME = time.monotonic()
        return HEADERS


def session():
    if not hasattr(LOCAL, "session"):
        LOCAL.session = requests.Session()
    return LOCAL.session


def call(method, path, body=None, params=None):
    response = session().request(method, "https://api.appstoreconnect.apple.com/v1/" + path,
                                 headers=headers(), json=body, params=params, timeout=60)
    if not response.ok:
        raise RuntimeError(f"{method} {path}: HTTP {response.status_code} {response.text[:1800]}")
    return response.json() if response.content else {}


def listing(path, params=None):
    result = []
    while path:
        response = call("GET", path, params=params)
        result.extend(response["data"])
        next_page = response.get("links", {}).get("next")
        path, params = (next_page.split("/v1/", 1)[1] if next_page else None), None
    return result


def relationship(kind, identifier):
    return {"data": {"type": kind, "id": identifier}}


def locales(version=VERSION):
    target = call("GET", "appStoreVersions/" + version)["data"]
    if version == VERSION:
        assert target["attributes"]["versionString"] == "1.4.15"
        assert target["attributes"]["appStoreState"] == "PREPARE_FOR_SUBMISSION"
    else:
        assert target["attributes"]["appStoreState"] == "READY_FOR_SALE"
    rows = listing(f"appStoreVersions/{version}/appStoreVersionLocalizations", {"limit": 100})
    assert len(rows) == 50
    return {row["attributes"]["locale"]: row["id"] for row in rows}


def placements(identifier, group=None):
    params = {"limit": 200, "sort": "placementGroupPosition", "include": "image"}
    if group:
        params.update({"filter[placementType]": "APP_SCREENSHOT", "filter[placementGroup]": group})
    return listing(f"appStoreVersionLocalizations/{identifier}/placements", params)


def manifest(ready_only=False):
    result = []
    for locale in sorted(locales()):
        for device, group in GROUPS.items():
            if ready_only and not all((ASSETS / locale / f"{index}_{device}.png").exists() for index in range(6)):
                continue
            for index in range(6):
                path = ASSETS / locale / f"{index}_{device}.png"
                content = path.read_bytes()
                with Image.open(path) as image:
                    assert image.mode == "RGB" and image.size == ((1320, 2868) if device == "IPHONE_69" else (2048, 2732)), path
                    image.verify()
                digest = hashlib.sha256(content).hexdigest()
                result.append({"key": f"{locale}/{path.name}", "locale": locale, "device": device,
                               "group": group, "index": index, "sha256": digest,
                               "reference": f"vyt-1.4.15-{locale}-{device}-{index}-{digest[:12]}"})
    if not ready_only:
        assert len(result) == 600
        save("manifest", result)
    return result


def snapshot():
    for label, version in [("draft-before", VERSION), ("live-before", LIVE)]:
        mapping = locales(version)
        with ThreadPoolExecutor(max_workers=5) as pool:
            result = dict(pool.map(lambda row: (row[0], placements(row[1])), mapping.items()))
        if not (ROOT / (label + ".json")).exists():
            save(label, result)
        print(label, len(result), "locales", sum(map(len, result.values())), "placements", flush=True)


def notes():
    for locale, identifier in locales().items():
        value = read("release-notes")[locale]
        call("PATCH", "appStoreVersionLocalizations/" + identifier,
             {"data": {"type": "appStoreVersionLocalizations", "id": identifier, "attributes": {"whatsNew": value}}})
        actual = call("GET", "appStoreVersionLocalizations/" + identifier)["data"]["attributes"]["whatsNew"]
        assert actual == value
    print("Localized release notes verified: 50", flush=True)


def upload(ready_only=False):
    rows = manifest(ready_only=ready_only)
    checkpoint = read("upload-checkpoint") if (ROOT / "upload-checkpoint.json").exists() else {}
    library = {row["attributes"]["referenceName"]: row for row in listing(
        f"appAssetLibraries/{APP}/images", {"filter[category]": "APP_SCREENSHOTS_AND_PREVIEWS", "limit": 200})}

    def one(row):
        content = (ASSETS / row["key"]).read_bytes()
        if row["key"] in checkpoint:
            assert checkpoint[row["key"]]["sha256"] == row["sha256"], (row["key"], "A previously uploaded file changed")
            if ready_only and checkpoint[row["key"]].get("state") in ["PREPARE_FOR_SUBMISSION", "APPROVED"]:
                return
        existing = checkpoint.get(row["key"]) or library.get(row["reference"])
        if existing:
            asset = call("GET", "appAssetLibraryImages/" + existing["id"])["data"]
        else:
            asset = call("POST", "appAssetLibraryImages", {"data": {
                "type": "appAssetLibraryImages", "attributes": {"fileName": Path(row["key"]).name,
                "fileSize": len(content), "category": "APP_SCREENSHOTS_AND_PREVIEWS", "referenceName": row["reference"]},
                "relationships": {"assetLibrary": relationship("appAssetLibraries", APP)}}})["data"]
        assert asset["attributes"]["fileSize"] == len(content)
        with LOCK:
            checkpoint[row["key"]] = {"id": asset["id"], "sha256": row["sha256"]}
            save("upload-checkpoint", checkpoint)
        if asset["attributes"]["state"] == "AWAITING_UPLOAD":
            offset = 0
            for operation in sorted(asset["attributes"]["uploadOperations"], key=lambda item: item["offset"]):
                url = urlparse(operation["url"])
                assert url.scheme == "https" and url.hostname.endswith(".apple.com") and operation["method"] == "PUT"
                assert operation["offset"] == offset
                end = offset + operation["length"]
                try:
                    response = session().put(operation["url"], data=content[offset:end], timeout=60, allow_redirects=False,
                                             headers={item["name"]: item["value"] for item in operation["requestHeaders"]})
                except requests.RequestException:
                    raise RuntimeError("Apple image transfer failed: " + row["key"]) from None
                assert response.ok, (row["key"], response.status_code)
                offset = end
            assert offset == len(content)
            call("PATCH", "appAssetLibraryImages/" + asset["id"], {"data": {"type": "appAssetLibraryImages",
                 "id": asset["id"], "attributes": {"uploaded": True}}})
        state = asset["attributes"]["state"]
        for _ in range(30):
            if state in ["PREPARE_FOR_SUBMISSION", "APPROVED"]:
                break
            asset = call("GET", "appAssetLibraryImages/" + asset["id"])["data"]
            state = asset["attributes"]["state"]
            if state in ["PREPARE_FOR_SUBMISSION", "APPROVED"]:
                break
            assert state != "FAILED", (row["key"], asset["attributes"].get("stateDetails"))
            time.sleep(2)
        assert state in ["PREPARE_FOR_SUBMISSION", "APPROVED"], (row["key"], state)
        with LOCK:
            checkpoint[row["key"]]["state"] = state
            save("upload-checkpoint", checkpoint)
        print("UPLOADED", row["key"], state, flush=True)

    with ThreadPoolExecutor(max_workers=4) as pool:
        list(pool.map(one, rows))


def upload_ready():
    """Upload completed sets while the remaining locales are still being captured."""
    upload(ready_only=True)


def order(identifier, group, identifiers):
    return call("POST", "appAssetLibraryPlacementOrderingRequests", {"data": {
        "type": "appAssetLibraryPlacementOrderingRequests", "attributes": {"placementGroup": group},
        "relationships": {"appStoreVersionLocalization": relationship("appStoreVersionLocalizations", identifier),
        "orderedPlacements": {"data": [{"type": "appAssetLibraryPlacements", "id": value} for value in identifiers]}}}})


def place():
    rows, mapping, assets = read("manifest"), locales(), read("upload-checkpoint")
    before = read("draft-before")
    checkpoint = read("placement-checkpoint") if (ROOT / "placement-checkpoint.json").exists() else {}
    assert len(assets) == 600 and all(asset["state"] in ["APPROVED", "PREPARE_FOR_SUBMISSION"] for asset in assets.values())

    def one(pair):
        locale, group = pair
        required = sorted((row for row in rows if row["locale"] == locale and row["group"] == group), key=lambda row: row["index"])
        old = [item["id"] for item in before[locale] if item["attributes"]["placementType"] == "APP_SCREENSHOT" and item["attributes"]["placementGroup"] == group]
        assert len(old) == 3
        key, identifier = locale + "/" + group, mapping[locale]
        with LOCK:
            record = checkpoint.setdefault(key, {"old": old, "new": []})
        current = placements(identifier, group)
        expected_assets = {assets[row["key"]]["id"] for row in required}
        assert all(item["id"] in old or item["relationships"]["image"]["data"]["id"] in expected_assets
                   for item in current), (key, "Unexpected external placement change")
        desired = []
        for row in required:
            aid = assets[row["key"]]["id"]
            existing = next((item for item in current if item["relationships"]["image"]["data"]["id"] == aid), None)
            if not existing:
                existing = call("POST", "appAssetLibraryPlacements", {"data": {
                    "type": "appAssetLibraryPlacements", "attributes": {"placementType": "APP_SCREENSHOT", "placementGroup": group},
                    "relationships": {"image": relationship("appAssetLibraryImages", aid),
                    "appStoreVersionLocalization": relationship("appStoreVersionLocalizations", identifier)}}})["data"]
                # Creation responses omit relationships; retain the image ID we just sent
                # so the next slide can inspect this newly created placement too.
                existing.setdefault("relationships", {})["image"] = relationship("appAssetLibraryImages", aid)
                current.append(existing)
            desired.append(existing["id"])
            with LOCK:
                record["new"] = list(dict.fromkeys(record["new"] + desired))
                save("placement-checkpoint", checkpoint)
        remaining = [item for item in old if any(value["id"] == item for value in current)]
        order(identifier, group, desired + remaining)
        for item in remaining:
            call("DELETE", "appAssetLibraryPlacements/" + item)
        order(identifier, group, desired)
        actual = placements(identifier, group)
        assert [item["id"] for item in actual] == desired
        with LOCK:
            record["complete"] = True
            save("placement-checkpoint", checkpoint)
        print("PLACED", key, "six ordered screenshots", flush=True)

    with ThreadPoolExecutor(max_workers=4) as pool:
        list(pool.map(one, [(locale, group) for locale in mapping for group in GROUPS.values()]))
    verify()


def verify():
    mapping, rows, assets = locales(), read("manifest"), read("upload-checkpoint")
    before = read("draft-before")
    with ThreadPoolExecutor(max_workers=5) as pool:
        after = dict(pool.map(lambda row: (row[0], placements(row[1])), mapping.items()))
    states = []
    for locale, identifier in mapping.items():
        for group in GROUPS.values():
            actual = placements(identifier, group)
            required = sorted((row for row in rows if row["locale"] == locale and row["group"] == group), key=lambda row: row["index"])
            assert len(actual) == 6
            assert [item["relationships"]["image"]["data"]["id"] for item in actual] == [assets[row["key"]]["id"] for row in required]
            states.extend(item["attributes"]["state"] for item in actual)
        assert all(item in after[locale] for item in before[locale] if item["attributes"]["placementType"] != "APP_SCREENSHOT")
    live_mapping = locales(LIVE)
    with ThreadPoolExecutor(max_workers=5) as pool:
        live_after = dict(pool.map(lambda row: (row[0], placements(row[1])), live_mapping.items()))
    normalize = lambda rows: {locale: sorted(items, key=lambda item: item["id"]) for locale, items in rows.items()}
    assert normalize(live_after) == normalize(read("live-before")), "The public version must remain unchanged while the draft is prepared"
    save("draft-after", after)
    save("verification", {"verifiedAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
         "version": "1.4.15", "versionId": VERSION, "locales": 50, "screenshots": 600,
         "placementStates": dict(Counter(states)), "liveVersionUnchanged": True, "creativePlacementsUnchanged": True})
    print("Verified: 50 locales, six iPhone and six iPad screenshots each; public version and creative placements preserved", flush=True)


def downloads():
    assets, rows = read("upload-checkpoint"), read("manifest")
    def one(row):
        asset = call("GET", "appAssetLibraryImages/" + assets[row["key"]]["id"])["data"]["attributes"]["imageAsset"]
        url = asset["templateUrl"].replace("{w}", str(asset["width"])).replace("{h}", str(asset["height"])).replace("{f}", "png")
        assert urlparse(url).scheme == "https" and urlparse(url).hostname.endswith(".mzstatic.com")
        response = session().get(url, timeout=60)
        response.raise_for_status()
        remote, local = Image.open(BytesIO(response.content)).convert("RGB"), Image.open(ASSETS / row["key"]).convert("RGB")
        assert remote.size == local.size and ImageChops.difference(remote, local).getbbox() is None, row["key"]
        return {"key": row["key"], "imageId": assets[row["key"]]["id"], "sha256": row["sha256"], "exactPixelMatch": True}
    with ThreadPoolExecutor(max_workers=4) as pool:
        result = list(pool.map(one, rows))
    save("download-verification", {"verifiedAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "count": len(result), "rows": result})
    print("Apple CDN exact pixel matches:", len(result), flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("stage", choices=["snapshot", "notes", "upload", "upload_ready", "place", "verify", "downloads"])
    arguments = parser.parse_args()
    globals()[arguments.stage]()
