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

# --- Superficies opcionales del framework ----------------------------------
# Valores por defecto de este proyecto; se pueden cambiar con -D al configurar
# (sin FORCE, para que la línea de comandos mande).
# - recomp-ui (launcher) apagado para el primer arranque: menos variables.
#   Se enciende junto con el asistente de primer uso más adelante.
# - Vulkan apagado: el renderizador por defecto es OpenGL y así la compilación
#   no depende de que glslc esté instalado o no.
set(PSX_RECOMP_UI OFF CACHE BOOL "Launcher recomp-ui")
set(PSX_ENABLE_VULKAN OFF CACHE BOOL "Renderizador Vulkan experimental")

include("${PSXRECOMP_ROOT}/runtime/runtime.cmake")

psxrecomp_add_game_runtime(psx-runtime
    PRELOADED_MODS_DIR "NONE"
    WINDOW_TITLE "crash2-native"
    DEFAULT_GAME_CONFIG_PATH "game.toml"
    MAX_PLAYERS 1
    GEN_MARKER "generated/SCUS_941.54_dispatch.c"
    GEN_FULL_GLOB "generated/SCUS_941.54_full_*.c"
)

# Copia game.toml junto al ejecutable para lanzarlo directo desde build-*/.
add_custom_command(TARGET psx-runtime POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${CMAKE_CURRENT_SOURCE_DIR}/game.toml"
        "$<TARGET_FILE_DIR:psx-runtime>/game.toml"
    COMMENT "Copiando game.toml junto al ejecutable"
    VERBATIM)
