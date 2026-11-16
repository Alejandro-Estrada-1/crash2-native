# ------------------------------------------------------------------
# Experiment 002: Frequency of 0x80016838 and hits on 0x80016868
#
# Precondition:  PCSX-Redux with GDB server active and Dynarec disabled;
#                load a save state inside a playable level (e.g.
#                slot 1: Turtle Woods). Running with PSX_GDB_TIMEOUT=60
#                is recommended due to the number of TCP stops (~60-120).
#                Note: since each breakpoint halts the emulated PS1, the
#                frequency computation uses emulated ticks of DAT_8003bea4
#                (which pause along with the CPU); for long minute-scale
#                captures without pausing frames, move this count to a Lua
#                script.
# Module:        main (0x80016838, 0x80016868, 0x8003bea4, 0x8006ccf0)
# Hypothesis:    FUN_8001645c calls VSync(0) at 0x80016838 once per logical
#                frame (~30 Hz in NTSC, ~2067 ticks of DAT_8003bea4 every 60
#                frames if ~1033.6 Hz is confirmed). The extra VSync(0) at
#                0x80016868 fires when the frame took < 0x19 (25) ticks
#                (~24.2 ms), capping the game at 30 Hz in light scenes.
# Success:       Over 60 consecutive iterations of 0x80016838:
#                - delta(DAT_8006ccf0) == 60 (1 call to 0x80016838 per frame)
#                - delta(DAT_8003bea4) ~= 2067 ticks for 60 frames (~30 Hz)
#                - record how many of the 60 passes executed 0x80016868
#                  (expected: majority in light scene / Crash standing still).
# Failure:       The breakpoint at 0x80016838 does not hit within
#                PSX_GDB_TIMEOUT seconds, delta(DAT_8006ccf0) != 60, or the
#                per-frame rate clearly differs from 30 Hz (e.g. ~60 Hz if
#                0x80016868 = 0 and ~17 ticks/frame in a light scene).
# Writes memory: no
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
