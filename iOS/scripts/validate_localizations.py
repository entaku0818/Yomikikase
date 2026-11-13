#!/usr/bin/env python3
"""Validate locale coverage, format arguments, metadata and screenshot assets."""
import argparse
import collections
import json
from pathlib import Path
import re
import struct

ROOT = Path(__file__).resolve().parents[1]
FORMAT = re.compile(r'%(?:\d+\$)?(?:lld|d|@|%)')

def arguments(value):
    return collections.Counter(re.sub(r'%\d+\$', '%', token) for token in FORMAT.findall(value))

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--screenshots', action='store_true')
    args = parser.parse_args()
    manifest = json.loads((ROOT / 'fastlane/locales.json').read_text())
    catalog = json.loads((ROOT / 'VoiceYourText/Localization/Localizable.xcstrings').read_text())
    errors = []
    review = collections.Counter()
    for locale in manifest:
        code, ui = locale['store'], locale['ui']
        for key, entry in catalog['strings'].items():
            if entry.get('shouldTranslate') is False:
                continue
            localizations = entry.get('localizations', {})
            unit = localizations.get(ui, {}).get('stringUnit', {})
            source = localizations.get('en', {}).get('stringUnit', {}).get('value', key)
            if 'value' not in unit or (source and not unit['value'].strip()):
                errors.append(f'{code}: missing translation {key}')
                continue
            if arguments(source) != arguments(unit['value']):
                errors.append(f'{code}: format arguments differ: {key}')
            if re.search(r'ZX(?:Q|PH)\s*\d+', unit['value']):
                errors.append(f'{code}: translation marker left: {key}')
            if unit.get('state') == 'needs_review':
                review[code] += 1
        info = ROOT / 'VoiceYourText/Localization' / f'{ui}.lproj/InfoPlist.strings'
        if not info.exists() or 'NSCameraUsageDescription' not in info.read_text():
            errors.append(f'{code}: missing camera usage translation')
        for field, limit in [('name', 30), ('subtitle', 30), ('keywords', 100), ('description', 4000), ('promotional_text', 170), ('release_notes', 4000)]:
            file = ROOT / 'fastlane/metadata' / code / (field + '.txt')
            value = file.read_text().strip() if file.exists() else ''
            if not value or len(value) > limit:
                errors.append(f'{code}: {field} length {len(value)} (max {limit})')
        if args.screenshots:
            folder = ROOT / 'fastlane/screenshots' / code
            sizes = collections.Counter()
            for file in folder.glob('*.png'):
                header = file.read_bytes()[:26]
                if header[:8] != b'\x89PNG\r\n\x1a\n':
                    errors.append(f'Invalid PNG: {file}')
                    continue
                size = struct.unpack('>II', header[16:24])
                if header[25] in (4, 6):
                    errors.append(f'Alpha channel: {file}')
                sizes[size] += 1
            if not any(sizes[s] >= 3 for s in [(1320, 2868), (1290, 2796)]):
                errors.append(f'{code}: fewer than 3 iPhone screenshots')
            if sizes[(2048, 2732)] < 3 and sizes[(2064, 2752)] < 3:
                errors.append(f'{code}: fewer than 3 iPad screenshots')
    for error in errors:
        print('ERROR:', error)
    print(f'{len(manifest)} locales; {len(catalog["strings"])} catalog entries; {len(errors)} errors')
    print('Translations awaiting linguistic review:', dict(review))
    raise SystemExit(bool(errors))

if __name__ == '__main__':
    main()
