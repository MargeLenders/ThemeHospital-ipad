#!/usr/bin/env bash
# ==============================================================================
#  setup_theme_hospital.sh
#  End-to-End Setup and Deployment Assistant for CorsixTH (Theme Hospital)
#  Targeting iPadOS and the iOS Simulator on macOS.
# ==============================================================================

set -uo pipefail

# ANSI color and style formatting
BOLD='\033[1m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

print_banner() {
  clear 2>/dev/null || true
  echo -e "${CYAN}${BOLD}"
  echo "╔══════════════════════════════════════════════════════════════════════════╗"
  echo "║                                                                          ║"
  echo "║   🏥  THEME HOSPITAL (CorsixTH) END-TO-END SETUP FOR iPadOS / iOS        ║"
  echo "║                                                                          ║"
  echo "╚══════════════════════════════════════════════════════════════════════════╝"
  echo -e "${NC}"
  echo -e "This automated wizard prepares everything needed to build and play"
  echo -e "${BOLD}Theme Hospital${NC} on your iPad or the Mac iPad Simulator without technical hassle."
  echo ""
}

info() {
  echo -e "${CYAN}${BOLD}==>${NC} ${BOLD}$1${NC}"
}

success() {
  echo -e "${GREEN}${BOLD}✔${NC} $1"
}

warn() {
  echo -e "${YELLOW}${BOLD}⚠${NC} $1"
}

error() {
  echo -e "${RED}${BOLD}✖ ERROR:${NC} $1"
}

# ------------------------------------------------------------------------------
# 1. Locate or Clone the Git Repository
# ------------------------------------------------------------------------------
ensure_repository() {
  info "Checking CorsixTH project directory..."

  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local root_dir=""

  if [[ -f "$script_dir/CorsixTH/CorsixTH.lua" && -f "$script_dir/ios/CMakeLists.txt" ]]; then
    root_dir="$script_dir"
  elif [[ -f "$script_dir/../CorsixTH/CorsixTH.lua" && -f "$script_dir/../ios/CMakeLists.txt" ]]; then
    root_dir="$(cd "$script_dir/.." && pwd)"
  elif [[ -f "$PWD/CorsixTH/CorsixTH.lua" && -f "$PWD/ios/CMakeLists.txt" ]]; then
    root_dir="$PWD"
  fi

  if [[ -n "$root_dir" ]]; then
    cd "$root_dir"
    ROOT_DIR="$root_dir"
    success "Local repository detected at: $ROOT_DIR"
    return 0
  fi

  # Not inside a cloned directory: prompt and clone
  warn "CorsixTH source repository was not detected in current working directory."
  local default_clone_dir="$HOME/CorsixTH-iOS"
  echo -e "Where would you like to clone the repository? [Default: ${BOLD}$default_clone_dir${NC}]"
  read -r -p "Target folder (press ENTER to use default): " user_clone_dir
  local target_dir="${user_clone_dir:-$default_clone_dir}"
  target_dir="${target_dir/#\~/$HOME}"

  local repo_url="${CORSIXTH_REPO_URL:-https://github.com/MargeLenders/ThemeHospital-ipad.git}"
  local repo_branch="${CORSIXTH_BRANCH:-main}"

  info "Cloning CorsixTH repository ($repo_url)..."
  mkdir -p "$(dirname "$target_dir")"
  git clone --depth 1 --branch "$repo_branch" "$repo_url" "$target_dir" || {
    info "Trying clone without branch specification..."
    git clone --depth 1 "$repo_url" "$target_dir"
  }

  cd "$target_dir"
  ROOT_DIR="$target_dir"
  success "Repository successfully cloned to: $ROOT_DIR"
}

# ------------------------------------------------------------------------------
# 2. System and Developer Tools Verification
# ------------------------------------------------------------------------------
check_system_tools() {
  echo ""
  info "Verifying required tools on your Mac..."

  # 1. Xcode Command Line Tools
  if ! xcode-select -p >/dev/null 2>&1; then
    warn "Apple Command Line Developer Tools not found."
    echo "Launching official Apple installation prompt..."
    xcode-select --install || true
    echo "Please finish the installation in the prompt window that appeared."
    read -r -p "When installation is complete, press [ENTER] to continue..."
  else
    success "Xcode Developer Tools detected."
  fi

  # 2. Ensure DEVELOPER_DIR if full Xcode is available
  if [[ -z "${DEVELOPER_DIR:-}" ]]; then
    for dev_dir in "/Applications/Xcode.app/Contents/Developer" "/Applications/Xcode-beta.app/Contents/Developer"; do
      if [[ -d "$dev_dir/Platforms/iPhoneOS.platform" ]]; then
        export DEVELOPER_DIR="$dev_dir"
        break
      fi
    done
  fi

  # 3. CMake
  if command -v cmake >/dev/null 2>&1; then
    success "CMake detected: $(cmake --version | head -n 1)"
  elif [[ -x "/opt/homebrew/bin/cmake" ]]; then
    export PATH="/opt/homebrew/bin:$PATH"
    success "CMake detected in Homebrew path."
  elif [[ -x "/usr/local/bin/cmake" ]]; then
    export PATH="/usr/local/bin:$PATH"
    success "CMake detected in /usr/local/bin."
  else
    warn "CMake is not installed on your system."
    if command -v brew >/dev/null 2>&1 || [[ -x "/opt/homebrew/bin/brew" ]]; then
      export PATH="/opt/homebrew/bin:$PATH"
      info "Installing CMake automatically via Homebrew..."
      brew install cmake
      success "CMake installed successfully."
    else
      error "CMake is required to build the game."
      echo "Install Homebrew from https://brew.sh or download CMake from https://cmake.org"
      exit 1
    fi
  fi

  # 4. Python 3
  if command -v python3 >/dev/null 2>&1; then
    success "Python 3 detected."
  else
    error "Python 3 is required for this setup wizard."
    exit 1
  fi
}

# ------------------------------------------------------------------------------
# 3. Heavy Lifting: Theme Hospital Original Game Assets (GOG)
# ------------------------------------------------------------------------------
setup_game_assets() {
  echo ""
  info "Checking Theme Hospital original game assets (GOG installer)..."

  local assets_dir="$ROOT_DIR/assets/theme_hospital"
  local extractor_script="$ROOT_DIR/scripts/extract_theme_hospital.py"

  # Check if valid assets are already installed
  if python3 -c "
import sys, os
from scripts.extract_theme_hospital import is_theme_hospital_root
if is_theme_hospital_root('$assets_dir'):
    sys.exit(0)
sys.exit(1)
" 2>/dev/null; then
    success "Original Theme Hospital game files already present in assets/theme_hospital."
    read -r -p "Would you like to keep them and proceed? [Y/n]: " keep_existing
    keep_existing="${keep_existing:-y}"
    if [[ "$keep_existing" =~ ^[yYsS]$ ]]; then
      # Ensure soundfont is present
      if [[ ! -f "$ROOT_DIR/assets/GeneralUser-GS.sf2" ]]; then
        info "Downloading high-quality MIDI soundfont..."
        python3 -c "from scripts.extract_theme_hospital import download_soundfont; download_soundfont('$ROOT_DIR/assets/GeneralUser-GS.sf2')" || true
      fi
      return 0
    fi
  fi

  # Auto-search for GOG installers in ~/Downloads and ~/Desktop
  local candidate=""
  info "Searching for existing installer files in Downloads or Desktop..."
  candidate="$(python3 -c "
import os, glob

search_dirs = [os.path.expanduser('~/Downloads'), os.path.expanduser('~/Desktop')]
patterns = ['*theme*hospital*.*', '*Theme*Hospital*.*', 'setup_theme_hospital*.exe']
valid_exts = {'.pkg', '.dmg', '.exe', '.zip', '.rar', '.7z'}

for d in search_dirs:
    if not os.path.exists(d): continue
    for pat in patterns:
        for f in glob.glob(os.path.join(d, pat)):
            if os.path.splitext(f)[1].lower() in valid_exts:
                print(f)
                exit(0)
" 2>/dev/null || true)"

  local selected_file=""
  if [[ -n "$candidate" && -f "$candidate" ]]; then
    echo ""
    echo -e "${GREEN}${BOLD}👉 Found Theme Hospital installer:${NC}"
    echo -e "   ${CYAN}$candidate${NC}"
    read -r -p "Would you like to use this file? [Y/n]: " use_candidate
    use_candidate="${use_candidate:-y}"
    if [[ "$use_candidate" =~ ^[yYsS]$ ]]; then
      selected_file="$candidate"
    fi
  fi

  while [[ -z "$selected_file" ]]; do
    echo ""
    echo -e "${YELLOW}${BOLD}📥 Drag and drop your downloaded GOG Theme Hospital installer file directly here, then press [ENTER]:${NC}"
    echo -e "   (Supported: macOS .pkg, .dmg, or Windows .exe installer)"
    read -r -p "File: " raw_path

    # Clean quotes, backslash escapes, and whitespace
    clean_path="$(python3 -c "
import sys
from scripts.extract_theme_hospital import clean_input_path
print(clean_input_path('''$raw_path'''))
" 2>/dev/null || true)"

    if [[ -n "$clean_path" && -e "$clean_path" ]]; then
      selected_file="$clean_path"
    else
      error "File not found at specified path: '$raw_path'"
      echo "Please try dragging the file from Finder again."
    fi
  done

  echo ""
  info "Extracting and organizing game assets..."
  if ! python3 "$extractor_script" "$selected_file" --dest "$assets_dir"; then
    error "Failed to extract game assets from '$selected_file'."
    return 1
  fi
  success "Original game assets prepared and ready for bundling."
}

# ------------------------------------------------------------------------------
# 4. Engine Third-Party Dependencies (SDL3, Lua, etc.)
# ------------------------------------------------------------------------------
prepare_dependencies() {
  echo ""
  info "Preparing iOS engine dependencies (SDL3, Lua, fonts, image codecs)..."
  bash "$ROOT_DIR/scripts/prepare_ios_deps.sh"
  success "iOS third-party dependencies verified."
}

# ------------------------------------------------------------------------------
# 5. Target Selection (Physical iPad or iOS Simulator)
# ------------------------------------------------------------------------------
select_target_and_deploy() {
  echo ""
  info "Detecting connected iOS devices..."

  local devices_json
  devices_json="$(python3 -c "
import json, subprocess
try:
    out = subprocess.check_output(['xcrun', 'devicectl', 'list', 'devices', '--json-output', '-'], text=True, stderr=subprocess.DEVNULL)
    data = json.loads(out)
    results = []
    for d in data.get('result', {}).get('devices', []):
        hw = d.get('hardwareProperties', {})
        conn = d.get('properties', {}).get('connection', {})
        results.append({
            'name': d.get('deviceProperties', {}).get('name', 'iOS Device'),
            'model': hw.get('marketingName', hw.get('deviceType', 'iPad')),
            'reality': hw.get('reality', 'unknown'),
            'udid': hw.get('udid') or d.get('identifier', ''),
            'connected': conn.get('state') == 'connected' or 'available' in str(conn.get('state', '')).lower()
        })
    print(json.dumps(results))
except Exception:
    print('[]')
" 2>/dev/null || echo "[]")"

  local physical_name=""
  local physical_udid=""
  local physical_model=""

  eval "$(python3 -c "
import json
try:
    devs = json.loads('''$devices_json''')
    phys = [d for d in devs if d.get('reality') == 'physical']
    if phys:
        conn = [d for d in phys if d.get('connected')]
        target = conn[0] if conn else phys[0]
        print(f'physical_name=\"{target.get(\"name\")}\"')
        print(f'physical_udid=\"{target.get(\"udid\")}\"')
        print(f'physical_model=\"{target.get(\"model\")}\"')
except Exception:
    pass
" 2>/dev/null || true)"

  echo ""
  echo -e "${BOLD}Where would you like to install or run Theme Hospital?${NC}"
  echo "--------------------------------------------------------"

  if [[ -n "$physical_udid" ]]; then
    echo -e "  ${BOLD}1)${NC} ${GREEN}On your connected physical iPad/device:${NC} ${BOLD}$physical_name${NC} ($physical_model)"
  else
    echo -e "  ${BOLD}1)${NC} On a physical iPad (connect via USB cable or Wi-Fi)"
  fi
  echo -e "  ${BOLD}2)${NC} ${CYAN}On the Mac iPad Simulator${NC} (no device or account required)"
  echo -e "  ${BOLD}3)${NC} Build only (generate Xcode project and .app bundle)"
  echo -e "  ${BOLD}4)${NC} Exit"
  echo "--------------------------------------------------------"
  read -r -p "Select option [1-4] (default: 1): " target_choice
  target_choice="${target_choice:-1}"

  case "$target_choice" in
    1)
      deploy_to_physical_device "$physical_name" "$physical_udid"
      ;;
    2)
      deploy_to_simulator
      ;;
    3)
      build_only
      ;;
    *)
      info "Setup completed. You can build or deploy at any time."
      exit 0
      ;;
  esac
}

# ------------------------------------------------------------------------------
# 6. Physical Device Deployment with Automatic Code Signing Detection
# ------------------------------------------------------------------------------
deploy_to_physical_device() {
  local dev_name="$1"
  local dev_udid="$2"

  if [[ -z "$dev_udid" ]]; then
    warn "No connected physical iPad detected at this moment."
    echo "Please connect your iPad via USB cable or ensure it is paired over Wi-Fi."
    read -r -p "Press [ENTER] once connected to scan again..."
    select_target_and_deploy
    return
  fi

  info "Configuring development signing for device ($dev_name)..."

  # Dynamically detect active Xcode developer team ID
  local detected_team=""

  eval "$(python3 -c "
import subprocess, plistlib, os, re

detected_team = ''

try:
    out = subprocess.check_output(['defaults', 'export', 'com.apple.dt.Xcode', '-'], stderr=subprocess.DEVNULL)
    plist = plistlib.loads(out)
    last_team = plist.get('IDEProvisioningTeamManagerLastSelectedTeamID')
    team_dict = plist.get('IDEProvisioningTeamByIdentifier', {})
    for acc_id, team_list in team_dict.items():
        for t in team_list:
            if t.get('teamID') == last_team or not detected_team:
                detected_team = t.get('teamID', '')
except Exception:
    pass

if not detected_team:
    try:
        out = subprocess.check_output(['security', 'find-identity', '-p', 'codesigning', '-v'], text=True)
        m = re.search(r'\"Apple Development:.*? \(([A-Z0-9]{10})\)\"', out)
        if m:
            detected_team = m.group(1)
    except Exception:
        pass

print(f'detected_team=\"{detected_team}\"')
" 2>/dev/null || true)"

  local team_id="${CORSIXTH_IOS_DEVELOPMENT_TEAM:-$detected_team}"

  if [[ -n "$team_id" ]]; then
    echo ""
    echo -e "${GREEN}${BOLD}✔ Detected Apple Developer Team in Xcode:${NC} ${CYAN}${BOLD}$team_id${NC}"
    read -r -p "Would you like to use this Team ID for code signing? [Y/n]: " use_detected
    use_detected="${use_detected:-y}"
    if [[ ! "$use_detected" =~ ^[yYsS]$ ]]; then
      read -r -p "Enter Team ID (10 alphanumeric characters): " team_id
    fi
  else
    while [[ -z "$team_id" ]]; do
      echo ""
      echo "Enter your Apple Development Team ID (10 alphanumeric characters from developer.apple.com or Xcode -> Settings -> Accounts):"
      read -r -p "Team ID: " team_id
      team_id="$(echo "$team_id" | tr -d '[:space:]')"
    done
  fi

  echo ""
  echo -e "Enter a unique Bundle Identifier for your Apple Developer account."
  echo -e "(Example: ${CYAN}com.exampleuser.corsixth${NC} or ${CYAN}com.yourname.themehospital${NC})"
  local default_bundle="${CORSIXTH_IOS_BUNDLE_IDENTIFIER:-com.exampleuser.corsixth}"
  read -r -p "Bundle Identifier [Default: $default_bundle]: " user_bundle_id
  local bundle_id="${user_bundle_id:-$default_bundle}"
  bundle_id="$(echo "$bundle_id" | tr -d '[:space:]')"

  echo ""
  info "Building CorsixTH for iPad (Team ID: $team_id, Bundle ID: $bundle_id)..."
  if ! CORSIXTH_IOS_DEVELOPMENT_TEAM="$team_id" CORSIXTH_IOS_BUNDLE_IDENTIFIER="$bundle_id" bash "$ROOT_DIR/scripts/build_ios_debug.sh" --device; then
    error "Build failed. Please check the Xcode compilation output above."
    return 1
  fi

  echo ""
  info "Installing and launching the app on $dev_name..."
  if ! CORSIXTH_IOS_BUNDLE_IDENTIFIER="$bundle_id" bash "$ROOT_DIR/scripts/deploy_ios_device.sh" --device "$dev_udid"; then
    error "Installation or launch on device failed."
    return 1
  fi

  echo ""
  print_success_guide "iPad ($dev_name)"
}

# ------------------------------------------------------------------------------
# 7. Simulator Deployment
# ------------------------------------------------------------------------------
deploy_to_simulator() {
  echo ""
  info "Building and launching on the iPad Simulator..."
  if ! bash "$ROOT_DIR/scripts/run_ios_simulator.sh" --landscape; then
    error "Failed to build or launch on the iPad Simulator."
    return 1
  fi
  print_success_guide "iPad Simulator"
}

# ------------------------------------------------------------------------------
# 8. Build Only Option
# ------------------------------------------------------------------------------
build_only() {
  echo ""
  echo "1) Build for physical device"
  echo "2) Build for iPad Simulator"
  read -r -p "Option [1-2]: " b_opt
  b_opt="${b_opt:-1}"

  if [[ "$b_opt" == "1" ]]; then
    if ! bash "$ROOT_DIR/scripts/build_ios_debug.sh" --device; then
      error "Build for physical device failed."
      return 1
    fi
  else
    if ! bash "$ROOT_DIR/scripts/build_ios_debug.sh" --simulator; then
      error "Build for iPad Simulator failed."
      return 1
    fi
  fi
  success "Build finished. App bundle is located under ios/build-*/"
}

# ------------------------------------------------------------------------------
# 9. Success Guide & Helpful Tips
# ------------------------------------------------------------------------------
print_success_guide() {
  local target_desc="$1"
  echo ""
  echo -e "${GREEN}${BOLD}══════════════════════════════════════════════════════════════════════════${NC}"
  echo -e "${GREEN}${BOLD}  🎉  INSTALLATION AND DEPLOYMENT COMPLETE!                                ${NC}"
  echo -e "${GREEN}${BOLD}══════════════════════════════════════════════════════════════════════════${NC}"
  echo -e "Theme Hospital is ready and running on: ${BOLD}$target_desc${NC}"
  echo ""
  echo -e "${BOLD}🎮 Touch Controls Quick Guide:${NC}"
  echo -e "  • ${CYAN}1-Finger Drag:${NC} Pan the hospital camera across the map."
  echo -e "  • ${CYAN}2-Finger Pinch:${NC} Zoom in and zoom out smoothly."
  echo -e "  • ${CYAN}2-Finger Tap:${NC}   Secondary action (right-click) to cancel or dismiss"
  echo -e "                     dialogs and windows."
  echo ""
  echo -e "${BOLD}💾 Save Games & Documents:${NC}"
  echo -e "  • On your iPad, your saved games and configuration are stored directly"
  echo -e "    in the official ${BOLD}Files${NC} app under (On My iPad → ${BOLD}CorsixTH${NC} → ${BOLD}Saves${NC})."
  echo ""
  echo -e "${BOLD}🚀 Subsequent Sessions:${NC}"
  echo -e "  • The game is now installed as a native app on your home screen. You can"
  echo -e "    tap the Theme Hospital icon at any time to play."
  echo -e "${GREEN}${BOLD}══════════════════════════════════════════════════════════════════════════${NC}"
  echo ""
}

# ------------------------------------------------------------------------------
# Main Entry Point
# ------------------------------------------------------------------------------
main() {
  print_banner
  ensure_repository
  check_system_tools
  setup_game_assets
  prepare_dependencies
  select_target_and_deploy
}

main "$@"
