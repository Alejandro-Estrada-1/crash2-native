# Resultado — Experimento 001: Ticks de `DAT_8003bea4` entre dos VSync

- **Fecha:** 2026-11-15
- **Script:** `re/experiments/001-ticks-rcnt2-vsync.gdb`
- **Comando:**
  ```bash
  PSX_GDB_PORT=3333 PSX_GDB_TIMEOUT=60 scripts/gdb-psx -batch -x re/experiments/001-ticks-rcnt2-vsync.gdb
  ```
- **Entorno:** PCSX-Redux Build `561` (`61e3086f`), CPU intérprete, depurador activo, GDB `:3333`.
- **Precondición:** Slot 1 cargado en el primer nivel, Crash quieto.
- **Estado de salida:** `exit 0`, `[Inferior 1 (process 1) detached]` (sin cuelgues ni pausas residuales).

## Salida observada

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

## Análisis

- En los 12 cuadros medidos, `DAT_8003bea4` avanzó `149304 - 148890 = 414` ticks, es decir **`34.50` ticks por cuadro** (alternando `34` y `35`), exactamente `2 * 17.25` ticks/VSync, lo cual concuerda con la tasa esperada del supuesto `SysClk/8` (~`1033.6 Hz`, ~`17.2` ticks por VSync NTSC de 60 Hz y ~`34.4` ticks por cuadro de 30 Hz).
- El breakpoint en `0x80016868` no saltó en ninguno de los 12 cuadros porque la escena del primer nivel tardó más de 1 VSync antes de `0x80016838`, de modo que al retornar `VSync(0)` en `0x80016840` ya habían pasado ~34–35 ticks (`>= 0x19`) y no hizo falta la espera extra. Por ello, la medición directa de `delta_1_vsync` (`0x80016868 -> 0x80016870`) queda pendiente para una escena más ligera (p. ej. menú/pausa).
