# ------------------------------------------------------------------
# Experiment 003: Pause menu — extra VSync (0x80016868) and ISR (0x8003be88)
#
# Precondition:  PCSX-Redux with GDB server active (port 3333) and CPU in
#                interpreter mode; load slot 1 in the first level, press Start
#                to open the pause menu and leave the game running in the
#                pause menu before launching this script.
#                Running with PSX_GDB_TIMEOUT=120 is recommended (Phase A of
#                20 frames without ISR breakpoint + Phase B of 3 frames with
#                breakpoint on 0x8003be88, ~125 TCP stops).
# Module:        main (0x80016838, 0x80016868, 0x8003be88, 0x8003bea4, 0x8006ccf0)
# Hypothesis:    a) In the pause menu (lighter scene), frame_end_sync
#                   reaches 0x80016838 in < 1 VSync, so delta < 0x19
#                   and the extra VSync(0) at 0x80016868 executes.
#                b) The rcnt2_tick_isr ISR (0x8003be88) runs ~34-35 times
#                   per 30 Hz frame, matching 1:1 with the increment of
#                   rcnt2_tick_count (0x8003bea4) in each frame.
# Success:       - In Phase A (20 frames paused): hits_6868_a is recorded
#                  (> 0 if pause triggers extra VSync) and delta_tick ~= 690.
#                - In Phase B (3 consecutive frames): on each frame,
#                  hits_isr(0x8003be88) == delta(0x8003bea4) and is around 34-35.
# Failure:       The breakpoint at 0x80016838 or 0x8003be88 does not hit within
#                PSX_GDB_TIMEOUT seconds, or hits_isr(0x8003be88) !=
#                delta(0x8003bea4) / differs clearly from ~34.5 per frame.
# Writes memory: no
# ------------------------------------------------------------------

# --- Phase A: 20 frames paused without breakpoint on 0x8003be88 ---
set $hits_a = 0
set $target_a = 20
set $hits_6868_a = 0
set $t_a0 = 0
set $c_a0 = 0

break *0x80016838
commands
  silent
  set $t_now = *(unsigned int *)0x8003bea4
  set $c_now = *(unsigned int *)0x8006ccf0
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
end

break *0x80016868
commands
  silent
  set $hits_6868_a = $hits_6868_a + 1
  continue
end

continue
delete

# --- Phase B: 3 consecutive frames with breakpoint on 0x8003be88 ---
set $frames_b = 0
set $target_b = 3
set $isr_hits = 0
set $hits_6868_b = 0
set $t_b_prev = 0

break *0x80016838
commands
  silent
  set $t_now = *(unsigned int *)0x8003bea4
  if $frames_b > 0
    printf "fase B cuadro %u: hits_isr(0x8003be88)=%u  delta_0x8003bea4=%u  extra_0x80016868=%u\n", $frames_b, $isr_hits, ($t_now - $t_b_prev), $hits_6868_b
  end
  set $t_b_prev = $t_now
  set $isr_hits = 0
  set $hits_6868_b = 0
  set $frames_b = $frames_b + 1
  if $frames_b <= $target_b
    continue
  end
end

break *0x80016868
commands
  silent
  set $hits_6868_b = $hits_6868_b + 1
  continue
end

break *0x8003be88
commands
  silent
  set $isr_hits = $isr_hits + 1
  continue
end

continue
delete
detach
