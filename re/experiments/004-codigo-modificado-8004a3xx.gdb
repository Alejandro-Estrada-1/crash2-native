# ------------------------------------------------------------------
# Experimento 004: Inspección de 0x8004A3xx y parches en RAM de BIOS
#
# Precondición:  Cualquier estado con el juego ya inicializado tras boot
#                (p. ej. slot 1 dentro del primer nivel, tras InitPAD).
# Módulo:        main (SCUS_941.54, 0x8004a2ec..0x8004a47c) y RAM de kernel
# Hipótesis:     1) El rango 0x8004a2ec..0x8004a47c en RAM viva coincide palabra
#                   por palabra con SCUS_941.54 (no es automodificado).
#                2) El código que el juego modifica en tiempo de ejecución vive
#                   en RAM del BIOS/kernel (puntero base = *(B0:57+0x16c),
#                   recuperable sin invocar B0:57 como *0x8005f32c - 0x884), donde
#                   _patch_pad, _send_pad y _remove_ChgclrPAD escriben sobre
#                   base+0x3d8, +0x4e0, +0x594 y +0x62c.
# Éxito:         0x8004a2ec..0x8004a47c coincide exactamente con el EXE estático;
#                *0x8005f32c != 0; base+0x3d8 y base+0x4e0 contienen
#                0x00551024 0x00000000 0x00000000 0x00000000; base+0x594 (11
#                palabras) y base+0x62c (9 palabras) están en 0x00000000.
# Fallo:         Alguna palabra en 0x8004a2ec..0x8004a47c difiere de SCUS_941.54,
#                o *0x8005f32c es 0, o los bloques en BIOS RAM no reflejan los
#                parches esperados.
# Escribe en memoria: no (solo lectura)
# ------------------------------------------------------------------

echo === [004] Palabras en RAM viva 0x8004a2ec..0x8004a47c (_patch_pad.._remove_ChgclrPAD) ===\n
x/104wx 0x8004a2ec

echo === [004] Punteros y estado en 0x8005f324..0x8005f347 ===\n
x/9wx 0x8005f324

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

detach
