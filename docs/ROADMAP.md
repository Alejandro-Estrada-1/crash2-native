English | [Español](ROADMAP.es.md)

# crash2-native — Project Roadmap

Native Linux port of *Crash Bandicoot 2: Cortex Strikes Back* (PS1, USA, `SCUS-94154`),
built on **psxrecomp**, with independent reverse engineering (Ghidra + agents via MCP),
distributed as an **AppImage**, and automated with **GitHub Actions**.

> The name `crash2-native` is provisional and can be changed anytime.

---

## 1. Why This Approach

| Decision | Rationale |
|---|---|
| **Build on psxrecomp, not Crash2Recomp** | Crash2Recomp (Zumbo06) has no license: its launcher, scripts, and patches are "all rights reserved". `psxrecomp` has a clear license (PolyForm Noncommercial 1.0.0) and is designed so each game lives in its own repo. |
| **Independent reverse engineering (Ghidra + MCP)** | Avoids depending on someone else's unlicensed work. Clean-room: from its release notes we use *what* problems exist; never its code, offsets, addresses, or structures. Everything we publish is independently observed and verified on `SCUS-94154`. |
| **Linux first** | `psxrecomp` already runs natively on Linux (demonstrated by RE3 and Hercules). Crash2Recomp only targets Windows. |
| **AppImage + Zig** | The game compiles on the user's machine. Zig provides a full, portable C/C++ compiler targeting older glibc (`x86_64-linux-gnu.2.28`), along with trimmed CMake, Ninja, prebuilt emitters, and vendored archives. |
| **GitHub Actions** | Reproducible builds in `ubuntu:22.04` (broad distro compatibility), automated releases with checksums, and zero load on the dev laptop. |
| **Owned codebase** | Every line of our code is explainable end-to-end. Strong portfolio value (DevOps + reverse engineering). |

---

## 2. Lessons from Other Projects

| Source | Lesson | How We Apply It |
|---|---|---|
| **psxrecomp** (mstan) | Titles live in their own repo with `psxrecomp/` and `recomp-ui/` as submodules. Runtime blocks outside boot text are captured and compiled dynamically; the interpreter is the safety net. | Repo layout, `game.toml`, `seeds/`, runtime overlay toolchain. |
| **Hercules Recompiled** | `psxrecomp` port compiling on Linux. Keeps framework changes as patches in `patches/psxrecomp/`. | Reference template for Phase 1. |
| **Mega Man X6 Recomp** | Seeds exported from Ghidra. Ghidra databases, binaries, generated C, and memory cards **stay local**. Framework fixes go upstream. | Strict git hygiene rules. |
| **RE3 Recompiled** | `recomp-ui` is a native launcher; Python is only needed at build/overlay time. Binaries built on Arch (newer glibc) fail on Ubuntu. | Use `recomp-ui`; build releases against older glibc (`ubuntu:22.04`). |
| **Crash2Recomp** (ideas only) | Widescreen: widening camera too far reveals missing geometry near the 4:3 edge; cropping the 12-line top/bottom black borders and keeping proportions clean avoids the known vertical-stretch bug. Avoid 60 FPS via game-loop duplication (breaks animations, timers, and per-level camera behavior). | Initial widescreen respecting `5/8` aspect scaling; avoid loop-duplication 60 FPS. |
| **Crash 1 Launcher** (MIT) | 60/120/240 FPS via **interpolation**: game logic stays at 30 Hz and camera/object transforms are interpolated on draw with zero physics side effects. | High FPS via interpolation in Phase 6. |
| **crash2-decomp** (Codeberg) | Matching decompilation of `SCUS-94154`. Uses AI, with "nothing depending on AI's word alone". | Source of naming context; destination for open contributions. |
| **portcove** (catalog) | Flagged in Crash2Recomp: missing accepted disc hashes, no bad-disc rejection, mismatched internal vs release version, missing checksums. | Our infrastructure priorities (`verify-disc`, tag-driven versions, `SHA256SUMS`). |
| **Savage Wind / ZA Recomp** | Bundle Zig inside the release package to compile on the user's machine. | AppImage with Zig. |

---

## 3. Improvements Over Crash2Recomp

1. **Native Linux** from day one (AppImage).
2. **Clear licensing**: MIT for our code + PolyForm NC / third-party notices in `NOTICE`.
3. **Strict disc verification**: Redump hash table and clear rejection of mismatched images (`tools/verify-disc` + `psxrecomp`).
4. **Verifiable releases**: version comes from the git tag; `SHA256SUMS` published with every release.
5. **High FPS via interpolation** rather than duplicating the game loop: logic stays bit-identical to PS1.
6. **Regression testing**: replays + logical state comparison so enhancements never alter gameplay logic.
7. **Open RE knowledge**: verified symbols and C structs published in `re/`.

---

## 4. Repository Structure

```
crash2-native/
├── psxrecomp/                 # submodule: mstan/psxrecomp (PolyForm NC 1.0.0)
├── recomp-ui/                 # submodule: native launcher for psxrecomp (MIT)
├── game.toml                  # game config (runtime, video, Redump digests)
├── seeds/                     # verified function starts for static recompilation
├── CMakeLists.txt
├── src/                       # OUR code: setup host, menu provider, hooks, interpolation, widescreen
├── mods/preloaded/            # preloaded title mod packages (widescreen toggle, etc.)
├── patches/
│   └── psxrecomp/             # patches to the framework (upstream candidates)
├── re/                        # reverse engineering knowledge (published)
│   ├── provisional_symbols.csv # unverified proposals (reviewable diff)
│   ├── symbols.csv            # human-verified symbols with module & evidence
│   ├── structs.h              # confirmed C structs (GoolObject, CameraTransformBlock, DisplayContext, PadState)
│   ├── NOTES.md               # confirmed / discarded / open log (with NOTES.es.md)
│   └── experiments/           # .gdb / .lua with preconditions & criteria + summaries
├── tools/
│   ├── ghidra/                # scripts: sync read-only mirror, export/import helpers
│   ├── verify-disc/           # (Rust) standalone Redump disc image verifier
│   └── regress/               # (Rust) replay & logical state regression tool
├── scripts/
│   ├── setup.sh               # dependencies, submodules, patches, disc check
│   ├── build_linux.sh         # generate + build
│   ├── respaldar_partidas.sh  # timestamped verified save backups
│   └── gdb-psx                # GDB wrapper for PCSX-Redux with timeout & auto-resume
├── packaging/
│   └── appimage/              # AppRun, .desktop, icon, build-appimage.sh, CHECK_FINDINGS.md
├── .github/workflows/
│   ├── ci.yml                 # push/PR: setup-host build, tools, syntax & hygiene checks
│   └── release.yml            # v* tags / dispatch: AppImage + SHA256SUMS
├── docs/                      # ROADMAP.md (this file) + ROADMAP.es.md
├── LICENSE                    # MIT license for our code (+ PolyForm NC notice)
├── NOTICE                     # third-party attributions (PolyForm NC, OpenBIOS, SDL3, Zig, etc.)
├── README.md                  # project overview & quickstart (+ README.es.md)
├── AGENTS.md                  # common agent rules (+ AGENTS.es.md)
├── CLAUDE.md                  # infrastructure role (+ CLAUDE.es.md)
├── GEMINI.md                  # reverse engineering role (+ GEMINI.es.md)
│
│   # --- Never in git (.gitignore, root-anchored without trailing /: /ghidra, /disc) ---
├── disc -> ../privado/disc     # symlink to legal disc image
├── saves -> ../privado/partidas
├── generated/                 # C generated from the game disc
├── build/  build-release/  build-setup/
└── ghidra                     # ignored (Ghidra project lives in ../privado/ghidra)
```

### Disk Layout

```
~/Descargas/PORTS/Crash2CSB/
├── crash2-native/        # main repo (main branch)
├── c2-infra/             # infrastructure worktree
├── c2-re/                # reverse engineering worktree
└── privado/              # NEVER in git
    ├── disc/             # Redump-verified .bin + .cue
    ├── exe/              # SCUS_941.54 and SYSTEM.CNF
    ├── ghidra/           # Ghidra project "crash2"
    └── emu/              # PCSX-Redux save states and memory cards
```

### Reference Disc (Redump)

| Field | Value |
|---|---|
| Serial | `SCUS-94154` (Original and Greatest Hits editions) |
| Size | `192,814,608` bytes (`81,979` sectors, 1 track) |
| CRC-32 | `395c0916` |
| MD5 | `3c31b5e038f025098a2fdfa70c8213f2` |
| SHA-1 | `3d37fe4288a83b01f1a0edbf78e76e0fede6bc22` |
| LibCrypt | No |

---

## 5. Toolchain

| Tool | Purpose | Arch Linux Package / Source |
|---|---|---|
| `psxrecomp` + `recomp-ui` | Recompiler, runtime, launcher | git submodules |
| `clang`/`gcc`, CMake, Ninja, Python 3 | Build and codegen | `pacman -S clang cmake ninja python` |
| Zig | Portable compiler for AppImage; `-target x86_64-linux-gnu.2.28` | `pacman -S zig` |
| Ghidra + `ghidra_psx_ldr` | Static analysis; PSX loader & PsyQ signatures | `pacman -S ghidra` + lab313ru plugin |
| `pyghidra-mcp` | Read-only MCP access to Ghidra project copy | `pyghidra-mcp==0.3.0` |
| PCSX-Redux | Emulator with debugger, GDB server, and Lua console | AppImage or AUR |
| GDB (`+ scripts/gdb-psx`) | Remote debugging in `-batch` mode with timeout | `pacman -S gdb` |
| Docker / Podman | Clean `ubuntu:22.04` container validation | `pacman -S docker` / `podman` |
| Rust (`cargo`) | Project tools: `verify-disc`, `regress` | `pacman -S rustup` |

---

## 6. Phases

### Phase 0 — Preparation
- [x] Verify disc: serial `SCUS-94154` and hashes against Redump.
- [x] Read `psxrecomp` docs (`EXECUTION_MODEL.md`, `ARCHITECTURE.md`, `BUILDING.md`, `GAME_PROJECT_SETUP.md`, `config_schema.md`).
- [x] Decide project license (MIT) and draft `NOTICE`.

**Done when:** environment is set up and disc is verified.

### Phase 1 — Template & Base Project
- [x] Study Hercules Recompiled (`game.toml`, seeds, patches, CMake) as reference.
- [x] Set up repository structure, submodules, `scripts/setup.sh`, and `scripts/build_linux.sh`.

**Done when:** build system structure is ready and verified.

### Phase 2 — Crash 2 Boots (30 FPS)
- [x] Minimal `game.toml` for `SCUS-94154` and initial seeds.
- [x] Integrate `recomp-ui` launcher, in-game menu (`src/menu_provider.c`), and setup wizard (`src/codegen_setup.c`).
- [x] Boot and play on Linux at 30 FPS with `803` seeds.

**Done when:** Crash 2 runs and plays a level at 30 FPS on Linux.

### Phase 3 — Reverse Engineering
- [x] Ghidra project with `ghidra_psx_ldr` and PsyQ 4.0 signatures.
- [x] Map PsyQ functions (`SetGeomScreen`, `DrawOTag`, `PutDispEnv`, `PutDrawEnv`, `VSync`, `CdRead`) and cross-references.
- [x] Map CD loading (`.NSD`/`.NSF` paging) and dynamic native MIPS blocks inside `GOOL` (`type == 11`, `sec[1]`, `0x8003aad4`).
- [x] Verify main 30 Hz timing loop, camera update, `512x216` (`y=12`) clipping, three `5/8` GTE scaling paths, active entity traversal (`gool_root_buckets` / `GoolObject`), `PadState`, and `RNG` (`001`–`008`).
- [x] Promote 60 confirmed symbols to `re/symbols.csv`, create `re/structs.h`, and expand `seeds/ghidra_funcs.txt` (`803` unique seeds).

**Done when:** camera, clipping, and main loop/entities are verified in the emulator.

### Phase 4 — Infrastructure
- [x] `tools/verify-disc` (Rust): Redump hashes and bad-image rejection.
- [x] `ci.yml`: `container: ubuntu:22.04` disc-less build and tests.
- [x] AppImage with Zig `0.17.1`, trimmed CMake, Ninja, `tomli`, pinned `type2-runtime`, user data in `~/.local/share/crash2-native/`.
- [x] `release.yml`: tag-driven version, AppImage + `SHA256SUMS`.
- [ ] Run remote `ci.yml` and `release.yml` (`workflow_dispatch` / `v0.1.0`) on GitHub Actions and verify on Arch + Ubuntu 22.04.

**Done when:** tag `v0.1.0` produces an AppImage on GitHub Actions that runs on Arch and Ubuntu 22.04.

### Phase 5 — Widescreen
- [x] Crop top and bottom 12-line black borders (`DRAWENV` `512x216` at `y=12`).
- [x] Reimplement "open camera slightly and stretch slightly" cleanly, preserving `5/8` GTE vertical scaling across all three confirmed paths (preloaded mod `crash2.enhancement.widescreen`, balanced `1.125x` default + `1.10x`/`1.20x`).
- [ ] Later, level by level: widen true projection/culling where level geometry permits.

### Phase 6 — High FPS via Interpolation
- [ ] Capture camera and active entity transforms (`gool_root_buckets`) on each 30 Hz logic tick.
- [ ] Interpolate on draw (60/120/144 Hz).
- [ ] Verify bit-identical logic against stock execution with `tools/regress`.

### Phase 7 — Regression Testing, Release & Upstream Contributions
- [ ] Level replays as local logical-state regression tests.
- [ ] Public release.
- [ ] Propose useful framework patches (`patches/psxrecomp/`) upstream to `mstan/psxrecomp`.

---

## 7. Two-Agent Workflow

| | Claude Code / Infra | Antigravity / RE |
|---|---|---|
| Role | Infrastructure | Reverse Engineering |
| Worktree / branch | `../c2-infra`, `infra/...` | `../c2-re`, `re/...` |
| Exclusive resource | Local builds | Emulator + GDB server |
| Rules | `CLAUDE.md` (imports `AGENTS.md`) | `GEMINI.md` + `AGENTS.md` |

Tasks live in GitHub Issues (`agente:claude`, `agente:agy`). The human merges
PRs into `main` and owns the canonical truth files (`symbols.csv`, `structs.h`,
`seeds/`, rules).

---

## 8. Open Risks and Mitigations

| Risk | Mitigation |
|---|---|
| Runtime fixes needed specifically for Crash 2 | Phase 3 findings + framework patches in `patches/psxrecomp/` |
| `psxrecomp` GPU constraints for full native widescreen | Start with slight FOV + crop/stretch respecting `5/8` aspect paths; extend renderer upstream if needed |
| `zig cc` compatibility with generated C / host headers | Verified in `infra/appimage-check` (`0001`/`0002` patches + minimal X11/GL/ALSA headers); system compiler fallback kept (`CRASH2NATIVE_USE_SYSTEM_CC=1`) |
| Disc streaming during gameplay | Verified in `005`: `.NSF` pages stream continuously via `CdRead` async state machine |
| AI agent makes confident mistakes | Nothing trusted without emulator verification; agents cannot edit Ghidra |
| Read-only Ghidra MCP | Proposals go to `re/provisional_symbols.csv`; human promotes and syncs |
| Unhit breakpoint hangs `gdb -batch` | `gdb-psx` uses `timeout`, fast connect abort, and `$c#63` resume; experiments declare preconditions and failure criteria |
| Dynamic MIPS code inside `GOOL` `.NSF` chunks (`sec[1]`) | Identified in `006` (`0x8003aad4`); `AppRun` bundles `tomli` + `zig-cc` for runtime overlay recompilation |
| Widescreen or interpolation silently alters logic | `tools/regress` compares logical state (`PadState`, `RNG`, `GoolObject`, counters), never pixels |
| PolyForm NC license | Project is and remains free and strictly noncommercial |
