English | [Español](001-ticks-rcnt2-vsync.es.md)

# Result — Experiment 001: `DAT_8003bea4` Ticks Between Two VSyncs

- **Date:** 2026-11-15
- **Script:** `re/experiments/001-ticks-rcnt2-vsync.gdb`
- **Command:**
  ```bash
  PSX_GDB_PORT=3333 PSX_GDB_TIMEOUT=60 scripts/gdb-psx -batch -x re/experiments/001-ticks-rcnt2-vsync.gdb
  ```
- **Environment:** PCSX-Redux Build `561` (`61e3086f`), interpreter CPU, debugger enabled, GDB `:3333`.
- **Precondition:** Slot 1 loaded in the first level, Crash standing still.
- **Exit status:** `exit 0`, `[Inferior 1 (process 1) detached]` (no hangs or residual pauses).

## Observed Output

```text
cuadro 00 @0x80016840: DAT_8003bea4=0x0002459a (148890)  (referencia inicial)
cuadro 01 @0x80016840: DAT_8003bea4=0x000245bd (148925)  delta_frame=35
cuadro 02 @0x80016840: DAT_8003bea4=0x000245df (148959)  delta_frame=34
cuadro 03 @0x80016840: DAT_8003bea4=0x00024602 (148994)  delta_frame=35
cuadro 04 @0x80016840: DAT_8003bea4=0x00024624 (149028)  delta_frame=34
cuadro 05 @0x80016840: DAT_8003bea4=0x00024646 (149062)  delta_frame=34
cuadro 06 @0x80016840: DAT_8003bea4=0x00024669 (149097)  delta_frame=35
cuadro 07 @0x80016840: DAT_8003bea4=0x0002468b (149131)  delta_frame=34
cuadro 08 @0x80016840: DAT_8003bea4=0x000246ae (149166)  delta_frame=35
cuadro 09 @0x80016840: DAT_8003bea4=0x000246d0 (149200)  delta_frame=34
cuadro 10 @0x80016840: DAT_8003bea4=0x000246f3 (149235)  delta_frame=35
cuadro 11 @0x80016840: DAT_8003bea4=0x00024715 (149269)  delta_frame=34
cuadro 12 @0x80016840: DAT_8003bea4=0x00024738 (149304)  delta_frame=35
```

## Analysis

- Across the 12 measured frames, `DAT_8003bea4` advanced `149304 - 148890 = 414` ticks, i.e. **`34.50` ticks per frame** (alternating `34` and `35`), exactly `2 * 17.25` ticks/VSync, matching the expected rate of the assumed `SysClk/8` (~`1033.6 Hz`, ~`17.2` ticks per 60 Hz NTSC VSync and ~`34.4` ticks per 30 Hz frame).
- The breakpoint at `0x80016868` did not hit in any of the 12 frames because the first-level scene took more than 1 VSync before `0x80016838`, so when `VSync(0)` returned at `0x80016840`, ~34–35 ticks (`>= 0x19`) had already elapsed and the extra wait was unnecessary. Therefore, direct measurement of `delta_1_vsync` (`0x80016868 -> 0x80016870`) remains pending for a lighter scene (e.g. menu/pause).
