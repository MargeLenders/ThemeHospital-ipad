#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IOS_DIR="$ROOT_DIR/ios"
CONFIGURATION="${CONFIGURATION:-Debug}"
BUILD_DIR="$IOS_DIR/build-device.nosync"
if [[ ! -d "$BUILD_DIR" && -d "$IOS_DIR/build-device" ]]; then
  BUILD_DIR="$IOS_DIR/build-device"
fi
BUNDLE_ID="${CORSIXTH_IOS_BUNDLE_IDENTIFIER:-org.corsixth.corsixth}"
DEVICE_ID=""
SCREENSHOT_PATH=""
DO_LAUNCH=true
DO_SCREENSHOT=true

usage() {
  cat <<'USAGE'
Usage: scripts/deploy_ios_device.sh [options]

Deploy and launch CorsixTH on a connected physical iOS device.

Options:
  -d, --device ID        UDID or name of the device (default: autodetect connected physical device)
  --config CONFIG        Build configuration (default: Debug)
  --no-launch            Do not launch the app after install
  --no-screenshot        Do not capture a screenshot after launch
  --screenshot PATH      Destination path for screenshot
  -h, --help             Show this help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--device)
      [[ $# -ge 2 ]] || { echo "--device requires a value" >&2; exit 2; }
      DEVICE_ID="$2"
      shift 2
      ;;
    --config|--configuration)
      [[ $# -ge 2 ]] || { echo "--config requires a value" >&2; exit 2; }
      CONFIGURATION="$2"
      shift 2
      ;;
    --no-launch)
      DO_LAUNCH=false
      shift
      ;;
    --no-screenshot)
      DO_SCREENSHOT=false
      shift
      ;;
    --screenshot)
      [[ $# -ge 2 ]] || { echo "--screenshot requires a value" >&2; exit 2; }
      SCREENSHOT_PATH="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 2
      ;;
  esac
done

command -v xcrun >/dev/null 2>&1 || { echo "xcrun is required." >&2; exit 1; }

# Find connected physical device if not specified
if [[ -z "$DEVICE_ID" ]]; then
  echo "Detecting connected physical iOS device..."
  DEVICE_ID="$(python3 -c "
import json, subprocess, sys
try:
    out = subprocess.check_output(['xcrun', 'devicectl', 'list', 'devices', '--json-output', '-'], text=True, stderr=subprocess.DEVNULL)
    data = json.loads(out)
    for d in data.get('result', {}).get('devices', []):
        hw = d.get('hardwareProperties', {})
        conn = d.get('properties', {}).get('connection', {})
        if hw.get('reality') == 'physical' and conn.get('state') == 'connected':
            print(hw.get('udid') or d.get('identifier'))
            sys.exit(0)
    for d in data.get('result', {}).get('devices', []):
        hw = d.get('hardwareProperties', {})
        if hw.get('reality') == 'physical':
            print(hw.get('udid') or d.get('identifier'))
            sys.exit(0)
except Exception:
    pass
" 2>/dev/null || true)"
  if [[ -z "$DEVICE_ID" ]]; then
    # Fallback to parsing text output if python or json failed
    DEVICE_ID="$(xcrun devicectl list devices 2>/dev/null | grep 'physical' | grep -oE '[0-9A-Fa-f]{8}-[0-9A-Fa-f]{16}' | head -n 1 || true)"
  fi
  if [[ -z "$DEVICE_ID" ]]; then
    echo "No connected physical iOS device detected." >&2
    echo "Connect your iPad via USB or Wi-Fi and verify with: xcrun devicectl list devices" >&2
    exit 1
  fi
fi

echo "Target device: $DEVICE_ID"

APP_PATH="$BUILD_DIR/$CONFIGURATION-iphoneos/corsixth_ios.app"
if [[ ! -d "$APP_PATH" ]]; then
  APP_PATH="$(find "$BUILD_DIR" -type d -path "*$CONFIGURATION*" -name corsixth_ios.app -print -quit)"
fi

if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
  echo "Error: Could not find corsixth_ios.app in $BUILD_DIR." >&2
  echo "Build the device target first with: ./scripts/build_ios_debug.sh --device" >&2
  exit 1
fi

echo "Installing $APP_PATH onto device $DEVICE_ID..."
xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH"
echo "Installation complete."

if [[ "$DO_LAUNCH" == "true" ]]; then
  # Read actual bundle ID from Info.plist in case it was overridden
  if [[ -f "$APP_PATH/Info.plist" ]]; then
    PLIST_BUNDLE_ID="$(plutil -extract CFBundleIdentifier raw "$APP_PATH/Info.plist" 2>/dev/null || true)"
    if [[ -n "$PLIST_BUNDLE_ID" ]]; then
      BUNDLE_ID="$PLIST_BUNDLE_ID"
    fi
  fi

  echo "Launching app with bundle identifier $BUNDLE_ID..."
  xcrun devicectl device process launch --device "$DEVICE_ID" --terminate-existing "$BUNDLE_ID"
  echo "Application launched."

  if [[ "$DO_SCREENSHOT" == "true" ]]; then
    echo "Waiting for app to initialize (4 seconds)..."
    sleep 4
    if [[ -z "$SCREENSHOT_PATH" ]]; then
      SCREENSHOT_PATH="/tmp/corsixth_device_screenshot.png"
    fi
    echo "Capturing screenshot to $SCREENSHOT_PATH..."
    xcrun devicectl device capture screenshot --device "$DEVICE_ID" --destination "$SCREENSHOT_PATH" || true
    echo "Screenshot saved to $SCREENSHOT_PATH"
  fi
fi
