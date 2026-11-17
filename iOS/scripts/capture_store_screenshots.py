"""Capture the six-screen set on the existing screenshot simulators, with checkpoints."""

import argparse
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "iOS/build/screenshots-2026-11-17"
DEVICES = {"iphone": "396797B4-39A0-462D-B310-FBF7FC945829", "ipad": "E79D78CD-19F0-4E53-91EE-E9E270E09D17"}
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("device", choices=DEVICES)
parser.add_argument("--manifest", type=Path, default=OUTPUT / "manifest.json")
args = parser.parse_args()
udid = DEVICES[args.device]
subprocess.run(["xcrun", "simctl", "boot", udid], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
subprocess.run(["xcrun", "simctl", "bootstatus", udid, "-b"], check=True, stdout=subprocess.DEVNULL)
subprocess.run(["xcrun", "simctl", "status_bar", udid, "override", "--time", "9:41", "--batteryState", "discharging",
                "--batteryLevel", "100", "--cellularMode", "active", "--cellularBars", "4", "--wifiBars", "3", "--dataNetwork", "wifi"], check=True)
subprocess.run(["xcrun", "simctl", "uninstall", udid, "com.entaku.VoiceYourText"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
products = ROOT / "iOS/build/DerivedData/Build/Products"
xctestrun = max(products.glob("*.xctestrun"), key=lambda path: path.stat().st_mtime)
environment = os.environ.copy()
environment.update({"TEST_RUNNER_SHOT_MANIFEST": str(args.manifest.resolve()),
                    "TEST_RUNNER_SHOT_OUTPUT": str(OUTPUT / "raw" / args.device)})
log = OUTPUT / f"capture-{args.device}.log"
with log.open("a") as stream:
    result = subprocess.run([
        "xcodebuild", "test-without-building", "-xctestrun", str(xctestrun),
        "-destination", f"platform=iOS Simulator,id={udid}",
        "-only-testing:VoiceYourTextUITests/AppStoreScreenshotTests/testCaptureExpandedLocales",
        "-resultBundlePath", str(OUTPUT / f"results-{args.device}-{time.time_ns()}.xcresult"),
        "-collect-test-diagnostics", "never",
        "-parallel-testing-enabled", "NO", "-maximum-test-execution-time-allowance", "14400",
        "-default-test-execution-time-allowance", "14400"
    ], env=environment, stdout=stream, stderr=subprocess.STDOUT)
print(f"{args.device} capture exit {result.returncode}; log: {log}")
sys.exit(result.returncode)
