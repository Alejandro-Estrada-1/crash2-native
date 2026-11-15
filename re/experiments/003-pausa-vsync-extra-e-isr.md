# Resultado — Experimento 003: Menú de pausa (`0x80016868` e ISR `0x8003be88`)

- **Fecha:** 2026-11-15
- **Script:** `re/experiments/003-pausa-vsync-extra-e-isr.gdb`
- **Comando:**
  ```bash
  PSX_GDB_PORT=3333 PSX_GDB_TIMEOUT=120 scripts/gdb-psx -batch -x re/experiments/003-pausa-vsync-extra-e-isr.gdb
  ```
- **Entorno:** PCSX-Redux Build `561` (`61e3086f`), CPU intérprete, depurador activo, GDB `:3333`.
- **Precondición:** Slot 1 cargado en el primer nivel, menú de pausa abierto (`Start`) y juego corriendo sin pausa del emulador.
- **Estado de salida:** `exit 0`, `[Inferior 1 (process 1) detached]` (emulador corriendo al terminar, sin pausa residual).

## Salida observada

```text
fase A (20 cuadros en pausa):
  disparos 0x80016868 (VSync extra) = 0 / 20
  delta frame_counter (0x8006ccf0) = 20
  delta rcnt2_tick_count (0x8003bea4) = 691 ticks

fase B cuadro 1: hits_isr(0x8003be88)=34  delta_0x8003bea4=34  extra_0x80016868=0
fase B cuadro 2: hits_isr(0x8003be88)=35  delta_0x8003bea4=35  extra_0x80016868=0
fase B cuadro 3: hits_isr(0x8003be88)=34  delta_0x8003bea4=34  extra_0x80016868=0
```

## Análisis y conclusiones

- **Confirmado (`rcnt2_tick_isr`, `0x8003be88`):** en los 3 cuadros de la Fase B, la ISR en `0x8003be88` se ejecutó `34`, `35` y `34` veces, coincidiendo exactamente **1:1** (`34 == 34`, `35 == 35`, `34 == 34`) con `delta(0x8003bea4)`. En Fase A (20 cuadros) acumuló `691` ticks (**`34.55` ticks/cuadro** ≈ `34.5` esperado a 30 Hz NTSC) y `delta frame_counter (0x8006ccf0) == 20`.
- **Descartado en el menú de pausa (`0x80016868`):** el `VSync(0)` extra en `0x80016868` se ejecutó **`0 / 20`** veces en Fase A y **`0 / 3`** en Fase B (`0 / 23` en total). En el menú de pausa el juego sigue tardando más de 1 VSync (>16.7 ms) antes de `0x80016838`, de modo que `0x80016838` ya sincroniza en el segundo VBlank (`delta >= 0x19`) y no entra a `0x80016868`.
