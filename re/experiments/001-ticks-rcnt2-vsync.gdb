# ------------------------------------------------------------------
# Experimento 001: Ticks de DAT_8003bea4 entre dos VSync
#
# Precondición:  PCSX-Redux con servidor GDB activo y Dynarec desactivado;
#                cargar un estado guardado en gameplay estable (ej. slot 1:
#                inicio de Turtle Woods, Crash quieto) o en pantalla de mapa,
#                donde FUN_8001645c se ejecute de forma continua.
# Módulo:        main (0x80016840, 0x80016868, 0x80016870, 0x8003bea4)
# Hipótesis:     DAT_8003bea4 avanza ~17 ticks (0x11) durante un único VSync
#                (confirmando el supuesto divisor /8 de RCntCNT2 con target
#                0x1000 en 60 Hz NTSC) y ~34 ticks (0x22) por cuadro de 30 Hz.
#                Medición pura de 1 VSync: entre el retorno de VSync(0) de
#                0x80016838 (en 0x80016840) y el retorno del VSync(0) extra de
#                0x80016868 (en 0x80016870 cuando pasó por 0x80016868).
# Éxito:         En los cuadros donde salta 0x80016868, delta_1_vsync está
#                entre 16 y 18 ticks (~17 = 0x11), y delta_frame entre dos
#                pasadas consecutivas por 0x80016840 es ~34 (0x22).
# Fallo:         El breakpoint en 0x80016840 no salta en PSX_GDB_TIMEOUT
#                segundos, o delta_1_vsync difiere claramente de ~17 ticks
#                (p. ej. ~137 si fuese SysClk/1, ~1-2, o 0 si el contador está
#                detenido por DAT_8006cb94 & 0x200000).
# Escribe en memoria: no
# ------------------------------------------------------------------

set $frames = 0
set $max_frames = 12
set $prev_tick = 0
set $tick_6840 = 0
set $in_extra = 0

break *0x80016840
commands
  silent
  set $cur = *(unsigned int *)0x8003bea4
  if $frames > 0
    printf "cuadro %02d @0x80016840: DAT_8003bea4=0x%08x (%u)  delta_frame=%u\n", $frames, $cur, $cur, ($cur - $prev_tick)
  else
    printf "cuadro %02d @0x80016840: DAT_8003bea4=0x%08x (%u)  (referencia inicial)\n", $frames, $cur, $cur
  end
  set $prev_tick = $cur
  set $tick_6840 = $cur
  set $frames = $frames + 1
  if $frames <= $max_frames
    continue
  end
end

break *0x80016868
commands
  silent
  set $in_extra = 1
  continue
end

break *0x80016870
commands
  silent
  if $in_extra == 1
    set $cur2 = *(unsigned int *)0x8003bea4
    printf "  extra VSync @0x80016868->0x80016870: DAT_8003bea4=0x%08x (%u)  delta_1_vsync=%u\n", $cur2, $cur2, ($cur2 - $tick_6840)
    set $in_extra = 0
  end
  continue
end

continue
delete
detach
