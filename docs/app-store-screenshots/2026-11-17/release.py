"""Select the validated build and submit the verified 1.4.15 screenshot update."""

import argparse
import hashlib
import time

import workflow as asc


def build():
    result = asc.call("GET", "builds", params={
        "filter[app]": asc.APP, "filter[version]": "53", "include": "preReleaseVersion"})
    matches = [row for row in result["data"] if any(
        version["id"] == row["relationships"]["preReleaseVersion"]["data"]["id"]
        and version["attributes"]["version"] == "1.4.15" for version in result.get("included", []))]
    assert len(matches) == 1
    value = matches[0]
    assert value["attributes"]["processingState"] == "VALID"
    assert not value["attributes"]["expired"]
    assert value["attributes"]["usesNonExemptEncryption"] is False
    return value


def status():
    version = asc.call("GET", "appStoreVersions/" + asc.VERSION)["data"]
    selected = asc.call("GET", f"appStoreVersions/{asc.VERSION}/build")["data"]
    submissions = asc.listing(f"apps/{asc.APP}/reviewSubmissions", {"limit": 100})
    ours = []
    for submission in submissions:
        if submission["attributes"]["state"] == "COMPLETE":
            continue
        items = asc.listing(f"reviewSubmissions/{submission['id']}/items", {"include": "appStoreVersion"})
        identifiers = [item["relationships"].get("appStoreVersion", {}).get("data") for item in items]
        if any(item and item["id"] == asc.VERSION for item in identifiers):
            assert all(item and item["id"] == asc.VERSION for item in identifiers)
            ours.append({"id": submission["id"], "state": submission["attributes"]["state"],
                         "appStoreVersionIds": [item["id"] for item in identifiers]})
    result = {"verifiedAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
              "version": version["attributes"]["versionString"], "versionId": asc.VERSION,
              "state": version["attributes"]["appStoreState"],
              "releaseType": version["attributes"]["releaseType"],
              "selectedBuild": {"id": selected["id"], "number": selected["attributes"]["version"],
                                "processingState": selected["attributes"]["processingState"]} if selected else None,
              "reviewSubmissions": ours}
    asc.save("release-status", result)
    print(result, flush=True)
    return result


def select_build():
    asc.locales()  # Assert editable 1.4.15 and the expected 50 localizations.
    value = build()
    asc.call("PATCH", f"appStoreVersions/{asc.VERSION}/relationships/build",
             asc.relationship("builds", value["id"]))
    selected = asc.call("GET", f"appStoreVersions/{asc.VERSION}/build")["data"]
    assert selected["id"] == value["id"]
    asc.save("build-selected", selected)
    print("Selected 1.4.15 build 53, VALID", flush=True)


def submit():
    current = status()
    if current["state"] == "WAITING_FOR_REVIEW":
        assert len(current["reviewSubmissions"]) == 1
        assert current["selectedBuild"]["id"] == build()["id"]
        return
    assert current["state"] == "PREPARE_FOR_SUBMISSION"
    assert current["releaseType"] == asc.read("version-1.4.15")["attributes"]["releaseType"] == "AFTER_APPROVAL"
    value = build()
    assert current["selectedBuild"]["id"] == value["id"]
    asc.verify()
    rows = asc.manifest()
    downloaded = asc.read("download-verification")
    assert downloaded["count"] == 600
    assert {row["key"]: row["sha256"] for row in rows} == {
        row["key"]: row["sha256"] for row in downloaded["rows"] if row["exactPixelMatch"]}
    notes = asc.read("release-notes")
    localizations = asc.listing(f"appStoreVersions/{asc.VERSION}/appStoreVersionLocalizations", {"limit": 100})
    assert len(localizations) == 50
    assert all(row["attributes"]["whatsNew"] == notes[row["attributes"]["locale"]] for row in localizations)
    asc.save("submission-preflight", {"versionId": asc.VERSION, "buildId": value["id"],
             "screenshots": 600, "locales": 50, "releaseNotesVerified": True,
             "manifestSha256": hashlib.sha256((asc.ROOT / "manifest.json").read_bytes()).hexdigest()})
    ready = [row for row in asc.listing(f"apps/{asc.APP}/reviewSubmissions", {"limit": 100})
             if row["attributes"]["state"] == "READY_FOR_REVIEW" and row["attributes"]["platform"] == "IOS"]
    assert len(ready) <= 1
    submission = ready[0] if ready else asc.call("POST", "reviewSubmissions", {"data": {
        "type": "reviewSubmissions", "attributes": {"platform": "IOS"},
        "relationships": {"app": asc.relationship("apps", asc.APP)}}})["data"]
    items = asc.listing(f"reviewSubmissions/{submission['id']}/items", {"include": "appStoreVersion"})
    assert all(item["relationships"].get("appStoreVersion", {}).get("data", {}).get("id") == asc.VERSION for item in items)
    if not items:
        asc.call("POST", "reviewSubmissionItems", {"data": {"type": "reviewSubmissionItems", "relationships": {
            "reviewSubmission": asc.relationship("reviewSubmissions", submission["id"]),
            "appStoreVersion": asc.relationship("appStoreVersions", asc.VERSION)}}})
    asc.call("PATCH", "reviewSubmissions/" + submission["id"], {"data": {
        "type": "reviewSubmissions", "id": submission["id"], "attributes": {"submitted": True}}})
    for _ in range(30):
        result = status()
        if result["state"] == "WAITING_FOR_REVIEW":
            asc.save("submission", result)
            return
        time.sleep(2)
    raise RuntimeError("Submission sent; waiting state has not yet been confirmed. Check status before retrying.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["status", "select_build", "submit"])
    globals()[parser.parse_args().action]()
