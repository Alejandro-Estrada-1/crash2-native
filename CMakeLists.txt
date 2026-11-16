cmake_minimum_required(VERSION 3.20)

# crash2-native: psxrecomp runtime + generated C from SCUS_941.54.
# Generated C (generated/) NEVER enters git: it is produced locally with
# scripts/build_linux.sh. Without it, the framework builds only the setup host.

set(PSXRECOMP_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/psxrecomp" CACHE PATH
    "Path to the psxrecomp submodule")
if(NOT EXISTS "${PSXRECOMP_ROOT}/runtime/runtime.cmake")
    message(FATAL_ERROR
        "Missing psxrecomp runtime: ${PSXRECOMP_ROOT}/runtime/runtime.cmake\n"
        "Run scripts/setup.sh (or git submodule update --init --recursive).")
endif()

project(Crash2Native LANGUAGES C CXX)

# AppImage mode: enabled only when AppRun or release.yml exports
# CRASH2NATIVE_APPIMAGE_TOOLCHAIN=1. Avoids relying on optional system libraries
# (OpenSSL/Freetype/HarfBuzz/ZLIB/SDL3), forces offline builds from vendored
# psxrecomp/third_party/ archives, and adds multiarch library search paths for
# find_library(GL/X11/ALSA) under zig cc. Leaves scripts/build_linux.sh and
# normal local builds unchanged.
if(DEFINED ENV{CRASH2NATIVE_APPIMAGE_TOOLCHAIN}
   AND NOT "$ENV{CRASH2NATIVE_APPIMAGE_TOOLCHAIN}" STREQUAL ""
   AND NOT "$ENV{CRASH2NATIVE_APPIMAGE_TOOLCHAIN}" STREQUAL "0")
    set(PSX_DEPS_OFFLINE ON CACHE BOOL
        "Use vendored archives under psxrecomp/third_party/" FORCE)
    foreach(_crash2_pkg SDL3 ZLIB OpenSSL Freetype PkgConfig)
        set(CMAKE_DISABLE_FIND_PACKAGE_${_crash2_pkg} ON CACHE BOOL
            "Disabled in AppImage mode for portability" FORCE)
    endforeach()
    unset(_crash2_pkg)
    list(APPEND CMAKE_LIBRARY_PATH
        "/usr/lib/x86_64-linux-gnu"
        "/lib/x86_64-linux-gnu"
        "/usr/lib64"
        "/usr/lib")
    list(REMOVE_DUPLICATES CMAKE_LIBRARY_PATH)
endif()

# --- Optional framework surfaces -------------------------------------------
# Project defaults; overridable with -D at configure time (without FORCE so
# CLI flags win). Note: an existing build retains its cache value;
# scripts/build_linux.sh passes PSX_RECOMP_UI explicitly to avoid depending on it.
# - recomp-ui on: startup launcher (--no-launcher skips it), OSD (FPS on F),
#   in-game pause menu, and Generate & rebuild wizard.
# - Vulkan off: default renderer is OpenGL so builds do not require glslc.
set(PSX_RECOMP_UI ON CACHE BOOL "recomp-ui launcher")
set(PSX_ENABLE_VULKAN OFF CACHE BOOL "Experimental Vulkan renderer")

include("${PSXRECOMP_ROOT}/runtime/runtime.cmake")

# With recomp-ui: first-run wizard (picks the disc and runs Generate & rebuild
# on the user's machine) configured in src/codegen_setup.c. Without generated/
# (or with -DPSXRECOMP_FORCE_SETUP_HOST=ON), only this setup host is built,
# which is what CI validates without a game disc.
set(_crash2_ui_args)
if(PSX_RECOMP_UI)
    list(APPEND _crash2_ui_args
        ENABLE_SETUP_WIZARD
        CODEGEN_SETUP_INCLUDE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/src"
        CODEGEN_SETUP_SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/src/codegen_setup.c")
endif()

psxrecomp_add_game_runtime(psx-runtime
    PRELOADED_MODS_DIR "NONE"
    WINDOW_TITLE "crash2-native"
    DEFAULT_GAME_CONFIG_PATH "game.toml"
    MAX_PLAYERS 1
    GEN_MARKER "generated/SCUS_941.54_dispatch.c"
    GEN_FULL_GLOB "generated/SCUS_941.54_full_*.c"
    ${_crash2_ui_args}
)

# In-game menu for a single-disc title (see src/menu_provider.c).
# Compiles to an empty translation unit when recomp-ui is disabled.
foreach(_crash2_t psx-runtime psx-runtime-pgxp)
    if(TARGET ${_crash2_t})
        target_sources(${_crash2_t} PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/src/menu_provider.c")
    endif()
endforeach()

# Copy game.toml beside the executable for direct launches from build-*/.
add_custom_command(TARGET psx-runtime POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${CMAKE_CURRENT_SOURCE_DIR}/game.toml"
        "$<TARGET_FILE_DIR:psx-runtime>/game.toml"
    COMMENT "Copying game.toml next to executable"
    VERBATIM)
