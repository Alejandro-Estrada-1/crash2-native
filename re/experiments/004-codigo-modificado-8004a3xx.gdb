# ------------------------------------------------------------------
# Experiment 004: Verification in PCSX-Redux of OpenBIOS patching
#                 over 0x8004A308 / 0x8004A3A8 / 0x8004A440
#
# Precondition:  PCSX-Redux running SCUS-94154 already initialized after
#                InitPAD (e.g. save state in slot 1 inside the first
#                level, Crash standing still; or pause menu). GDB on :3333.
# BIOS:          OpenBIOS (integrated in PCSX-Redux; exact version/build ID
#                to be confirmed on execution)
# Module:        main (SCUS_941.54, 0x8004a2ec..0x8004a47f)
# Hypothesis:    In the static SCUS_941.54 binary nothing writes to
#                0x8004A3xx, but OpenBIOS intercepts GetB0Table (B0:57) via
#                getB0table -> patch_hook($ra): patches DAT_8005f32c/30/38
#                in RAM and rewrites the 4 words starting at $ra in the caller
#                with `nop; nop; b +N; nop` to skip the BIOS write:
#                - _patch_pad        (0x8004a308): nop; nop; b +10 (0x1000000a); nop -> 0x8004a33c
#                - _send_pad         (0x8004a3a8): nop; nop; b +12 (0x1000000c); nop -> 0x8004a3e4
#                - _remove_ChgclrPAD (0x8004a440): nop; nop; b +5  (0x10000005); nop -> 0x8004a460
# Success:       In live PCSX-Redux RAM (with OpenBIOS), all three windows
#                show that rewrite (`0x00000000 0x00000000 0x100000xx
#                0x00000000`) and DAT_8005f32c/30/38 are populated by the hook.
# Failure:       0x8004a308 / 0x8004a3a8 / 0x8004a440 preserve `0x8c42016c`
#                (`lw v0,0x16c(v0)` from the unmodified EXE) or show opcodes
#                different from the OpenBIOS pattern.
# Writes memory: no (read-only)
# ------------------------------------------------------------------

echo === [004] Foco 1: _patch_pad en 0x8004a308 (EXE: 8c42016c... | OpenBIOS: 0 0 1000000a 0) ===\n
x/14wx 0x8004a308

echo === [004] Foco 2: _send_pad en 0x8004a3a8 (EXE: 8c42016c... | OpenBIOS: 0 0 1000000c 0) ===\n
x/16wx 0x8004a3a8

echo === [004] Foco 3: _remove_ChgclrPAD en 0x8004a440 (EXE: 8c42016c... | OpenBIOS: 0 0 10000005 0) ===\n
x/10wx 0x8004a440

echo === [004] Bloque completo 0x8004a2ec..0x8004a47f (101 palabras) ===\n
x/101wx 0x8004a2ec

echo === [004] Punteros y estado en 0x8005f324..0x8005f347 ===\n
x/9wx 0x8005f324

printf "DAT_8005f32c (EnablePAD)  = 0x%08x\n", *(unsigned int*)0x8005f32c
printf "DAT_8005f330 (DisablePAD) = 0x%08x\n", *(unsigned int*)0x8005f330
printf "DAT_8005f338 (_SendPAD)   = 0x%08x\n", *(unsigned int*)0x8005f338

detach
