/* psxrecomp "codegen host" configuration for crash2-native.
 * Based on psxrecomp/tools/new_project_layout/templates/codegen_setup.h.in.
 * Compiled only when PSX_RECOMP_UI=ON (requires recomp_launcher.h). */
#ifndef CODEGEN_SETUP_H
#define CODEGEN_SETUP_H

#include "recomp_launcher.h"

#ifdef __cplusplus
extern "C" {
#endif

void psx_game_codegen_setup_apply(RecompLauncherCGameInfo* gi);
void psx_game_codegen_relaunch_or_exit(const char* disc_path);
void psx_game_codegen_forward_if_built(int argc, char** argv);

#ifdef __cplusplus
}
#endif

#endif
