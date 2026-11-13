#!/bin/bash
# Capture three real app screens per locale. No upload is performed.
# Usage: bash iOS/scripts/capture_all_locales.sh <simulator-udid> <IPHONE_69|IPAD_PRO_3GEN_129>
# Build once first with xcodebuild build-for-testing. Set SHOT_MANIFEST to a subset for retries.
set -euo pipefail
IOS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
UDID="${1:?Simulator UDID required}"
DEVICE="${2:?Screenshot device family required}"
DD="${DERIVED_DATA_PATH:-${IOS_DIR}/build/ShotsDD}"
MANIFEST="${SHOT_MANIFEST:-${IOS_DIR}/fastlane/screenshot-locales.json}"
OUTPUT="${SHOT_OUTPUT:-${IOS_DIR}/build/all_locale_screenshots/${DEVICE}}"
XCTESTRUN=$(python3 - "$DD" <<'PY'
import pathlib,sys
files=list((pathlib.Path(sys.argv[1])/'Build/Products').glob('*.xctestrun'))
if not files: raise SystemExit('Run xcodebuild build-for-testing first')
print(max(files,key=lambda p:p.stat().st_mtime))
PY
)
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b
xcrun simctl status_bar "$UDID" override --time 9:41 --batteryState discharging --batteryLevel 100 \
  --cellularMode active --cellularBars 4 --wifiBars 3 --dataNetwork wifi
mkdir -p "$OUTPUT"
TEST_RUNNER_SHOT_MANIFEST="$MANIFEST" TEST_RUNNER_SHOT_OUTPUT="$OUTPUT" TEST_RUNNER_SHOT_DEVICE="$DEVICE" \
  xcodebuild test-without-building -xctestrun "$XCTESTRUN" \
  -destination "platform=iOS Simulator,id=${UDID}" \
  -only-testing:VoiceYourTextUITests/AppStoreScreenshotTests/testCaptureAllLocales \
  -parallel-testing-enabled NO -maximum-test-execution-time-allowance 7200 \
  -default-test-execution-time-allowance 7200
