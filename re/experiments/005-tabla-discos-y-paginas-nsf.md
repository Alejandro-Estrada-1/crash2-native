# Resultado — Experimento 005: Tabla CD ISO9660 y paginación dinámica NSD/NSF

- **Fecha:** 2026-11-15
- **Script:** `re/experiments/005-tabla-discos-y-paginas-nsf.gdb`
- **Comando:**
  ```bash
  PSX_GDB_PORT=3333 scripts/gdb-psx -batch -x re/experiments/005-tabla-discos-y-paginas-nsf.gdb
  ```
- **Entorno:** PCSX-Redux (GDB `:3333`, nivel activo `0x1e` / `30`, juego corriendo; snapshot en `$pc = 0x8001b790`, `$sp = 0x801ffdb0`, `$gp = 0x8005f17c`).
- **BIOS (`0xbfc00000+0x1000`):** `sha256: 870563babc435b1027ab59237eb150e2f95ffe385f9d29830f45e1e038fc351e` (`OpenBIOS PCSX-Redux build 561`).
- **Estado de salida:** `exit 0`, `[Inferior 1 (process 1) detached]`.

## Salida observada frente a la expectativa

1. **Estado global y `disc_file_table` (`0x80069034`):**
   - `cd_mode (0x8005f1a4) = 1`, `current_level_id (0x8005f3ec) = 0x1e (30)`, `next_level_id (0x8005f3f0) = -1`, `frame_counter = 26991`, `rcnt2_tick_count = 958804`, `geom_screen (0x80060884) = 288`.

| `level_id` | Dirección tabla | `nsd_lba` medido | `nsd_size` medido | `nsf_lba` medido | Coincide con ISO |
|---|---|---|---|---|---|
| `0x02` | `0x8006904c` | `57385` (`0xe029`) | `5844` (`0x16d4`) | `57388` (`0xe02c`) | Sí (exacto) |
| `0x10` | `0x800690f4` | `25` (`0x19`) | `5412` (`0x1524`) | `28` (`0x1c`) | Sí (exacto) |
| `0x3c` | `0x80069304` | `56422` (`0xdc66`) | `3284` (`0xcd4`) | `56424` (`0xdc68`) | Sí (exacto) |
| `0x1e` (activo) | `0x8006919c` | `29760` (`0x7440`) | `5124` (`0x1404`) | `29763` (`0x7443`) | Sí (coherente con `nsd_paging_state`) |

2. **Heap del juego y `nsd_paging_state` (`0x80067588`):**
   - `bss_end/heap_start = 0x8006f1f0`, `heap_head = 0x8006f1f4`, `heap_brk = 0x801fd848`, `heap_limit = 0x801ff000`, `heap_init_flag = 1`.
   - `nsd_paging_state`: `+0x00 active = 1`, `+0x04 level_id = 0x1e (30)`, `+0x08 eid_buckets_ptr = 0x8006f1f8`, `+0x0c eid_list_ptr = 0x8006f718`, `+0x14 world_hdr_ptr = 0x80070378`, `+0x18 nsd_buf = 0x8006f1f8`, `+0x20 nsf_base_lba = 29763 (0x7443)`, `+0x28 num_phys_pages = 21`, `num_virt_pages = 37`, `pending_pages = 0`, `active_cd_page = 0x00000000`, `eid_lut_ptr = 0x80070600`.
   - Cabecera `*nsd_buf + 0x400`: `nsf_page_count = 0x4c (76)`, `eid_count = 0x18c (396)`.
   - Primeros 4 slots físicos (`0x800675b4`, stride `0x2c`, páginas contiguas de `0x10000` = `64 KiB`):
     - `phys[0] @0x800675b4`: `buf=0x800ad844`, `state=0x14`, `page_id=0x5f`, `page_hdr={magic=0x1234, type=0, eid=0x5f, cnt=2}`
     - `phys[1] @0x800675e0`: `buf=0x800bd844`, `state=0x14`, `page_id=0x8d`, `page_hdr={magic=0x1234, type=0, eid=0x8d, cnt=9}`
     - `phys[2] @0x8006760c`: `buf=0x800cd844`, `state=0x14`, `page_id=0x69`, `page_hdr={magic=0x1234, type=0, eid=0x69, cnt=3}`
     - `phys[3] @0x80067638`: `buf=0x800dd844`, `state=0x14`, `page_id=0x37`, `page_hdr={magic=0x1234, type=0, eid=0x37, cnt=2}`

3. **Verificación secundaria (`quantize_frame_ticks` en `0x80016f04`):**
   - `fb_cur (0x80063450) = 0x800654f0`: `raw_ticks (+0x0c) = 963760`, `quant_ticks (+0x14) = 34 (0x22)`.
   - `fb_prev (0x80063454) = 0x800654f0`: `raw_ticks (+0x0c) = 963967`, `quant_ticks (+0x14) = 34 (0x22)` (`2 × 0x11`).

## Conclusión

- **Confirmado en vivo en PCSX-Redux:** `iso9660_scan_levels` (`0x800316ec`) puebla `disc_file_table` (`0x80069034`) exactamente con los LBA/tamaños del ISO; `level_load` (`0x80014c68`) configura `nsd_paging_state` (`0x80067588`) y asigna `.NSD`, LUT de EIDs y `21` páginas físicas de `64 KiB` dentro del heap propio del juego (`>= 0x8006f1f4`); y el campo `+0x14` de ticks cuantizados por `quantize_frame_ticks` (`0x80016f04`) vale exactamente `0x22` (`34`, múltiplo de `0x11`).
