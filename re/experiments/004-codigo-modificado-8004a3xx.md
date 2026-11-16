English | [Español](004-codigo-modificado-8004a3xx.es.md)

# Result — Experiment 004: OpenBIOS Patching over `0x8004A308` / `0x8004A3A8` / `0x8004A440`

- **Date:** 2026-11-15
- **Script:** `re/experiments/004-codigo-modificado-8004a3xx.gdb`
- **Command:**
  ```bash
  PSX_GDB_PORT=3333 PSX_GDB_TIMEOUT=60 scripts/gdb-psx -batch -x re/experiments/004-codigo-modificado-8004a3xx.gdb
  ```
- **Environment:** PCSX-Redux (interpreter CPU, debugger enabled, GDB `:3333`).
- **BIOS:** OpenBIOS (integrated in PCSX-Redux).
- **Precondition:** Slot 1 loaded in the first level (after `InitPAD`), game running.
- **Exit status:** `exit 0`, `[Inferior 1 (process 1) detached]`.

## Observed Output vs. Expectation

1. **The 3 windows after `B0:57` (`GetB0Table`) in `0x8004a2ec..0x8004a47f`:**

| Window | Function (`main`) | Words in `SCUS_941.54` (static EXE) | Words in live RAM (PCSX-Redux + OpenBIOS) | Matches expectation |
|---|---|---|---|---|
| `0x8004a308..0x8004a314` | `_patch_pad` | `8c42016c 3c018006 20430884 ac23f32c` | `00000000 00000000 1000000a 00000000` (`nop; nop; b +10; nop`) | Yes (exact) |
| `0x8004a3a8..0x8004a3b4` | `_send_pad` | `8c42016c 3c0a8005 3c098005 3c018006` | `00000000 00000000 1000000c 00000000` (`nop; nop; b +12; nop`) | Yes (exact) |
| `0x8004a440..0x8004a44c` | `_remove_ChgclrPAD` | `8c42016c 240a0009 2043062c 254affff` | `00000000 00000000 10000005 00000000` (`nop; nop; b +5; nop`) | Yes (exact) |

   - The rest of the `0x8004a2ec..0x8004a47f` block (the other 89 of 101 words) remains word-for-word identical to the `SCUS_941.54` executable.

2. **Pointers and saved return addresses in `0x8005f324..0x8005f344`:**
   - `DAT_8005f324 = 0x8004a03c` (saved return from `_patch_pad` ← `InitPAD` at `0x8004a034`)
   - `DAT_8005f334 = 0x8004a070` (saved return from `_send_pad` ← `InitPAD` at `0x8004a068`)
   - `DAT_8005f344 = 0x8004a02c` (saved return from `_remove_ChgclrPAD` ← `InitPAD` at `0x8004a024`)
   - `DAT_8005f32c` (`EnablePAD`) = `0xbfc088f4`
   - `DAT_8005f330` (`DisablePAD`) = `0xbfc08904`
   - `DAT_8005f338` (`_SendPAD`) = `0x00003f88`

## Conclusion

- **Dynamically confirmed in PCSX-Redux with OpenBIOS:** the rewrite observed at `0x8004a308`, `0x8004a3a8`, and `0x8004a440` in `psxrecomp` occurs identically in the original game running under OpenBIOS (`nop; nop; b +10/+12/+5; nop`), and `DAT_8005f32c/30/38` are populated directly by OpenBIOS's `patch_hook` (`EnablePAD`/`DisablePAD` pointing to `0xbfc0xxxx` and `_SendPAD` pointing to kernel RAM `0x00003f88`).
- Therefore, **the game is not self-modifying**: it is standard behavior of **OpenBIOS**'s `getB0table` → `patch_hook` mechanism over PsyQ 4.0 `libapi` routines (`_patch_pad`, `_send_pad`, `_remove_ChgclrPAD`).
