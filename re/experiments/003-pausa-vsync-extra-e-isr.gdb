# ------------------------------------------------------------------
# Experimento 003: Menú de pausa — VSync extra (0x80016868) e ISR (0x8003be88)
#
# Precondición:  PCSX-Redux con servidor GDB activo (puerto 3333) y CPU en
#                intérprete; cargar slot 1 en el primer nivel, pulsar Start
#                para abrir el menú de pausa y dejar el juego corriendo en el
#                menú de pausa antes de lanzar este script.
#                Se recomienda ejecutar con PSX_GDB_TIMEOUT=120 (Fase A de 20
#                cuadros con ISR deshabilitada + Fase B de 3 cuadros con
#                breakpoint en 0x8003be88 habilitado, ~125 paradas TCP).
# Módulo:        main (0x80016838, 0x80016868, 0x8003be88, 0x8003bea4, 0x8006ccf0)
# Hipótesis:     a) En el menú de pausa (escena más ligera), frame_end_sync
#                   llega a 0x80016838 en < 1 VSync, de modo que delta < 0x19
#                   y se ejecuta el VSync(0) extra en 0x80016868.
#                b) La ISR rcnt2_tick_isr (0x8003be88) se ejecuta ~34–35 veces
#                   por cuadro de 30 Hz, coincidiendo 1:1 con el incremento de
#                   rcnt2_tick_count (0x8003bea4) en cada cuadro.
# Éxito:         - En Fase A (20 cuadros en pausa): se registra hits_6868_a
#                  (> 0 si la pausa dispara el VSync extra) y delta_tick ≈ 690.
#                - En Fase B (3 cuadros consecutivos): en cada cuadro,
#                  hits_isr(0x8003be88) == delta(0x8003bea4) y ronda 34–35.
# Fallo:         El breakpoint en 0x80016838 o 0x8003be88 no salta en
#                PSX_GDB_TIMEOUT segundos, o hits_isr(0x8003be88) !=
#                delta(0x8003bea4) / difiere claramente de ~34.5 por cuadro.
# Escribe en memoria: no
# ------------------------------------------------------------------

set $phase = 0
set $hits_a = 0
set $target_a = 20
set $hits_6868_a = 0
set $t_a0 = 0
set $c_a0 = 0

set $frames_b = 0
set $target_b = 3
set $isr_hits = 0
set $hits_6868_b = 0
set $t_b_prev = 0

# Breakpoint 1: VSync(0) principal en frame_end_sync
break *0x80016838
commands
  silent
  set $t_now = *(unsigned int *)0x8003bea4
  set $c_now = *(unsigned int *)0x8006ccf0
  if $phase == 0
    if $hits_a == 0
      set $t_a0 = $t_now
      set $c_a0 = $c_now
    end
    set $hits_a = $hits_a + 1
    if $hits_a <= $target_a
      continue
    end
    printf "fase A (%u cuadros en pausa):\n", $target_a
    printf "  disparos 0x80016868 (VSync extra) = %u / %u\n", $hits_6868_a, $target_a
    printf "  delta frame_counter (0x8006ccf0) = %u\n", ($c_now - $c_a0)
    printf "  delta rcnt2_tick_count (0x8003bea4) = %u ticks\n", ($t_now - $t_a0)
    set $phase = 1
    set $t_b_prev = $t_now
    set $isr_hits = 0
    set $hits_6868_b = 0
    enable 3
    continue
  else
    set $frames_b = $frames_b + 1
    printf "fase B cuadro %u: hits_isr(0x8003be88)=%u  delta_0x8003bea4=%u  extra_0x80016868=%u\n", $frames_b, $isr_hits, ($t_now - $t_b_prev), $hits_6868_b
    set $t_b_prev = $t_now
    set $isr_hits = 0
    set $hits_6868_b = 0
    if $frames_b < $target_b
      continue
    end
    disable 3
  end
end

# Breakpoint 2: VSync(0) extra condicional en frame_end_sync
break *0x80016868
commands
  silent
  if $phase == 0
    set $hits_6868_a = $hits_6868_a + 1
  else
    set $hits_6868_b = $hits_6868_b + 1
  end
  continue
end

# Breakpoint 3: rcnt2_tick_isr (habilitado solo en Fase B)
break *0x8003be88
commands
  silent
  set $isr_hits = $isr_hits + 1
  continue
end
disable 3

continue
delete
detach
