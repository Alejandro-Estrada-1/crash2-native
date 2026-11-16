/* In-game recomp-ui menu registration for crash2-native.
 *
 * psxrecomp automatically attaches the recomp-ui menu only for multi-disc
 * titles (PsxMenuHost.default_selection, runtime/src/main.cpp). Crash 2 is
 * single-disc, so we register it here as documented in
 * psxrecomp/runtime/include/psx_menu_host.h: "a title that wants a provider
 * registers it with psx_menu_set_provider() before the game window opens
 * (for example from a static initializer in the title's own code)".
 *
 * Rows: Display > Fullscreen; Graphics > Renderer...; System > Resume,
 * Pause in menu, Return to launcher, Quit. Opened via F10, Ctrl+L, or
 * Select + L3 (recomp-ui/docs/RUNTIME_UI.md).
 *
 * Without recomp-ui (PSX_RECOMP_UI=OFF) or under SDL2 this unit compiles empty,
 * matching the equivalent guard in main.cpp. */

#include "psx_menu_host.h"

/* Same detection as main.cpp (recomp_overlay_setup): the provider exists
 * only when recomp-ui is on the include path. */
#if defined(__has_include)
#if __has_include("recomp_ui_psx_menu.h")
#include "recomp_ui_psx_menu.h"
#define CRASH2_HAS_RECOMP_UI_MENU 1
#endif
#endif

#if defined(RECOMP_LAUNCHER) && defined(CRASH2_HAS_RECOMP_UI_MENU) && defined(PSX_SDL3)

#include <stdio.h>

__attribute__((constructor))
static void crash2_register_menu_provider(void) {
    if (!psx_menu_set_provider(recomp_ui_psx_menu_provider()))
        fprintf(stderr, "crash2-native: runtime rejected recomp-ui menu "
                        "(ABI mismatch); in-game menu disabled\n");
}

#endif
