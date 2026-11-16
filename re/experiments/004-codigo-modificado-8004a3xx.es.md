[English](004-codigo-modificado-8004a3xx.md) | Español

# Resultado — Experimento 004: Parcheo de OpenBIOS sobre `0x8004A308` / `0x8004A3A8` / `0x8004A440`

- **Fecha:** 2026-11-15
- **Script:** `re/experiments/004-codigo-modificado-8004a3xx.gdb`
- **Comando:**
  ```bash
  PSX_GDB_PORT=3333 PSX_GDB_TIMEOUT=60 scripts/gdb-psx -batch -x re/experiments/004-codigo-modificado-8004a3xx.gdb
  ```
- **Entorno:** PCSX-Redux (CPU intérprete, depurador activo, GDB `:3333`).
- **BIOS:** OpenBIOS (integrada en PCSX-Redux).
- **Precondición:** Slot 1 cargado en el primer nivel (tras `InitPAD`), juego corriendo.
- **Estado de salida:** `exit 0`, `[Inferior 1 (process 1) detached]`.

## Salida observada frente a la expectativa

1. **Las 3 ventanas tras `B0:57` (`GetB0Table`) en `0x8004a2ec..0x8004a47f`:**

| Ventana | Función (`main`) | Palabras en `SCUS_941.54` (EXE estático) | Palabras en RAM viva (PCSX-Redux + OpenBIOS) | Coincide con expectativa |
|---|---|---|---|---|
| `0x8004a308..0x8004a314` | `_patch_pad` | `8c42016c 3c018006 20430884 ac23f32c` | `00000000 00000000 1000000a 00000000` (`nop; nop; b +10; nop`) | Sí (exacto) |
| `0x8004a3a8..0x8004a3b4` | `_send_pad` | `8c42016c 3c0a8005 3c098005 3c018006` | `00000000 00000000 1000000c 00000000` (`nop; nop; b +12; nop`) | Sí (exacto) |
| `0x8004a440..0x8004a44c` | `_remove_ChgclrPAD` | `8c42016c 240a0009 2043062c 254affff` | `00000000 00000000 10000005 00000000` (`nop; nop; b +5; nop`) | Sí (exacto) |

   - El resto del bloque `0x8004a2ec..0x8004a47f` (las otras 89 de 101 palabras) permanece idéntico palabra por palabra al ejecutable `SCUS_941.54`.

2. **Punteros y retornos guardados en `0x8005f324..0x8005f344`:**
   - `DAT_8005f324 = 0x8004a03c` (retorno guardado de `_patch_pad` ← `InitPAD` en `0x8004a034`)
   - `DAT_8005f334 = 0x8004a070` (retorno guardado de `_send_pad` ← `InitPAD` en `0x8004a068`)
   - `DAT_8005f344 = 0x8004a02c` (retorno guardado de `_remove_ChgclrPAD` ← `InitPAD` en `0x8004a024`)
   - `DAT_8005f32c` (`EnablePAD`) = `0xbfc088f4`
   - `DAT_8005f330` (`DisablePAD`) = `0xbfc08904`
   - `DAT_8005f338` (`_SendPAD`) = `0x00003f88`

## Conclusión

- **Confirmado dinámicamente en PCSX-Redux con OpenBIOS:** la reescritura observada en `0x8004a308`, `0x8004a3a8` y `0x8004a440` en `psxrecomp` ocurre de forma idéntica en el juego original corriendo bajo OpenBIOS (`nop; nop; b +10/+12/+5; nop`), y `DAT_8005f32c/30/38` quedan poblados directamente por `patch_hook` de OpenBIOS (`EnablePAD`/`DisablePAD` hacia `0xbfc0xxxx` y `_SendPAD` hacia RAM de kernel `0x00003f88`).
- Por tanto, **el juego no se automodifica**: es comportamiento estándar del mecanismo `getB0table` → `patch_hook` de **OpenBIOS** sobre las rutinas `libapi` de PsyQ 4.0 (`_patch_pad`, `_send_pad`, `_remove_ChgclrPAD`).
