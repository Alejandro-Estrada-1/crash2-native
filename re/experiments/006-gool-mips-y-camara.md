English | [Español](006-gool-mips-y-camara.es.md)

# Result — Experiment 006: Native MIPS Code in GOOL (`type == 11`, `0x8003aad4`), BSS Audit, and Camera/Projection

- **Date:** 2026-11-15
- **Script:** `re/experiments/006-gool-mips-y-camara.gdb`
- **Command:**
  ```bash
  PSX_GDB_PORT=3333 PSX_GDB_TIMEOUT=45 scripts/gdb-psx -batch -x re/experiments/006-gool-mips-y-camara.gdb
  ```
- **Environment:** PCSX-Redux (GDB `:3333`, active level `0x1e` / `30`, game running; start at `$pc = 0x8002a158`).
- **BIOS (`0xbfc00000+0x1000`):** `sha256: 870563babc435b1027ab59237eb150e2f95ffe385f9d29830f45e1e038fc351e` (`OpenBIOS PCSX-Redux build 561`).
- **Exit status:** `exit 0`, `[Inferior 1 (process 1) detached]`.

## Observed Output vs. Expectation

1. **Resident `GOOL` (`type == 11`) chunks in physical pool `0x800675b4`:**
   - **12** resident `type == 11` entries were detected across `phys[9]..phys[18]`, including `phys[15] (0x8019d844) ent[0]=0x8019d870 EID=0x4e938ccd sec[1]=0x8019d8b4` and `phys[15] ent[3]=0x801a4e5c EID=0x66536ecd sec[1]=0x801a4ea0`.

2. **Live verification 1 — jump `0x8003aad4: jalr s5` into MIPS block in heap RAM:**
   - `hit1=1 (hops1=0)`, `$pc = 0x8003aad4`, **`$s5 = 0x8019da70`**, `$s0 (obj) = 0x800a0770`, `$s8 = 0x1f800000`, `$ra = 0x8003a574`.
   - `$s5 = 0x8019da70` lands exactly at `sec[1] + 0x1bc` of resident GOOL chunk `EID=0x4e938ccd` (`phys[15]`, `0x8019d8b4`).
   - Live disassembly from `0x8019da70`:
     ```mips
     0x8019da70: lw    v0, -4(s6)
     0x8019da74: nop
     0x8019da78: sw    v0, 216(s0)
     0x8019da7c: addiu s6, s6, -4
     0x8019da80: sw    s6, 188(s0)
     0x8019da84: jalr  s5, ra
     0x8019da88: nop
     0x8019da8c: .word 0x1c300e4b    ; interleaved GOOL bytecode
     0x8019da90: .word 0x49be0be0    ; opcode 0x49 (jumps back to MIPS)
     0x8019da94: lw    v0, -4(s6)
     ...
     ```
   - Confirms during real execution the interleaving of GOOL bytecode (`0x1c300e4b`, `0x49be0be0`) between native MIPS blocks separated by `jalr s5, ra; nop`.

3. **BSS audit `DAT_80062a18` (`+0x10` used by `FUN_80041e5c @ 0x80041f34`):**
   - `0x80062a18..0x80062a24`: `0x800607f4` (`&cam_pos`), `0x80060824`, `0x80060924`, `0x80060774` (`&cam_view_matrix`).
   - `0x80062a28..0x80062a38` (`+0x10..+0x20`): `0x8003dd0c`, `0x80042420`, `0x800426a0`, `0x80042548`, `0x80042818`. All 5 function pointers point statically inside `SCUS_941.54` (`0x80010000..0x8005f800`), with no code in the heap.

4. **Projection, camera, `-5/8` scale, and `SetGeomOffset`:**
   - Read state: `geom_screen = 288 (0x120)`, `letterbox_level = 0`, `geom_offset_x = 0`, `geom_offset_y = 0`, `cam_shake_y = 0`, `current_zone = 0x800d5830`, `current_cam_path = 0x800da9b0`, `progress = 0x9bb`, `cam_pos = (9498721, 2139189, 14054973)`, `cam_rot = (3685, 229, 4095)`.
   - Live matrices (`cam_rot_matrix 0x80060754` vs `cam_view_matrix 0x80060774`):
     - Row 0 preserved (`0x0f07, 0xfffb, 0xfa81`).
     - Row 1 scaled by exact `-5/8`: `-826 (0xfcc6) -> 516 (0x0204)`, `3309 (0x0ced) -> -2069 (0xf7eb)`, `-2270 (0xf722) -> 1418 (0x058a)`.
     - Row 2 negated (`0x0472 -> 0xfb8e`, `0x096f -> 0xf691`, `0x0c23 -> 0xf3dd`) and identical translation `t[0..2]` (`0x000090f0, 0x000020a4, 0x0000d676`).
   - `display_ctx_pool`: `disp_ctx_count = 2`, `disp_ctx_front = 0x8006345c`, `disp_ctx_draw = 0x8006345c`, `disp_ctx_work = 0x800654f0`.
   - **Live verification 2 (`0x8004efe8` `SetGeomOffset`):** `hit2=1 (hops2=0)`, `$ra = 0x80017f78` (`cam_update`), `$a0 (OFX) = 256 (0x100)`, `$a1 (OFY) = 108 (0x6c)`.

## Conclusion

- **Live-confirmed in PCSX-Redux:**
  1. `gool_interpret` (`0x8003a014`) executes native MIPS blocks stored in `sec[1]` of `GOOL` (`type = 11`) chunks in RAM via `0x8003aad4: jalr s5`, interleaved with bytecode words (`0x49be0be0`, etc.) and returning via `jalr s5, ra`.
  2. `DAT_80062a18+0x10..0x20` points exclusively to static functions in `SCUS_941.54`.
  3. `cam_matrix_aspect_scale` (`0x80017af8`) applies the `-5/8` factor live to the Y row of `cam_view_matrix`, and `cam_update` (`0x80017bc4`) sets `SetGeomOffset(256, 108)` (`512x216` centered in `DrawEnv`).
