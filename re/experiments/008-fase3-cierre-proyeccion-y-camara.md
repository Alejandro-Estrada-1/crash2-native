English | [Español](008-fase3-cierre-proyeccion-y-camara.es.md)

# Result — Experiment 008: Phase 3 Closure (`0x8003d3cc` / `0x8001bd84`, `PadState` Lua, Cameras, and `seeds` Audit)

- **Date:** 2026-11-15
- **Scripts:**
  - `re/experiments/008-fase3-cierre-proyeccion-y-camara.gdb`
  - `re/experiments/008-pad-state.lua`
- **Commands:**
  ```bash
  PSX_GDB_PORT=3333 PSX_GDB_TIMEOUT=45 scripts/gdb-psx -batch -x re/experiments/008-fase3-cierre-proyeccion-y-camara.gdb
  # and in the PCSX-Redux Lua Console:
  dofile("~/Descargas/PORTS/Crash2CSB/c2-re/re/experiments/008-pad-state.lua")
  ```
- **Environment:** PCSX-Redux (`SCUS-94154`, active level `0x1e` / `30`, GDB `:3333`):
  - **GDB Pass 1 (playing level, no Pause):** start `$pc = 0x00001de4`.
  - **Lua Sampling (`008-pad-state.lua`):** `45` logical frames (`frame_counter = 22288..22332`) in active gameplay with live Crash movement.
  - **GDB Pass 2 (Pause menu `Start` open):** start `$pc = 0x8004a640`.
- **BIOS (`0xbfc00000+0x1000`):** `sha256: 870563babc435b1027ab59237eb150e2f95ffe385f9d29830f45e1e038fc351e` (`OpenBIOS PCSX-Redux build 561`).
- **GDB exit status:** `exit 0`, `[Inferior 1 (process 1) detached]` in both passes.

## Observed Output vs. Expectation

1. **Third `5/8` path (`draw_text_3d` `0x8001bd84` → `model_view_matrix_build` `0x8003d3cc`) in Pass 2 (Pause):**
   - `draw_text_3d (0x8001bd84)`: **HIT** (`frame=0`, `ra=0x8001af24`, `obj(a0)=0x800a1b8c`, `hdr(a1)=0x801a17bc`, `idx(a2)=70`, `rmode=6`).
   - `model_view_matrix_build (0x8003d3cc)`: **HIT** (`frame=0`, `ra=0x8001be38`, `a0=0x800a1bec`, `a1=0x8006083c`, `is2d(a2)=1`, `sh(a3)=0`, `mat=0x800607d4`).
   - **Exact `-(val * 5) >> 3` measurement (`0x8003d8f8` → `0x8003d94c`):**
     - `PRE  (0x8003d8f8)`: `IR(s3, s0, s4) = (0, 519, 0)`, `R11/12/13(s2, s7, s1) = (326, 0, 0)`.
     - `POST (0x8003d94c)`: `-(v*5>>3) (s3, s0, s4) = (0, -324, 0)`, packed `t0 = 0x00000146` (`326`), `t1 = 0x00000000`, `t2 = 0x0000febc` (`(int16_t)0xfebc = -324 = -(519 * 5 >> 3)`).
   - Did not fire within the 5-frame window: `sprite_billboard_draw` (`0x80044830`, `spr=0`) and `world_to_screen` (`0x8001ed60`, `w2s=0`; sole known static xref in GOOL opcode `0x800385b0`).

2. **Camera dispatch, WGEO shaders, and letterbox (`0x80026ca0`, `0x80020a24`, `0x80016c58`):**
   - **Pass 1 (playing):**
     - `cam_mode_dispatch` (`0x80026ca0`): **HIT** (`frame=0`, `ra=0x80011b68`, `cam_trans_state(0x8005b994)=5`, `cam_submode(0x800608f0)=0`, `level_flags=0x0c01ffff`, `ctrl_scale(0x8006cbb4)=0x100`).
     - `zone_gfx_mode_apply` (`0x80020a24`): **HIT** (`frame=0`, `ra=0x80017be0`, `zone_gfx_flags=0x00000000`, `level_flags=0x0c01ffff`, `wgeo_shaders=0x8003dd0c, 0x80042420, 0x800426a0, 0x80042548, 0x80042818`).
   - **Pass 2 (Pause):**
     - `zone_gfx_mode_apply` (`0x80020a24`): **HIT** (`frame=0`, `ra=0x80017be0`, `zone_gfx_flags=0x00000010`, `level_flags=0x0401dffe`).
   - In both scenes `letterbox_level (0x8006cc94) = 0`, `letterbox_prev (0x8005f1d4) = 0`, `geom_screen = 288 (0x120)`, and `SetGeomScreen` (`0x8004f008`) did not change (`setH=0`).

3. **`PadState` (`0x80069920`) and `RNG` across 45 live frames (`008-pad-state.lua`, `/tmp/exp008_pad_state.txt`):**
   - `pad_type = 0x41`, `raw_stat = 0x00`, `demo_mode = 0`, `frame_counter = 22288..22332`:
     - Frames `01..31` (idle): `pressed=0x0000`, `held=0x0000`, `prev1=0x0000`, `angle=2048`, `mag=0`, `dir=8`, `player=(12126208, 249589, 43272192)`.
     - Frame `32` (`0x2000` rising edge): `pressed=0x2000`, `held=0x2000`, `prev1=0x0000`, `angle=1024`, `mag=256`, `dir=2`, `player.x=12128256`.
     - Frames `33..35` (held `0x2000`): `pressed=0x0000`, `held=0x2000`, `prev1=0x2000`, `player.x` advances to `12146688`.
     - Frame `36` (release edge): `pressed=0x0000`, `held=0x0000`, `prev1=0x2000`, `angle=1024`, `mag=0`, `dir=8`.
     - Frames `39..45` (`0x1000` rising edge and hold): on frame `39` `pressed=0x1000`, `held=0x1000`, `prev1=0x0000`, `angle=2048`, `mag=256`, `dir=0`; on `40..45` `pressed=0x0000`, `held=0x1000`, `prev1=0x1000`, moving Crash up to `(12179456, 288001, 43196416)`.
   - Across all 45 frames in the active level: `rng_a (0x8005f220) = 0x00003039` and `rng_b (0x8005f224) = 0x00000001` constant.

4. **Static audit of `seeds/ghidra_funcs.txt` (`748` unique addresses in `0x800111b0..0x8005b118`):**
   - Out of **105** addresses `< 0x8005b1d8` recorded in `re/symbols.csv` + `re/provisional_symbols.csv`: **89** are present in `seeds/ghidra_funcs.txt` and **16** are missing:
     - **14 missing standalone function starts** (all preceded by `jr ra` / delay slot): `0x8003be88` (`rcnt2_tick_isr`, already confirmed in `symbols.csv`), `0x8001c718` (`gool_object_tick`, confirmed), `0x80044558` (`hud_transform_2d`, confirmed), `0x80044830` (`sprite_billboard_draw`), `0x800189c4` (`gool_on_entry_nop`), `0x8001ee64` (`opat_init`), `0x8001efd8` (`opat_fini`), `0x8001f018` (`opat_post_load`), `0x8001f9c4` (`ldat_post_load`), `0x8001fddc` (`zdat_on_entry`), `0x8001ff30` (`zdat_on_unload`), `0x8003147c` (`rng_a_mod`), `0x80031658` (`rng_b_init`), `0x8004a364` (`_SendPAD`).
     - The remaining **2** are not new functions: `0x8003bea4` (`rcnt2_tick_count`, 4-byte data) and `0x8003aad4` (`gool_op49_exec_mips`, internal jump-table label inside `gool_interpret 0x8003a014`).
   - Across a full scan of the 4 dispatch tables (`entry_type_handlers` `0x8005b1d8`, `0x8005b650`, `0x8005b690`, `0x8005b6d0..0x8005b7af`), **61** unique code addresses `< 0x8005b1d8` are missing (**53** standalone function starts: `21` in `entry_type_handlers`, `3` in `0x8005b650`, `9` in `0x8005b690`, `20` in `0x8005b6d0..af`; plus `8` internal stubs).

## Conclusion

- Live-confirmed: `draw_text_3d` (`0x8001bd84`), `model_view_matrix_build` (`0x8003d3cc`, exact `-5/8` scale: `519 -> -324 = 0xfebc`), `cam_mode_dispatch` (`0x80026ca0`), `zone_gfx_mode_apply` (`0x80020a24`), and the full frame-by-frame dynamics of `PadState` (`0x80069920`) for `tools/regress`.
- Remaining as `propuesto` (did not trigger in the tested scene): `world_to_screen` (`0x8001ed60`), `sprite_billboard_draw` (`0x80044830`), and the `letterbox_level != 0` case on `SetGeomScreen` (`0x8004f008`).
