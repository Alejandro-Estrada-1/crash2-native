/* Menú dentro del juego de recomp-ui para crash2-native.
 *
 * psxrecomp solo conecta solo el menú de recomp-ui en juegos multidisco
 * (PsxMenuHost.default_selection, runtime/src/main.cpp). Crash 2 es de un
 * disco, así que lo registramos aquí, como indica
 * psxrecomp/runtime/include/psx_menu_host.h: "a title that wants a provider
 * registers it with psx_menu_set_provider() before the game window opens
 * (for example from a static initializer in the title's own code)".
 *
 * Filas: Display > Fullscreen; Graphics > Renderer...; System > Resume,
 * Pause in menu, Return to launcher, Quit. Se abre con F10, Ctrl+L o
 * Select + L3 (recomp-ui/docs/RUNTIME_UI.md).
 *
 * Sin recomp-ui (PSX_RECOMP_UI=OFF) o con SDL2 este archivo no hace nada,
 * igual que la guarda equivalente de main.cpp. */

#include "psx_menu_host.h"

/* Misma detección que main.cpp (recomp_overlay_setup): el proveedor existe
 * solo si recomp-ui está en el include path. */
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
        fprintf(stderr, "crash2-native: el runtime rechazó el menú de recomp-ui "
                        "(ABI distinta); el menú dentro del juego queda desactivado\n");
}

#endif
