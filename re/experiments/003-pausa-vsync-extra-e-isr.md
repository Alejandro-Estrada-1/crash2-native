English | [Español](003-pausa-vsync-extra-e-isr.es.md)

# Result — Experiment 003: Pause Menu (`0x80016868` and ISR `0x8003be88`)

- **Date:** 2026-11-15
- **Script:** `re/experiments/003-pausa-vsync-extra-e-isr.gdb`
- **Command:**
  ```bash
  PSX_GDB_PORT=3333 PSX_GDB_TIMEOUT=120 scripts/gdb-psx -batch -x re/experiments/003-pausa-vsync-extra-e-isr.gdb
  ```
- **Environment:** PCSX-Redux Build `561` (`61e3086f`), interpreter CPU, debugger enabled, GDB `:3333`.
- **Precondition:** Slot 1 loaded in the first level, pause menu open (`Start`), and game running without emulator pause.
- **Exit status:** `exit 0`, `[Inferior 1 (process 1) detached]` (emulator still running at exit, no residual pause).

## Observed Output

```text
fase A (20 cuadros en pausa):
  disparos 0x80016868 (VSync extra) = 0 / 20
  delta frame_counter (0x8006ccf0) = 20
  delta rcnt2_tick_count (0x8003bea4) = 691 ticks

fase B cuadro 1: hits_isr(0x8003be88)=34  delta_0x8003bea4=34  extra_0x80016868=0
fase B cuadro 2: hits_isr(0x8003be88)=35  delta_0x8003bea4=35  extra_0x80016868=0
fase B cuadro 3: hits_isr(0x8003be88)=34  delta_0x8003bea4=34  extra_0x80016868=0
```

## Analysis and Conclusions

- **Confirmed (`rcnt2_tick_isr`, `0x8003be88`):** across the 3 frames of Phase B, the ISR at `0x8003be88` executed `34`, `35`, and `34` times, matching **1:1** (`34 == 34`, `35 == 35`, `34 == 34`) with `delta(0x8003bea4)`. In Phase A (20 frames) it accumulated `691` ticks (**`34.55` ticks/frame** ≈ `34.5` expected at 30 Hz NTSC) and `delta frame_counter (0x8006ccf0) == 20`.
- **Ruled out in the pause menu (`0x80016868`):** the extra `VSync(0)` at `0x80016868` executed **`0 / 20`** times in Phase A and **`0 / 3`** in Phase B (`0 / 23` total). Even in the pause menu the game still takes more than 1 VSync (>16.7 ms) before `0x80016838`, so `0x80016838` already synchronizes on the second VBlank (`delta >= 0x19`) and does not enter `0x80016868`.
