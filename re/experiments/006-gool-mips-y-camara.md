# Resultado — Experimento 006: Código MIPS nativo en GOOL (`type == 11`, `0x8003aad4`), auditoría BSS y Cámara/Proyección

- **Fecha:** 2026-11-15
- **Script:** `re/experiments/006-gool-mips-y-camara.gdb`
- **Comando:**
  ```bash
  PSX_GDB_PORT=3333 PSX_GDB_TIMEOUT=45 scripts/gdb-psx -batch -x re/experiments/006-gool-mips-y-camara.gdb
  ```
- **Entorno:** PCSX-Redux (GDB `:3333`, nivel activo `0x1e` / `30`, juego corriendo; inicio en `$pc = 0x8002a158`).
- **BIOS (`0xbfc00000+0x1000`):** `sha256: 870563babc435b1027ab59237eb150e2f95ffe385f9d29830f45e1e038fc351e` (`OpenBIOS PCSX-Redux build 561`).
- **Estado de salida:** `exit 0`, `[Inferior 1 (process 1) detached]`.

## Salida observada frente a la expectativa

1. **Chunks `GOOL` (`type == 11`) residentes en el pool físico `0x800675b4`:**
   - Se detectaron **12** entradas `type == 11` residentes entre `phys[9]..phys[18]`, incluyendo `phys[15] (0x8019d844) ent[0]=0x8019d870 EID=0x4e938ccd sec[1]=0x8019d8b4` y `phys[15] ent[3]=0x801a4e5c EID=0x66536ecd sec[1]=0x801a4ea0`.

2. **Verificación viva 1 — salto `0x8003aad4: jalr s5` hacia bloque MIPS en RAM heap:**
   - `hit1=1 (hops1=0)`, `$pc = 0x8003aad4`, **`$s5 = 0x8019da70`**, `$s0 (obj) = 0x800a0770`, `$s8 = 0x1f800000`, `$ra = 0x8003a574`.
   - `$s5 = 0x8019da70` cae exactamente en `sec[1] + 0x1bc` del chunk GOOL residente `EID=0x4e938ccd` (`phys[15]`, `0x8019d8b4`).
   - Desensamblado en vivo desde `0x8019da70`:
     ```mips
     0x8019da70: lw    v0, -4(s6)
     0x8019da74: nop
     0x8019da78: sw    v0, 216(s0)
     0x8019da7c: addiu s6, s6, -4
     0x8019da80: sw    s6, 188(s0)
     0x8019da84: jalr  s5, ra
     0x8019da88: nop
     0x8019da8c: .word 0x1c300e4b    ; bytecode GOOL intercalado
     0x8019da90: .word 0x49be0be0    ; opcode 0x49 (vuelve a saltar a MIPS)
     0x8019da94: lw    v0, -4(s6)
     ...
     ```
   - Confirma en ejecución real la intercalación de bytecode GOOL (`0x1c300e4b`, `0x49be0be0`) entre bloques MIPS nativos separados por `jalr s5, ra; nop`.

3. **Auditoría BSS `DAT_80062a18` (`+0x10` usado por `FUN_80041e5c @ 0x80041f34`):**
   - `0x80062a18..0x80062a24`: `0x800607f4` (`&cam_pos`), `0x80060824`, `0x80060924`, `0x80060774` (`&cam_view_matrix`).
   - `0x80062a28..0x80062a38` (`+0x10..+0x20`): `0x8003dd0c`, `0x80042420`, `0x800426a0`, `0x80042548`, `0x80042818`. Los 5 punteros de función apuntan estáticamente dentro de `SCUS_941.54` (`0x80010000..0x8005f800`), sin código en heap.

4. **Proyección, cámara, escala `-5/8` y `SetGeomOffset`:**
   - Estado leído: `geom_screen = 288 (0x120)`, `letterbox_level = 0`, `geom_offset_x = 0`, `geom_offset_y = 0`, `cam_shake_y = 0`, `current_zone = 0x800d5830`, `current_cam_path = 0x800da9b0`, `progress = 0x9bb`, `cam_pos = (9498721, 2139189, 14054973)`, `cam_rot = (3685, 229, 4095)`.
   - Matrices en vivo (`cam_rot_matrix 0x80060754` vs `cam_view_matrix 0x80060774`):
     - Fila 0 conservada (`0x0f07, 0xfffb, 0xfa81`).
     - Fila 1 escalada exactamente `-5/8`: `-826 (0xfcc6) -> 516 (0x0204)`, `3309 (0x0ced) -> -2069 (0xf7eb)`, `-2270 (0xf722) -> 1418 (0x058a)`.
     - Fila 2 negada (`0x0472 -> 0xfb8e`, `0x096f -> 0xf691`, `0x0c23 -> 0xf3dd`) y traslación `t[0..2]` idéntica (`0x000090f0, 0x000020a4, 0x0000d676`).
   - `display_ctx_pool`: `disp_ctx_count = 2`, `disp_ctx_front = 0x8006345c`, `disp_ctx_draw = 0x8006345c`, `disp_ctx_work = 0x800654f0`.
   - **Verificación viva 2 (`0x8004efe8` `SetGeomOffset`):** `hit2=1 (hops2=0)`, `$ra = 0x80017f78` (`cam_update`), `$a0 (OFX) = 256 (0x100)`, `$a1 (OFY) = 108 (0x6c)`.

## Conclusión

- **Confirmado en vivo en PCSX-Redux:**
  1. `gool_interpret` (`0x8003a014`) ejecuta bloques MIPS nativos alojados en `sec[1]` de chunks `GOOL` (`type = 11`) en RAM mediante `0x8003aad4: jalr s5`, intercalados con palabras de bytecode (`0x49be0be0`, etc.) y con retorno `jalr s5, ra`.
  2. `DAT_80062a18+0x10..0x20` apunta exclusivamente a funciones estáticas de `SCUS_941.54`.
  3. `cam_matrix_aspect_scale` (`0x80017af8`) aplica en vivo el factor `-5/8` a la fila Y de `cam_view_matrix`, y `cam_update` (`0x80017bc4`) fija `SetGeomOffset(256, 108)` (`512x216` centrado en `DrawEnv`).
