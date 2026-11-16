English | [Español](README.es.md)

# tools/regress — Logical-State Regression Tests

Pending Rust tool (Phase 6/7) that replays inputs and compares the game's
**logical state** (positions, entity states, RNG, counters) against a recorded
reference. It never compares framebuffer pixels. With interpolation or
widescreen enabled, logical state must remain bit-for-bit identical to the
reference (`AGENTS.md`, "Technical Priorities").

## Fixed Reference Conditions

A reference is only comparable with runs executed under identical conditions.
Each reference must record the following fields, and the tool must refuse to
compare if any of them differs:

- **BIOS: currently OpenBIOS** (bundled by `psxrecomp`, `bios/openbios.bin`).
  With a different BIOS, game code in RAM differs: OpenBIOS rewrites the PsyQ
  functions `_patch_pad`, `_send_pad`, and `_remove_ChgclrPAD`
  (`0x8004A2EC`–`0x8004A47C`) at boot so they skip kernel patching, whereas a
  Sony BIOS executes them unmodified and patches the kernel. Pad handling may
  differ. Details and evidence: `patches/psxrecomp/UPSTREAM.md`, section 6. Also
  record whether BIOS boot was skipped (`bios_boot=HLE`) or not.
- Disc (Redump SHA-1) and framework commit (`psxrecomp`).
- Seeds and generated C (hash of `generated/`).
- Any configuration affecting game logic (`game.toml`, active mods).
