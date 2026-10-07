#!/bin/bash
#
#  appstore_screenshots.sh
#  VoiceYourText
#
#  App Store 用スクリーンショットを実画面から作り直す。
#    1. シミュレータ（6.9インチ）で UI テスト AppStoreScreenshotTests を走らせ、実画面を撮る
#       （デモデータは DEBUG 限定の ScreenshotDemoSeeder が入れる）
#    2. compose_screenshots.py で背景・キャッチコピー・端末フレームを合成する
#
#  使い方（どこからでも可）:
#    iOS/scripts/appstore_screenshots.sh             # 10言語を撮影＋合成
#    iOS/scripts/appstore_screenshots.sh ja          # 言語を絞る
#    SKIP_CAPTURE=1 iOS/scripts/appstore_screenshots.sh   # 撮影済みの素材から合成だけやり直す
#
#    THEME=light|night iOS/scripts/appstore_screenshots.sh  # 背景トーンを変える（既定 indigo）
#
#  出力: iOS/build/appstore_screenshots/{raw,final}/<lang>/ と final/compare_<lang>.png（旧新比較）
#    final/<lang>/APP_IPHONE_69_<n>.png (1320x2868) と APP_IPHONE_67_<n>.png (1290x2796)
#  アップロードはしない（fastlane/screenshots への配置も手動）。
#

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
IOS_DIR="${REPO_ROOT}/iOS"
PROJECT="${IOS_DIR}/VoiceYourText.xcodeproj"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-${IOS_DIR}/build/ShotsDD}"
OUT_DIR="${OUT_DIR:-${IOS_DIR}/build/appstore_screenshots}"
SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 18 Pro Max}"
BUNDLE_ID="com.entaku.VoiceYourText"
LANGS=("$@")
[ ${#LANGS[@]} -eq 0 ] && LANGS=(ja en-US de-DE es-ES fr-FR it ko th tr vi)

udid=$(xcrun simctl list devices available -j | /usr/bin/python3 -c '
import json, sys
name = sys.argv[1]
for runtime, devices in json.load(sys.stdin)["devices"].items():
    for d in devices:
        if d["name"] == name:
            print(d["udid"]); sys.exit()
' "$SIMULATOR_NAME")
[ -n "$udid" ] || { echo "シミュレータ「${SIMULATOR_NAME}」が見つかりません" >&2; exit 1; }

capture() {
    xcrun simctl boot "$udid" 2>/dev/null || true
    xcrun simctl bootstatus "$udid" -b >/dev/null
    xcrun simctl status_bar "$udid" override --time 9:41 --batteryState discharging --batteryLevel 100 \
        --cellularMode active --cellularBars 4 --wifiBars 3 --dataNetwork wifi --operatorName ""

    xcodebuild build-for-testing \
        -project "$PROJECT" -scheme VoiceYourText -configuration Debug \
        -destination "platform=iOS Simulator,id=${udid}" \
        -derivedDataPath "$DERIVED_DATA_PATH" \
        -skipMacroValidation -skipPackagePluginValidation CODE_SIGNING_ALLOWED=NO -quiet
    xctestrun=$(ls "$DERIVED_DATA_PATH"/Build/Products/*.xctestrun | head -1)

    for lang in "${LANGS[@]}"; do
        # アプリの言語コード・AppleLocale・UI テストがタップする文言（Localizable.xcstrings から）
        info=$(/usr/bin/env python3 "${IOS_DIR}/scripts/compose_screenshots.py" --labels "$lang")
        code=$(echo "$info" | sed -n 1p)
        locale=$(echo "$info" | sed -n 2p)
        labels=$(echo "$info" | sed -n 3p)
        raw="${OUT_DIR}/raw/${lang}"
        rm -rf "$raw" && mkdir -p "$raw"
        # 毎回入れ直してデモデータと起動回数（レビュー依頼の判定）を初期状態にする
        xcrun simctl uninstall "$udid" "$BUNDLE_ID" || true
        echo "▶ ${lang} を撮影"
        TEST_RUNNER_SHOT_DIR="$raw" TEST_RUNNER_SHOT_LANG="$code" \
            TEST_RUNNER_SHOT_LOCALE="$locale" TEST_RUNNER_SHOT_LABELS="$labels" \
            xcodebuild test-without-building -xctestrun "$xctestrun" \
            -destination "platform=iOS Simulator,id=${udid}" \
            -only-testing:VoiceYourTextUITests/AppStoreScreenshotTests \
            -parallel-testing-enabled NO -quiet \
            || { echo "✗ ${lang} の撮影に失敗" >&2; FAILED+=("$lang"); }
    done
}

# 1言語の失敗で全体を止めず、最後にまとめて報告する
FAILED=()
[ "${SKIP_CAPTURE:-0}" = "1" ] || capture

for lang in "${LANGS[@]}"; do
    /usr/bin/env python3 "${IOS_DIR}/scripts/compose_screenshots.py" \
        --lang "$lang" --raw "${OUT_DIR}/raw/${lang}" --out "${OUT_DIR}/final/${lang}" \
        --theme "${THEME:-indigo}" --compare-old "${IOS_DIR}/fastlane/screenshots/${lang}" \
        || { echo "✗ ${lang} の合成に失敗" >&2; FAILED+=("$lang"); }
done
if [ ${#FAILED[@]} -gt 0 ]; then
    echo "❌ 失敗: ${FAILED[*]}" >&2
    exit 1
fi
echo "✅ ${OUT_DIR}/final"
