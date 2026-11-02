cmake_minimum_required(VERSION 3.22)

set(CMAKE_POLICY_VERSION_MINIMUM "3.5" CACHE STRING "" FORCE)

project(corsixth_ios LANGUAGES C CXX OBJC OBJCXX)

if(NOT CMAKE_SYSTEM_NAME STREQUAL "iOS")
    message(FATAL_ERROR "Configure the iOS target with -DCMAKE_SYSTEM_NAME=iOS, or use scripts/build_ios_debug.sh.")
endif()

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

if(NOT DEFINED CMAKE_OSX_DEPLOYMENT_TARGET)
    set(CMAKE_OSX_DEPLOYMENT_TARGET "16.0" CACHE STRING "" FORCE)
endif()

set(CORSIXTH_ROOT "${CMAKE_CURRENT_LIST_DIR}/..")
set(CORSIXTH_IOS_BUNDLED_ASSETS_DIR "${CORSIXTH_ROOT}/assets/theme_hospital" CACHE PATH "Local Theme Hospital assets to bundle into iOS app.")

# --- Third-party dependencies configuration ---

# 1. SDL3
set(SDL_SHARED OFF CACHE BOOL "" FORCE)
set(SDL_STATIC ON CACHE BOOL "" FORCE)
set(SDL_TEST OFF CACHE BOOL "" FORCE)
set(SDL_TESTS OFF CACHE BOOL "" FORCE)
set(SDL_INSTALL OFF CACHE BOOL "" FORCE)
if(NOT EXISTS "${CMAKE_CURRENT_LIST_DIR}/third_party/SDL3/CMakeLists.txt")
    message(FATAL_ERROR "Missing SDL3 sources at ios/third_party/SDL3.")
endif()
add_subdirectory("${CMAKE_CURRENT_LIST_DIR}/third_party/SDL3" "${CMAKE_BINARY_DIR}/SDL3")

# 2. SDL3_mixer
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
set(SDLMIXER_SAMPLES OFF CACHE BOOL "" FORCE)
set(SDLMIXER_VENDORED OFF CACHE BOOL "" FORCE)
set(SDLMIXER_WAVE ON CACHE BOOL "" FORCE)
set(SDLMIXER_AIFF ON CACHE BOOL "" FORCE)
set(SDLMIXER_VOC ON CACHE BOOL "" FORCE)
set(SDLMIXER_AU ON CACHE BOOL "" FORCE)
set(SDLMIXER_FLAC OFF CACHE BOOL "" FORCE)
set(SDLMIXER_FLAC_LIBFLAC OFF CACHE BOOL "" FORCE)
set(SDLMIXER_FLAC_DRFLAC OFF CACHE BOOL "" FORCE)
set(SDLMIXER_GME OFF CACHE BOOL "" FORCE)
set(SDLMIXER_MOD OFF CACHE BOOL "" FORCE)
set(SDLMIXER_MOD_XMP OFF CACHE BOOL "" FORCE)
set(SDLMIXER_MP3 OFF CACHE BOOL "" FORCE)
set(SDLMIXER_MP3_DRMP3 OFF CACHE BOOL "" FORCE)
set(SDLMIXER_MP3_MPG123 OFF CACHE BOOL "" FORCE)
set(SDLMIXER_MIDI OFF CACHE BOOL "" FORCE)
set(SDLMIXER_OPUS OFF CACHE BOOL "" FORCE)
set(SDLMIXER_VORBIS_STB OFF CACHE BOOL "" FORCE)
set(SDLMIXER_VORBIS_VORBISFILE OFF CACHE BOOL "" FORCE)
set(SDLMIXER_VORBIS_TREMOR OFF CACHE BOOL "" FORCE)
set(SDLMIXER_WAVPACK OFF CACHE BOOL "" FORCE)
if(NOT EXISTS "${CMAKE_CURRENT_LIST_DIR}/third_party/SDL3_mixer/CMakeLists.txt")
    message(FATAL_ERROR "Missing SDL3_mixer sources at ios/third_party/SDL3_mixer.")
endif()
add_subdirectory("${CMAKE_CURRENT_LIST_DIR}/third_party/SDL3_mixer" "${CMAKE_BINARY_DIR}/SDL3_mixer")

# 3. zstd
set(ZSTD_BUILD_STATIC ON CACHE BOOL "" FORCE)
set(ZSTD_BUILD_SHARED OFF CACHE BOOL "" FORCE)
set(ZSTD_BUILD_PROGRAMS OFF CACHE BOOL "" FORCE)
set(ZSTD_BUILD_TESTS OFF CACHE BOOL "" FORCE)
if(NOT EXISTS "${CMAKE_CURRENT_LIST_DIR}/third_party/zstd/build/cmake/CMakeLists.txt")
    message(FATAL_ERROR "Missing zstd sources at ios/third_party/zstd.")
endif()
add_subdirectory("${CMAKE_CURRENT_LIST_DIR}/third_party/zstd/build/cmake" "${CMAKE_BINARY_DIR}/zstd")

# 4. libpng
set(PNG_SHARED OFF CACHE BOOL "" FORCE)
set(PNG_STATIC ON CACHE BOOL "" FORCE)
set(PNG_TESTS OFF CACHE BOOL "" FORCE)
set(PNG_TOOLS OFF CACHE BOOL "" FORCE)
set(PNG_EXECUTABLES OFF CACHE BOOL "" FORCE)
if(NOT EXISTS "${CMAKE_CURRENT_LIST_DIR}/third_party/libpng/CMakeLists.txt")
    message(FATAL_ERROR "Missing libpng sources at ios/third_party/libpng.")
endif()
add_subdirectory("${CMAKE_CURRENT_LIST_DIR}/third_party/libpng" "${CMAKE_BINARY_DIR}/libpng")

# 5. freetype
set(FT_DISABLE_HARFBUZZ ON CACHE BOOL "" FORCE)
set(FT_DISABLE_BZIP2 ON CACHE BOOL "" FORCE)
set(FT_DISABLE_BROTLI ON CACHE BOOL "" FORCE)
set(FT_DISABLE_PNG ON CACHE BOOL "" FORCE)
set(FT_DISABLE_ZLIB OFF CACHE BOOL "" FORCE)
if(NOT EXISTS "${CMAKE_CURRENT_LIST_DIR}/third_party/freetype/CMakeLists.txt")
    message(FATAL_ERROR "Missing freetype sources at ios/third_party/freetype.")
endif()
add_subdirectory("${CMAKE_CURRENT_LIST_DIR}/third_party/freetype" "${CMAKE_BINARY_DIR}/freetype")

# 6. Lua 5.4 + LFS + LPeg (Static Library)
file(GLOB LUA_CORE_SOURCES "${CMAKE_CURRENT_LIST_DIR}/third_party/lua/src/*.c")
list(FILTER LUA_CORE_SOURCES EXCLUDE REGEX ".*/lua\\.c$")
list(FILTER LUA_CORE_SOURCES EXCLUDE REGEX ".*/luac\\.c$")

file(GLOB LPEG_SOURCES "${CMAKE_CURRENT_LIST_DIR}/third_party/lpeg/*.c")
set(LFS_SOURCES "${CMAKE_CURRENT_LIST_DIR}/third_party/lfs/src/lfs.c")

add_library(lua_static STATIC
    ${LUA_CORE_SOURCES}
    ${LPEG_SOURCES}
    ${LFS_SOURCES}
)
target_compile_definitions(lua_static PRIVATE LUA_COMPAT_5_3 LUA_USE_IOS)
target_include_directories(lua_static PUBLIC
    "${CMAKE_CURRENT_LIST_DIR}/third_party/lua/src"
    "${CMAKE_CURRENT_LIST_DIR}/third_party/lpeg"
    "${CMAKE_CURRENT_LIST_DIR}/third_party/lfs/src"
)

# 7. Internal helper libraries (RncLib, WhereamiLib)
add_library(RncLib STATIC
    "${CORSIXTH_ROOT}/libs/rnc/rnc.cpp"
    "${CORSIXTH_ROOT}/libs/rnc/rnc.h"
)
target_include_directories(RncLib PUBLIC "${CORSIXTH_ROOT}/libs/rnc")
set_target_properties(RncLib PROPERTIES
    CXX_STANDARD 17
    XCODE_ATTRIBUTE_CLANG_CXX_LANGUAGE_STANDARD "c++17"
)

add_library(WhereamiLib STATIC
    "${CORSIXTH_ROOT}/libs/whereami/whereami.c"
    "${CORSIXTH_ROOT}/libs/whereami/whereami.h"
)
target_include_directories(WhereamiLib PUBLIC "${CORSIXTH_ROOT}/libs/whereami")

# 8. Configure config.h
set(CORSIX_TH_SEARCH_LOCAL_DATADIRS ON)
set(CORSIX_TH_INTERPRETER_NAME CorsixTH.lua)
set(CORSIX_TH_INTERPRETER_PATH CorsixTH.lua)
set(CORSIX_TH_LINK_LUA_MODULES ON)
set(CORSIX_TH_OS "macos")
set(CORSIX_TH_ARCH "arm64")
set(CORSIX_TH_FONT "")

configure_file(
    "${CORSIXTH_ROOT}/CorsixTH/Src/config.h.in"
    "${CMAKE_CURRENT_BINARY_DIR}/CorsixTH/Src/config.h"
)

# --- CorsixTH Engine Sources ---
set(CORSIXTH_ENGINE_SOURCES
    "${CORSIXTH_ROOT}/CorsixTH/Src/random.c"
    "${CORSIXTH_ROOT}/CorsixTH/Src/bootstrap.cpp"
    "${CORSIXTH_ROOT}/CorsixTH/Src/iso_fs.cpp"
    "${CORSIXTH_ROOT}/CorsixTH/Src/lua_rnc.cpp"
    "${CORSIXTH_ROOT}/CorsixTH/Src/midi_player.cpp"
    "${CORSIXTH_ROOT}/CorsixTH/Src/persist_lua.cpp"
    "${CORSIXTH_ROOT}/CorsixTH/Src/run_length_encoder.cpp"
    "${CORSIXTH_ROOT}/CorsixTH/Src/sdl_audio.cpp"
    "${CORSIXTH_ROOT}/CorsixTH/Src/sdl_core.cpp"
    "${CORSIXTH_ROOT}/CorsixTH/Src/sdl_wm.cpp"
    "${CORSIXTH_ROOT}/CorsixTH/Src/th.cpp"
    "${CORSIXTH_ROOT}/CorsixTH/Src/th_gfx.cpp"
    "${CORSIXTH_ROOT}/CorsixTH/Src/th_gfx_font.cpp"
    "${CORSIXTH_ROOT}/CorsixTH/Src/th_gfx_sdl.cpp"
    "${CORSIXTH_ROOT}/CorsixTH/Src/th_lua.cpp"
    "${CORSIXTH_ROOT}/CorsixTH/Src/th_lua_anims.cpp"
    "${CORSIXTH_ROOT}/CorsixTH/Src/th_lua_gfx.cpp"
    "${CORSIXTH_ROOT}/CorsixTH/Src/th_lua_iso.cpp"
    "${CORSIXTH_ROOT}/CorsixTH/Src/th_lua_lfs_ext.cpp"
    "${CORSIXTH_ROOT}/CorsixTH/Src/th_lua_map.cpp"
    "${CORSIXTH_ROOT}/CorsixTH/Src/th_lua_midi.cpp"
    "${CORSIXTH_ROOT}/CorsixTH/Src/th_lua_movie.cpp"
    "${CORSIXTH_ROOT}/CorsixTH/Src/th_lua_sound.cpp"
    "${CORSIXTH_ROOT}/CorsixTH/Src/th_lua_strings.cpp"
    "${CORSIXTH_ROOT}/CorsixTH/Src/th_lua_ui.cpp"
    "${CORSIXTH_ROOT}/CorsixTH/Src/th_map.cpp"
    "${CORSIXTH_ROOT}/CorsixTH/Src/th_map_overlays.cpp"
    "${CORSIXTH_ROOT}/CorsixTH/Src/th_movie.cpp"
    "${CORSIXTH_ROOT}/CorsixTH/Src/th_pathfind.cpp"
    "${CORSIXTH_ROOT}/CorsixTH/Src/th_sound.cpp"
    "${CORSIXTH_ROOT}/CorsixTH/Src/th_strings.cpp"
    "${CORSIXTH_ROOT}/CorsixTH/Src/xmi2mid.cpp"
    "${CORSIXTH_ROOT}/CorsixTH/Src/main.cpp"
    "${CMAKE_CURRENT_LIST_DIR}/src/fluid_player_stub.cpp"
)

# Asset catalog for AppIcon
set(CORSIXTH_IOS_ASSETS_CATALOG "${CMAKE_CURRENT_LIST_DIR}/Assets.xcassets")
set_source_files_properties(${CORSIXTH_IOS_ASSETS_CATALOG} PROPERTIES
    MACOSX_PACKAGE_LOCATION Resources
)

# App Executable Target
add_executable(corsixth_ios MACOSX_BUNDLE
    "${CMAKE_CURRENT_LIST_DIR}/src/ios_main.cpp"
    "${CMAKE_CURRENT_LIST_DIR}/src/ios_alert.mm"
    ${CORSIXTH_ENGINE_SOURCES}
    ${CORSIXTH_IOS_ASSETS_CATALOG}
)

target_include_directories(corsixth_ios PRIVATE
    "${CMAKE_CURRENT_BINARY_DIR}/CorsixTH/Src"
    "${CORSIXTH_ROOT}/CorsixTH/Src"
    "${CORSIXTH_ROOT}/CorsixTH/Lua"
    "${CMAKE_CURRENT_LIST_DIR}/include"
    "${CMAKE_CURRENT_LIST_DIR}/src"
    "${CMAKE_CURRENT_LIST_DIR}/third_party/lua/src"
    "${CMAKE_CURRENT_LIST_DIR}/third_party/zstd/lib"
    "${CMAKE_CURRENT_LIST_DIR}/third_party/freetype/include"
)

target_link_libraries(corsixth_ios PRIVATE
    lua_static
    RncLib
    WhereamiLib
    libzstd_static
    png_static
    freetype
    SDL3::SDL3-static
    SDL3_mixer::SDL3_mixer
    z
)

# Disable code signing for static library helper targets in Xcode
foreach(STATIC_TARGET IN ITEMS
    lua_static RncLib WhereamiLib libzstd_static png_static freetype SDL3-static SDL3_mixer-static
)
    if(TARGET ${STATIC_TARGET})
        set_target_properties(${STATIC_TARGET} PROPERTIES
            XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED "NO"
            XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED "NO"
            XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY ""
        )
    endif()
endforeach()

# Configure Bundle Properties & Signing
if(NOT DEFINED CORSIXTH_IOS_BUNDLE_IDENTIFIER)
    if(DEFINED ENV{CORSIXTH_IOS_BUNDLE_IDENTIFIER})
        set(CORSIXTH_IOS_BUNDLE_IDENTIFIER "$ENV{CORSIXTH_IOS_BUNDLE_IDENTIFIER}" CACHE STRING "Bundle identifier")
    else()
        set(CORSIXTH_IOS_BUNDLE_IDENTIFIER "org.corsixth.corsixth" CACHE STRING "Bundle identifier")
    endif()
endif()

set_target_properties(corsixth_ios PROPERTIES
    CXX_STANDARD 17
    CXX_STANDARD_REQUIRED ON
    CXX_EXTENSIONS OFF
    XCODE_ATTRIBUTE_CLANG_CXX_LANGUAGE_STANDARD "c++17"
    XCODE_ATTRIBUTE_CLANG_CXX_LIBRARY "libc++"
    MACOSX_BUNDLE TRUE
    MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_LIST_DIR}/Info.plist.in"
    XCODE_ATTRIBUTE_CODE_SIGN_STYLE "Automatic"
    XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY "Apple Development"
    XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "${CORSIXTH_IOS_BUNDLE_IDENTIFIER}"
    XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "1,2"
    XCODE_ATTRIBUTE_ASSETCATALOG_COMPILER_APPICON_NAME "AppIcon"
)

if(NOT DEFINED CORSIXTH_IOS_DEVELOPMENT_TEAM)
    if(DEFINED ENV{CORSIXTH_IOS_DEVELOPMENT_TEAM})
        set(CORSIXTH_IOS_DEVELOPMENT_TEAM "$ENV{CORSIXTH_IOS_DEVELOPMENT_TEAM}" CACHE STRING "Development team")
    else()
        set(CORSIXTH_IOS_DEVELOPMENT_TEAM "" CACHE STRING "Development team")
    endif()
endif()

if(CORSIXTH_IOS_DEVELOPMENT_TEAM)
    set_target_properties(corsixth_ios PROPERTIES
        XCODE_ATTRIBUTE_DEVELOPMENT_TEAM "${CORSIXTH_IOS_DEVELOPMENT_TEAM}"
    )
endif()

# Post-build: copy CorsixTH Lua scripts, bitmaps, levels, campaigns to the app bundle
add_custom_command(TARGET corsixth_ios POST_BUILD
    COMMAND "${CMAKE_COMMAND}" -E copy "${CORSIXTH_ROOT}/CorsixTH/CorsixTH.lua" "$<TARGET_BUNDLE_DIR:corsixth_ios>/CorsixTH.lua"
    COMMAND "${CMAKE_COMMAND}" -E copy_directory "${CORSIXTH_ROOT}/CorsixTH/Lua" "$<TARGET_BUNDLE_DIR:corsixth_ios>/Lua"
    COMMAND "${CMAKE_COMMAND}" -E copy_directory "${CORSIXTH_ROOT}/CorsixTH/Bitmap" "$<TARGET_BUNDLE_DIR:corsixth_ios>/Bitmap"
    COMMAND "${CMAKE_COMMAND}" -E copy_directory "${CORSIXTH_ROOT}/CorsixTH/Levels" "$<TARGET_BUNDLE_DIR:corsixth_ios>/Levels"
    COMMAND "${CMAKE_COMMAND}" -E copy_directory "${CORSIXTH_ROOT}/CorsixTH/Campaigns" "$<TARGET_BUNDLE_DIR:corsixth_ios>/Campaigns"
    COMMENT "Copying CorsixTH scripts and assets into the iOS app bundle"
)

if(EXISTS "${CORSIXTH_IOS_BUNDLED_ASSETS_DIR}")
    add_custom_command(TARGET corsixth_ios POST_BUILD
        COMMAND "${CMAKE_COMMAND}" -E make_directory "$<TARGET_BUNDLE_DIR:corsixth_ios>/assets"
        COMMAND "${CMAKE_COMMAND}" -E copy_directory "${CORSIXTH_IOS_BUNDLED_ASSETS_DIR}" "$<TARGET_BUNDLE_DIR:corsixth_ios>/assets/theme_hospital"
        COMMENT "Copying local Theme Hospital assets into the iOS debug bundle"
    )
endif()

add_custom_command(TARGET corsixth_ios POST_BUILD
    COMMAND /usr/bin/find "$<TARGET_BUNDLE_DIR:corsixth_ios>" -name ".DS_Store" -delete
    COMMAND /usr/bin/xattr -cr "$<TARGET_BUNDLE_DIR:corsixth_ios>"
    COMMENT "Stripping extended attributes and .DS_Store from iOS app bundle"
)
