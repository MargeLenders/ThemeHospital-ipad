#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IOS_DIR="$ROOT_DIR/ios"
CONFIGURATION="${CONFIGURATION:-Debug}"
CORSIXTH_IOS_DEVELOPMENT_TEAM="${CORSIXTH_IOS_DEVELOPMENT_TEAM:-}"
CORSIXTH_IOS_BUNDLE_IDENTIFIER="${CORSIXTH_IOS_BUNDLE_IDENTIFIER:-org.corsixth.corsixth}"
PLATFORM="simulator"
CMAKE_ARGS=()

if [[ "$(uname -m)" == "arm64" ]]; then
  DEFAULT_SIM_ARCH="arm64"
else
  DEFAULT_SIM_ARCH="x86_64"
fi
ARCHS="$DEFAULT_SIM_ARCH"
SDK="iphonesimulator"
BUILD_DIR="$IOS_DIR/build-simulator.nosync"

usage() {
  cat <<'USAGE'
Usage: scripts/build_ios_debug.sh [options] [-- cmake-args...]

Build the CorsixTH iOS app with CMake's Xcode generator.

Options:
  --simulator           Build for iphonesimulator (default, signing disabled)
  --device              Build for iphoneos arm64; requires CORSIXTH_IOS_DEVELOPMENT_TEAM
  --release             Build with Release configuration
  --relwithdebinfo      Build with RelWithDebInfo configuration
  --configuration CONFIG Build configuration (default: Debug)
  --archs ARCHS         Target architectures (default: host simulator arch or arm64 for device)
  --build-dir DIR       CMake build directory (default: ios/build-simulator or ios/build-device)
  -h, --help            Show this help

Environment:
  CORSIXTH_IOS_DEVELOPMENT_TEAM   Apple development team id (required for --device)
  CORSIXTH_IOS_BUNDLE_IDENTIFIER  Bundle identifier (default: org.corsixth.corsixth)
USAGE
}

ensure_xcode_developer_dir() {
  if [[ -n "${DEVELOPER_DIR:-}" ]]; then
    return
  fi
  if xcrun --sdk "$SDK" --show-sdk-path >/dev/null 2>&1; then
    return
  fi

  local developer_dir
  for developer_dir in \
    "/Applications/Xcode.app/Contents/Developer" \
    "/Applications/Xcode-beta.app/Contents/Developer"; do
    if [[ -d "$developer_dir/Platforms/iPhoneSimulator.platform" && -d "$developer_dir/Platforms/iPhoneOS.platform" ]]; then
      export DEVELOPER_DIR="$developer_dir"
      return
    fi
  done
}

verify_tools() {
  command -v cmake >/dev/null 2>&1 || { echo "cmake is required." >&2; exit 1; }
  command -v xcrun >/dev/null 2>&1 || { echo "Xcode xcrun is required." >&2; exit 1; }
  ensure_xcode_developer_dir
  xcrun --sdk "$SDK" --show-sdk-path >/dev/null
}

configure_project() {
  local cmake_args=(
    cmake -S "$IOS_DIR" -B "$BUILD_DIR" -G Xcode
    -DCMAKE_SYSTEM_NAME=iOS
    -DCMAKE_OSX_SYSROOT="$SDK"
    -DCMAKE_OSX_ARCHITECTURES="$ARCHS"
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5
    -DCORSIXTH_IOS_BUNDLED_ASSETS_DIR="$ROOT_DIR/assets/theme_hospital"
  )
  if [[ -n "${CORSIXTH_IOS_DEVELOPMENT_TEAM:-}" ]]; then
    cmake_args+=(-DCORSIXTH_IOS_DEVELOPMENT_TEAM="$CORSIXTH_IOS_DEVELOPMENT_TEAM")
  fi
  if [[ -n "${CORSIXTH_IOS_BUNDLE_IDENTIFIER:-}" ]]; then
    cmake_args+=(-DCORSIXTH_IOS_BUNDLE_IDENTIFIER="$CORSIXTH_IOS_BUNDLE_IDENTIFIER")
  fi
  if ((${#CMAKE_ARGS[@]})); then
    cmake_args+=("${CMAKE_ARGS[@]}")
  fi
  "${cmake_args[@]}"
  local link_target="${BUILD_DIR%.nosync}"
  if [[ "$BUILD_DIR" == *.nosync && "$link_target" != "$BUILD_DIR" ]]; then
    ln -sfn "$(basename "$BUILD_DIR")" "$link_target"
  fi
}

build_project() {
  local xcode_settings=()
  if [[ "$PLATFORM" == "simulator" ]]; then
    xcode_settings+=(CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="")
  else
    if [[ -z "${CORSIXTH_IOS_DEVELOPMENT_TEAM:-}" ]]; then
      echo "CORSIXTH_IOS_DEVELOPMENT_TEAM is required for --device builds." >&2
      exit 1
    fi
    xcode_settings+=(DEVELOPMENT_TEAM="$CORSIXTH_IOS_DEVELOPMENT_TEAM")
    if [[ -n "${CORSIXTH_IOS_BUNDLE_IDENTIFIER:-}" ]]; then
      xcode_settings+=(PRODUCT_BUNDLE_IDENTIFIER="$CORSIXTH_IOS_BUNDLE_IDENTIFIER")
    fi
    xcode_settings+=(-allowProvisioningUpdates)
  fi

  cmake --build "$BUILD_DIR" --config "$CONFIGURATION" --target corsixth_ios -- "${xcode_settings[@]}"
}

print_app_path() {
  local app
  if [[ -d "$BUILD_DIR/$CONFIGURATION-$SDK/corsixth_ios.app" ]]; then
    app="$BUILD_DIR/$CONFIGURATION-$SDK/corsixth_ios.app"
  else
    app="$(find "$BUILD_DIR" -type d -path "*$CONFIGURATION*" -name corsixth_ios.app -print -quit)"
  fi
  if [[ -n "$app" ]]; then
    echo "Built $app"
  else
    echo "Built corsixth_ios, but could not locate corsixth_ios.app under $BUILD_DIR" >&2
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --simulator)
      PLATFORM="simulator"
      SDK="iphonesimulator"
      ARCHS="$DEFAULT_SIM_ARCH"
      BUILD_DIR="$IOS_DIR/build-simulator.nosync"
      shift
      ;;
    --device)
      PLATFORM="device"
      SDK="iphoneos"
      ARCHS="arm64"
      BUILD_DIR="$IOS_DIR/build-device.nosync"
      shift
      ;;
    --release)
      CONFIGURATION="Release"
      shift
      ;;
    --relwithdebinfo)
      CONFIGURATION="RelWithDebInfo"
      shift
      ;;
    --configuration|--config)
      [[ $# -ge 2 ]] || { echo "--configuration requires a value" >&2; exit 2; }
      CONFIGURATION="$2"
      shift 2
      ;;
    --archs)
      [[ $# -ge 2 ]] || { echo "--archs requires a value" >&2; exit 2; }
      ARCHS="$2"
      shift 2
      ;;
    --build-dir)
      [[ $# -ge 2 ]] || { echo "--build-dir requires a value" >&2; exit 2; }
      BUILD_DIR="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      CMAKE_ARGS=("$@")
      break
      ;;
    *)
      CMAKE_ARGS+=("$1")
      shift
      ;;
  esac
done

verify_tools
configure_project
build_project
print_app_path
