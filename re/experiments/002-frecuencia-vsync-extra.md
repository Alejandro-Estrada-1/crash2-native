English | [Español](002-frecuencia-vsync-extra.es.md)

# Result — Experiment 002: Frequency of `0x80016838` and Hits on `0x80016868`

- **Date:** 2026-11-15
- **Script:** `re/experiments/002-frecuencia-vsync-extra.gdb`
- **Command:**
  ```bash
  PSX_GDB_PORT=3333 PSX_GDB_TIMEOUT=120 scripts/gdb-psx -batch -x re/experiments/002-frecuencia-vsync-extra.gdb
  ```
- **Environment:** PCSX-Redux Build `561` (`61e3086f`), interpreter CPU, debugger enabled, GDB `:3333`.
- **Precondition:** Slot 1 loaded in the first level, Crash standing still.
- **Exit status:** `exit 0`, `[Inferior 1 (process 1) detached]` (no hangs or residual pauses).

## Observed Output

```text
resumen (60 cuadros completos entre paso 1 y paso 61 de 0x80016838):
  cuadros medidos (0x80016838) = 60
  disparos 0x80016868 (VSync extra) = 0
  delta DAT_8006ccf0 = 60
  delta DAT_8003bea4 = 2071 ticks (ticks/cuadro = 34)
```

## Analysis

- `delta DAT_8006ccf0 == 60` confirms that `0x80016838` (`VSync(0)` in `FUN_8001645c`) runs **once per logical frame**.
- `delta DAT_8003bea4 == 2071` ticks across 60 frames equals **`34.52` ticks/frame** (~`2071 / 1033.6 ≈ 2.004 s` for 60 frames ≈ **`30.0 Hz`**).
- `disparos 0x80016868 = 0` across the 60 measured frames with Crash standing still in the first level: the CPU+GPU work of that scene exceeds 1 VSync (>16.7 ms), so the first `VSync(0)` (`0x80016838`) already synchronizes on the second VBlank (`delta >= 0x19`) and does not need the extra `VSync(0)`. Measuring on the pause/map screen remains pending to verify the case where `0x80016868` does fire.
