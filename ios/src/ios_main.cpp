/*
  iOS Main entry point for CorsixTH on iPadOS.
  Prepares sandbox environment, Documents directory, and launches SDL3 / Lua loop.
*/

#include "../../CorsixTH/Src/main.h"
#include "config.h"

#include <SDL3/SDL.h>
#include <SDL3/SDL_main.h>
#include <SDL3_mixer/SDL_mixer.h>

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <memory>
#include <string>
#include <sys/stat.h>
#include <unistd.h>

#include "../../CorsixTH/Src/bootstrap.h"
#include "../../CorsixTH/Src/lua.hpp"
#include "../../CorsixTH/Src/sdl_core.h"
#include "../../CorsixTH/Src/th_lua.h"
#include "../../CorsixTH/Src/th_sound.h"

template <typename T1, typename T2>
struct types_equal {
  enum {
    result = -1,
  };
};

template <typename T1>
struct types_equal<T1, T1> {
  enum {
    result = 1,
  };
};

static bool directory_exists(const char* path) {
  struct stat info;
  return path && stat(path, &info) == 0 && S_ISDIR(info.st_mode);
}

static bool file_exists(const char* path) {
  struct stat info;
  return path && stat(path, &info) == 0 && S_ISREG(info.st_mode);
}

static std::string join_path(const std::string& left, const char* right) {
  if (left.empty()) {
    return right ? std::string(right) : std::string();
  }
  if (!right || !right[0]) {
    return left;
  }
  if (left.back() == '/') {
    return left + right;
  }
  return left + "/" + right;
}

static std::string parent_path(const std::string& path) {
  std::string::size_type slash = path.find_last_of('/');
  if (slash == std::string::npos) {
    return ".";
  }
  if (slash == 0) {
    return "/";
  }
  return path.substr(0, slash);
}

static bool make_directory(const char* path) {
  if (!path || !path[0]) {
    return false;
  }
  if (mkdir(path, 0755) == 0) {
    return true;
  }
  return errno == EEXIST && directory_exists(path);
}

static bool make_directories(const std::string& path) {
  if (path.empty()) {
    return false;
  }
  std::string current;
  std::string::size_type index = 0;
  if (path[0] == '/') {
    current = "/";
    index = 1;
  }
  while (index < path.size()) {
    std::string::size_type slash = path.find('/', index);
    std::string part = slash == std::string::npos ? path.substr(index) : path.substr(index, slash - index);
    if (!part.empty()) {
      if (!current.empty() && current.back() != '/') {
        current += "/";
      }
      current += part;
      if (!make_directory(current.c_str())) {
        return false;
      }
    }
    if (slash == std::string::npos) {
      break;
    }
    index = slash + 1;
  }
  return directory_exists(path.c_str());
}

static bool copy_file(const char* source, const char* dest) {
  int in = open(source, O_RDONLY);
  if (in < 0) {
    return false;
  }
  if (!make_directories(parent_path(dest))) {
    close(in);
    return false;
  }
  int out = open(dest, O_WRONLY | O_CREAT | O_TRUNC, 0644);
  if (out < 0) {
    close(in);
    return false;
  }
  char buffer[32768];
  bool ok = true;
  for (;;) {
    ssize_t bytes = read(in, buffer, sizeof(buffer));
    if (bytes == 0) {
      break;
    }
    if (bytes < 0) {
      ok = false;
      break;
    }
    const char* cursor = buffer;
    ssize_t remaining = bytes;
    while (remaining > 0) {
      ssize_t written = write(out, cursor, (size_t)remaining);
      if (written <= 0) {
        ok = false;
        remaining = 0;
        break;
      }
      cursor += written;
      remaining -= written;
    }
    if (!ok) break;
  }
  if (close(out) != 0) {
    ok = false;
  }
  close(in);
  return ok;
}

static bool copy_directory_recursive(const char* source, const char* dest) {
  DIR* dir = opendir(source);
  if (!dir) {
    return false;
  }
  if (!make_directories(dest)) {
    closedir(dir);
    return false;
  }
  bool ok = true;
  for (;;) {
    struct dirent* entry = readdir(dir);
    if (!entry) {
      break;
    }
    if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) {
      continue;
    }
    std::string source_path = join_path(source, entry->d_name);
    std::string dest_path = join_path(dest, entry->d_name);
    struct stat info;
    if (lstat(source_path.c_str(), &info) != 0) {
      ok = false;
      break;
    }
    if (S_ISDIR(info.st_mode)) {
      if (!copy_directory_recursive(source_path.c_str(), dest_path.c_str())) {
        ok = false;
        break;
      }
    } else if (S_ISREG(info.st_mode)) {
      if (!copy_file(source_path.c_str(), dest_path.c_str())) {
        ok = false;
        break;
      }
    }
  }
  closedir(dir);
  return ok;
}

static void prepare_ios_environment() {
  const char* home = getenv("HOME");
  if (!home) return;
  std::string docs = std::string(home) + "/Documents";
  make_directories(docs);

  // Direct CorsixTH config.txt and Saves to user-accessible Documents directory
  setenv("XDG_CONFIG_HOME", docs.c_str(), 1);

  // iOS sandbox does not provide USER or USERNAME by default; provide a fallback
  setenv("USER", "Player", 0);
  setenv("USERNAME", "Player", 0);

  std::printf("[CorsixTH iOS] HOME: %s\n", home);
  std::printf("[CorsixTH iOS] Documents: %s\n", docs.c_str());

  // Check if theme hospital assets already exist in Documents/HOSP
  std::string hosp_dest = docs + "/HOSP";
  bool has_assets = directory_exists((hosp_dest + "/DATA").c_str()) ||
                    directory_exists((hosp_dest + "/data").c_str());

  if (!has_assets) {
    const char* base_path = SDL_GetBasePath();
    if (base_path) {
      std::string bundle_assets = std::string(base_path) + "assets/theme_hospital";
      if (directory_exists(bundle_assets.c_str())) {
        std::printf("[CorsixTH iOS] Copying bundled game assets into %s...\n", hosp_dest.c_str());
        copy_directory_recursive(bundle_assets.c_str(), hosp_dest.c_str());
      }
    }
  }
}

int main(int argc, char** argv) {
  struct compile_time_lua_check {
    int lua_5_point_1_required[LUA_VERSION_NUM >= 501 ? 1 : -1];
    int number_is_double[types_equal<lua_Number, double>::result];
  };

  prepare_ios_environment();

  SDL_SetHint(SDL_HINT_ORIENTATIONS,
              "LandscapeLeft LandscapeRight Portrait PortraitUpsideDown");

  bool bRun = true;

  while (bRun) {
    lua_state_unique_ptr L(luaL_newstate());
    if (L == nullptr) {
      std::fprintf(stderr,
                   "Fatal error starting CorsixTH: "
                   "Cannot open Lua state.\n");
      return 0;
    }
    lua_atpanic(L.get(), lua_panic);
    luaL_openlibs(L.get());
    lua_settop(L.get(), 0);
    lua_pushcfunction(L.get(), lua_stacktrace);
    lua_pushcfunction(L.get(), lua_init);

    lua_checkstack(L.get(), argc);
    for (int i = 0; i < argc; ++i) {
      lua_pushstring(L.get(), argv[i]);
    }

    if (lua_pcall(L.get(), argc, 0, 1) != 0) {
      const char* err = lua_tostring(L.get(), -1);
      if (err != nullptr) {
        std::fprintf(stderr, "%s\n", err);
      } else {
        std::fprintf(stderr,
                     "An error has occurred in CorsixTH:\n"
                     "Uncaught non-string Lua error\n");
      }
      lua_pushcfunction(L.get(), bootstrap_lua_error_report);
      lua_insert(L.get(), -2);
      if (lua_pcall(L.get(), 1, 0, 0) != 0) {
        std::fprintf(stderr, "%s\n", lua_tostring(L.get(), -1));
      }
    }
    mainloop(L.get());

    lua_getfield(L.get(), LUA_REGISTRYINDEX, "_RESTART");
    bRun = lua_toboolean(L.get(), -1) != 0;

    L.reset(nullptr);
    th::sound::quit();
    MIX_Quit();
    SDL_Quit();

    if (bRun) {
      std::printf("\n\nRestarting...\n\n\n");
    }
  }

  return 0;
}
