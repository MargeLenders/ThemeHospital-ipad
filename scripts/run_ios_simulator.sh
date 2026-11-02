#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -d "$ROOT_DIR/ios/build-simulator.nosync" ]]; then
  BUILD_DIR="$ROOT_DIR/ios/build-simulator.nosync"
else
  BUILD_DIR="$ROOT_DIR/ios/build-simulator"
fi
BUNDLE_ID="${CORSIXTH_IOS_BUNDLE_IDENTIFIER:-org.corsixth.corsixth}"
DO_BUILD=1
LANDSCAPE=1
PORTRAIT=0
DEVICE_SELECTOR=""
SIMULATOR_UDID=""
SIMULATOR_NAME=""
BUILD_ARGS=()

usage() {
  cat <<'USAGE'
Usage: scripts/run_ios_simulator.sh [options] [-- cmake-args...]

Build, install with simctl, sync assets, and launch CorsixTH on the iOS simulator.

Options:
  --no-build        Reuse the existing simulator app bundle
  --build-dir DIR   CMake build directory (default: ios/build-simulator)
  --device NAME     Boot and launch on the named simulator or UDID
  --landscape       Rotate Simulator.app to landscape before launch (default)
  --portrait        Rotate Simulator.app to portrait before launch
  --no-landscape    Leave the Simulator.app window in its current orientation
  -h, --help        Show this help
USAGE
}

find_app() {
  find "$BUILD_DIR" -type d -name corsixth_ios.app -print -quit
}

ensure_xcode_developer_dir() {
  if [[ -n "${DEVELOPER_DIR:-}" ]]; then
    return
  fi
  if xcrun --sdk iphonesimulator --show-sdk-path >/dev/null 2>&1; then
    return
  fi

  local developer_dir
  for developer_dir in \
    "/Applications/Xcode.app/Contents/Developer" \
    "/Applications/Xcode-beta.app/Contents/Developer"; do
    if [[ -d "$developer_dir/Platforms/iPhoneSimulator.platform" ]]; then
      export DEVELOPER_DIR="$developer_dir"
      return
    fi
  done
}

list_available_devices() {
  xcrun simctl list devices available |
    sed -nE 's/^[[:space:]]+(.+) \(([A-F0-9-]{36})\) \((Shutdown|Booted)\).*$/\1|\2|\3/p'
}

select_simulator() {
  local record=""
  if [[ -n "$DEVICE_SELECTOR" ]]; then
    if [[ "$DEVICE_SELECTOR" =~ ^[A-Fa-f0-9-]{36}$ ]]; then
      local normalized_udid
      normalized_udid="$(printf '%s' "$DEVICE_SELECTOR" | tr '[:lower:]' '[:upper:]')"
      record="$(list_available_devices | awk -F'|' -v udid="$normalized_udid" '$2 == udid { print; exit }')"
    else
      record="$(list_available_devices | awk -F'|' -v name="$DEVICE_SELECTOR" '$1 == name { print; exit }')"
      if [[ -z "$record" ]]; then
        record="$(list_available_devices | awk -F'|' -v name="$DEVICE_SELECTOR" 'index($1, name) == 1 { print; exit }')"
      fi
    fi
    if [[ -z "$record" ]]; then
      echo "No available simulator matched: $DEVICE_SELECTOR" >&2
      exit 1
    fi
  else
    record="$(list_available_devices | awk -F'|' '$3 == "Booted" && $1 ~ /^iPad/ { print; exit }')"
    if [[ -z "$record" ]]; then
      record="$(list_available_devices | awk -F'|' '$3 == "Booted" && $1 ~ /^iP(ad|hone)/ { print; exit }')"
    fi
    if [[ -z "$record" ]]; then
      record="$(list_available_devices | awk -F'|' '$1 ~ /^iPad Pro 11-inch/ { print; exit }')"
    fi
    if [[ -z "$record" ]]; then
      record="$(list_available_devices | awk -F'|' '$1 ~ /^iPad/ { print; exit }')"
    fi
    if [[ -z "$record" ]]; then
      record="$(list_available_devices | awk -F'|' '$1 ~ /^iPhone/ { print; exit }')"
    fi
  fi

  if [[ -z "$record" ]]; then
    echo "No available iOS simulator found." >&2
    exit 1
  fi

  local state
  IFS='|' read -r SIMULATOR_NAME SIMULATOR_UDID state <<<"$record"
}

boot_simulator_if_needed() {
  select_simulator
  echo "Using simulator: $SIMULATOR_NAME ($SIMULATOR_UDID)"
  xcrun simctl boot "$SIMULATOR_UDID" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$SIMULATOR_UDID" -b
}

rotate_simulator_orientation() {
  if [[ "$PORTRAIT" -eq 0 && "$LANDSCAPE" -eq 0 ]]; then
    return
  fi
  if ! command -v osascript >/dev/null 2>&1; then
    return
  fi

  local target_orientation="Landscape Right"
  if [[ "$PORTRAIT" -eq 1 ]]; then
    target_orientation="Portrait"
  fi

  open -a Simulator --args -CurrentDeviceUDID "$SIMULATOR_UDID" >/dev/null 2>&1 || true
  if ! SIMULATOR_NAME="$SIMULATOR_NAME" TARGET_ORIENTATION="$target_orientation" osascript >/dev/null 2>&1 <<'APPLESCRIPT'; then
set targetName to system attribute "SIMULATOR_NAME"
set targetOrientation to system attribute "TARGET_ORIENTATION"
tell application "Simulator" to activate
delay 0.5
tell application "System Events"
  tell process "Simulator"
    set targetItem to missing value
    tell menu "Window" of menu bar item "Window" of menu bar 1
      repeat with windowItem in menu items
        set windowName to name of windowItem
        if windowName is not missing value and windowName starts with targetName then
          set targetItem to windowItem
          exit repeat
        end if
      end repeat
    end tell
    if targetItem is not missing value then
      click targetItem
      delay 0.3
    end if
    click menu item targetOrientation of menu "Orientation" of menu item "Orientation" of menu "Device" of menu bar item "Device" of menu bar 1
  end tell
end tell
APPLESCRIPT
    true
  fi
}

run_build() {
  local build_args=(
    "$ROOT_DIR/scripts/build_ios_debug.sh" --simulator --build-dir "$BUILD_DIR" --
  )
  if ((${#BUILD_ARGS[@]})); then
    build_args+=("${BUILD_ARGS[@]}")
  fi
  "${build_args[@]}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-build)
      DO_BUILD=0
      shift
      ;;
    --build-dir)
      [[ $# -ge 2 ]] || { echo "--build-dir requires a value" >&2; exit 2; }
      BUILD_DIR="$2"
      shift 2
      ;;
    --device)
      [[ $# -ge 2 ]] || { echo "--device requires a simulator name or UDID" >&2; exit 2; }
      DEVICE_SELECTOR="$2"
      shift 2
      ;;
    --landscape)
      LANDSCAPE=1
      PORTRAIT=0
      shift
      ;;
    --portrait)
      LANDSCAPE=0
      PORTRAIT=1
      shift
      ;;
    --no-landscape)
      LANDSCAPE=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      BUILD_ARGS=("$@")
      break
      ;;
    *)
      BUILD_ARGS+=("$1")
      shift
      ;;
  esac
done

if ! command -v xcrun >/dev/null 2>&1; then
  echo "Xcode xcrun is required." >&2
  exit 1
fi
ensure_xcode_developer_dir

if [[ "$DO_BUILD" -eq 1 ]]; then
  run_build
fi

APP="$(find_app)"
if [[ -z "$APP" ]]; then
  echo "Missing iOS app bundle under $BUILD_DIR" >&2
  exit 1
fi

boot_simulator_if_needed
rotate_simulator_orientation

echo "Installing $APP to simulator..."
xcrun simctl install "$SIMULATOR_UDID" "$APP"

# Pre-populate simulator Documents container with Theme Hospital assets if present
if [[ -d "$ROOT_DIR/assets/theme_hospital" ]]; then
  CONTAINER_DATA="$(xcrun simctl get_app_container "$SIMULATOR_UDID" "$BUNDLE_ID" data 2>/dev/null || true)"
  if [[ -n "$CONTAINER_DATA" && -d "$CONTAINER_DATA" ]]; then
    mkdir -p "$CONTAINER_DATA/Documents/HOSP"
    if [[ ! -f "$CONTAINER_DATA/Documents/HOSP/DATA/MPDAT.DAT" && ! -f "$CONTAINER_DATA/Documents/HOSP/data/mpdat.dat" ]]; then
      echo "Syncing Theme Hospital assets to Simulator Documents/HOSP..."
      cp -R "$ROOT_DIR/assets/theme_hospital/"* "$CONTAINER_DATA/Documents/HOSP/"
    fi
  fi
fi

echo "Launching $BUNDLE_ID on $SIMULATOR_NAME..."
xcrun simctl launch "$SIMULATOR_UDID" "$BUNDLE_ID"
