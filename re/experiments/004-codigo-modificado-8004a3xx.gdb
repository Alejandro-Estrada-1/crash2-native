# ------------------------------------------------------------------
# Experimento 004: Verificación en PCSX-Redux del parcheo de OpenBIOS
#                  sobre 0x8004A308 / 0x8004A3A8 / 0x8004A440
#
# Precondición:  PCSX-Redux corriendo con SCUS-94154 ya inicializado tras
#                InitPAD (p. ej. estado guardado en slot 1 dentro del primer
#                nivel, Crash quieto; o menú de pausa). GDB en :3333.
# BIOS:          OpenBIOS (integrada en PCSX-Redux; pendiente confirmar
#                versión/build ID exacto al ejecutar)
# Módulo:        main (SCUS_941.54, 0x8004a2ec..0x8004a47f)
# Hipótesis:     En el binario estático SCUS_941.54 nadie escribe sobre
#                0x8004A3xx, pero OpenBIOS intercepta GetB0Table (B0:57) vía
#                getB0table -> patch_hook($ra): parchea DAT_8005f32c/30/38
#                en RAM y reescribe las 4 palabras desde $ra en el llamador
#                con `nop; nop; b +N; nop` para saltar la escritura sobre BIOS:
#                - _patch_pad        (0x8004a308): nop; nop; b +10 (0x1000000a); nop -> 0x8004a33c
#                - _send_pad         (0x8004a3a8): nop; nop; b +12 (0x1000000c); nop -> 0x8004a3e4
#                - _remove_ChgclrPAD (0x8004a440): nop; nop; b +5  (0x10000005); nop -> 0x8004a460
# Éxito:         En RAM viva de PCSX-Redux (con OpenBIOS), las tres ventanas
#                muestran esa reescritura (`0x00000000 0x00000000 0x100000xx
#                0x00000000`) y DAT_8005f32c/30/38 quedan poblados por el hook.
# Fallo:         0x8004a308 / 0x8004a3a8 / 0x8004a440 conservan `0x8c42016c`
#                (`lw v0,0x16c(v0)` del EXE sin modificar) o muestran otros
#                opcodes distintos al patrón de OpenBIOS.
# Escribe en memoria: no (solo lectura)
# ------------------------------------------------------------------

echo === [004] Foco 1: _patch_pad en 0x8004a308 (EXE: 8c42016c... | OpenBIOS: 0 0 1000000a 0) ===\n
x/14wx 0x8004a308

echo === [004] Foco 2: _send_pad en 0x8004a3a8 (EXE: 8c42016c... | OpenBIOS: 0 0 1000000c 0) ===\n
x/16wx 0x8004a3a8

echo === [004] Foco 3: _remove_ChgclrPAD en 0x8004a440 (EXE: 8c42016c... | OpenBIOS: 0 0 10000005 0) ===\n
x/10wx 0x8004a440

echo === [004] Bloque completo 0x8004a2ec..0x8004a47f (101 palabras) ===\n
x/101wx 0x8004a2ec

echo === [004] Punteros y estado en 0x8005f324..0x8005f347 ===\n
x/9wx 0x8005f324

printf "DAT_8005f32c (EnablePAD)  = 0x%08x\n", *(unsigned int*)0x8005f32c
printf "DAT_8005f330 (DisablePAD) = 0x%08x\n", *(unsigned int*)0x8005f330
printf "DAT_8005f338 (_SendPAD)   = 0x%08x\n", *(unsigned int*)0x8005f338

detach
