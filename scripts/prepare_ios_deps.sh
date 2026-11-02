#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
THIRD_PARTY_DIR="$ROOT_DIR/ios/third_party"
mkdir -p "$THIRD_PARTY_DIR"

echo "==> Checking iOS dependencies in $THIRD_PARTY_DIR..."

# 1. SDL3
if [[ ! -d "$THIRD_PARTY_DIR/SDL3" ]]; then
  echo "==> Cloning SDL3 (release-3.4.18)..."
  git clone --depth 1 --branch release-3.4.18 https://github.com/libsdl-org/SDL.git "$THIRD_PARTY_DIR/SDL3"
fi
if [[ -f "$ROOT_DIR/ios/patches/sdl3_uikit_orientation_metal.patch" ]]; then
  git -C "$THIRD_PARTY_DIR/SDL3" apply "$ROOT_DIR/ios/patches/sdl3_uikit_orientation_metal.patch" 2>/dev/null || true
fi

# 2. SDL3_mixer
if [[ ! -d "$THIRD_PARTY_DIR/SDL3_mixer" ]]; then
  echo "==> Cloning SDL3_mixer (release-3.2.4)..."
  git clone --depth 1 --branch release-3.2.4 https://github.com/libsdl-org/SDL_mixer.git "$THIRD_PARTY_DIR/SDL3_mixer"
fi

# 3. Lua 5.4.7
if [[ ! -d "$THIRD_PARTY_DIR/lua/src" ]]; then
  echo "==> Downloading Lua 5.4.7..."
  mkdir -p "$THIRD_PARTY_DIR/lua"
  curl -sL https://www.lua.org/ftp/lua-5.4.7.tar.gz | tar -xz -C "$THIRD_PARTY_DIR"
  mv "$THIRD_PARTY_DIR/lua-5.4.7"/* "$THIRD_PARTY_DIR/lua/"
  rm -rf "$THIRD_PARTY_DIR/lua-5.4.7"
fi

# 4. LuaFileSystem
if [[ ! -d "$THIRD_PARTY_DIR/lfs" ]]; then
  echo "==> Cloning LuaFileSystem..."
  git clone --depth 1 https://github.com/lunarmodules/luafilesystem.git "$THIRD_PARTY_DIR/lfs"
fi

# 5. LPeg
if [[ ! -d "$THIRD_PARTY_DIR/lpeg" ]]; then
  echo "==> Downloading LPeg 1.1.0..."
  mkdir -p "$THIRD_PARTY_DIR/lpeg"
  curl -sL https://www.inf.puc-rio.br/~roberto/lpeg/lpeg-1.1.0.tar.gz | tar -xz -C "$THIRD_PARTY_DIR/lpeg" --strip-components=1
fi

# 6. zstd
if [[ ! -d "$THIRD_PARTY_DIR/zstd" ]]; then
  echo "==> Cloning zstd (v1.5.7)..."
  git clone --depth 1 --branch v1.5.7 https://github.com/facebook/zstd.git "$THIRD_PARTY_DIR/zstd"
fi

# 7. libpng
if [[ ! -d "$THIRD_PARTY_DIR/libpng" ]]; then
  echo "==> Cloning libpng (v1.6.43)..."
  git clone --depth 1 --branch v1.6.43 https://github.com/pnggroup/libpng.git "$THIRD_PARTY_DIR/libpng"
fi

# 8. FreeType
if [[ ! -d "$THIRD_PARTY_DIR/freetype" ]]; then
  echo "==> Cloning FreeType (VER-2-13-2)..."
  git clone --depth 1 --branch VER-2-13-2 https://github.com/freetype/freetype.git "$THIRD_PARTY_DIR/freetype"
fi

echo "==> All iOS third_party dependencies ready!"
