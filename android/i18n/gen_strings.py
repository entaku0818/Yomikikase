#!/usr/bin/env python3
"""
android/i18n/strings.json（キー → 言語 → 文言）から app/src/main/res/values*/strings.xml を生成する。

使い方: python3 android/i18n/gen_strings.py
- 文言を足すときは strings.json に全13言語分を書いてから実行する（足りない言語があるとエラーで止まる）
- 既定（values/）は英語。端末の言語が13言語以外なら英語が出る
- %1$s / %1$d などの書式と、改行を表す \\n は全言語で数をそろえる（ずれていたらエラー）
"""
import collections
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
RES = os.path.join(HERE, "..", "app", "src", "main", "res")
FOLDERS = {
    "en": "values", "ja": "values-ja", "de": "values-de", "es": "values-es", "fr": "values-fr",
    "it": "values-it", "ko": "values-ko", "pt": "values-pt", "ru": "values-ru", "th": "values-th",
    "tr": "values-tr", "vi": "values-vi", "zh": "values-zh",
}


def placeholders(text):
    return collections.Counter(re.findall(r"%\d\$[sd]", text))


def escape(text):
    text = text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
    text = text.replace("'", "\\'").replace('"', '\\"')
    if text.startswith(("@", "?")):
        text = "\\" + text
    return text


def main():
    strings = json.load(open(os.path.join(HERE, "strings.json"), encoding="utf-8"))
    errors = []
    for key, by_lang in strings.items():
        base = by_lang.get("en", "")
        for lang in FOLDERS:
            value = by_lang.get(lang)
            if not value:
                errors.append(f"{key}: {lang} がない")
            elif placeholders(value) != placeholders(base):
                errors.append(f"{key}: {lang} の書式（%1$s など）が英語と合わない")
            elif value.count("\\n") != base.count("\\n"):
                errors.append(f"{key}: {lang} の改行（\\n）の数が英語と合わない")
    if errors:
        sys.exit("\n".join(errors))

    for lang, folder in FOLDERS.items():
        os.makedirs(os.path.join(RES, folder), exist_ok=True)
        lines = [
            '<?xml version="1.0" encoding="utf-8"?>',
            "<!-- 自動生成（android/i18n/strings.json から android/i18n/gen_strings.py で生成）。直接編集しない -->",
            "<resources>",
        ]
        lines += [f'    <string name="{key}">{escape(by_lang[lang])}</string>' for key, by_lang in strings.items()]
        lines.append("</resources>\n")
        with open(os.path.join(RES, folder, "strings.xml"), "w", encoding="utf-8") as f:
            f.write("\n".join(lines))
    print(f"{len(strings)} 件 × {len(FOLDERS)} 言語を生成しました")


if __name__ == "__main__":
    main()
