# ------------------------------------------------------------------
# Experimento 002: Frecuencia de 0x80016838 y disparos de 0x80016868
#
# Precondición:  PCSX-Redux con servidor GDB activo y Dynarec desactivado;
#                cargar un estado guardado dentro de un nivel jugable (ej.
#                slot 1: Turtle Woods). Se recomienda ejecutar con
#                PSX_GDB_TIMEOUT=60 por el número de paradas TCP (~60-120).
#                Nota: como cada breakpoint detiene la PS1 emulada, el cálculo
#                de frecuencia usa los ticks emulados de DAT_8003bea4 (que se
#                pausan junto con la CPU); para capturas largas de minutos sin
#                pausar cuadros, pasar este conteo a un script Lua.
# Módulo:        main (0x80016838, 0x80016868, 0x8003bea4, 0x8006ccf0)
# Hipótesis:     FUN_8001645c llama a VSync(0) en 0x80016838 una vez por cuadro
#                lógico (~30 Hz en NTSC, ~2067 ticks de DAT_8003bea4 cada 60
#                cuadros si se confirma ~1033.6 Hz). El VSync(0) extra en
#                0x80016868 se dispara cuando el cuadro tardó < 0x19 (25) ticks
#                (~24.2 ms), limitando el juego a 30 Hz en escenas ligeras.
# Éxito:         En 60 iteraciones consecutivas de 0x80016838:
#                - delta(DAT_8006ccf0) == 60 (1 llamada a 0x80016838 por cuadro)
#                - delta(DAT_8003bea4) ≈ 2067 ticks para 60 cuadros (~30 Hz)
#                - se registra cuántas de las 60 pasadas ejecutaron 0x80016868
#                  (esperado: mayoría en escena ligera/Crash quieto).
# Fallo:         El breakpoint en 0x80016838 no salta en PSX_GDB_TIMEOUT
#                segundos, delta(DAT_8006ccf0) != 60, o la tasa por cuadro
#                difiere claramente de 30 Hz (p. ej. ~60 Hz si 0x80016868 = 0
#                y ~17 ticks/cuadro en escena ligera).
# Escribe en memoria: no
# ------------------------------------------------------------------

set $target_frames = 60
set $hits_6838 = 0
set $hits_6868 = 0
set $t_start = 0
set $c_start = 0

break *0x80016838
commands
  silent
  set $t_now = *(unsigned int *)0x8003bea4
  set $c_now = *(unsigned int *)0x8006ccf0
  if $hits_6838 == 0
    set $t_start = $t_now
    set $c_start = $c_now
  end
  set $hits_6838 = $hits_6838 + 1
  if $hits_6838 <= $target_frames
    continue
  end
  set $dt_ticks = $t_now - $t_start
  set $dc_frames = $c_now - $c_start
  printf "resumen (%u cuadros completos entre paso 1 y paso %u de 0x80016838):\n", $target_frames, $hits_6838
  printf "  cuadros medidos (0x80016838) = %u\n", $target_frames
  printf "  disparos 0x80016868 (VSync extra) = %u\n", $hits_6868
  printf "  delta DAT_8006ccf0 = %u\n", $dc_frames
  printf "  delta DAT_8003bea4 = %u ticks (ticks/cuadro = %u)\n", $dt_ticks, ($dt_ticks / $target_frames)
end

break *0x80016868
commands
  silent
  set $hits_6868 = $hits_6868 + 1
  continue
end

continue
delete
detach
