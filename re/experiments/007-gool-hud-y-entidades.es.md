[English](007-gool-hud-y-entidades.md) | Español

# Resultado — Experimento 007: Entidades GOOL, `DispEnv`/`DrawEnv`, `hud_transform_2d` y escala `-5/8`

- **Fecha:** 2026-11-15
- **Script:** `re/experiments/007-gool-hud-y-entidades.gdb`
- **Comando:**
  ```bash
  PSX_GDB_PORT=3333 PSX_GDB_TIMEOUT=45 scripts/gdb-psx -batch -x re/experiments/007-gool-hud-y-entidades.gdb
  ```
- **Entorno:** PCSX-Redux (GDB `:3333`, nivel activo `0x1e` / `30`, juego corriendo):
  - **Pasada 1 (reposo en nivel, HUD oculto):** inicio en `$pc = 0x8004a640`.
  - **Pasada 2 (tras mover a Crash en el nivel y abrir menú de Pausa `Start`):** inicio en `$pc = 0x8004a5f4`.
- **BIOS (`0xbfc00000+0x1000`):** `sha256: 870563babc435b1027ab59237eb150e2f95ffe385f9d29830f45e1e038fc351e` (`OpenBIOS PCSX-Redux build 561`).
- **Estado de salida:** `exit 0`, `[Inferior 1 (process 1) detached]` en ambas pasadas.

## Salida observada frente a la expectativa

1. **Entidades GOOL, movimiento de Crash y cubetas raíz (`0x8006cb18..0x8006cb57`) vs lista libre (`0x8006cb58`):**
   - `gool_player_ptr` (`0x8005f38c`) == `gool_player_slot` (`0x8006cb10`) = `0x800ad504`, `gool_object_pool` (`0x8006cb14`) = `0x8009fe80`.
   - **Cambio de estado de Crash entre pasadas (`gool_player_ptr`, `+0x00=1`, `+0x04=3`):**
     - **Pasada 1 (reposo):** `zone = 0x800d5830`, `pos (+0x60..+0x68) = (9414656, 1723645, 14018560)`, `rot (+0x6c..+0x74) = (0, 442, 0)`, `scale = (4096, 4096, 4096)`, `vel = (0, -136000, 0)`, `anim_seq (+0xe8) = 0x80184300`, `anim_frame (+0xec) = 5376 (>>8 = 18)` (previo `2560` en la corrida inicial).
     - **Pasada 2 (tras mover a Crash y abrir Pausa):** `zone = 0x800fd860`, **`pos = (10926080, 2287103, 9566208)`**, **`rot = (0, 3936, 0)`**, `anim_seq = 0x801841d4`, `anim_frame = 17664 (>>8 = 69)`. Además `player_pos_copy` (`0x8005f494..9c`) coincidió exactamente con `(10926080, 2287103, 9566208)`.
   - **Conteo exacto del árbol activo frente al pool de 96 slots (`96 + 1 jugador = 97` objetos):**
     - **Pasada 1 (sin Pausa):** **15** nodos activos (`+0x04 == 3`) recorridos en las 8 cubetas raíz (`0x8006cb18..0x8006cb57`) + **82** nodos en lista libre (`0x8006cb58`) = **`97`**.
     - **Pasada 2 (Pausa abierta, spawns en `bucket[7]`):** **33** nodos activos en cubetas raíz + **64** en lista libre (`0x8006cb58`) = **`97`**.
     - En **ambas pasadas**, el barrido lineal de los 96 slots de `gool_object_pool` (`0x8009fe80`, stride `0x23c`) contó **55** slots con `+0x04 == 3`, confirmando el análisis estático de `FUN_80019e08` (`0x80019e08`): al liberar entidades hacia `0x8006cb58`, `+0x04` **no** se limpia a cero. Para Fase 6 (interpolación), recorrer `gool_root_buckets` (`0x8006cb18..0x8006cb57`) es obligatorio.

2. **`DisplayContext`, `DISPENV` (`512x240`) y `DRAWENV` (`512x216`, `y=12`):**
   - `disp_ctx_front` (`0x800654f0`): `id = 1`, `raw_ticks = 2486784 / 2774294`, `quant_ticks (+0x14) = 34 (0x22)`.
   - `DISPENV (+0x2018 = 0x80067508)`: `disp = (512, 0, 512, 240)`, `inter = 0`, `rgb24 = 0` (y buffer `0` `0x8006345c` verificado con `disp = (0, 0, 512, 240)`).
   - `DRAWENV (+0x202c = 0x8006751c)`: `clip = (512, 12, 512, 216)`, `ofs = (512, 12)`, `isbg = 1`.
   - En `work +0x2088..+0x2090`: cola enlazada y cursor de arena activos (`head = 0x80070910 / 0x80070a54`, `base = 0x80070734`, `cur = 0x80070734 / 0x80070ab8`).

3. **Breakpoints del bucle principal, recorte, cielo, HUD 2D y escala `-5/8`:**
   - `gool_object_tick` (`0x8001c718`): **HIT** (`hops=0`, `ra=0x80018ad4`, `a0=0x800a0534`, `kind=3`).
   - `gool_physics_step` (`0x8001d63c`): **HIT** (`hops=0`, `ra=0x8001c9ec`, `a0=0x800a0534` / `0x800a14d8`, `dt=34`).
   - `render_queue_flush` (`0x8003db94`): **HIT** (`hops=0`, `ra=0x80011db4`, `a0=0x80070910` / `0x80070a54`).
   - `draw_letterbox_and_fov` (`0x80016c58`): **HIT** (`hops=0`, `ra=0x8001658c`, `a0=0`, `a1=0`, `geom_screen=288`).
   - `quantize_frame_ticks` (`0x80016f04`): **HIT** (`hops=0`, `ra=0x8001697c`, `a0=34` en Pasada 1 y `a0=35 (0x23)` en Pasada 2).
   - **Ventana de 5 cuadros (`frame_end_sync` `0x8001645c`):**
     - **Pasada 1 (nivel jugando, `level_flags = 0x0c01ffff`, bit `0x2000 sky = 1`):**
       - `draw_bg_tile` (`0x80016a60`): **HIT** (`frame=1`, `ra=0x80016790`, `a0=0`, `a1=0`, `a2=512`, `a3=216`, `c=(55,47,0)`).
       - `matrix_aspect_scale_local` (`0x80043090 -> 0x80043088`): **HIT** desde `0x800444c8` (`frame=0`), `PRE t0=0x00000acc t2=0x00000d80 (+3456) t4=0x00001333 (+4915)` -> `POST t0=0x00000acc t2=0x0000f790 (-2160 = -3456 * 5 / 8) t4=0xffffeccd (-4915)`.
       - `hud_transform_2d` (`0x80044558`): `hit_hud=0` (HUD oculto en reposo).
     - **Pasada 2 (Pausa abierta, `level_flags = 0x0401dffe`, bit `0x2000 sky = 0`):**
       - **`hud_transform_2d` (`0x80044558`):** **HIT** (`frame=0`, `ra=0x8003dc9c`, `gp(obj)=0x800a2fa8`, `v1=0x1f800000`, `x=0 y=0`).
       - **`matrix_aspect_scale_local` (`0x80043090 -> 0x80043088`):** **HIT** inmediatamente después con **`ra=0x80044564`** (retorno dentro de `hud_transform_2d`): `PRE t0=0x000007bd (1981) t2=0x0000055b (+1371) t4=0x00000640 (+1600)` -> **`POST t0=0x000007bd t2=0x0000fca8 (-856 = -1371 * 5 / 8) t4=0xfffff9c0 (-1600)`**.
       - `draw_bg_tile` (`0x80016a60`): `hit_tile=0` (bandera `0x2000` apagada en Pausa).

4. **RNG y entrada (`PadState`):**
   - `pad_count (0x8006991c) = 2`, `demo_mode (0x8006cd14) = 0`, `Pad1: raw_stat=0x00, type=0x41, dir=8`.
   - `rng_a (0x8005f220) = 0x00003039` sin cambio en reposo ni tras moverse/abrir Pausa; `rng_b (0x8005f224)` cambió entre sesiones (`0x237c228a -> 0xaf1cf0fb`).

## Conclusión

- **Confirmado en vivo en PCSX-Redux (`SCUS-94154`):**
  1. `GoolObject`, `gool_player_ptr` (`0x8005f38c`), `gool_player_slot` (`0x8006cb10`), `gool_object_pool` (`0x8006cb14`), `gool_root_buckets` (`0x8006cb18..0x8006cb57`) y `gool_free_bucket` (`0x8006cb58`) quedan verificados en vivo; mover a Crash cambia exactamente `pos`, `rot`, `zone` y `anim_frame`, y las 8 cubetas raíz son imprescindibles frente al pool plano porque `55` slots conservan `+0x04 == 3` tras liberarse.
  2. `DISPENV` (`512x240`), `DRAWENV` (`512x216`, `y=12`, `ofs_y=12`), `draw_letterbox_and_fov`, `draw_bg_tile` (`512x216`), `quantize_frame_ticks`, `render_queue_flush`, `hud_transform_2d` (`0x80044558`) y la escala GTE **`-5/8`** en fila Y + negación Z de `matrix_aspect_scale_local` (`0x80043090`) quedan verificados bit a bit en ejecución real.
