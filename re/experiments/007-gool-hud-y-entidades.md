English | [Español](007-gool-hud-y-entidades.es.md)

# Result — Experiment 007: GOOL Entities, `DispEnv`/`DrawEnv`, `hud_transform_2d`, and `-5/8` Scale

- **Date:** 2026-11-15
- **Script:** `re/experiments/007-gool-hud-y-entidades.gdb`
- **Command:**
  ```bash
  PSX_GDB_PORT=3333 PSX_GDB_TIMEOUT=45 scripts/gdb-psx -batch -x re/experiments/007-gool-hud-y-entidades.gdb
  ```
- **Environment:** PCSX-Redux (GDB `:3333`, active level `0x1e` / `30`, game running):
  - **Pass 1 (idle in level, HUD hidden):** start at `$pc = 0x8004a640`.
  - **Pass 2 (after moving Crash in the level and opening Pause menu `Start`):** start at `$pc = 0x8004a5f4`.
- **BIOS (`0xbfc00000+0x1000`):** `sha256: 870563babc435b1027ab59237eb150e2f95ffe385f9d29830f45e1e038fc351e` (`OpenBIOS PCSX-Redux build 561`).
- **Exit status:** `exit 0`, `[Inferior 1 (process 1) detached]` in both passes.

## Observed Output vs. Expectation

1. **GOOL entities, Crash movement, and root buckets (`0x8006cb18..0x8006cb57`) vs free list (`0x8006cb58`):**
   - `gool_player_ptr` (`0x8005f38c`) == `gool_player_slot` (`0x8006cb10`) = `0x800ad504`, `gool_object_pool` (`0x8006cb14`) = `0x8009fe80`.
   - **Crash state change between passes (`gool_player_ptr`, `+0x00=1`, `+0x04=3`):**
     - **Pass 1 (idle):** `zone = 0x800d5830`, `pos (+0x60..+0x68) = (9414656, 1723645, 14018560)`, `rot (+0x6c..+0x74) = (0, 442, 0)`, `scale = (4096, 4096, 4096)`, `vel = (0, -136000, 0)`, `anim_seq (+0xe8) = 0x80184300`, `anim_frame (+0xec) = 5376 (>>8 = 18)` (earlier `2560` in the initial run).
     - **Pass 2 (after moving Crash and opening Pause):** `zone = 0x800fd860`, **`pos = (10926080, 2287103, 9566208)`**, **`rot = (0, 3936, 0)`**, `anim_seq = 0x801841d4`, `anim_frame = 17664 (>>8 = 69)`. Moreover, `player_pos_copy` (`0x8005f494..9c`) matched `(10926080, 2287103, 9566208)` identically.
   - **Exact active-tree vs 96-slot pool count (`96 + 1 player = 97` objects):**
     - **Pass 1 (no Pause):** **15** active nodes (`+0x04 == 3`) walked across the 8 root buckets (`0x8006cb18..0x8006cb57`) + **82** nodes in free list (`0x8006cb58`) = **`97`**.
     - **Pass 2 (Pause open, spawns in `bucket[7]`):** **33** active nodes in root buckets + **64** in free list (`0x8006cb58`) = **`97`**.
     - In **both passes**, linearly scanning the 96 slots of `gool_object_pool` (`0x8009fe80`, stride `0x23c`) counted **55** slots with `+0x04 == 3`, confirming the static analysis of `FUN_80019e08` (`0x80019e08`): when freeing entities into `0x8006cb58`, `+0x04` is **not** cleared to zero. For Phase 6 (interpolation), traversing `gool_root_buckets` (`0x8006cb18..0x8006cb57`) is mandatory.

2. **`DisplayContext`, `DISPENV` (`512x240`), and `DRAWENV` (`512x216`, `y=12`):**
   - `disp_ctx_front` (`0x800654f0`): `id = 1`, `raw_ticks = 2486784 / 2774294`, `quant_ticks (+0x14) = 34 (0x22)`.
   - `DISPENV (+0x2018 = 0x80067508)`: `disp = (512, 0, 512, 240)`, `inter = 0`, `rgb24 = 0` (and buffer `0` `0x8006345c` verified with `disp = (0, 0, 512, 240)`).
   - `DRAWENV (+0x202c = 0x8006751c)`: `clip = (512, 12, 512, 216)`, `ofs = (512, 12)`, `isbg = 1`.
   - In `work +0x2088..+0x2090`: active linked queue and arena cursor (`head = 0x80070910 / 0x80070a54`, `base = 0x80070734`, `cur = 0x80070734 / 0x80070ab8`).

3. **Main-loop breakpoints, cropping, sky, 2D HUD, and `-5/8` scale:**
   - `gool_object_tick` (`0x8001c718`): **HIT** (`hops=0`, `ra=0x80018ad4`, `a0=0x800a0534`, `kind=3`).
   - `gool_physics_step` (`0x8001d63c`): **HIT** (`hops=0`, `ra=0x8001c9ec`, `a0=0x800a0534` / `0x800a14d8`, `dt=34`).
   - `render_queue_flush` (`0x8003db94`): **HIT** (`hops=0`, `ra=0x80011db4`, `a0=0x80070910` / `0x80070a54`).
   - `draw_letterbox_and_fov` (`0x80016c58`): **HIT** (`hops=0`, `ra=0x8001658c`, `a0=0`, `a1=0`, `geom_screen=288`).
   - `quantize_frame_ticks` (`0x80016f04`): **HIT** (`hops=0`, `ra=0x8001697c`, `a0=34` in Pass 1 and `a0=35 (0x23)` in Pass 2).
   - **5-frame window (`frame_end_sync` `0x8001645c`):**
     - **Pass 1 (playing level, `level_flags = 0x0c01ffff`, bit `0x2000 sky = 1`):**
       - `draw_bg_tile` (`0x80016a60`): **HIT** (`frame=1`, `ra=0x80016790`, `a0=0`, `a1=0`, `a2=512`, `a3=216`, `c=(55,47,0)`).
       - `matrix_aspect_scale_local` (`0x80043090 -> 0x80043088`): **HIT** from `0x800444c8` (`frame=0`), `PRE t0=0x00000acc t2=0x00000d80 (+3456) t4=0x00001333 (+4915)` -> `POST t0=0x00000acc t2=0x0000f790 (-2160 = -3456 * 5 / 8) t4=0xffffeccd (-4915)`.
       - `hud_transform_2d` (`0x80044558`): `hit_hud=0` (HUD hidden when idle).
     - **Pass 2 (Pause open, `level_flags = 0x0401dffe`, bit `0x2000 sky = 0`):**
       - **`hud_transform_2d` (`0x80044558`):** **HIT** (`frame=0`, `ra=0x8003dc9c`, `gp(obj)=0x800a2fa8`, `v1=0x1f800000`, `x=0 y=0`).
       - **`matrix_aspect_scale_local` (`0x80043090 -> 0x80043088`):** **HIT** immediately afterwards with **`ra=0x80044564`** (return inside `hud_transform_2d`): `PRE t0=0x000007bd (1981) t2=0x0000055b (+1371) t4=0x00000640 (+1600)` -> **`POST t0=0x000007bd t2=0x0000fca8 (-856 = -1371 * 5 / 8) t4=0xfffff9c0 (-1600)`**.
       - `draw_bg_tile` (`0x80016a60`): `hit_tile=0` (flag `0x2000` cleared in Pause).

4. **RNG and input (`PadState`):**
   - `pad_count (0x8006991c) = 2`, `demo_mode (0x8006cd14) = 0`, `Pad1: raw_stat=0x00, type=0x41, dir=8`.
   - `rng_a (0x8005f220) = 0x00003039` unchanged while idle and after moving/opening Pause; `rng_b (0x8005f224)` changed between sessions (`0x237c228a -> 0xaf1cf0fb`).

## Conclusion

- **Live-confirmed in PCSX-Redux (`SCUS-94154`):**
  1. `GoolObject`, `gool_player_ptr` (`0x8005f38c`), `gool_player_slot` (`0x8006cb10`), `gool_object_pool` (`0x8006cb14`), `gool_root_buckets` (`0x8006cb18..0x8006cb57`), and `gool_free_bucket` (`0x8006cb58`) are live-verified; moving Crash directly changes `pos`, `rot`, `zone`, and `anim_frame`, and the 8 root buckets are mandatory over the flat pool because `55` slots keep `+0x04 == 3` after release.
  2. `DISPENV` (`512x240`), `DRAWENV` (`512x216`, `y=12`, `ofs_y=12`), `draw_letterbox_and_fov`, `draw_bg_tile` (`512x216`), `quantize_frame_ticks`, `render_queue_flush`, `hud_transform_2d` (`0x80044558`), and the GTE **`-5/8`** Y-row scale + Z negation in `matrix_aspect_scale_local` (`0x80043090`) are bit-for-bit verified in live execution.
