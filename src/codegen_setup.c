/* Configuración del asistente de primer uso ("Generate & rebuild") para
 * crash2-native. Basado en la plantilla del framework
 * (psxrecomp/tools/new_project_layout/templates/codegen_setup.c.in).
 *
 * El asistente corre en la máquina del usuario: lee su disco, ejecuta
 * psxrecomp_cli.py generate (C en generated/) y luego rebuild (build-release/).
 * El C generado nunca sale de esa máquina ni entra a git.
 *
 * En Linux, el CLI usa cmake, ninja, python3 y el compilador del PATH; si
 * falta alguno, falla con un mensaje claro y no descarga nada
 * (tools/toolchain_pack.py, ensure_toolchain). */

#include "codegen_setup.h"

#include "psxrecomp_codegen_host.h"

static const PsxrecompCodegenHostConfig kCodegenConfig = {
    .display_name = "crash2-native",
    .project_root_env = "CRASH2NATIVE_PROJECT_ROOT",
    .build_dir_env = "CRASH2NATIVE_BUILD_DIR",
    .force_setup_env = "CRASH2NATIVE_FORCE_SETUP",
    .psxrecomp_cli_relpath = "psxrecomp/psxrecomp_cli.py",
    .seed_cfg_relpath = "game.toml",
    .game_toml_relpath = "game.toml",
    .gen_marker_relpath = "generated/SCUS_941.54_dispatch.c",
    .build_dir_name = "build-release",
    .cmake_target = "psx-runtime",
    .exe_basename = "crash2_native",
    .prepare_note =
        "Uses your legal disc with the local psxrecomp SDK to generate "
        "BIOS + game C, then cmake --build. The product lives under "
        "build-release/; reopening this setup exe forwards there.",
    .prepare_note_windows = NULL,
    .prepare_note_no_cmake =
        "Uses your legal disc with the local psxrecomp SDK to generate "
        "BIOS + game C. Install CMake, Ninja, Python 3 and a C/C++ compiler, "
        "rebuild into build-release/, then relaunch this setup exe.",
};

void psx_game_codegen_setup_apply(RecompLauncherCGameInfo* gi) {
    psxrecomp_codegen_host_apply(gi, &kCodegenConfig);
}

void psx_game_codegen_relaunch_or_exit(const char* disc_path) {
    psxrecomp_codegen_host_relaunch_or_exit(disc_path);
}

void psx_game_codegen_forward_if_built(int argc, char** argv) {
    psxrecomp_codegen_host_forward_if_built(&kCodegenConfig, argc, argv);
}
