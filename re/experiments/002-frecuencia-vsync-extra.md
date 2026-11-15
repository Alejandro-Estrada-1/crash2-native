# Resultado — Experimento 002: Frecuencia de `0x80016838` y disparos de `0x80016868`

- **Fecha:** 2026-11-15
- **Script:** `re/experiments/002-frecuencia-vsync-extra.gdb`
- **Comando:**
  ```bash
  PSX_GDB_PORT=3333 PSX_GDB_TIMEOUT=120 scripts/gdb-psx -batch -x re/experiments/002-frecuencia-vsync-extra.gdb
  ```
- **Entorno:** PCSX-Redux Build `561` (`61e3086f`), CPU intérprete, depurador activo, GDB `:3333`.
- **Precondición:** Slot 1 cargado en el primer nivel, Crash quieto.
- **Estado de salida:** `exit 0`, `[Inferior 1 (process 1) detached]` (sin cuelgues ni pausas residuales).

## Salida observada

```text
resumen (60 cuadros completos entre paso 1 y paso 61 de 0x80016838):
  cuadros medidos (0x80016838) = 60
  disparos 0x80016868 (VSync extra) = 0
  delta DAT_8006ccf0 = 60
  delta DAT_8003bea4 = 2071 ticks (ticks/cuadro = 34)
```

## Análisis

- `delta DAT_8006ccf0 == 60` confirma que `0x80016838` (`VSync(0)` en `FUN_8001645c`) se ejecuta **1 vez por cuadro lógico**.
- `delta DAT_8003bea4 == 2071` ticks en 60 cuadros equivale a **`34.52` ticks/cuadro** (~`2071 / 1033.6 ≈ 2.004 s` para 60 cuadros ≈ **`30.0 Hz`**).
- `disparos 0x80016868 = 0` en los 60 cuadros medidos con Crash quieto en el primer nivel: el trabajo CPU+GPU de esa escena supera 1 VSync (>16.7 ms), así que el primer `VSync(0)` (`0x80016838`) sincroniza ya en el segundo VBlank (`delta >= 0x19`) y no necesita el `VSync(0)` adicional. Queda pendiente medir en pantalla de pausa/mapa para comprobar el caso en que `0x80016868` sí se dispara.
