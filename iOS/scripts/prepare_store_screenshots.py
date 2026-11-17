"""Prepare the six-screen capture manifest and existing localized captions."""

import json
from pathlib import Path

import compose_screenshots as original

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "iOS/build/screenshots-2026-11-17"
CATALOG = json.loads((ROOT / "iOS/VoiceYourText/Localization/Localizable.xcstrings").read_text())["strings"]
LOCALES = json.loads((ROOT / "iOS/fastlane/screenshot-locales.json").read_text())
HOME = json.loads((ROOT / "iOS/fastlane/screenshot-captions.json").read_text())
HERO = HOME
PRIMARY = {original.LOCALES[locale][0]: locale for locale in original.LOCALES}


def translate(key, ui):
    value = CATALOG[key]["localizations"][ui]["stringUnit"]["value"]
    assert value, (key, ui)
    return value


manifest, captions = [], {}
for locale in LOCALES:
    store, ui = locale["store"], locale["ui"]
    primary = PRIMARY.get(ui)
    labels = {key: translate(key, ui) for key in original.UI_KEYS}
    labels["_playTitle"] = original.PLAYING_TITLE[primary] if primary else locale["sampleTitle"]
    labels["_sleep30"] = translate("%d分後に停止", ui).replace("%d", "30").replace("%lld", "30")
    manifest.append({**locale, "labels": labels})
    if primary:
        first, second, third = original.SLIDES[primary][:3]
    else:
        first = ("playing", HERO[store]["shot.playing.title"], HERO[store]["shot.playing.subtitle"])
        second = ("home", HOME[store]["shot.home.title"], HOME[store]["shot.home.subtitle"])
        third = ("speed", translate("再生速度", ui), translate("声の速さ", ui))
    captions[store] = [
        {"screen": screen, "title": title, "subtitle": subtitle}
        for screen, title, subtitle in [
            first, second, third,
            ("pdf", translate("PDFをそのまま読み上げ", ui), translate("PDFやスキャン書類を読み上げ", ui)),
            ("sleeptimer", translate("スリープタイマー", ui), labels["_sleep30"]),
            ("dictionary", translate("ユーザー辞書", ui), translate("単語の読み方をカスタマイズできます", ui)),
        ]
    ]

assert len(manifest) == len(captions) == 50
priority = ["ja", "en-US", "ar-SA", "zh-Hans", "th", "hi"]
manifest.sort(key=lambda row: priority.index(row["store"]) if row["store"] in priority else len(priority))
OUTPUT.mkdir(parents=True, exist_ok=True)
for name, data in [("manifest", manifest), ("captions", captions),
                   ("sample-ja", [row for row in manifest if row["store"] == "ja"])]:
    (OUTPUT / f"{name}.json").write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
print(f"Prepared {len(manifest)} locales, six screens per locale")
