# ------------------------------------------------------------------
# Experimento 004: Prueba discriminante sobre 0x8004A3xx
#                  (¿reescritura del juego o del runtime de psxrecomp?)
#
# Precondición:  PCSX-Redux corriendo con SCUS-94154 ya inicializado tras
#                InitPAD (p. ej. estado guardado en slot 1 dentro del primer
#                nivel, Crash quieto; o menú de pausa). GDB en :3333.
# Módulo:        main (SCUS_941.54, 0x8004a2ec..0x8004a47f) y RAM de kernel
# Hipótesis:     En el binario original SCUS_941.54 no existe ninguna escritura
#                sobre 0x8004a2ec..0x8004a47f. Si el runtime de psxrecomp es
#                quien reescribe 0x8004a308/a3a8/a440 con `nop; nop; b +N; nop`
#                (para evitar el parcheo directo sobre BIOS), entonces en el
#                juego original (PCSX-Redux) esas direcciones deben conservar
#                intactas las instrucciones del EXE (`0x8c42016c` = `lw v0,0x16c(v0)`).
# Éxito (autor = psxrecomp):
#                1) Todo 0x8004a2ec..0x8004a47f en RAM viva es idéntico palabra
#                   por palabra a SCUS_941.54; en particular:
#                   - 0x8004a308 == 0x8c42016c, 0x8004a30c == 0x3c018006
#                   - 0x8004a3a8 == 0x8c42016c, 0x8004a3ac == 0x3c0a8005
#                   - 0x8004a440 == 0x8c42016c, 0x8004a444 == 0x240a0009
#                2) *0x8005f32c != 0 y la RAM del BIOS en pad_base muestra los
#                   parches aplicados por _patch_pad/_send_pad/_remove_ChgclrPAD.
# Fallo (autor = juego u overlay):
#                0x8004a308, 0x8004a3a8 o 0x8004a440 contienen `0x00000000`
#                (`nop`) o una instrucción distinta de `SCUS_941.54`.
# Escribe en memoria: no (solo lectura)
# ------------------------------------------------------------------

echo === [004] Foco 1: _patch_pad desde 0x8004a308 (esperado: 8c42016c 3c018006 20430884 ac23f32c ...) ===\n
x/14wx 0x8004a308

echo === [004] Foco 2: _send_pad desde 0x8004a3a8 (esperado: 8c42016c 3c0a8005 3c098005 3c018006 ...) ===\n
x/16wx 0x8004a3a8

echo === [004] Foco 3: _remove_ChgclrPAD desde 0x8004a440 (esperado: 8c42016c 240a0009 2043062c 254affff ...) ===\n
x/10wx 0x8004a440

echo === [004] Bloque completo 0x8004a2ec..0x8004a47f (101 palabras) vs SCUS_941.54 ===\n
x/101wx 0x8004a2ec

echo === [004] Punteros y estado en 0x8005f324..0x8005f347 ===\n
x/9wx 0x8005f324

if *(unsigned int*)0x8005f32c != 0
  set $pad_base = *(unsigned int*)0x8005f32c - 0x884
  printf "pad_base (*(B0:57+0x16c)) = 0x%08x\n", $pad_base
  printf "DAT_8005f32c (EnablePAD)  = 0x%08x (esperado pad_base+0x884)\n", *(unsigned int*)0x8005f32c
  printf "DAT_8005f330 (DisablePAD) = 0x%08x (esperado pad_base+0x894)\n", *(unsigned int*)0x8005f330
  printf "DAT_8005f338 (_SendPAD)   = 0x%08x (esperado pad_base+0x7a0)\n", *(unsigned int*)0x8005f338

  echo === [004] Parche _send_pad: pad_base + 0x3d8 (4 palabras, esperado 00551024 0 0 0) ===\n
  x/4wx ($pad_base + 0x3d8)

  echo === [004] Parche _send_pad: pad_base + 0x4e0 (4 palabras, esperado 00551024 0 0 0) ===\n
  x/4wx ($pad_base + 0x4e0)

  echo === [004] Parche _patch_pad: pad_base + 0x594 (11 palabras, esperado todo 0) ===\n
  x/11wx ($pad_base + 0x594)

  echo === [004] Parche _remove_ChgclrPAD: pad_base + 0x62c (9 palabras, esperado todo 0) ===\n
  x/9wx ($pad_base + 0x62c)
else
  echo AVISO: DAT_8005f32c es 0 (InitPAD/_patch_pad no ejecutado o puenteado)\n
end

detach
