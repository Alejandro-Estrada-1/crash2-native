[English](008-fase3-cierre-proyeccion-y-camara.md) | Español

# Resultado — Experimento 008: Cierre de Fase 3 (`0x8003d3cc` / `0x8001bd84`, `PadState` Lua, cámaras y auditoría de `seeds`)

- **Fecha:** 2026-11-15
- **Scripts:**
  - `re/experiments/008-fase3-cierre-proyeccion-y-camara.gdb`
  - `re/experiments/008-pad-state.lua`
- **Comandos:**
  ```bash
  PSX_GDB_PORT=3333 PSX_GDB_TIMEOUT=45 scripts/gdb-psx -batch -x re/experiments/008-fase3-cierre-proyeccion-y-camara.gdb
  # y en Consola Lua de PCSX-Redux:
  dofile("~/Descargas/PORTS/Crash2CSB/c2-re/re/experiments/008-pad-state.lua")
  ```
- **Entorno:** PCSX-Redux (`SCUS-94154`, nivel activo `0x1e` / `30`, GDB `:3333`):
  - **Pasada 1 GDB (nivel jugando, sin Pausa):** inicio `$pc = 0x00001de4`.
  - **Muestreo Lua (`008-pad-state.lua`):** `45` cuadros lógicos (`frame_counter = 22288..22332`) en juego activo con movimiento real de Crash.
  - **Pasada 2 GDB (menú de Pausa `Start` abierto):** inicio `$pc = 0x8004a640`.
- **BIOS (`0xbfc00000+0x1000`):** `sha256: 870563babc435b1027ab59237eb150e2f95ffe385f9d29830f45e1e038fc351e` (`OpenBIOS PCSX-Redux build 561`).
- **Estado de salida GDB:** `exit 0`, `[Inferior 1 (process 1) detached]` en ambas pasadas.

## Salida observada frente a la expectativa

1. **Tercera ruta `5/8` (`draw_text_3d` `0x8001bd84` → `model_view_matrix_build` `0x8003d3cc`) en Pasada 2 (Pausa):**
   - `draw_text_3d (0x8001bd84)`: **HIT** (`frame=0`, `ra=0x8001af24`, `obj(a0)=0x800a1b8c`, `hdr(a1)=0x801a17bc`, `idx(a2)=70`, `rmode=6`).
   - `model_view_matrix_build (0x8003d3cc)`: **HIT** (`frame=0`, `ra=0x8001be38`, `a0=0x800a1bec`, `a1=0x8006083c`, `is2d(a2)=1`, `sh(a3)=0`, `mat=0x800607d4`).
   - **Medición exacta `-(val * 5) >> 3` (`0x8003d8f8` → `0x8003d94c`):**
     - `PRE  (0x8003d8f8)`: `IR(s3, s0, s4) = (0, 519, 0)`, `R11/12/13(s2, s7, s1) = (326, 0, 0)`.
     - `POST (0x8003d94c)`: `-(v*5>>3) (s3, s0, s4) = (0, -324, 0)`, empaquetado `t0 = 0x00000146` (`326`), `t1 = 0x00000000`, `t2 = 0x0000febc` (`(int16_t)0xfebc = -324 = -(519 * 5 >> 3)`).
   - No dispararon en la ventana de 5 cuadros: `sprite_billboard_draw` (`0x80044830`, `spr=0`) ni `world_to_screen` (`0x8001ed60`, `w2s=0`; único xref estático conocido en opcode GOOL `0x800385b0`).

2. **Despacho de cámara, shaders WGEO y letterbox (`0x80026ca0`, `0x80020a24`, `0x80016c58`):**
   - **Pasada 1 (jugando):**
     - `cam_mode_dispatch` (`0x80026ca0`): **HIT** (`frame=0`, `ra=0x80011b68`, `cam_trans_state(0x8005b994)=5`, `cam_submode(0x800608f0)=0`, `level_flags=0x0c01ffff`, `ctrl_scale(0x8006cbb4)=0x100`).
     - `zone_gfx_mode_apply` (`0x80020a24`): **HIT** (`frame=0`, `ra=0x80017be0`, `zone_gfx_flags=0x00000000`, `level_flags=0x0c01ffff`, `wgeo_shaders=0x8003dd0c, 0x80042420, 0x800426a0, 0x80042548, 0x80042818`).
   - **Pasada 2 (Pausa):**
     - `zone_gfx_mode_apply` (`0x80020a24`): **HIT** (`frame=0`, `ra=0x80017be0`, `zone_gfx_flags=0x00000010`, `level_flags=0x0401dffe`).
   - En ambas escenas `letterbox_level (0x8006cc94) = 0`, `letterbox_prev (0x8005f1d4) = 0`, `geom_screen = 288 (0x120)` y `SetGeomScreen` (`0x8004f008`) no cambió (`setH=0`).

3. **`PadState` (`0x80069920`) y `RNG` en 45 cuadros reales (`008-pad-state.lua`, `/tmp/exp008_pad_state.txt`):**
   - `pad_type = 0x41`, `raw_stat = 0x00`, `demo_mode = 0`, `frame_counter = 22288..22332`:
     - Cuadros `01..31` (reposo): `pressed=0x0000`, `held=0x0000`, `prev1=0x0000`, `angle=2048`, `mag=0`, `dir=8`, `player=(12126208, 249589, 43272192)`.
     - Cuadro `32` (flanco de pulsación `0x2000`): `pressed=0x2000`, `held=0x2000`, `prev1=0x0000`, `angle=1024`, `mag=256`, `dir=2`, `player.x=12128256`.
     - Cuadros `33..35` (sostenido `0x2000`): `pressed=0x0000`, `held=0x2000`, `prev1=0x2000`, `player.x` avanza hasta `12146688`.
     - Cuadro `36` (flanco de liberación): `pressed=0x0000`, `held=0x0000`, `prev1=0x2000`, `angle=1024`, `mag=0`, `dir=8`.
     - Cuadros `39..45` (flanco y sostén `0x1000`): en cuadro `39` `pressed=0x1000`, `held=0x1000`, `prev1=0x0000`, `angle=2048`, `mag=256`, `dir=0`; en `40..45` `pressed=0x0000`, `held=0x1000`, `prev1=0x1000`, moviendo a Crash hasta `(12179456, 288001, 43196416)`.
   - Durante los 45 cuadros en nivel activo: `rng_a (0x8005f220) = 0x00003039` y `rng_b (0x8005f224) = 0x00000001` constantes.

4. **Auditoría estática de `seeds/ghidra_funcs.txt` (`748` direcciones únicas en `0x800111b0..0x8005b118`):**
   - De **105** direcciones `< 0x8005b1d8` registradas en `re/symbols.csv` + `re/provisional_symbols.csv`: **89** están en `seeds/ghidra_funcs.txt` y **16** faltan:
     - **14 inicios de función independientes ausentes** (todos precedidos por `jr ra` / slot): `0x8003be88` (`rcnt2_tick_isr`, ya confirmado en `symbols.csv`), `0x8001c718` (`gool_object_tick`, confirmado), `0x80044558` (`hud_transform_2d`, confirmado), `0x80044830` (`sprite_billboard_draw`), `0x800189c4` (`gool_on_entry_nop`), `0x8001ee64` (`opat_init`), `0x8001efd8` (`opat_fini`), `0x8001f018` (`opat_post_load`), `0x8001f9c4` (`ldat_post_load`), `0x8001fddc` (`zdat_on_entry`), `0x8001ff30` (`zdat_on_unload`), `0x8003147c` (`rng_a_mod`), `0x80031658` (`rng_b_init`), `0x8004a364` (`_SendPAD`).
     - Las otras **2** no son funciones nuevas: `0x8003bea4` (`rcnt2_tick_count`, dato de 4 B) y `0x8003aad4` (`gool_op49_exec_mips`, etiqueta interna de tabla de saltos dentro de `gool_interpret 0x8003a014`).
   - En barrido completo de las 4 tablas de despacho (`entry_type_handlers` `0x8005b1d8`, `0x8005b650`, `0x8005b690`, `0x8005b6d0..0x8005b7af`), faltan **61** direcciones únicas de código `< 0x8005b1d8` (**53** inicios de función independientes: `21` en `entry_type_handlers`, `3` en `0x8005b650`, `9` en `0x8005b690`, `20` en `0x8005b6d0..af`; más `8` stubs internos).

## Conclusión

- Quedan confirmados en vivo `draw_text_3d` (`0x8001bd84`), `model_view_matrix_build` (`0x8003d3cc`, escala exacta `-5/8`: `519 -> -324 = 0xfebc`), `cam_mode_dispatch` (`0x80026ca0`), `zone_gfx_mode_apply` (`0x80020a24`) y la dinámica completa cuadro a cuadro de `PadState` (`0x80069920`) para `tools/regress`.
- Permanecen como `propuesto` (sin disparo en la escena probada) `world_to_screen` (`0x8001ed60`), `sprite_billboard_draw` (`0x80044830`) y el caso `letterbox_level != 0` sobre `SetGeomScreen` (`0x8004f008`).
