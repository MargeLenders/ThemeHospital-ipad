# Theme Hospital (CorsixTH) on iPadOS / iOS

This directory provides the native port, CMake build definition, and automated setup scripts for running **Theme Hospital (CorsixTH)** on iPadOS and the macOS iOS Simulator.

---

## ⚡ Quick Start (Non-Technical / Automated)

The repository provides an end-to-end automated wizard that handles tool checks, game data extraction, dependency downloads, code signing, and device deployment.

### Option 1: Finder (1-Click)
1. In macOS Finder, navigate to the project root folder.
2. Double-click **`Install_Theme_Hospital.command`**.
3. Follow the friendly interactive prompts in the Terminal window that opens.

### Option 2: Terminal
Run the setup script from the repository root:
```bash
./setup.sh
```

---

## 📦 What the Setup Wizard Does

1. **System & Tool Verification:**
   - Checks for Xcode Command Line Tools (`xcode-select`), CMake, and Python 3.
   - Automatically installs missing tools via Homebrew where available.

2. **Game Asset Extraction (*Heavy Lifting*):**
   - Theme Hospital requires original game assets (graphics, sound, levels).
   - The setup wizard accepts your downloaded **GOG installer**:
     - macOS `.pkg` flat packages
     - macOS `.dmg` disk images
     - Windows `.exe` Inno Setup packages
     - `.zip` or uncompressed directories
   - You can simply **drag and drop** the installer file into the Terminal window when prompted, or let the script auto-detect installer files in your `~/Downloads` folder.
   - Assets are verified and extracted into `assets/theme_hospital/`.
   - High-quality MIDI soundfont (`GeneralUser-GS.sf2`) is downloaded automatically.

3. **Engine Third-Party Dependencies:**
   - Automatically downloads and configures SDL3, SDL3_mixer, Lua 5.4, LuaFileSystem, LPeg, zstd, libpng, and FreeType under `ios/third_party/`.

4. **Target Selection & Deployment:**
   - **Physical iPad:** Automatically detects your connected iPad via USB or local Wi-Fi, identifies your Apple Development signing certificate from the macOS Keychain, compiles the app, and installs it onto your device.
   - **iPad Simulator:** Launches the simulator on your Mac in landscape orientation, installs the bundle, and starts the game.

---

## 🎮 Touch Controls

- **1-Finger Drag:** Pan the hospital camera across the map.
- **2-Finger Pinch:** Smooth zoom in and zoom out.
- **2-Finger Tap:** Secondary action (right-click) to cancel placements or dismiss open dialogs.

---

## 💾 Saved Games and File Access

CorsixTH integrates with the standard iPadOS **Files** app:
- Open the **Files** app on your iPad.
- Go to **On My iPad** → **CorsixTH**.
- You can access `config.txt`, custom levels, and saved games (`Saves/`).

---

## 🛠 Advanced / Manual Commands

If you prefer building manually without the wizard:

### 1. Extract Game Assets
```bash
./scripts/extract_theme_hospital.py /path/to/theme_hospital_installer.pkg
```

### 2. Prepare Dependencies
```bash
./scripts/prepare_ios_deps.sh
```

### 3. Build & Run on Simulator
```bash
./scripts/run_ios_simulator.sh --landscape
```

### 4. Build & Deploy to Connected Device
```bash
CORSIXTH_IOS_DEVELOPMENT_TEAM="YOUR_TEAM_ID" ./scripts/build_ios_debug.sh --device
./scripts/deploy_ios_device.sh
```
