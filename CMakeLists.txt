cmake_minimum_required(VERSION 3.20)

# crash2-native: runtime de psxrecomp + C generado de SCUS_941.54.
# El C generado (generated/) NUNCA entra a git: se produce en local con
# scripts/build_linux.sh. Sin él, el framework compila solo el "setup host".

set(PSXRECOMP_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/psxrecomp" CACHE PATH
    "Ruta al submódulo psxrecomp")
if(NOT EXISTS "${PSXRECOMP_ROOT}/runtime/runtime.cmake")
    message(FATAL_ERROR
        "Falta el runtime de psxrecomp: ${PSXRECOMP_ROOT}/runtime/runtime.cmake\n"
        "Ejecuta scripts/setup.sh (o git submodule update --init --recursive).")
endif()

project(Crash2Native LANGUAGES C CXX)

# Modo AppImage: activado solo cuando AppRun o release.yml exportan
# CRASH2NATIVE_APPIMAGE_TOOLCHAIN=1. Evita depender de opcionales del sistema
# (OpenSSL/Freetype/HarfBuzz/ZLIB/SDL3), fuerza descargas offline desde
# psxrecomp/third_party/ y añade rutas multiarch para find_library(GL/X11/ALSA)
# con zig cc. No altera scripts/build_linux.sh ni builds locales normales.
if(DEFINED ENV{CRASH2NATIVE_APPIMAGE_TOOLCHAIN}
   AND NOT "$ENV{CRASH2NATIVE_APPIMAGE_TOOLCHAIN}" STREQUAL ""
   AND NOT "$ENV{CRASH2NATIVE_APPIMAGE_TOOLCHAIN}" STREQUAL "0")
    set(PSX_DEPS_OFFLINE ON CACHE BOOL
        "Usar archivos vendorizados en psxrecomp/third_party/" FORCE)
    foreach(_crash2_pkg SDL3 ZLIB OpenSSL Freetype PkgConfig)
        set(CMAKE_DISABLE_FIND_PACKAGE_${_crash2_pkg} ON CACHE BOOL
            "Desactivado en modo AppImage para portabilidad" FORCE)
    endforeach()
    unset(_crash2_pkg)
    list(APPEND CMAKE_LIBRARY_PATH
        "/usr/lib/x86_64-linux-gnu"
        "/lib/x86_64-linux-gnu"
        "/usr/lib64"
        "/usr/lib")
    list(REMOVE_DUPLICATES CMAKE_LIBRARY_PATH)
endif()

# --- Superficies opcionales del framework ----------------------------------
# Valores por defecto de este proyecto; se pueden cambiar con -D al configurar
# (sin FORCE, para que la línea de comandos mande). Ojo: un build ya
# configurado conserva el valor de su caché; scripts/build_linux.sh pasa
# PSX_RECOMP_UI explícito para no depender de eso.
# - recomp-ui encendido: launcher al arrancar (--no-launcher lo salta), OSD
#   (FPS con F), menú dentro del juego y asistente Generate & rebuild.
# - Vulkan apagado: el renderizador por defecto es OpenGL y así la compilación
#   no depende de que glslc esté instalado o no.
set(PSX_RECOMP_UI ON CACHE BOOL "Launcher recomp-ui")
set(PSX_ENABLE_VULKAN OFF CACHE BOOL "Renderizador Vulkan experimental")

include("${PSXRECOMP_ROOT}/runtime/runtime.cmake")

# Con recomp-ui: asistente de primer uso (elige el disco y hace Generate &
# rebuild en la máquina del usuario) y su configuración en src/codegen_setup.c.
# Sin generated/ (o con -DPSXRECOMP_FORCE_SETUP_HOST=ON) se compila solo ese
# "setup host", que es lo que puede compilar el CI sin el disco.
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

# Menú dentro del juego para un título de un disco (ver src/menu_provider.c).
# Sin recomp-ui el archivo compila vacío.
foreach(_crash2_t psx-runtime psx-runtime-pgxp)
    if(TARGET ${_crash2_t})
        target_sources(${_crash2_t} PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/src/menu_provider.c")
    endif()
endforeach()

# Copia game.toml junto al ejecutable para lanzarlo directo desde build-*/.
add_custom_command(TARGET psx-runtime POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${CMAKE_CURRENT_SOURCE_DIR}/game.toml"
        "$<TARGET_FILE_DIR:psx-runtime>/game.toml"
    COMMENT "Copiando game.toml junto al ejecutable"
    VERBATIM)
