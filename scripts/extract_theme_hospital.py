#!/usr/bin/env python3
"""
extract_theme_hospital.py
Extracts and normalizes Theme Hospital original game assets from GOG installers
(macOS .pkg, .dmg, Windows .exe, .zip, .rar, or directory) into assets/theme_hospital.
Designed for automated, end-to-end setups on macOS.
"""

import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.request
import zipfile

SOUNDFONT_URL = (
    "https://raw.githubusercontent.com/mrbumpy409/GeneralUser-GS/"
    "684543d5e5efaef08d02be50dcda8d552478fa60/GeneralUser-GS.sf2"
)


def log(msg, prefix="==>"):
    print(f"{prefix} {msg}", flush=True)


def clean_input_path(raw_path):
    """Clean quotes, terminal backslash-escapes, whitespace, and tilde."""
    if not raw_path:
        return ""
    p = raw_path.strip()
    # Strip wrapping quotes
    if (p.startswith('"') and p.endswith('"')) or (p.startswith("'") and p.endswith("'")):
        p = p[1:-1].strip()
    # Replace backslash-escaped characters (e.g., '\ ' -> ' ', '\(' -> '(')
    p = re.sub(r"\\(.)", r"\1", p)
    p = os.path.expanduser(p)
    return os.path.abspath(p)


def is_theme_hospital_root(path):
    """Check if path contains the required Theme Hospital files/folders."""
    if not os.path.isdir(path):
        return False
    try:
        entries = os.listdir(path)
    except OSError:
        return False

    lower_dirs = set()
    lower_files = set()
    for e in entries:
        full = os.path.join(path, e)
        if os.path.isdir(full):
            lower_dirs.add(e.lower())
        else:
            lower_files.add(e.lower())

    # CorsixTH requires 'data', 'levels', and 'qdata' directories
    has_dirs = {"data", "levels", "qdata"}.issubset(lower_dirs)
    has_exe = any(
        exe in lower_files
        for exe in ("hospital.exe", "hosp.exe", "hosp95.exe", "dos4gw.exe")
    )

    return has_dirs or (has_exe and "data" in lower_dirs)


def find_theme_hospital_root(start_dir):
    """Recursively search for the directory containing Theme Hospital data."""
    if is_theme_hospital_root(start_dir):
        return start_dir

    for root, dirs, _ in os.walk(start_dir):
        if is_theme_hospital_root(root):
            return root
    return None


def extract_pkg(pkg_path, output_dir):
    """Expand macOS flat installer package."""
    log(f"Unpacking macOS installer package (.pkg): {os.path.basename(pkg_path)}...")
    # pkgutil requires the destination directory to NOT exist beforehand
    if os.path.exists(output_dir):
        try:
            os.rmdir(output_dir)
        except OSError:
            shutil.rmtree(output_dir, ignore_errors=True)

    # First try --expand-full which automatically unpacks Payload archives
    res = subprocess.run(
        ["pkgutil", "--expand-full", pkg_path, output_dir],
        capture_output=True,
        text=True,
    )
    if res.returncode != 0:
        log("Trying standard package expansion mode...", prefix="...")
        subprocess.run(
            ["pkgutil", "--expand", pkg_path, output_dir],
            check=True,
            capture_output=True,
        )

    # Check if there are any unexpanded Payload files
    for root, _, files in os.walk(output_dir):
        for f in files:
            if f.lower() in ("payload", "payload.gz"):
                payload_path = os.path.join(root, f)
                target_payload_dir = os.path.join(root, "unpacked_payload")
                os.makedirs(target_payload_dir, exist_ok=True)
                try:
                    subprocess.run(
                        f"cd '{target_payload_dir}' && cpio -idmv < '{payload_path}'",
                        shell=True,
                        capture_output=True,
                    )
                except Exception:
                    pass


def extract_dmg(dmg_path, output_dir):
    """Mount DMG disk image and extract contents."""
    log(f"Mounting DMG disk image: {os.path.basename(dmg_path)}...")
    mount_point = tempfile.mkdtemp(prefix="th_dmg_mount_")
    try:
        subprocess.run(
            ["hdiutil", "attach", dmg_path, "-nobrowse", "-readonly", "-mountpoint", mount_point],
            check=True,
            capture_output=True,
        )

        # Check if there is a .pkg or .app or game directory inside
        found_pkg = None
        for root, dirs, files in os.walk(mount_point):
            for f in files:
                if f.endswith(".pkg"):
                    found_pkg = os.path.join(root, f)
                    break
            if found_pkg:
                break

        if found_pkg:
            extract_pkg(found_pkg, output_dir)
        else:
            # Copy all files from mount point to output_dir
            for item in os.listdir(mount_point):
                src = os.path.join(mount_point, item)
                dst = os.path.join(output_dir, item)
                if os.path.isdir(src):
                    shutil.copytree(src, dst, symlinks=True)
                else:
                    shutil.copy2(src, dst)
    finally:
        subprocess.run(["hdiutil", "detach", mount_point, "-force"], capture_output=True)
        if os.path.exists(mount_point):
            shutil.rmtree(mount_point, ignore_errors=True)


def extract_exe(exe_path, output_dir):
    """Extract Windows Inno Setup installer."""
    log(f"Extracting Windows installer (.exe): {os.path.basename(exe_path)}...")
    innoextract_bin = shutil.which("innoextract")
    if not innoextract_bin and os.path.exists("/opt/homebrew/bin/innoextract"):
        innoextract_bin = "/opt/homebrew/bin/innoextract"

    if innoextract_bin:
        res = subprocess.run(
            [innoextract_bin, "--extract", "--output-dir", output_dir, exe_path],
            capture_output=True,
            text=True,
        )
        if res.returncode == 0:
            return

    # Try unar if innoextract is not present or failed
    unar_bin = shutil.which("unar")
    if not unar_bin and os.path.exists("/opt/homebrew/bin/unar"):
        unar_bin = "/opt/homebrew/bin/unar"

    if unar_bin:
        res = subprocess.run(
            [unar_bin, "-o", output_dir, exe_path],
            capture_output=True,
            text=True,
        )
        if res.returncode == 0:
            return

    # If neither worked, try brew install innoextract
    brew_bin = shutil.which("brew") or (
        "/opt/homebrew/bin/brew" if os.path.exists("/opt/homebrew/bin/brew") else None
    )
    if brew_bin:
        log("Installing 'innoextract' utility via Homebrew...")
        subprocess.run([brew_bin, "install", "innoextract"], check=True)
        innoextract_bin = shutil.which("innoextract") or "/opt/homebrew/bin/innoextract"
        subprocess.run(
            [innoextract_bin, "--extract", "--output-dir", output_dir, exe_path],
            check=True,
        )
    else:
        raise RuntimeError(
            "'innoextract' is required to unpack the Windows .exe installer.\n"
            "Install it via 'brew install innoextract' or provide the Mac .pkg installer instead."
        )


def extract_archive(archive_path, output_dir):
    """Extract zip, tar, or other archives."""
    log(f"Extracting archive: {os.path.basename(archive_path)}...")
    if zipfile.is_zipfile(archive_path):
        with zipfile.ZipFile(archive_path, "r") as zf:
            zf.extractall(output_dir)
        return

    unar_bin = shutil.which("unar") or (
        "/opt/homebrew/bin/unar" if os.path.exists("/opt/homebrew/bin/unar") else None
    )
    if unar_bin:
        subprocess.run([unar_bin, "-o", output_dir, archive_path], check=True)
        return

    raise RuntimeError(f"Unsupported archive format or missing 'unar': {archive_path}")


def download_soundfont(dest_file):
    """Download GeneralUser-GS.sf2 soundfont for MIDI music playback."""
    if os.path.isfile(dest_file) and os.path.getsize(dest_file) > 1000000:
        log(f"Soundfont detected: {dest_file}")
        return

    log("Downloading high-quality MIDI soundfont (GeneralUser-GS.sf2)...")
    os.makedirs(os.path.dirname(dest_file), exist_ok=True)
    temp_dest = dest_file + ".download"

    def progress(blocks_transferred, block_size, total_size):
        if total_size > 0:
            percent = min(100, int(blocks_transferred * block_size * 100 / total_size))
            mb = (blocks_transferred * block_size) / (1024 * 1024)
            total_mb = total_size / (1024 * 1024)
            sys.stdout.write(f"\r==> Downloading soundfont: {mb:.1f}/{total_mb:.1f} MB ({percent}%)")
            sys.stdout.flush()

    try:
        urllib.request.urlretrieve(SOUNDFONT_URL, temp_dest, reporthook=progress)
        print()
        os.rename(temp_dest, dest_file)
        log("Soundfont successfully downloaded.")
    except Exception as e:
        print()
        if os.path.exists(temp_dest):
            os.remove(temp_dest)
        log(f"Warning: Failed to download soundfont ({e}). Game will run without MIDI music.", prefix="⚠️")


def fix_permissions(directory):
    """Set readable/executable permissions for all game files."""
    for root, dirs, files in os.walk(directory):
        for d in dirs:
            try:
                os.chmod(os.path.join(root, d), 0o755)
            except OSError:
                pass
        for f in files:
            try:
                os.chmod(os.path.join(root, f), 0o644)
            except OSError:
                pass


def process_gog_source(source_path, dest_dir, download_sf=True):
    """Main extraction and installation workflow."""
    clean_src = clean_input_path(source_path)
    if not clean_src:
        raise ValueError("File path cannot be empty.")
    if not os.path.exists(clean_src):
        raise FileNotFoundError(f"File or directory not found: '{clean_src}'")

    dest_dir = os.path.abspath(dest_dir)
    assets_parent = os.path.dirname(dest_dir)
    os.makedirs(assets_parent, exist_ok=True)

    log(f"Processing source: {clean_src}")
    temp_dir = None

    try:
        game_root = None

        if os.path.isdir(clean_src):
            log("Analyzing selected directory...")
            game_root = find_theme_hospital_root(clean_src)
        else:
            ext = os.path.splitext(clean_src)[1].lower()
            temp_dir = tempfile.mkdtemp(prefix="th_extract_")

            if ext == ".pkg":
                extract_pkg(clean_src, temp_dir)
            elif ext == ".dmg":
                extract_dmg(clean_src, temp_dir)
            elif ext in (".exe",):
                extract_exe(clean_src, temp_dir)
            elif ext in (".zip", ".rar", ".7z", ".tar", ".gz"):
                extract_archive(clean_src, temp_dir)
            else:
                raise ValueError(
                    f"Unrecognized file extension '{ext}'.\n"
                    "Supported formats: .pkg (Mac GOG), .dmg, .exe (Windows GOG), .zip, or directory."
                )

            game_root = find_theme_hospital_root(temp_dir)

        if not game_root:
            raise RuntimeError(
                "Original Theme Hospital data files were not found in the provided source.\n"
                "Please make sure your installer is the complete game (must contain DATA, LEVELS, and QDATA)."
            )

        log(f"Game data located at: {game_root}")
        log(f"Copying game files to {dest_dir}...")

        if os.path.exists(dest_dir):
            shutil.rmtree(dest_dir)
        os.makedirs(dest_dir, exist_ok=True)

        for item in os.listdir(game_root):
            src_item = os.path.join(game_root, item)
            dst_item = os.path.join(dest_dir, item)
            if os.path.isdir(src_item):
                shutil.copytree(src_item, dst_item)
            else:
                shutil.copy2(src_item, dst_item)

        fix_permissions(dest_dir)

        # Verify integrity
        if not is_theme_hospital_root(dest_dir):
            raise RuntimeError("Verification error: Essential files are missing from destination.")

        log("✅ Theme Hospital files successfully installed and verified.")

        if download_sf:
            sf_dest = os.path.join(assets_parent, "GeneralUser-GS.sf2")
            download_soundfont(sf_dest)

        return True

    finally:
        if temp_dir and os.path.exists(temp_dir):
            shutil.rmtree(temp_dir, ignore_errors=True)


def main():
    parser = argparse.ArgumentParser(
        description="Extract and prepare original Theme Hospital game assets (GOG)."
    )
    parser.add_argument("source", help="Path to GOG installer file or directory.")
    parser.add_argument(
        "--dest",
        default="assets/theme_hospital",
        help="Destination directory (default: assets/theme_hospital).",
    )
    parser.add_argument(
        "--no-soundfont",
        action="store_true",
        help="Skip downloading MIDI soundfont.",
    )
    args = parser.parse_args()

    try:
        process_gog_source(
            source_path=args.source,
            dest_dir=args.dest,
            download_sf=not args.no_soundfont,
        )
    except Exception as e:
        log(f"ERROR: {e}", prefix="❌")
        sys.exit(1)


if __name__ == "__main__":
    main()
