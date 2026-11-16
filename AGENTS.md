English | [Español](AGENTS.es.md)

# AGENTS.md — crash2-native (common rules for all agents)

This file is read by Claude Code (via `CLAUDE.md`) and Antigravity. Each agent
also has its specific role in its own file: `CLAUDE.md` (infrastructure) and
`GEMINI.md` (reverse engineering).

Native Linux port of *Crash Bandicoot 2: Cortex Strikes Back* (PS1, `SCUS-94154`)
built on **psxrecomp**. The full roadmap, phases, and rationale for every
decision are in `docs/ROADMAP.md`. Read that file at the start of a session for
any non-trivial task.

## Unbreakable Rules

1. **Nothing from the game enters git.** No disc images, no extracted
   executables, no generated C (`generated/`), no Ghidra projects (`ghidra/`),
   no memory cards, no save states, and no memory dumps. Before every commit,
   check `git status`. If anything like that appears, stop and report it.
2. **Clean-room regarding Crash2Recomp (Zumbo06).** Its repository has no
   license. Do not copy its code, offsets, addresses, structures, or constants.
   You may read its release notes to know *what* problems exist; every fact
   added to `re/` must be independently observed and verified on `SCUS-94154`
   with Ghidra and PCSX-Redux.
3. **psxrecomp is PolyForm Noncommercial 1.0.0.** Preserve its notices. No
   commercial use.
4. **Do not modify `psxrecomp/` directly.** Framework changes go as patches in
   `patches/psxrecomp/`, explained in the commit message. If a change is
   generic, mark it as an upstream candidate.
5. **Nothing is true until verified in the game.** See "Reverse Engineering"
   below.
6. **The user's disc is read-only.** Never modify it.

## Repository Map

| Path | Contents | In git? |
|---|---|---|
| `psxrecomp/`, `recomp-ui/` | Framework submodules | yes (as submodules) |
| `game.toml`, `seeds/`, `CMakeLists.txt` | Game configuration and seeds | yes |
| `src/` | Our code: hooks, interpolation, widescreen, setup/menu | yes |
| `patches/psxrecomp/` | Patches to the framework | yes |
| `re/provisional_symbols.csv` | Unverified agent proposals | yes |
| `re/symbols.csv`, `re/structs.h` | Human-verified data only | yes |
| `re/NOTES.md`, `re/experiments/` | Reverse-engineering log and experiments (`.gdb`, `.lua`, summaries) | yes |
| `tools/` | `ghidra/` (scripts), `verify-disc/` and `regress/` (Rust) | yes |
| `scripts/` | `setup.sh`, `build_linux.sh`, `gdb-psx`, `respaldar_partidas.sh` | yes |
| `packaging/appimage/` | `AppRun`, `.desktop`, icon, packaging script | yes |
| `.github/workflows/` | `ci.yml`, `release.yml` | yes |
| `README.md`, `LICENSE`, `NOTICE`, `docs/` | Project documentation and legal notices | yes |
| `/disc` (symlink), `/generated`, `/build*`, `/ghidra` | Game data and build outputs | **no** |

`.gitignore` anchors those paths to the root with no trailing slash (`/ghidra`,
not `ghidra/`), so it does not accidentally ignore `tools/ghidra/` while still
ignoring symlinks. Follow the same format when adding ignored paths.

### Disk Layout

```
Crash2CSB/
├── crash2-native/   # repository, main branch (human)
├── c2-infra/        # Claude / Infra worktree
├── c2-re/           # Antigravity / RE worktree
└── privado/         # outside git: disc/, exe/ (SCUS_941.54), ghidra/ (project), emu/
```

`disc` inside the repo is a symlink to `../privado/disc`. Never copy data from
`privado/` into the repo. The executable for static analysis is at
`../privado/exe/SCUS_941.54`.

## Commands

```bash
scripts/setup.sh                       # submodules and dependencies
scripts/build_linux.sh                 # generate C from disc/ and compile
ninja -C build-release -j2             # rebuild after a change (laptop: few jobs)
export PSX_GDB_PORT=<port>             # port shown in PCSX-Redux configuration
scripts/gdb-psx -batch -x re/experiments/<exp>.gdb   # experiment against PCSX-Redux (with timeout)
PSX_GDB_TIMEOUT=60 scripts/gdb-psx -batch -x ...     # longer timeout if needed
```

Development hardware: Intel Tiger Lake laptop (4 cores, Iris Xe). Use `-j2` or
`-j4`; do not launch heavy parallel builds. Final builds run on GitHub Actions.

## Reverse Engineering: Mandatory Cycle

Tools: Ghidra (with `ghidra_psx_ldr`; MCP access, read-only), PCSX-Redux with
its GDB server and Lua console, `scripts/gdb-psx`.

**Only the human modifies the Ghidra project.** Agents must not rename or
comment inside Ghidra, even if the tool permits it. Proposals go into
`re/provisional_symbols.csv` as a reviewable diff.

1. **Hypothesis.** Start from known functions (PsyQ: `SetGeomScreen`, `DrawOTag`,
   `VSync`, `CdRead`, ...) and follow cross-references. Formulate a concrete
   hypothesis: "the function at `0x8002xxxx` updates the camera".
2. **Code location.** Before anything else, determine whether the address
   belongs to the **main executable** (`main`) or to dynamically loaded RAM
   blocks/chunks (e.g., `.NSF` `GOOL` type 11), and when it is loaded.
3. **Static evidence.** Provide addresses, cross-references, relevant
   pseudocode/disassembly, and constants. Never a conclusion alone.
4. **Proposal.** Add a row to `re/provisional_symbols.csv` with status
   `propuesto`.
5. **Dynamic experiment.** Copy `re/experiments/000-plantilla.gdb` as
   `NNN-description.gdb` and fill in its header: **precondition** (exact save
   slot or active screen), **hypothesis**, **success criteria**, and **failure
   criteria** (including "the breakpoint does not hit within N seconds"). Run it
   with `scripts/gdb-psx -batch`, which enforces a timeout and resumes the
   emulator on exit.
   - To observe multiple consecutive frames (e.g., logging values during
     gameplay), use a short Lua script in PCSX-Redux instead of stopping every
     frame with breakpoints.
   - Before writing to game memory, request a saved state in the emulator.
   - Save a result summary (`NNN-description.md` + `.es.md`) next to the script.
6. **Logging.** Record in `re/NOTES.md` (and `re/NOTES.es.md`): date,
   hypothesis, experiment, result (`confirmado` / `descartado` / `dudoso`).
   Update `status` in `re/provisional_symbols.csv`.
7. **Promotion.** Only the human promotes confirmed items: into `re/symbols.csv`
   with evidence, and if applicable into `re/structs.h`, `seeds/`, and Ghidra
   (`tools/ghidra/`).

If a hypothesis cannot be verified, state so explicitly. Never fill gaps with
assumptions.

### Format of `re/provisional_symbols.csv` and `re/symbols.csv`

```
address,name,module,hypothesis,evidence,experiment,status,date
0x8002xxxx,camera_update,main,"updates camera each tick","xref from ...","re/experiments/007-camara.gdb",propuesto,2026-11-15
```

- `module`: `main` or `overlay:<identifier>`.
- `status`: `propuesto`, `confirmado`, or `descartado` (in `symbols.csv`, only
  `confirmado`).

## Technical Priorities

- **Widescreen:** first crop the top and bottom black bars (`DRAWENV` `512x216`
  at `y=12`); then "open the camera slightly and close the gap by stretching
  slightly". Do not widen the FOV too far: levels have no geometry outside the
  4:3 frustum. Always verify proportions across the confirmed `5/8` GTE scaling
  paths (known risk of vertically stretched geometry).
- **High FPS:** via **interpolation**. Game logic remains at 30 Hz; camera and
  active entity transforms (walked via `gool_root_buckets`, never the flat pool)
  are captured each tick and interpolated on draw. Do not duplicate the game
  loop.
- **Regression:** `tools/regress` compares **logical state** (positions, entity
  states, RNG, counters), never framebuffer pixels, independent of resolution,
  FOV, and interpolation. With interpolation or widescreen enabled, logical
  state must remain **bit-identical** to the reference. If it changes,
  something altered game logic.

## Packaging and CI

- Releases built inside `container: ubuntu:22.04` (glibc 2.35). Never publish
  binaries built on local Arch Linux.
- The AppImage bundles Zig (`-target x86_64-linux-gnu.2.28`), trimmed CMake,
  Ninja, prebuilt emitters, vendored offline archives, and `tomli` to compile
  the game on the user's machine (with fallback to system compilers if needed).
- The AppImage is read-only: generated code, builds, caches, and saves live in
  `~/.local/share/crash2-native/`.
- Version comes from the git tag. Every release publishes `SHA256SUMS`.
- Workflows use minimal `permissions:`, SHA-pinned actions, and hash-verified
  downloads.
- CI **has no access to the game disc**: it builds tools and setup host, and
  runs tests that do not require the disc.

## Multi-Agent Workflow

| Role | Agent | Branch / Worktree | Can write in |
|---|---|---|---|
| Infrastructure | Claude Code | `infra/...` in `../c2-infra` | `scripts/`, `.github/`, `packaging/`, `tools/verify-disc/`, `tools/regress/`, `src/`, `game.toml`, `CMakeLists.txt`, `patches/` |
| Reverse Engineering | Antigravity | `re/...` in `../c2-re` | `re/provisional_symbols.csv`, `re/NOTES.md`, `re/NOTES.es.md`, `re/experiments/`, `tools/ghidra/` |
| Human | — | `main` | `AGENTS.md`, `CLAUDE.md`, `GEMINI.md` (+ `.es.md`), `docs/ROADMAP.md` (+ `.es.md`), `README.md` (+ `.es.md`), `LICENSE`, `NOTICE`, `re/symbols.csv`, `re/structs.h`, `seeds/`, Ghidra project |

- **Outside your column, read-only.** If you need a change in another role's
  files, describe it in the issue or summary; do not make it yourself.
- **Tasks live in GitHub Issues** tagged `agente:claude` or `agente:agy`. Each
  issue states which files are touched and when it is done.
- **Agents do not hand work directly to each other.** Exchange happens via
  human-confirmed files (`re/symbols.csv`, `re/structs.h`) and PRs merged into
  `main` by the human.
- **Exclusive resources:** the emulator and its GDB server belong to the
  reverse-engineering agent (`gdb-psx` also uses a lock). Heavy local builds
  belong to the infrastructure agent. Never run two builds simultaneously.
- **Cross-review:** an agent may be asked to review the other's PR and search
  for counterexamples. Agreement is not verification: verification remains an
  experiment in the emulator.
- Stay up to date with `git rebase main` before opening a PR.

## Working Style

- Small, focused changes; one topic per commit, clear commit messages.
- Before a large task, propose a short plan and wait for confirmation.
- If a decision affects licensing, repo structure, or published content, ask
  first.
- **Language & formatting:** code identifiers, code/script comments, and
  primary Markdown documentation (`.md`) must be in **English**; `NOTICE` stays
  English-only. Every `.md` document must have a matching Spanish translation
  (`<name>.es.md`) in the same directory with a language switcher at the top.
  **Do not use emojis** anywhere in documentation, comments, or commits.
- When finishing a task: report what changed, how it was tested, and what
  remains pending.
