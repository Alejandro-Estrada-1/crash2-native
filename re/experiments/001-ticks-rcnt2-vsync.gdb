# ------------------------------------------------------------------
# Experiment 001: DAT_8003bea4 ticks between two VSyncs
#
# Precondition:  PCSX-Redux with GDB server active and Dynarec disabled;
#                load a save state in steady gameplay (e.g. slot 1:
#                start of Turtle Woods, Crash standing still) or on the map
#                screen, where FUN_8001645c executes continuously.
# Module:        main (0x80016840, 0x80016868, 0x80016870, 0x8003bea4)
# Hypothesis:    DAT_8003bea4 advances ~17 ticks (0x11) during a single VSync
#                (confirming the assumed /8 divider of RCntCNT2 with target
#                0x1000 at 60 Hz NTSC) and ~34 ticks (0x22) per 30 Hz frame.
#                Pure 1-VSync measurement: between the return of VSync(0) at
#                0x80016838 (at 0x80016840) and the return of the extra VSync(0)
#                at 0x80016868 (at 0x80016870 when it went through 0x80016868).
# Success:       On frames where 0x80016868 hits, delta_1_vsync is
#                between 16 and 18 ticks (~17 = 0x11), and delta_frame between
#                two consecutive passes through 0x80016840 is ~34 (0x22).
# Failure:       The breakpoint at 0x80016840 does not hit within
#                PSX_GDB_TIMEOUT seconds, or delta_1_vsync clearly differs
#                from ~17 ticks (e.g. ~137 if it were SysClk/1, ~1-2, or 0 if
#                the counter is halted by DAT_8006cb94 & 0x200000).
# Writes memory: no
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
