English | [Español](NOTES.es.md)

# Reverse Engineering Log — crash2-native (`SCUS-94154`)

Live log of the static and dynamic analysis of *Crash Bandicoot 2: Cortex Strikes Back* (USA, `SCUS-94154`).

> **Rules for this log (see `AGENTS.md` and `GEMINI.md`):**
> - **Clean-room:** every recorded fact comes exclusively from original observations of `SCUS_941.54` in Ghidra and PCSX-Redux.
> - **Nothing is true until verified in the game:** every static hypothesis goes through `re/provisional_symbols.csv` and a reproducible experiment in `re/experiments/`.
> - **Mandatory module tag:** always state whether an address belongs to `main` or `overlay:<id>` and on which screen/level it is loaded.

---

## 1. Environment Status

| Component | Observed state | Notes |
|---|---|---|
| Main executable | Ready | `../privado/exe/SCUS_941.54` (disc verified against Redump) |
| Ghidra | Project created | Version `12.2` in `/opt/ghidra` (`application.java.min=25`); project `../privado/ghidra/crash2` |
| `ghidra_psx_ldr` | Loaded in project | Release `2026.11.08` (PSX loader, PsyQ `4.0` detected) |
| System JVM | Configured via env | Default `java-21-openjdk` (unchanged); `JAVA_HOME=/usr/lib/jvm/java-27-openjdk` only for REA |
| Ghidra MCP | Active (`pyghidra-mcp==0.3.0`) | Headless over copy `../privado/ghidra-ro/crash2.gpr` (`JAVA_HOME=/usr/lib/jvm/java-27-openjdk`); `PSX:LE:32:default (1.5)` verified |
| PCSX-Redux | Ready and validated | Build `561`, commit `61e3086f` (2026-11-14); interpreter CPU, debugger enabled, GDB server on port `3333` |
| `gdb` + `scripts/gdb-psx` | Verified against emulator | `GNU gdb (GDB) 18.1` (`mips:3000`); experiments `001` and `002` ran cleanly (`exit 0`, proper `detach`) |

---

## 2. Open Objectives (Phase 3)

- [x] Create Ghidra project (`../privado/ghidra/crash2`) with `ghidra_psx_ldr` (PsyQ 4.0 detected).
- [x] Install and configure Ghidra MCP (`pyghidra-mcp==0.3.0`, `tools/ghidra/sync-ro.sh`, `../privado/ghidra-ro/crash2.gpr`) and verify reading `SCUS_941.54` with language `PSX:LE:32:default (1.5)`.
- [x] First static MCP task: locate what writes to `DAT_8003bea4` and which function is registered with `VSyncCallback`; proposals recorded in `re/provisional_symbols.csv`.
- [x] Dynamically verify in PCSX-Redux the rate of `DAT_8003bea4` (~34.5 ticks/frame = ~17.25 ticks/VSync), `0x80016838` (30 Hz), and ISR `0x8003be88` 1:1 per frame (`001`, `002`, `003`); `0x80016868` yielded `0/23` in pause (pending only if tested on a lighter screen such as title/loading).
- [x] Install and configure PCSX-Redux (Build `561`, commit `61e3086f`, interpreter + GDB port `3333`) and validate connection with `scripts/gdb-psx`.
- [x] Locate base PsyQ functions (`SetGeomScreen`, `DrawOTag`, `VSync`, `CdRead`) and map XREFs (`005`–`008`).
- [x] Identify CD loading system and dynamic blocks (NSD/NSF paging and native MIPS blocks in `sec[1]` of `GOOL` type 11 chunks, `005`–`006`).
- [x] Locate main loop (30 Hz), camera update, projection/clipping parameters (`512x216`, `5/8` across 3 paths), entity list (`gool_root_buckets` / `GoolObject`), `PadState`, and `RNG` (`006`–`008`, promoted to `re/symbols.csv` and `re/structs.h`).

---

## 3. Entry Template

```markdown
### YYYY-MM-DD — <Short title>

- **Module:** `main` | `overlay:<id>` | `environment`
- **Hypothesis:** <what we believe or evaluate>
- **Static evidence:** <addresses, XREFs, constants, or local checks>
- **Experiment:** `re/experiments/NNN-name.gdb` (or `.lua` / manual test)
- **Result:** `confirmado` | `descartado` | `dudoso` | `pendiente`
- **Next step:** <concrete action>
```

---

## 4. Chronological Log

### 2026-11-15 — Preparation: MCP evaluation for Ghidra 12.2 and PCSX-Redux GDB server

- **Module:** `environment`
- **Hypothesis:** A read-only MCP is required that can query an existing Ghidra 12.2 project created with `ghidra_psx_ldr` without modifying `../privado/ghidra`, along with defining the GDB server configuration in PCSX-Redux.
- **Observed evidence (local system + documentation):**
  - `/opt/ghidra/Ghidra/application.properties` declares `application.version=12.2`, `application.java.min=25`, and `application.java.compiler=25`.
  - `archlinux-java status` shows `java-21-openjdk (default)` and `java-27-openjdk` available. Any headless/Gradle tool outside the Ghidra launcher requires `JAVA_HOME=/usr/lib/jvm/java-27-openjdk`.
  - Tools already on `PATH`: `node`, `npm`, `npx`, `python3`, `uv`, `pipx`, `gdb` (`GNU gdb (GDB) 18.1`, tested with `set architecture mips:3000`). Neither `gradle` nor `pcsx-redux` is installed yet.
  - **Ghidra MCP comparison (read-only over existing 12.2 + `ghidra_psx_ldr` project):**
    1. **`REA` (`morluto/rea` / `rea-agents`):** Node.js CLI/MCP (`npx rea-agents`) wrapping Ghidra's `analyzeHeadless` using `GHIDRA_INSTALL_DIR` and `JAVA_HOME`. Given `REA_GHIDRA_PROJECT_PATH`, it copies the project into its own workspace and opens it with `-readOnly` and `-noanalysis` validating the binary SHA-256: protects `../privado/ghidra` at the OS level, avoids lock conflicts with the GUI, and does not require compiling Java plugins with Gradle. Still needs a live test to verify `analyzeHeadless` loads the `PSX` language from `ghidra_psx_ldr` under `~/.config/ghidra/ghidra_12.2_DEV/Extensions/`.
    2. **`ReVa` (`cyberkaida/reverse-engineering-assistant`):** Native Java extension for Ghidra (GUI or headless, Java 25+ on 12.2+). Exposes write/scripting tools (not read-only by default) and requires an exact build for Ghidra 12.2 or building with `gradle build`. Running inside Ghidra, it inherits `ghidra_psx_ldr` directly.
    3. **`GhidraMCP` (`LaurieWired/GhidraMCP` / `bethington/ghidra-mcp`):** GUI Java plugin (`127.0.0.1:8080`) + Python bridge via `uvx`. Inherits `ghidra_psx_ldr` in the open GUI, but is also not read-only (exposes mutations unless blocked client-side) and the plugin depends on the exact Ghidra version (v2.0 releases target 12.1.4; 12.2 may require building from source).
    4. **`pyghidra-mcp` / `re-mcp-ghidra`:** Based on `pyghidra` + `JPype` (headless; `pyghidra-mcp` has `--gui`). `pyghidra-mcp` includes write tools, locks `.gpr` in headless mode, and creates indexes (ChromaDB) next to the project; `re-mcp-ghidra` prioritizes read resources. Both depend on `JAVA_HOME` >= 25 and the JVM loading the `ghidra_psx_ldr` extension to read the `PSX` language.
  - **PCSX-Redux (GDB server):**
    - Enabled in GUI via `Configuration -> Emulation` (or `Emulator -> Settings` depending on version): check **Enable Debugger**, check **Enable GDB Server**, and **disable Dynarec CPU** (use the interpreter so breakpoints and single-stepping are reliable).
    - Default TCP port: **`3333`** (`localhost:3333`, configurable depending on build). In this repository it binds with `export PSX_GDB_PORT=3333` for `scripts/gdb-psx`.
- **Experiment:** Not executed (preparation only; Ghidra project still being created and PCSX-Redux not yet installed).
- **Result:** `pendiente` (configuration proposal ready for human review).
- **Next step:** Confirm which MCP to install (recommended: `rea-agents` with `JAVA_HOME=/usr/lib/jvm/java-27-openjdk` and `GHIDRA_INSTALL_DIR=/opt/ghidra`) once `../privado/ghidra` is finished, and validate reading the `PSX` language and PsyQ signatures in an initial test.

### 2026-11-15 — Pre-check of `rea-agents@6.9.0` (ruled out for `SCUS_941.54`)

- **Module:** `environment`
- **Hypothesis:** `rea-agents@6.9.0` (`REA`) can open `~/Descargas/PORTS/Crash2CSB/privado/ghidra/crash2.gpr` (program `SCUS_941.54`, `PSX` language from `ghidra_psx_ldr`) read-only via `REA_GHIDRA_PROJECT_PATH`.
- **Observed evidence (without installing packages, inspecting the `rea-agents@6.9.0` npm tarball and local files):**
  - `SCUS_941.54` has a `PS-X EXE` header (`50 53 2d 58 20 45 58 45`).
  - The verified project is `../privado/ghidra/crash2.gpr` and the program in `crash2.rep/idata/00/*.prp` is `SCUS_941.54`.
  - In `rea-agents@6.9.0`:
    - `GhidraClient.js` and `GhidraSessionRoot.js` create temporary copies in `os.tmpdir()` (`/tmp/rea-ghidra-*`, outside the worktrees) and delete them on exit.
    - However, `package/dist/artifacts/artifactFormats.js` only accepts `mach-o`, `elf`, `pe`, `dos-mz`, `dos-com`, `raw-binary`, and `gamecube-dol` (not `psx-exe`).
    - `package/dist/ghidra/GhidraProvider.js` (lines 269–277) rejects `REA_GHIDRA_PROJECT_PATH` for every format other than `elf`, `pe`, or `mach-o` (`existingProjectUnsupported()`).
    - `package/dist/ghidra/GhidraRawBinaryLanguage.js` does not include `mips` either.
- **Experiment:** Static inspection of the `rea-agents@6.9.0` package prior to installing it.
- **Result:** `descartado` (`rea-agents@6.9.0` does not support `PS-X EXE` or projects using `ghidra_psx_ldr`).
- **Next step:** Choose between `ReVa v7.3.2` (prebuilt extension for Ghidra `12.2` in GUI assistant mode) or `pyghidra-mcp==0.3.0` (headless with `JAVA_HOME=/usr/lib/jvm/java-27-openjdk` over a copy at `../privado/ghidra-ro`).

### 2026-11-15 — Initial hypothesis (human static analysis): `FUN_8001645c` (end-of-frame)

- **Module:** `main` (pending confirmation in `../privado/ghidra/crash2` with REA)
- **Hypothesis:** `FUN_8001645c` corresponds to end-of-frame / display buffer synchronization.
- **Static evidence (observed by the human in Ghidra, pending verification in REA and emulator):**
  - Call to `DrawSync(0)`.
  - Rotation of three pointers/structures at `DAT_80063450`, `DAT_80063454`, and `DAT_80063458`.
  - Call to `VSync(0)` at `0x80016838`.
  - Conditional call to `VSync(0)` at `0x80016868` when `(DAT_8003bea4 - *(DAT_80063450 + 0xc)) < 0x19`.
  - Open question: which routine writes/increments `DAT_8003bea4` (possible VSync/tick counter).
- **Experiment:** Not executed (pending REA installation and later PCSX-Redux setup).
- **Result:** `pendiente` (static analysis only; unverified in-game).
- **Next step:** After confirming `REA` setup, query `../privado/ghidra/crash2` read-only to locate what writes `DAT_8003bea4` and what function is registered in `VSyncCallback`, recording proposals in `re/provisional_symbols.csv`.

### 2026-11-15 — Activation of `pyghidra-mcp==0.3.0`, writes to `DAT_8003bea4`, and `VSyncCallback` callback

- **Module:** `main` (`SCUS_941.54`, verified in `../privado/ghidra-ro/crash2.gpr` with `Language ID: PSX:LE:32:default (1.5)`, `PsyQ Version: 4.0.0`, `Executable Format: PSX Executables Loader`)
- **Hypothesis:**
  1. `DAT_8003bea4` is a time/VSync counter incremented by a periodic interrupt.
  2. `VSyncCallback` registers the routine responsible for advancing that counter.
- **Static evidence (via `pyghidra-mcp==0.3.0`, read-only):**
  - **Writes to `DAT_8003bea4` (`0x8003bea4`):**
    1. **`0x8003be88` (`LAB_8003be88`, leaf routine not yet defined as a function in Ghidra) at `0x8003bea0`:** increments `DAT_8003bea4` by `+1`:
       `8003be88 lui v1,0x8004; 8003be8c addiu v1,v1,-0x415c; 8003be90 lw v0,0(v1); 8003be98 addiu v0,v0,1; 8003be9c jr ra; 8003bea0 _sw v0,0(v1)`.
       Registered in `FUN_80015614` (`0x80015704`–`0x8001570c`) via `OpenEvent(0xf2000002, 2, 0x1000, &LAB_8003be88)`, followed by `EnableEvent()`, `SetRCnt(0xf2000002, 0x1000, 0x1000)` (`0x80015724`–`0x80015734`), and `StartRCnt(0xf2000002)`.
       - **Basis and assumption regarding the `/8` divider:** inspecting `SetRCnt` (`0x80049dcc`, PsyQ 4.0) in the binary, for `param_1 == 2` (`0xf2000002 & 0xffff`) and `(param_3 & 1) == 0` (`RCntMdSC` disabled, case `param_3 = 0x1000`), `SetRCnt` starts from `uVar3 = 0x48`, changes it to `0x248` (`if (param_1 == 2 && (param_3 & 1) == 0)`), and since `(param_3 & 0x1000) != 0` applies `uVar3 |= 0x10`, writing **`0x258`** (`0x0200 | 0x0040 | 0x0010 | 0x0008`) into counter 2's mode register (`*(PTR_TMR_DOTCLOCK_VAL_8005cb4c + 0x24)`) and `0x1000` as target (`+0x28`). **Assumption:** following the PS1 `T2_MODE` register hardware spec (where bits 8–9 select the clock source and bit 9 = `0x200` corresponds to `SysClk/8`) and consistency with the game's `0x11` (17) and `0x22` (34) thresholds, we assume a rate of `~33.8688 MHz / 8 / 0x1000 ≈ 1033.6 Hz` (~17.2 ticks per 60 Hz NTSC VSync and ~34.4 per 30 Hz frame). **Dynamic verification in PCSX-Redux is still needed** to confirm it indeed increases by ~17 ticks per VSync (`re/experiments/001-ticks-rcnt2-vsync.gdb`).
    2. **`FUN_8001645c` at `0x800168d8`:** when `(DAT_8006cb94 & 0x200000) != 0`, stops `StopRCnt(0xf2000002)` and manually adds `DAT_8003bea4 += 0x22`.
    3. **`FUN_8001645c` at `0x80016940`:** if `DAT_8006cd14 == 2`, assigns `DAT_8003bea4 = *DAT_8005f374`.
    4. **`FUN_80011800` at `0x80011990`:** restores `DAT_8003bea4 = DAT_8005f2c4` (in a flow linked to `DAT_8005f180`).
    5. **`FUN_80037698` at `0x80037e10`:** assigns `DAT_8003bea4 = *puVar1` (opcode dispatcher `case 0xc`, subcase `0xd`; subcase `0xc` reads it).
  - **`VSyncCallback` (`0x8004a708`):**
    - Has only 2 XREFs, both inside PsyQ `libsnd` 4.0:
      - `SSSTART_OBJ_18C` (`0x80054d58`, call at `0x80054d7c`): registers `SsSeqCalledTbyT` (`0x80054f04`, read from `PTR_SsSeqCalledTbyT_8005efe0 = 0x80054f04`) if `DAT_8005efe8 != 0`.
      - `SsEnd` (`0x80052b80`, call at `0x80052bcc`): passes `(f *)0x0` to unregister the callback.
    - **Partial result on `VSyncCallback`:** the game does not use `VSyncCallback` for its frame counter; that callback is exclusively for audio (`SsSeqCalledTbyT`), while the game's frame clock is the `RCntCNT2` interrupt (`0x8003be88`).
  - **Additional static confirmation of `FUN_8001645c` and `FUN_80016f04`:**
    - In `FUN_8001645c`: confirmed `DrawSync(0)`, `DAT_80063450`/`54`/`58` rotation, `VSync(0)` at `0x80016838`, conditional `VSync(0)` at `0x80016868` with `(uint)(DAT_8003bea4 - *(int *)(DAT_80063450 + 0xc)) < 0x19`, writing the frame timestamp into `*(DAT_80063454 + 0xc)` (`0x80016958`), `PutDispEnv`, `PutDrawEnv`, and `DrawOTag`, called at the end of the `FUN_80011800` loop.
    - **`FUN_80016f04` (`quantize_frame_ticks`, `0x80016f04`–`0x80016f40`):**
      - Sole XREF in the binary: `FUN_8001645c` at `0x80016974` (`jal 0x80016f04`), passing `a0 = *(int *)(DAT_80063454 + 0xc) - *(int *)(DAT_80063450 + 0xc)` (`0x80016978 _subu a0,v0,a0`) and storing its return value in `*(DAT_80063450 + 0x14)` (`0x80016988 sw v0,0x14(v1)`).
      - Verified disassembly/pseudocode: if `param_1 < 0` returns `0x22`; if `< 0x13` returns `0x11`; if `< 0x24` returns `0x22`; if `< 0x35` returns `0x33`; if `>= 0x35` returns `param_1` unquantized (multiples of `0x11` = 17 ticks). Checking which functions read field `+0x14` of the `DAT_80063450` struct remains pending.
    - **Note on provisional names (`sys_init` and `main_loop`):** `FUN_80015614` (`sys_init`) and `FUN_80011800` (`main_loop`) remain in `re/provisional_symbols.csv` as `propuesto` with a provisional name tag; their callers and full scope still need verification before finalizing those names.
- **Experiment:** Prepared unrun [001-ticks-rcnt2-vsync.gdb](experiments/001-ticks-rcnt2-vsync.gdb) and [002-frecuencia-vsync-extra.gdb](experiments/002-frecuencia-vsync-extra.gdb) (see dynamic results below).
- **Result:** `propuesto` (static analysis complete; dynamic verification logged in the next entry).
- **Next step:** Human promotion into `re/symbols.csv` when appropriate, and test `0x80016868` in a light scene or pause screen.

### 2026-11-15 — Experiments 001 and 002 in PCSX-Redux (`DAT_8003bea4` rate and `0x80016838` / `0x80016868` frequency)

- **Module:** `main` (`0x80016838`, `0x80016840`, `0x80016868`, `0x80016870`, `0x8003bea4`, `0x8006ccf0`)
- **Precondition:** PCSX-Redux Build `561` (`61e3086f`, 2026-11-14), interpreter CPU, debugger enabled, GDB on `localhost:3333`; slot 1 loaded inside the first level with Crash standing still.
- **Hypothesis:**
  1. Under the `SysClk/8` assumption on `RCntCNT2`, `DAT_8003bea4` advances ~17 ticks per VSync (~34.4 per 30 Hz frame).
  2. `FUN_8001645c` executes `VSync(0)` at `0x80016838` once per frame (~30 Hz) and calls the extra `VSync(0)` at `0x80016868` when `delta < 0x19`.
- **Experiments:** [001-ticks-rcnt2-vsync.gdb](experiments/001-ticks-rcnt2-vsync.gdb) ([summary](experiments/001-ticks-rcnt2-vsync.md)) and [002-frecuencia-vsync-extra.gdb](experiments/002-frecuencia-vsync-extra.gdb) ([summary](experiments/002-frecuencia-vsync-extra.md)).
- **Observed results (both ended with `exit 0` and clean `detach`):**
  - **Experiment 001 (12 frames at `0x80016840`):** `DAT_8003bea4` went from `0x0002459a` (`148890`) to `0x00024738` (`149304`), with `delta_frame` strictly alternating between `34` and `35` ticks (`35, 34, 35, 34, 34, 35, 34, 35, 34, 35, 34, 35`; average **`414 / 12 = 34.50` ticks/frame**). The `0x80016868` breakpoint did not hit in any of those 12 frames.
  - **Experiment 002 (60 frames between pass 1 and pass 61 of `0x80016838`):**
    - `measured frames (0x80016838) = 60`, `delta DAT_8006ccf0 = 60` (exactly 1 call to `0x80016838` per `FUN_8001645c` frame).
    - `delta DAT_8003bea4 = 2071` ticks (`2071 / 60 = 34.52` ticks/frame; GDB integer division = `34`).
    - `hits 0x80016868 (extra VSync) = 0`.
- **Result:** `confirmado` partially (`DAT_8003bea4` advances at `34.5` ticks per 30 Hz frame = **`~17.25` ticks per VSync**, validating the `SysClk/8` / `~1033.6 Hz` assumption and the 30 Hz pace of `0x80016838`; in the first level with Crash standing still, each frame takes > 1 VSync before `0x80016838`, so `delta >= 0x19` upon returning from `0x80016838` and `0x80016868` hit `0` times, leaving a light scenario such as pause or map pending to observe `0x80016868` active and measure a direct 1-VSync delta).
- **Next step:** Repeat `001`/`002` on the map or pause screen if observing `0x80016868` (>0) hits and the direct 1-VSync delta (~17 ticks) between `0x80016840` and `0x80016870` is desired.

### 2026-11-15 — Readers of `*(DAT_80063450 + 0x14)`, `frame_counter` proposal, and `003` preparation

- **Module:** `main` (`0x80063450`, `0x8006ccf0`, `0x80019f08`, `0x8001d2c4`, `0x8001d63c`, `0x8001e3dc`, `0x8001e544`)
- **Hypothesis:**
  1. `*(DAT_80063450 + 0x14)` (computed by `quantize_frame_ticks` in `frame_end_sync`) is the per-frame `dt` variable used to scale physics, movement, and rotations (with `0x22 / 1024 ≈ 1/30 s` nominal and cap `0x66` = 102).
  2. `DAT_8006ccf0` is the global logical frame counter (`frame_counter`).
  3. In the pause menu (light scene), `0x80016868` should fire on at least some frames and ISR `0x8003be88` should execute ~34–35 times per frame, matching `delta DAT_8003bea4`.
- **Static evidence (via `pyghidra-mcp==0.3.0`, read-only):**
  - **Writers of `*(DAT_80063450 + 0x14)`:**
    - `FUN_800160b0` (`0x800161b0`, double-buffer init of `DAT_8006344c = 2` structs): initializes `piVar2[5]` (`+0x14`) to `0x22` and `piVar2[3]` (`+0xc`) to `DAT_8003bea4`.
    - `frame_end_sync` (`0x80016974`–`0x80016988`): updates `*(DAT_80063450 + 0x14) = quantize_frame_ticks(*(DAT_80063454 + 0xc) - *(DAT_80063450 + 0xc))`.
    - `FUN_800158e0` (`0x80015cc8`): when `DAT_8006cd14 == 2` and `piVar1 == piVar7 + 0x424` (demo/input playback), sets `*(int *)(DAT_80063450 + 0x14) = piVar7[0x423]`.
  - **Readers of `*(DAT_80063450 + 0x14)` (all XREFs to `0x80063450`, applying cap `<= 0x66`):**
    1. **`FUN_80019f08` (`0x80019f0c`, called from `FUN_8001c29c` at `0x8001c2e8` and `FUN_8001d63c` at `0x8001df84`):** copies `*(uint *)(DAT_80063450 + 0x14)` (capped at `0x66`) to scratchpad word `DAT_1f800054` (alongside `DAT_1f800050 = DAT_80060944` and `DAT_1f800058 = &DAT_8006cb70`) before calling `FUN_8003b940`. (Note: if other routines access scratchpad via base pointer `0x1f800000`, Ghidra does not list a direct XREF to `0x1f800054`).
    2. **`FUN_8001e3dc` (`0x8001e3e0`) and `FUN_8001e544` (`0x8001e548`):** angular interpolation/stepping in base `0xfff`; compute `(param_3 * dt) >> 10` (with `0x66` cap on `dt`) to advance angles.
    3. **`FUN_8001d2c4` (`0x8001d400`):** horizontal speed/heading integration; multiplies `*param_2 * dt` (cap `0x66`), shifts `>> 10`, and applies displacement to `param_1 + 0x84`/`+0x8c`.
    4. **`FUN_8001d63c` (`0x8001d9d4`, `0x8001dadc`, `0x8001db50`, `0x8001dbf8`, `0x8001de08`, `0x8001e290`):** entity physics/movement update (`param_1`):
       - Acceleration and deceleration of scalar speed (`+0x104`) at `0x8001d9d4`, `0x8001dadc`, `0x8001db50`, `0x8001dbf8` (`>> 10`, cap `0x66`).
       - Position X/Y/Z (`+0x60`, `+0x64`, `+0x68`) integration from velocities (`+0x84`, `+0x88`, `+0x8c`) multiplied by `dt` (`>> 10`, cap `0x66`) at `0x8001de08` (3 consecutive reads).
       - Gravity on Y velocity (`+0x88`) at `0x8001e290`: `*(param_1 + 0x88) += dt * -4000` (cap `0x66`, terminal velocity `-0x2ee000`).
    - **Key observation for interpolation / 60+ FPS:** the game physics explicitly scaling by `*(DAT_80063450 + 0x14)` (quantized to `0x11`/`0x22`/`0x33` and capped at `0x66`) confirms why game logic must not be altered or duplicated: any change to `rcnt2_tick_count` or `quantize_frame_ticks` would directly affect speeds, rotations, and gravity in `FUN_8001d63c` and `FUN_8001d2c4`.
  - **`DAT_8006ccf0` (`frame_counter`) proposal:** has only 3 XREFs: read and `+1` write at the start of `frame_end_sync` (`0x8001647c`/`0x80016490`) and reset to `0` in `FUN_8002efe4` (`0x8002f088`); in `002` it gave `delta == 60` over 60 frames.
- **Experiment:** [003-pausa-vsync-extra-e-isr.gdb](experiments/003-pausa-vsync-extra-e-isr.gdb) ([summary](experiments/003-pausa-vsync-extra-e-isr.md)) executed in the pause menu (`exit 0`, clean `detach`).
  - **Phase A (20 frames paused):** `hits 0x80016868 = 0 / 20`, `delta frame_counter (0x8006ccf0) = 20`, `delta rcnt2_tick_count (0x8003bea4) = 691 ticks` (`34.55` ticks/frame).
  - **Phase B (3 frames paused with breakpoint on `0x8003be88`):**
    - Frame 1: `hits_isr(0x8003be88)=34`, `delta_0x8003bea4=34`, `extra_0x80016868=0`.
    - Frame 2: `hits_isr(0x8003be88)=35`, `delta_0x8003bea4=35`, `extra_0x80016868=0`.
    - Frame 3: `hits_isr(0x8003be88)=34`, `delta_0x8003bea4=34`, `extra_0x80016868=0`.
- **Result:**
  - `confirmado` dynamically (ready for human review): `rcnt2_tick_isr` (`0x8003be88`) matches `rcnt2_tick_count` 1:1 (`34/34`, `35/35`, `34/34`) and `frame_counter` (`0x8006ccf0`) matches frame count 1:1 (`20/20` in `003`, `60/60` in `002`).
  - `descartado` for the pause menu: `0x80016868` does not fire there (`0 / 23`), because the pause menu still renders the background for more than 1 VSync.
- **Next step:** Human review to promote `rcnt2_tick_isr` (`0x8003be88`) and `frame_counter` (`0x8006ccf0`) to `re/symbols.csv`; if observing `0x80016868` active (>0) is desired, test on a pure 2D screen (e.g. title / loading screen).

### 2026-11-15 — Static analysis of `0x8004A3xx` and RAM patching routines (PsyQ 4.0)

- **Module:** `main` (`SCUS_941.54`, image range `[0x80010000, 0x8005f800)`).
- **Hypothesis / Question:** What code lives at `0x8004A3xx`, whether that range modifies itself in RAM, or whether it modifies other code in memory at runtime.
- **Static evidence (Ghidra `ghidra_psx_ldr` + inspection of the `SCUS_941.54` binary):**
  - The range `0x8004a2b4..0x8004a47c` corresponds to `libapi` (PsyQ 4.0) functions linked into `main`:
    - `0x8004a2ec..0x8004a34c` (`_patch_pad`, called by `InitPAD` at `0x8004a034` and `PAD_init` at `0x80049f98`): calls `EnterCriticalSection` (`0x80049d1c`), invokes `B0:57` (`GetB0Table`), reads `base = *(B0Table + 0x16c)`, stores `base + 0x884` into `DAT_8005f32c` (used by `EnablePAD` `0x8004a2c4`) and `base + 0x894` into `DAT_8005f330` (used by `DisablePAD` `0x8004a2d8`), **writes `0` to 11 words (`0x2c` bytes) at `base + 0x594..0x5bc`**, and calls `FlushCache` (`0x8004a354`). (`ExitCriticalSection` is run by the caller immediately after).
    - `0x8004a354..0x8004a360` (`FlushCache`, `A0:44`): `li t2,0xa0; jr t2; _li t1,0x44`. Sole implementation of `li t1,0x44` in all of `SCUS_941.54`, with 5 call XREFs: `_patch_pad` (`0x8004a338`), `_send_pad` (`0x8004a3e0`), `_remove_ChgclrPAD` (`0x8004a45c`), `_patch_gte` (`0x8004f23c`), and `FUN_8005b118` (`0x8005b15c`).
    - `0x8004a364..0x8004a388` (`_SendPAD`): calls indirectly via `*DAT_8005f338` (0 call XREFs in the binary).
    - `0x8004a38c..0x8004a420` (`_send_pad`, called by `InitPAD` at `0x8004a068` and `PAD_init` at `0x80049fcc`): calls `EnterCriticalSection`, invokes `B0:57`, reads `base = *(B0Table + 0x16c)`, stores `base + 0x7a0` into `DAT_8005f338`, **copies the 4 words (`0x10` bytes) from `0x8004a408..0x8004a414` (`0x00551024`, `0`, `0`, `0`) into two areas of the PAD driver in BIOS RAM (`base + 0x3d8` and `base + 0x4e0`)**, calls `FlushCache`, and calls `ExitCriticalSection`.
    - `0x8004a424..0x8004a47c` (`_remove_ChgclrPAD`, called by `InitPAD` at `0x8004a024` and `PAD_init` at `0x80049f88`): invokes `B0:57`, reads `base = *(B0Table + 0x16c)`, **writes `0` to 9 words (`0x24` bytes) at `base + 0x62c..0x64c`**, calls `FlushCache`, and calls `ExitCriticalSection`.
  - Game startup call chain: `start` (`0x80049b2c`) -> `main` (`0x800117bc`) -> `FUN_80015614` (`0x800156d4`) -> `FUN_80015828(2)` (`0x80015890`) -> `InitPAD` (`0x8004a000`) -> `_remove_ChgclrPAD`, `_patch_pad`, `_send_pad`.
  - Other routines in the binary that patch kernel RAM via `GetC0Table` (`B0:56`) and call `FlushCache` (`0x8004a354`):
    - `_patch_gte` (`0x8004f1f8`, called by `InitGeom` `0x8004ec38`): copies 14 words (`0x38` bytes, `0x8004f260..0x8004f297`) over `*(C0Table + 0x18)` before `FlushCache`.
    - `FUN_8005b118` (`0x8005b118`, possible `_ExitCard`, called by `StopCARD` `0x8005b0c0` <- `FUN_80036304`): copies 3 words (`0x0c` bytes at `0x8005b180..0x8005b18b`, `0` in the binary) into `*(C0Table + 0x18) + 0x70` before `FlushCache`.
  - **Writes to `0x8004A3xx` (static analysis):** a full scan of `SCUS_941.54` (`0x80010000..0x8005f800`) found no `lui`/`addiu|sw|sh|sb` pair nor any 32-bit pointer in tables targeting `0x8004a200..0x8004a4ff` for writing; references to `0x8004a000..0x8004afff` are solely constant/table reads (`0x8004a408..0x8004a418` in `_send_pad`, `_Pad1`, `_IsVSync`) or `jal` calls. Their only writes inside `[0x80010000, 0x8005f800)` land in state variables/pointers at `0x8005f324..0x8005f344`.
  - **Actual runtime mechanism under OpenBIOS (key finding, corrects prior hypothesis):**
    - Although statically in `SCUS_941.54` nothing writes to `0x8004A3xx`, at runtime **OpenBIOS does rewrite `0x8004a308`, `0x8004a3a8`, and `0x8004a440`** (it is BIOS-modified code, not game self-modification).
    - In `psxrecomp` (`generated/OpenBIOS_full.c` and `recompiler/seeds/openbios_elf_seeds.json`, OpenBIOS `55fbf04`), `getB0table` (`0xBFC05BB0`, syscall `B0:57`) passes the caller's `$ra` to `patch_hook` (`0xBFC07E84`). Depending on the code signature at `$ra`, `patch_hook` delegates to:
      - `patch_pad_2_execute` (`0xBFC0817C`): patches the game pointers (`DAT_8005f32c`/`DAT_8005f330`) and rewrites starting at `$ra = 0x8004a308` with `nop; nop; b +10; nop` (`0x00000000, 0x00000000, 0x1000000a, 0x00000000`, jumping to `0x8004a33c`, after `FlushCache`).
      - `send_pad_2_execute` (`0xBFC082DC`): patches the `_SendPAD` pointer (`DAT_8005f338`, `0x000040b0` observed in `OpenBIOS_full.c`) and rewrites starting at `$ra = 0x8004a3a8` with `nop; nop; b +12; nop` (`0x1000000c`, jumping to `0x8004a3e4`, after `FlushCache`).
      - `remove_ChgclrPAD_2_execute` (`0xBFC08254`): rewrites starting at `$ra = 0x8004a440` with `nop; nop; b +5; nop` (`0x10000005`, jumping to `0x8004a460`, after `FlushCache`).
    - Note on `SCPH1001.toml` / retail BIOS vs. OpenBIOS: a retail BIOS lacks this caller hook (which is why `SCUS_941.54` contains patches targeting `*(B0Table + 0x16c)`), whereas under OpenBIOS (both `psxrecomp` and PCSX-Redux) page `0x8004A000` in RAM is rewritten. From this point on, every experiment in `re/experiments/` explicitly records the BIOS used.
- **Executed experiment (PCSX-Redux + OpenBIOS):** [004-codigo-modificado-8004a3xx.gdb](experiments/004-codigo-modificado-8004a3xx.gdb) ([summary](experiments/004-codigo-modificado-8004a3xx.md)) — read-only, `exit 0`, `[Inferior 1 (process 1) detached]`.
  - **Observed in live RAM (`0x8004a2ec..0x8004a47f`, 101 words):**
    - `0x8004a308` (`_patch_pad`): `00000000 00000000 1000000a 00000000` (`nop; nop; b +10; nop`, exact match; original EXE `8c42016c...`).
    - `0x8004a3a8` (`_send_pad`): `00000000 00000000 1000000c 00000000` (`nop; nop; b +12; nop`).
    - `0x8004a440` (`_remove_ChgclrPAD`): `00000000 00000000 10000005 00000000` (`nop; nop; b +5; nop`).
    - The other 89 words of the block match `SCUS_941.54` word-for-word.
  - **Populated pointers at `0x8005f324..0x8005f344`:**
    - `DAT_8005f32c` (`EnablePAD`) = `0xbfc088f4`, `DAT_8005f330` (`DisablePAD`) = `0xbfc08904`, `DAT_8005f338` (`_SendPAD`) = `0x00003f88`.
    - Saved `InitPAD` returns: `DAT_8005f324 = 0x8004a03c`, `DAT_8005f334 = 0x8004a070`, `DAT_8005f344 = 0x8004a02c`.
- **Result:** `confirmado` dynamically that **OpenBIOS** (`getB0table` → `patch_hook`) performs the rewrites at `0x8004a308/a3a8/a440`, ruling out self-modifying game code in `SCUS_941.54` at `0x8004A3xx`. Promoted to `re/symbols.csv`: `_patch_pad` (`0x8004a2ec`), `_send_pad` (`0x8004a38c`), `_remove_ChgclrPAD` (`0x8004a424`), and `FlushCache` (`0x8004a354`); `_SendPAD` (`0x8004a364`) and `_patch_gte` (`0x8004f1f8`) remain `propuesto` (not yet live-tested).

### 2026-11-15 — Discrepancy between OpenBIOS versions and proposal to identify the BIOS

- **Environment / Finding:** comparing the pointers installed into RAM by OpenBIOS in `004` (PCSX-Redux) against those observed in `psxrecomp`'s OpenBIOS (`OpenBIOS_full.c`, commit `55fbf04`), the addresses do not match:

| In-game pointer | PCSX-Redux (`004`) | `psxrecomp` (`55fbf04`, `OpenBIOS_full.c`) |
|---|---|---|
| `DAT_8005f32c` (`EnablePAD`) | `0xbfc088f4` | `0xbfc07734` |
| `DAT_8005f330` (`DisablePAD`) | `0xbfc08904` | `0xbfc07744` |
| `DAT_8005f338` (`_SendPAD`) | `0x00003f88` | `0x000040b0` |

- **Hypothesis:** PCSX-Redux bundles a different OpenBIOS version/build than the one pinned by `psxrecomp` (`55fbf04`); the `getB0table` → `patch_hook` mechanism is equivalent, but internal ROM/kernel offsets differ.
- **Result (`confirmado` via 512 KiB SHA-256 hashes):**
  - PCSX-Redux Build `561` (`resources/openbios.bin`): `8a8925807952965c4a116239a21903476c5c585387a1d4778a90b9b9c01804ee`
  - `psxrecomp` (`build-release/bios/openbios.bin`, OpenBIOS `55fbf04`): `fabe498fbf224e4721f12f31b6f5fe0659205e341dc4e5c5f91b9bd1a1011c57`
  - The hashes differ: confirmed that these are two different OpenBIOS builds, explaining the pointer discrepancy observed in `004`.
  - **Operational comparison rule:** to compare emulator and port identically (e.g. ROM/kernel addresses or BIOS patches), PCSX-Redux must be configured to load the same OpenBIOS ROM as `psxrecomp` (`sha256: fabe498fbf224e4721f12f31b6f5fe0659205e341dc4e5c5f91b9bd1a1011c57`).
- **Proposal for exact BIOS recording per experiment (without committing binaries):**
  - Read the ROM mapped at `0xbfc00000..0xbfc80000` (512 KiB) temporarily and read-only — for example, in GDB `dump binary memory /tmp/psx_bios.bin 0xbfc00000 0xbfc80000`, compute `sha256sum /tmp/psx_bios.bin` (or `crc32`), and delete `/tmp/psx_bios.bin` immediately, or compute the hash from the PCSX-Redux Lua console — and record in `# BIOS:` of the `.gdb` (see [000-plantilla.gdb](experiments/000-plantilla.gdb)) and in the `.md` summary the BIOS name, emulator build, and that hash (along with any version/build string present in the ROM if applicable).

### 2026-11-15 — Base PsyQ, absence of native MIPS overlays, and NSD/NSF paging system

- **Objective (Phase 3 start, PsyQ + overlays block):** locate `SetGeomScreen`, `DrawOTag`, `PutDispEnv`, `PutDrawEnv`, `VSync`, and `CdRead` in `SCUS_941.54` (`main`), map their XREFs, determine which overlays exist and how/where they load in RAM, and check whether `sys_init`, `main_loop`, and `quantize_frame_ticks` are ready for verification/promotion.
- **Executable startup and heap (`SCUS_941.54`, `pc0=0x80049b2c`, `t_addr=0x80010000`, `t_size=0x4f800`):**
  - `start` (`0x80049b2c`, `SNMAIN.OBJ/__SN_ENTRY_POINT`) clears BSS from `DAT_8005f2a4` to `&DAT_8006f1f0`, sets `DAT_8005cb28 = &DAT_8006f1f0`, initializes the custom allocator with `FUN_8001144c(&DAT_8006f1f4)`, and invokes `main` (`0x800117bc`) at `0x80049bc8`.
  - `main` (`0x800117bc`) sets `DAT_8005f1a4 = 1` (CD mode; when `0`, development strings `"c:/src/crash2/target/"` + `"streams/"` exist at `0x80010000..0x8001006f`), calls `sys_init` (`0x800117d8`), enters `main_loop(0x3c)` (`0x800117e0`), and exits into `sys_shutdown` (`0x800157a0` at `0x800117e8`).
  - Custom dynamic allocator over the post-BSS arena (between `0x8006f1f4` and `DAT_8005f2b4`, head at `DAT_80062bac` and sentinel `0xfffffffe`): `heap_alloc` (`0x8001148c`, 11 XREFs), `heap_free` (`0x800116c0`, 9 XREFs), and `heap_realloc` (`0x800116d4`, 2 XREFs).
- **Base PsyQ functions and mapped XREFs (`SCUS_941.54`):**

| Address | PsyQ Symbol | Game XREFs | Internal PsyQ XREFs / notes |
|---|---|---|---|
| `0x8004f008` | `SetGeomScreen` | **4**: `FUN_80016c58` (`0x80016ec4`), `FUN_8001798c` (`0x800179c0`), `FUN_800200a8` (`0x80020890`), `FUN_8002f6c8` (`0x8002f8b4`) | `gte_ldH a0; jr ra; _nop`. Neighbors: `InitGeom` (`0x8004ec30`, `sys_init` at `0x80015640`), `SetGeomOffset` (`0x8004efe8`, `FUN_8001798c` at `0x800179cc` and `FUN_80017bc4` at `0x80017f70`). Also `cfc2` (`gte_stH t7`) reads at `0x8004457c`/`0x800447c4`. |
| `0x8004c644` | `DrawOTag` | **1**: `frame_end_sync` (`0x80016a18`) | Sole caller in binary (`DrawOTagEnv` `0x8004c7bc` has 0 XREFs). Submits `DAT_80063454 + 0x18` when `DAT_800675ac == 0`. |
| `0x8004c910` | `PutDispEnv` | **2**: `FUN_800160b0` (`0x800161b4`), `frame_end_sync` (`0x800169ac`) | `FUN_800160b0` defines 2 `512x240` buffers (`SetDefDispEnv`). |
| `0x8004c6b8` | `PutDrawEnv` | **3**: `FUN_8001601c` (`0x8001604c`), `FUN_800160b0` (`0x800161c4`), `frame_end_sync` (`0x800169bc`) | `FUN_8001601c` clears `0,0..1024,512`; `FUN_800160b0` sets `SetDefDrawEnv(..., iVar1, 0xc, 0x200, 0xd8)` (`512x216` at `y=12`, origin of the 12-line black bars; `FUN_80016c58` draws 3 `POLY_F4` and recalculates `SetGeomScreen`). |
| `0x8004a484` | `VSync` | **11** at 4 sites: `frame_end_sync` x2 (`0x80016838`, `0x80016868`), `FUN_80036164` x4 (`0x8003625c..8c`, MC), `FUN_80035444` x3 (`0x80035540/5c/d0`, MC), and MC code outside functions at `0x80034b44`/`0x80034b64` x2 | **+19 in PsyQ** (`CD_cw` x2, `CD_sync` x2, `CD_datasync` x2, `CDREAD_OBJ_6B8` x1, `cd_read_retry` x3, `CdReadSync` x2, `CD_ready` x2, `CDREAD_OBJ_1A4` x3, `set_alarm` x1, `get_alarm` x1). `VSyncCallback` (`0x8004a708`) only has 2 XREFs in `libsnd` (`SsEnd` and `SSSTART_OBJ_18C`). |
| `0x80048f74` | `CdRead` | **3**: `cd_read_file_sync` (`0x800123f0` at `0x800124c4`), `cd_read_sectors_sync` (`0x80031680` at `0x800316bc`), and `cd_async_read_page` (`0x80012f24` at `0x80013008`) | **0 in PsyQ.** Neighbors used by game: `CdReadSync` (`0x80049078`, XREFs `0x80012ee4` and `0x800316c8`), `CdControl` (`0x80046b50`, 3 in game + 3 `cd_read_retry`), `CdControlF` (`0x80046c88`, 2 in game + 5 `libcd`), `CdSync` (`0x80046ae0`, 4 in game), `CdIntToPos` (`0x80046f9c`, 4 in game). `CdSearchFile` is not linked. |

- **Conclusion on overlays and code in RAM (corrected — dynamic native MIPS code DOES exist inside `.NSF` `GOOL` chunks):**
  1. **ISO9660 disc (`Crash Bandicoot 2 - Cortex Strikes Back (USA).bin`, PVD `CD001`, volume `SCUS-94154`):** there are indeed no `.BIN`, `.OVL`, or secondary executables besides `/SYSTEM.CNF;1` (LBA `23`, `66` B), `/SCUS_941.54;1` (LBA `81669`, `327680` B), and **38 `.NSD`/`.NSF` pairs**.
  2. **`FlushCache` (`0x8004a354`):** confirmed **0 calls in game code** (`0x80010000..0x80049174`); all 53 BIOS `A0/B0/C0` stubs and the sole 5 XREFs to `FlushCache` (`A0:0x44`) belong to PsyQ initialization (`_patch_pad`, `_send_pad`, `_remove_ChgclrPAD`, `_patch_gte`, `FUN_8005b118`).
  3. **Base/layout correction for `entry_type_handlers` (`0x8005b1d8..0x8005b43f`, 22 entries × `0x1c` B):** the table starts 8 bytes earlier (`0x8005b1d8` with `"NONE\0\0\0\0"`), not at `0x8005b1e0`. Actual layout: `+0x00 char name[8]` (`[0]="NONE"`, `[1]="SVTX"`, `[2]="TGEO"`, `[3]="WGEO"`, `[4]="SLST"`, `[5]="TPAG"`, `[6]="LDAT"`, `[7]="ZDAT"`, `[8]="CPAT"`, `[9]="BINF"`, `[10]="OPAT"`, `[11]="GOOL"`, `[12]="ADIO"`, `[13]="MIDI"`, `[14]="INST"`, `[15]="VCOL"`, `[16]="LINK"`, `[17]="MDAT"`, `[18]="IPAL"`, `[19]="PBAK"`, `[20]="SDIO"`, `[21]="VIDO"`), `+0x08 init` (`0x8005b1e0`), `+0x0c post_load`, `+0x10 on_entry`, `+0x14 on_unload`, `+0x18 fini`. Word `0x00000008` at `0x8005b440` already lies outside the table. Furthermore, `0x8001ee64`/`0x8001efd8`/`0x8001f018` belong to `[10]="OPAT"`, while `[11]="GOOL"` only registers `on_entry = 0x800189c4` (`li v0,-0xff; jr ra`, nop OK).
  4. **Erratum (actual source of heap MIPS code):** the prior conclusion that "no native MIPS overlays exist" is **ruled out**. Native R3000 MIPS code does execute out of `.NSF` heap pages, **embedded directly inside section `sec[1]` of `type = 11` (`"GOOL"`) chunks** and dispatched by the GOOL interpreter (see next section).
- **How the actual CD loading system works (NSD/NSF paging and RAM addresses):**
  - **Disc table `disc_file_table` (`0x80069034`, `12`-byte stride):** `iso9660_scan_levels` (`0x800316ec`, called in `sys_init @ 0x80015760`) reads PVD (LBA `0x10`), Path Table (`+0x8c`), and `S0..S3` directories via `cd_read_sectors_sync` (`0x80031680`), storing per `level_id`: `+0x00 & 0x7fffff = nsd_lba`, `+0x04 & 0x1ffff = nsd_size`, `+0x08 & 0xffffff = nsf_lba`. Samples verified on disc:
    - `0x02` (`S0/S0000002`, offset `0x8006904c`): `nsd_lba=57385 (0xe029)`, `nsd_size=5844 (0x16d4)`, `nsf_lba=57388 (0xe02c)` (`pages=0xd6`, `eids=0x19b`)
    - `0x10` (`S1/S0000010`, offset `0x800690f4`): `nsd_lba=25 (0x19)`, `nsd_size=5412 (0x1524)`, `nsf_lba=28 (0x1c)` (`pages=0x4a`, `eids=0x1aa`)
    - `0x3c` (`S3/S000003C`, offset `0x80069304`): `nsd_lba=56422 (0xdc66)`, `nsd_size=3284 (0xcd4)`, `nsf_lba=56424 (0xdc68)` (`pages=0x1e`, `eids=0xb5`)
  - **Level lifecycle and dynamic RAM addresses (`nsd_paging_state` at `0x80067588`):**
    - `main_loop` calls `level_load(&DAT_80067588, 0x3c)` on startup (`0x8001182c`) and performs level transitions (`level_unload` at `0x80011ad0`/`0x80011df8` -> `level_load` at `0x80011b10`) when `next_level_id` (`0x8005f3f0`) changes (e.g. via `FUN_80037698` at `0x80037dc8`, which also pre-seeks the laser with `cd_preseek_level` `0x80012e4c`).
    - **RAM destination:** `level_load` loads `.NSD` synchronously via `cd_read_file_sync` (`0x800123f0`) into a block allocated by `heap_alloc` and resized with `heap_realloc`, allocates the EID LUT at `DAT_80067fc4` (`nsd[0x400]*4`), and allocates a contiguous pool of up to **21 physical `64 KiB` pages** (`iVar3 << 16`, trying from `0x15` downwards until fitting in the heap between `0x8006f1f4` and `DAT_8005f2b4`). There are no fixed per-level addresses: addresses depend on prior `heap_alloc` allocations.
    - **Continuous per-frame paging:** `main_loop` calls `nsf_paging_pump(-1)` (`0x80012bc4`) every frame (`0x80011b48`) (and blocking paths call `nsf_paging_wait_idle` at `0x80012dc0`), stepping up to `21` physical descriptors (`0x800675b4`, stride `0x2c`) and `37` (`0x25`) virtual descriptors (`0x80067954`, stride `0x2c`) through the `nsf_page_state_step` state machine (`0x80013200`, 30 entries in `PTR_LAB_80010138`) → `cd_async_read_page` (`0x80012f24`, reads in `0x20`-sector = 64 KiB spans from `DAT_800675a8`) → `cd_async_sync` (`0x80012ed0`) → `nsf_page_relocate` (`0x8001254c`, relocates pointers when `*buf==0x1234` and `type!=1`) → `nsf_page_finish` (`0x800125f8`, registers in `DAT_80067590`/`DAT_80067fc4`, calls `entry_type_handlers+0x8` or uploads `type==1` textures to VRAM via `LoadImage`).
- **Secondary review (`sys_init`, `main_loop`, `quantize_frame_ticks`):**
  - `sys_init` (`0x80015614`): 1 exact XREF (`main @ 0x800117d8`); besides what was already described, invokes `iso9660_scan_levels` (`0x80015760`). Statically ready; live verification at cold boot or indirectly via its side effects (`0x8005cb28`, `0x80069034`, `0x8003be88`, `0x8005f1a4`).
  - `main_loop` (`0x80011800`): 1 exact XREF (`main @ 0x800117e0` with `a0 = 0x3c`). Main-loop scope statically completed (`level_load`/`level_unload`/`nsf_paging_pump`/`frame_end_sync`). Ready for live verification (active call stack/state in Experiment `005` and/or transition breakpoint without `SIGTRAP`).
  - `quantize_frame_ticks` (`0x80016f04`): 1 sole confirmed XREF in `frame_end_sync @ 0x80016974` (`*(uint*)(DAT_80063450 + 0x14)`), and all 5 readers in the binary mapped (`FUN_80019f08`, `FUN_8001e3dc`, `FUN_8001e544`, `FUN_8001d2c4`, `FUN_8001d63c`). Ready for direct dynamic observation of the quantized field in [005-tabla-discos-y-paginas-nsf.gdb](experiments/005-tabla-discos-y-paginas-nsf.gdb) (all 3 remain `propuesto` until the human runs/evaluates `005` or decides live-read verification suffices).
- **Experiment (`confirmado` live):** [005-tabla-discos-y-paginas-nsf.md](experiments/005-tabla-discos-y-paginas-nsf.md) (read-only verification in PCSX-Redux on level `0x1e`).

### 2026-11-15 — Static analysis Front 1 (native MIPS code in GOOL `sec[1]`) and Front 2 (Camera / Projection / Cropping)

- **Counterexample motivation (Front 1):** port notes (`patches/psxrecomp/UPSTREAM.md` §2, showing recompiled fragments at `0x800F5000`/`0x80191000`/`0x80195000` and 272 `.so` files) and leads in `overlay_captures.json` (`0x800BF000` / `0x800BFFA4` / `0x800BFFD0` and `0x80171000` / `0x801716C4` / `0x80171708`) showed MIPS code execution in RAM heap pages. Everything documented below was independently verified on `SCUS_941.54` (`../privado/ghidra-ro`) and the game ISO image, and confirmed live in [006-gool-mips-y-camara.md](experiments/006-gool-mips-y-camara.md).
- **On-disc origin of heap MIPS code (`type = 11`, `"GOOL"`):**
  - Across the **38 `.NSF` files** on the ISO9660 disc there are **453** entries with `type = 11` (`"GOOL"`), of which **319** contain native R3000 MIPS instruction blocks embedded in `sec[1]` ending in `0x03e0a809` (`jalr s5, ra`) or `0x03e00008; 0x34150000` (`jr ra; ori s5, zero, 0`). Across all `type != 11` entries in the 38 `.NSF` files the count is **0**.
  - Samples verified in the ISO matching the observed heap regions:
    - `S3/S000003C.NSF`, page `1` (`pid=3`, `lba=56456`, `ecnt=7`), `entry[2]` (`off=0x7984..0xa090`, `eid=0x6e93b94d`, `type=11`, `secs=6`, `sec_offs=['0x2c','0x44','0x1cc8','0x1ef0','0x1fc4','0x21c4','0x270c']`): its **`sec[1]` (`0x1c84` B)** section contains 10 MIPS blocks preceded by word `0x49be0be0`, including `sec1+0x3c4` (`page_off=0x7d8c`) and `sec1+0x3f0`.
    - `S1/S0000010.NSF`, page `16` (`lba=540`), `entry[4]` (`off=0x7648..0xb5e4`, `eid=0x66536ecd`, `type=11`), its **`sec[1]` (`0x31cc` B)** section contains 102 MIPS blocks preceded by `0x49be0be0`, including `sec1+0x8c4` (`page_off=0x7f50`) and `sec1+0x920`.
- **Dispatch from `SCUS_941.54` (`gool_interpret @ 0x8003a014`):**
  - `gool_interpret` reads `a1 = *s5++` (`s5 = *(obj + 0xc0)`, GOOL bytecode cursor), sets `$s8 = 0x1f800000`, queries table pointer `*(0x1f80005c)` (`gool_opcode_table` at `0x8005c514..0x8005c64f`, 79 entries), and dispatches on `(a1 >> 24) & 0xff`.
  - **Opcode `0x49`** jumps to **`0x8003aad4`**: `jalr s5; nop; bne s5, zero, 0x8003a06c`. Upon encountering `0x49be0be0` inside `sec[1]`, `$s5` already points to the next word (start of the native MIPS block inside the 64 KiB heap page), and the CPU jumps straight into the heap.
  - The `sec[1]` MIPS blocks examined in `S3/p01[2]` and `S1/p16[4]` have **0** `jal` calls back to `SCUS_941.54` and **0** `$gp` accesses; they manipulate `$s0` (`object*`) and `$s8` (`0x1f800000`), and exit via `0x03e0a809; nop` (`jalr s5, ra`, loading into `$s5` the next bytecode word after the block and resuming the loop at `0x8003a06c`) or via `0x03e00008; 0x34150000` (`jr ra; ori s5, zero, 0`, returning `$s5 = 0` to end the step at `0x8003abe8`).
  - All remaining GOOL opcodes (`0x00..0x48`, `0x4a..0x4e`) jump solely to static handlers inside `SCUS_941.54` (`0x80037440..0x80039c08` via `0x80039fcc`/`0x80039ff4`).
  - **Audit of remaining `jalr` and BIOS calls in `SCUS_941.54`:** of the 152 `jalr` words detected in the executable, 15 fall inside `.rodata`/data constants (`>= 0x8005b56c`); in `.text`, aside from `0x8003aad4`, the inspected indirect dispatches use static tables/functions in `SCUS_941.54` (`entry_type_handlers`, trees `0x80018aa8..0x80018dd0`, tables `0x8005b650`/`0x8005c514`, clipping `0x80044aa0/aa8/b00` at `0x80044e84..4f30`, callbacks `FUN_800349f8` and `FUN_8003cd0c`; in `FUN_80041e5c @ 0x80041f34` `DAT_80062a18+0x10..+0x20` confirmed live in `006` with static `SCUS_941.54` pointers). All 53 BIOS `A0/B0/C0` stubs are confined to `0x80049174..0x8005b108` and the sole `FlushCache` (`A0:0x44` at `0x8004a354`) has only 5 startup XREFs.
  - **Explanation of the artifacts in `UPSTREAM.md` §2 ("BC0x / invalid instructions in heap"):** the same `sec[1]` section interleaves GOOL bytecode (e.g. `0x49be0be0`, whose top nibble `0x12` corresponds to the MIPS `COP2` opcode) between the MIPS blocks, and shares the 64 KiB page with other sections and non-executable data; linear disassembly of the whole page interprets data/bytecode as broken instructions.
  - **Runtime I-cache coherence without `FlushCache`:** the engine reads `.NSF` pages via DMA (`CdRead`) with no subsequent `FlushCache` calls, and `nsf_page_relocate` (`0x8001254c`) only relocates chunk tables/pointers (without modifying `sec[1]` MIPS instructions). The page allocator (`nsf_page_alloc_evict @ 0x800136c8`) blocks physical page eviction while its pin/refcount byte `+0x0f` (`DAT_800675c3`, incremented by `eid_pin_or_load @ 0x80013f5c` / `eid_wait_and_pin @ 0x80013fd8` / `nsd_resolve_eid @ 0x80014260` and released by `eid_unpin @ 0x80014078` / `nsd_release_eid @ 0x800143c0`) is `> 0`. On PS1 hardware, the direct-mapped 4 KiB instruction cache naturally turns over as extensive main-loop/PsyQ code executes between page/level loads; under static recompilation (`psxrecomp`), lacking `FlushCache`, the runtime must discover/invalidate `.so` caches when new code arrives at previously seen heap addresses.
- **Static map of Display, Cropping, Projection, and Camera (Front 2):**
  - **Resolution and black-bar cropping (`display_init @ 0x800160b0`, `frame_end_sync @ 0x8001645c`):** `display_init` (called in `sys_init @ 0x80015674`) sets up two `0x2094`-byte contexts in `display_ctx_pool` (`0x8006345c`) rotated by `disp_ctx_front/draw/work` (`0x80063450/54/58`), with `SetDefDispEnv(..., i*0x200, 0, 0x200, 0xf0)` (`512x240`) and `SetDefDrawEnv(..., i*0x200, 0xc, 0x200, 0xd8)` (`512x216` at `y=12`). Every frame, `frame_end_sync` calls `draw_letterbox_and_fov` (`0x80016c58(DAT_8006cc94, DAT_8005f1d4)`), which draws 3 black `POLY_F4` extra-crop bars, adjusts `DrawEnv` `ofs` (`0x80d`/`0x2036`), reads base FOV, and shrinks `H` by `(H/24)*param_1`. Then `frame_end_sync` draws the background/horizon using a `POLY_F4` of width `0x200` (`512`) and height `216`, computing cutoff at `Y = (DAT_80060884 * sin(DAT_80060800) * 0xaa >> 0x14) - (unaff_s2 - 0x6c)`.
  - **Callers of `SetGeomScreen` (`0x8004f008`) and `SetGeomOffset` (`0x8004efe8`):**
    - `cam_init` (`0x8001798c`): sets `geom_screen` (`0x80060884`) = `0x120` (`288`), `SetGeomScreen(0x120)`, `SetGeomOffset(0,0)`, color matrix `0x8006088c`, `cam_state_zero(&DAT_800607f4)` (`z = 0x1f400`), `DAT_80060840 = 0xe1000`, `DAT_80060844 = 0x5dc000`, and clears `geom_offset_x/y` (`0x8006cc20/24`).
    - `cam_zone_switch` (`0x800200a8`, 14 callers): selects zone `current_zone_entry` (`0x800608cc`), path `current_cam_path` (`0x800608d4`), and progress `cam_path_progress` (`0x800608e0`), evaluates the spline/path with `cam_eval_path` (`0x80026a08` → `0x80060818..38` → `0x800607f4..814`), reads property **`0x130`** via `cam_fov_read` (`0x80023d7c`, default `0x120`), and if different from `0x80060884` invokes `SetGeomScreen`.
    - `cam_spawn_reset` (`0x8002f6c8`, 3 callers): restores `SetGeomScreen(DAT_80060884)`, resets `cam_shake_y` (`0x8006cb78 = 0`), resets zone and Crash entity (`DAT_8005f38c`).
    - `draw_letterbox_and_fov` (`0x80016c58`): modulates `geom_screen` during black bars, also calling `cam_fov_read`.
    - `cam_update` (`0x80017bc4`): calls `FUN_80020a24()`, builds `cam_rot_matrix` (`0x80060754`) from `-cam_rot` (`0x80060800..08`, Z→X→Y order), applies translation `-cam_pos>>8` (`0x800607f4..fc`), generates `cam_view_matrix` (`0x80060774`) via `cam_matrix_aspect_scale` (`0x80017af8`), sets **`SetGeomOffset(0x100 + DAT_8006cc20, 0x6c + (DAT_8006cb78 >> 8) + DAT_8006cc24)`** (center `256, 108` + shake/offset), damps `0x8006cb78`, and syncs `0x8006cc04..18`.
  - **Critical `5/8` aspect compensation (`0.625`, `512`px vs `320`px) for Phase 5:** both **`cam_matrix_aspect_scale` (`0x80017af8`)** (on `cam_view_matrix`: row 1 `* -5 >> 3`, row 2 negated) and **`model_view_matrix_build` (`0x8003d3cc`, sole call from `FUN_8001bd84`)** (row 1 `* 5 >> 3`) compensate in the GTE for the `512`-pixel framebuffer width (`320 / 512 = 5 / 8`). Furthermore `world_to_screen` (`0x8001ed60`) projects relative to center `(0x100, 0x6c)`. Any future FOV/widescreen change via `SetGeomScreen` without preserving or readjusting that `5/8` ratio in both matrices would stretch or squash geometry relative to the background/2D layer.
- **Experiment (`confirmado` live):** [006-gool-mips-y-camara.md](experiments/006-gool-mips-y-camara.md) ([006-gool-mips-y-camara.gdb](experiments/006-gool-mips-y-camara.gdb)).

### 2026-11-15 — Live verification of `005` and `006`, and Front 3: GOOL Entities, Camera (`structs.h`), and `512x216` / `5/8` dependencies

- **Dynamic results (`005` and `006`, BIOS `870563ba...`, `OpenBIOS PCSX-Redux build 561`, active level `0x1e`):**
  - **`005` (`confirmado`):** `disc_file_table` (`0x80069034`) matches the ISO identically (`0x02`, `0x10`, `0x3c`, and active `0x1e` at `0x8006919c`: `nsd_lba=29760, nsd_size=5124, nsf_lba=29763`); `nsd_paging_state` (`0x80067588`) is active with `21` physical slots (`0x800ad844..`, stride `0x10000`, `magic=0x1234`, `type=0`), `37` virtual slots, and `*(disp_ctx+0x14) = 0x22` (`34`, `2×0x11` from `quantize_frame_ticks`).
  - **`006` (`confirmado`):**
    1. At `0x8003aad4` (`gool_op49_exec_mips`) the live `tbreak` hit (`hops1=0`, `$ra=0x8003a574`, `$s0=0x800a0770`, `$s8=0x1f800000`) with **`$s5 = 0x8019da70`** (inside `phys[15]`, `EID=0x4e938ccd sec[1]=0x8019d8b4`). `x/16i 0x8019da70` showed the native MIPS block ending in `0x8019da84: jalr s5, ra; nop`, followed by `.word 0x1c300e4b` and `.word 0x49be0be0` (interleaved `0x49` opcode) and the next MIPS block at `0x8019da94`.
    2. **BSS audit `DAT_80062a18`:** `0x80062a28..0x80062a38` (`+0x10..+0x20`) contains exclusively static `SCUS_941.54` pointers (`0x8003dd0c`, `0x80042420`, `0x800426a0`, `0x80042548`, `0x80042818`), ruling out heap execution via `0x80041f34`.
    3. `cam_matrix_aspect_scale` (`0x80017af8`) verified word-for-word in RAM (`cam_rot_matrix 0x80060754` vs `cam_view_matrix 0x80060774`: row 1 `* -5 >> 3`, row 2 negated, translation preserved), and `tbreak` on `SetGeomOffset` (`0x8004efe8`, `ra=0x80017f78`) measured `$a0=256 (0x100), $a1=108 (0x6c)` with `geom_screen=288`.

- **Front 3.1 — Pool and active GOOL entity list per frame (Phase 6 / interpolation):**
  - **Pools and root buckets (`opat_init @ 0x8001ee64`):**
    - `gool_object_pool` (`0x8006cb14`): `heap_alloc(0xd680)` = **96 slots (`0x60`) × `0x23c` (`572`) bytes**, with metadata sub-structure linked at `+0x08`.
    - `gool_player_slot` (`0x8006cb10`): `heap_alloc(0x33c)` (`828` B) dedicated for Crash (`gool_player_ptr` at `0x8005f38c`).
    - `gool_root_buckets` (`0x8006cb18..0x8006cb57`): **8 root buckets** (`8`-byte stride, `+0x00=2, +0x04=first_child`; bucket 4 at `0x8006cb38` for type `0x300`/HUD objects, bucket 6 at `0x8006cb48` for player, free list at `0x8006cb58..5f`).
  - **Per-frame loop in `main_loop` (`0x80011800`):**
    1. `0x80011d84` calls `gool_tick_all` (`0x8001c29c(active)`), which calls `0x80018dd0(&LAB_80018cac, &gool_object_tick, active)` traversing the **8 buckets** (`0x8006cb18..57`) in pre-order.
    2. `gool_object_tick` (`0x8001c718`) processes every node with `+0x04 == 3`: saves prior `pos/rot` on the stack (`+0x60..+0x74`), steps `gool_interpret` (`0x8003a014`), calls `gool_physics_step` (`0x8001d63c` — integrates velocities using `dt = *(disp_ctx_front + 0x14)` capped at `0x66`, `(vel * dt) >> 10`), `gool_render_prep` (`0x8001aa80`), and depending on visibility flags, `gool_render_enqueue` (`0x8001abf8`, appends nodes to `*(disp_ctx_work + 0x2088)`/`+0x2090`).
    3. `0x80011d94` calls `render_queue_flush` (`0x8003db94`), which drains `*(disp_ctx_work + 0x2088)` calling transform, prep, and draw for each queued node.

- **Front 3.2 — Observed layouts to propose for `re/structs.h` (not edited by RE agent):**
  - **`GoolObject` (`0x23c` B; player `0x33c` B at `0x8006cb10`):**
    - `+0x00`: `int32 handle` (`0` free, `1` object, `2` bucket) | `+0x04`: `int32 node_kind` (`3` active object)
    - `+0x08`: `void *meta_ptr` (local matrix `0x00..0x1c`, SVTX data `+0x20..+0x2c`, bbox `+0x30..+0x44`)
    - `+0x0c`: `void *gool_entry` | `+0x18`: `void *zone_entry` | `+0x20..+0x3f`: RGB tint/color
    - `+0x40`: `self` | `+0x44`: `parent` | `+0x48`: `next_sibling` | `+0x4c`: `first_child` | `+0x58`: `rider_or_child`
    - **`+0x60, +0x64, +0x68`**: `int32 pos[3]` (`x, y, z` fixed-point `<< 8`)
    - **`+0x6c, +0x70, +0x74`**: `int32 rot[3]` (`rx, ry, rz`, full turn = `4096`)
    - **`+0x78, +0x7c, +0x80`**: `int32 scale[3]` (`sx, sy, sz`, unit = `0x1000`)
    - `+0x84..+0x8c`: `int32 vel[3]` | `+0x90..+0x98`: target angles/limits | `+0xa8/+0xac`: status flags
    - `+0xb8`: `int32 entity_id` (`>>8` index into bitfield `0x8006b1c4`) | `+0xbc`: `uint32 *gool_sp` | `+0xc0`: `uint32 *gool_pc` (`$s5`) | `+0xc8`: `pending_pc`
    - `+0xe8`: `uint8 *anim_seq` (`*anim_seq`: `1` SVTX, `2` sprite, `4` 3D text, `5` fragments) | **`+0xec`: `int32 anim_frame`** (`>> 8`, `0x8001a90c` already interpolates when flag bit 0 is set)
    - `+0xf0`: `spawn_subentry` | `+0xf8`: `path_len` | `+0xfc`: `floor_y` | `+0x100..+0x108`: flags/speed/tint | `+0x118`: `ot_depth_bias` | `+0x120..+0x122`: `render_mode, draw_type, light_mode`.
  - **`CameraState` (`0x80060754..0x80060958` + auxiliaries):**
    - `0x80060754` (`0x20` B): `MATRIX cam_rot_matrix` | `0x80060774` (`0x20` B): `MATRIX cam_view_matrix` (`-5/8` Y)
    - `0x80060794` (`0x20` B): `cam_view_matrix_copy` | `0x800607b4` / `0x800607d4`: alt matrices (`0x8001bd84`)
    - `0x800607f4..0x80060814` (`9×int32`): `pos[3]` (`7f4..7fc`), `rot[3]` (`800..808`), `scale[3]` (`80c..814`)
    - `0x80060818..0x80060838`: `cam_target_state` (`cam_eval_path` → `cam_zone_switch`) | `0x8006083c..44`: `cam_render_pos`
    - `0x80060884`: `geom_screen` (`H`) | `0x800608cc/d4/e0`: zone/path/progress | `0x8006cc20/24` + `0x8006cb78`: offsets and Y shake.
  - **`DisplayContext` (`0x8006345c`, `2` × `0x2094` B):** `+0x00` id (`0/1`), `+0x04` ot/buf base, `+0x08` `prim_ptr`, `+0x0c` `raw_ticks`, `+0x10` `draw_end_ticks`, `+0x14` `quant_ticks`, `+0x18..+0x2017` OT (`2048` words), `+0x2018` `DISPENV` (`20` B), `+0x202c` `DRAWENV` (`92` B), `+0x2088..+0x2090` entity node queue/arena.

- **Front 3.3 — Additional `512x216` and `5/8` dependencies in HUD / sprites / background (Phase 5):**
  - **Three independent sites with Y-axis `5/8` factor:** (1) `cam_matrix_aspect_scale` (`0x80017af8`, `* -5 >> 3`), (2) **`model_view_matrix_build` (`0x8003d3cc` for 3D/HUD text, `-(val * 5) >> 3` in Y row 1, confirmed `519 -> -324 = 0xfebc` in `008`)**, and (3) **`matrix_aspect_scale_local` (`0x80043090`, `-((val * 0xa0) >> 8) = -5/8` in Y row and Z row negation)**, inline clone used by **`hud_transform_2d` (`0x80044558`)** and modes `0x800443ec`/`0x800444bc`/`0x800447a4` (`0x8005b690`). `hud_transform_2d` sets `TR = (x>>8, -(y>>8), gte_stH())`, projecting HUD around `SetGeomOffset(256, 108)` without depending on `H`, while keeping Y `-5/8` scaling relative to the `512px` width.
  - **Sprites, background, fades, and `512x216` hardware clipping:**
    - `sprite_billboard_draw` (`0x80044830`, `0x8005b708[3]`): generates a `POLY_FT4` quad projected by GTE using the active center/view.
    - `draw_bg_tile` (`0x80016a60`): `512x216` background/horizon `TILE` using `horizon_y` with `0xaa` (`DAT_80060884 * sin(rx) * 0xaa >> 0x14`), `0x6c`, and `letterbox_level * 0x78 >> 3`.
    - `draw_screen_fade` (`0x80016b08`): fade `POLY_F4` over `0..512 × -12..228` relative to `DrawEnv` `y=12`.
    - **4 screen clipping limits `0x00d90200` (`512 × 217`):** `0x80041bf0`, `0x80041fa0` (`FUN_80041e5c`), `0x80045154` (`FUN_80044f54`), and `0x800453dc` (`draw_particles` `0x80045218`).

### 2026-11-15 — Live verification of Experiment `007` and static closure of Phase 3 (`RNG`, `PadState`, special cameras/renders)

- **Dynamic results of [007-gool-hud-y-entidades.md](experiments/007-gool-hud-y-entidades.md) (BIOS `870563ba...`, `OpenBIOS PCSX-Redux build 561`, level `0x1e`):**
  - **GOOL entities and movement delta:** `gool_player_ptr` (`0x8005f38c`) == `gool_player_slot` (`0x8006cb10`) = `0x800ad504`, `gool_object_pool` (`0x8006cb14`) = `0x8009fe80`. When moving Crash between Pass 1 and Pass 2 (`Start`/Pause):
    - `zone`: `0x800d5830 -> 0x800fd860`
    - `pos (+0x60..+0x68)`: `(9414656, 1723645, 14018560) -> (10926080, 2287103, 9566208)` (mirrored identically in `player_pos_copy` `0x8005f494..9c`)
    - `rot (+0x6c..+0x74)`: `(0, 442, 0) -> (0, 3936, 0)` | `anim_seq (+0xe8)`: `0x80184300 -> 0x801841d4` | `anim_frame (+0xec)`: `2560 -> 5376 -> 17664` (`>>8 = 69`).
  - **MANDATORY RULE FOR PHASE 6 (interpolation):** although a flat scan of the 96 slots in `gool_object_pool` (`0x8009fe80`, stride `0x23c`) counted **55** slots with `+0x04 == 3` in both passes, walking the actual tree yielded exact counts totaling the `96 + 1 = 97` objects: **15** active in `gool_root_buckets` (`0x8006cb18..0x8006cb57`) + **82** in `gool_free_bucket` (`0x8006cb58`) = `97` at idle; and **33** active (including UI nodes in `bucket[7]`) + **64** in `0x8006cb58` = `97` in Pause. As statically confirmed by `FUN_80019e08` (`0x80019e08`), freeing an object returns it to `0x8006cb58` **without clearing `+0x04`** (`= 3`). **In Phase 6 it is mandatory to traverse the 8 root buckets (`0x8006cb18..0x8006cb57`) following `+0x4c first_child` / `+0x48 next_sibling`** and never scan `gool_object_pool` by `+0x04 == 3`, to avoid interpolating freed objects. *(Precision note: in `gool_physics_step(obj, a1, a2)`, `a1` `sp+0x18` holds valid previous data only on the carrier/vehicle branch; for ordinary nodes it retains stack contents).*
  - **`DisplayContext`, 2D HUD, and `-5/8` aspect:**
    - `DISPENV (+0x2018)`: `512x240` verified on buffer `0` (`0x8006345c`, `x=0`) and `1` (`0x800654f0`, `x=512`); `DRAWENV (+0x202c)`: `clip=(0|512, 12, 512, 216)`, `ofs=(0|512, 12)`, `isbg=1`; `quant_ticks (+0x14) = 34 (0x22)`.
    - Live-confirmed `tbreak` hits: `gool_object_tick` (`0x8001c718`), `gool_physics_step` (`0x8001d63c`), `render_queue_flush` (`0x8003db94`), `draw_letterbox_and_fov` (`0x80016c58`, `geom_screen=288`), `quantize_frame_ticks` (`0x80016f04`, `a0=34/35`), `draw_bg_tile` (`0x80016a60` in level with `level_flags=0x0c01ffff`, `a2=512, a3=216`, skipped in Pause `0x0401dffe`), **`hud_transform_2d` (`0x80044558`)** in Pause (`ra=0x8003dc9c, gp=0x800a2fa8`), and chained **`matrix_aspect_scale_local` (`0x80043090 -> 0x80043088`)** (`ra=0x800444c8` and `ra=0x80044564`) scaling the GTE matrix by exact `-5/8` in Y row (`0x0d80 -> 0xf790`, `-3456*5/8 = -2160`; `0x055b -> 0xfca8`, `-1371*5/8 = -856`) and negating Z row (`0x1333 -> 0xffffeccd`, `0x0640 -> 0xfffff9c0`).

- **Static closure of Phase 3 — Random number generators (`RNG` for `tools/regress`):**
  - Two identical POSIX-style LCGs (`seed = seed * 0x41c64e6d + 0x3039; u = (seed / 0xf) % 0x7ffffff; return (int)u % mod`, `0` if `mod == 0`):
    - **LCG A (`rng_a_seed @ 0x8005f220`, `.sdata=1`):** `rng_a_init` (`0x8003155c`, called in `sys_init @ 0x8001567c`, sets `0x3039`), `rng_a_seed_set` (`0x8003156c`, called in `demo_playback_init @ 0x8002fd24` with `*(DAT_8005f3d8 + 4)`), and `rng_a_mod` (`0x8003147c`). In `SCUS_941.54` there are no direct calls (`jal`/pointers) to `0x8003147c`, and live in level `0x1e` (`007`) `0x8005f220` remained `0x00003039`.
    - **LCG B (`rng_b_seed @ 0x8005f224`, `.sdata=1`):** `rng_b_init` (`0x80031658`, `= 0x3039`, `0` xrefs in `SCUS`) and **`rng_b_mod` (`0x80031578`)** with 6 callers in `SCUS_941.54`: `demo_attract_pick` (`0x8002fef4`), SPU voice priority/selection (`0x80032a5c`), random Memory Card save name/ID `0..999998` (`0x800354b8`, `0x8003699c`), and MC helpers (`0x80035ac4`, `0x80035bc4`). Live in `007`, `0x8005f224` changed between sessions (`0x237c228a -> 0xaf1cf0fb`). *(Audit note: `0x8003df10..0x800417c8` and `0x80043778/8c` use `+0xa8($gp)` over `$gp` = local/scratchpad SVTX/WGEO rendering context, not `0x8005f224`.)*
    - **Isolated visual LCG:** `draw_water_ripples` (`0x80044f54`) and `draw_particles` (`0x80045218`) use fixed per-frame local visual constants (`0x30125400`/`0x493583fe`) with no persistent game state.

- **Static closure of Phase 3 — Processed input (`PadState`) and demo playback:**
  - `pad_init` (`0x80015828(2)`, called from `sys_init 0x80015614`) sets `pad_count` (`0x8006991c`) = `2`, clears structures, and registers `InitPAD(&0x80069920, 0x22, &0x8006996c, 0x22)`, `StartPAD()`, and `ChangeClearPAD(0)`.
  - **`PadState` (`2` × `0x4c` = `76` B, at `0x80069920` Pad 1 and `0x8006996c` Pad 2):** updated by `pad_update` (`0x800158e0`):
    - `+0x00..+0x21` (`34` B): raw DMA buffer (`+0x00 raw_stat`, `+0x01 pad_type`, `+0x02..+0x03` raw active-low buttons, `+0x06/+0x07` analog Y/X calibrated with `0x8006cdd0..0x8006cde4`).
    - `+0x24` (`0x80069944`): `buttons_pressed` (`held & ~prev1 & 0xffff`).
    - `+0x28` (`0x80069948`): `buttons_held` (active-high, DualShock `'S'` remap, `0x0f17` mask if input frozen, D-pad↔`0xf000` coupling via table `0x8005b440`).
    - `+0x2c`: `buttons_prev1` | `+0x30`: `buttons_pressed_prev` | `+0x34`: `buttons_prev2`.
    - `+0x38`: `stick_angle` (`0..4095`) | `+0x3c`: `stick_mag` (`<0x66 -> 0`) | `+0x40`: `dir_index` (`0..7`, `8` neutral).
  - Pad 1 mirrors `mag/angle` at `0x8006cd60`/`0x8006cd64`. With **`demo_mode` (`0x8006cd14`)**: `0` normal gameplay (`007`), `2` playback (`demo_playback_init 0x8002fcf8` loads `DAT_8005f3d8`, seeds `0x8005f220`, injects inputs from cursor `0x8005f374`, and restores `*(disp_ctx_front+0x14)` / `rcnt2_tick_count`), `3` random attract selection (`demo_attract_pick 0x8002fe58`). Main readers of `+0x24/+0x28`: `main_loop`, `0x80026ca0`, `0x800237f8`, `0x80036fac`.

- **Static closure of Phase 3 — Special cameras, WGEO shaders, and conditional passes:**
  - **Complete PsyQ scan in `SCUS_941.54` (`0x80010000..0x80046800`):** all modes (on-foot levels, vehicles, chases, bonus stages, and bosses) go through the exact same output path (`DrawOTag` 1 xref, `PutDispEnv` 2, `PutDrawEnv` 3, `SetGeomScreen` 4, `SetGeomOffset` 2).
  - **Camera state machine (`cam_mode_dispatch @ 0x80026ca0`, called at `main_loop 0x80011b60`):**
    - `DAT_8005b994`: `5` normal; `6` `0x80022a5c` (multi-frame interpolated pan `0x8005ba14/18/1c..`); `7` `0x80022e74` (hold/warp); `9` `0x80022f58`.
    - When `DAT_8005b994 == 5`, `switch (DAT_800608f0)` (prop `0x29`): `0` `0x8002271c`; `2` `cam_mode_rail_chase` (`0x80022878`, lookahead/chase with prop `0x160`); `3` `cam_mode_scaled_follow` (`0x80022314`, X scale `*5>>3` if `*(DAT_8006759c+8)==3`); `4` `cam_mode_polar_360` (`0x80021a08`, 360° polar / bosses around `0x8005bb00/08`); `8` `0x800225c0`; `10` `cam_mode_fixed_aim` (`0x80021f4c`, fixed/turret with `ratan2` on `0x8005bb3c/44`); `default` `cam_zone_switch` (`0x800200a8`).
    - Optional mirror/reflection matrices `0x800607b4`/`0x800607d4` when `*(current_zone_entry+0x10)+0x29c & 0x1000`, and vehicle control override `DAT_8006cbb4` (`0` if `DAT_80062ad8 & 0x400`, vs normal `0x100` in `gool_physics_step`).
  - **WGEO shaders and special passes (`zone_gfx_mode_apply @ 0x80020a24`, prop `0x185` -> `DAT_80062ad8` and `level_flags 0x8006cb94`):** switches the 5 static pointers at `DAT_80062a28..38` (including darkness/firefly `&0x100` with `0x8006cd50`, flags `0x800004`, `0x200`, `0x8000`, `8`, `0x20`, `0x200000`, `0x40`, and `DirnD` lightning `level_flags & 0x1000000`) and gates three conditional render passes: `draw_water_ripples` (`0x80044f54`, `&0x10`, clip `0xd90200`), `draw_particles` (`0x80045218`, `&0x400000`, clip `0xd90200`), and `vram_backbuf_copy` (`0x8002706c`, `level_flags & 0x40000`, `MoveImage` `(0,0x108,w,0xf0)` in `frame_end_sync`).

- **Struct proposals for `re/structs.h` (pending human promotion):**
  ```c
  /* PadState (0x4c bytes): 0x80069920 (Pad 1), 0x8006996c (Pad 2) */
  typedef struct PadState {
      uint8_t  raw[0x22];              /* +0x00: +0x00 raw_stat, +0x01 pad_type, +0x02..03 digital, +0x06..07 analog Y/X */
      uint16_t _pad22;
      uint32_t buttons_pressed;        /* +0x24: held & ~prev1 & 0xffff */
      uint32_t buttons_held;           /* +0x28 */
      uint32_t buttons_prev1;          /* +0x2c */
      uint32_t buttons_pressed_prev;   /* +0x30 */
      uint32_t buttons_prev2;          /* +0x34 */
      int32_t  stick_angle;            /* +0x38: 0..4095 */
      int32_t  stick_mag;              /* +0x3c: <0x66 -> 0 */
      int32_t  dir_index;              /* +0x40: 0..7, 8 = neutral */
      uint32_t _unk44;                 /* +0x44 */
      uint32_t _unk48;                 /* +0x48 */
  } PadState;

  /* GoolObject (0x23c bytes at 0x8006cb14; player 0x33c bytes at 0x8006cb10).
     IMPORTANT Phase 6: iterate the 8 buckets 0x8006cb18..0x8006cb57, never the flat pool. */
  typedef struct GoolObject {
      int32_t  handle;                 /* +0x00: 0 free, 1 object, 2 bucket */
      int32_t  node_kind;              /* +0x04: 3 active (not cleared on free) */
      void    *meta_ptr;               /* +0x08 */
      void    *gool_entry;             /* +0x0c */
      uint8_t  _unk10[0x08];
      void    *zone_entry;             /* +0x18 */
      uint8_t  _unk1c[0x24];           /* +0x20..+0x3f color/tint */
      struct GoolObject *self;         /* +0x40 */
      struct GoolObject *parent;       /* +0x44 */
      struct GoolObject *next_sibling; /* +0x48 */
      struct GoolObject *first_child;  /* +0x4c */
      uint8_t  _unk50[0x08];
      struct GoolObject *rider;        /* +0x58 */
      uint32_t _unk5c;
      int32_t  pos[3];                 /* +0x60..+0x68: fixed << 8 */
      int32_t  rot[3];                 /* +0x6c..+0x74: 4096 = full turn */
      int32_t  scale[3];               /* +0x78..+0x80: 0x1000 = 1.0 */
      int32_t  vel[3];                 /* +0x84..+0x8c */
      int32_t  target_rot[3];          /* +0x90..+0x98 */
      uint8_t  _unk9c[0x0c];
      uint32_t status_flags_a;         /* +0xa8 */
      uint32_t status_flags_b;         /* +0xac */
      uint8_t  _unkb0[0x08];
      int32_t  entity_id;              /* +0xb8 */
      uint32_t *gool_sp;               /* +0xbc */
      uint32_t *gool_pc;               /* +0xc0 */
      uint32_t _unkc4;
      uint32_t *pending_pc;            /* +0xc8 */
      uint8_t  _unkcc[0x1c];
      uint8_t *anim_seq;               /* +0xe8: *anim_seq = 1 SVTX, 2 sprite, 4 text3D, 5 frag */
      int32_t  anim_frame;             /* +0xec: fixed << 8 */
      uint8_t  _unkf0[0x28];           /* +0xf0 subentry, +0xfc floor_y */
      int32_t  ot_depth_bias;          /* +0x118 */
      uint32_t _unk11c;
      uint8_t  render_mode;            /* +0x120 */
      uint8_t  draw_type;              /* +0x121 */
      uint8_t  light_mode;             /* +0x122 */
      uint8_t  _unk123[0x119];
  } GoolObject;
  ```

### 2026-11-15 — Experiment `008`: third `5/8` path, live `PadState` (Lua), cameras, and `seeds/ghidra_funcs.txt` audit

- **Dynamic results of [008-fase3-cierre-proyeccion-y-camara.md](experiments/008-fase3-cierre-proyeccion-y-camara.md) (BIOS `870563ba...`, level `0x1e`):**
  1. **Third `5/8` path confirmed in Pause:** `draw_text_3d` (`0x8001bd84`, `ra=0x8001af24, rmode=6`) chains to `model_view_matrix_build` (`0x8003d3cc`, `ra=0x8001be38, is2d=1`). Between `0x8003d8f8` and `0x8003d94c`, measured `PRE IR(s3,s0,s4)=(0, 519, 0)` and `R11/12/13=(326, 0, 0)` → `POST -(v*5>>3) (s3,s0,s4)=(0, -324, 0)` with `t0=0x00000146`, `t2=0x0000febc` (`-324 = -(519*5>>3)` exact). Remaining `propuesto` because they did not fire in that scene: `sprite_billboard_draw` (`0x80044830`), `world_to_screen` (`0x8001ed60`, sole static xref `0x800385b0`), and `SetGeomScreen` with `letterbox_level != 0` (`letterbox_level = 0`, `geom_screen = 288`).
  2. **45-frame Lua sampling (`008-pad-state.lua`, `frame_counter = 22288..22332`):** validated in real time `buttons_pressed == buttons_held & ~buttons_prev1` (`0x2000` on frame `32` with `prev1=0`→`0x2000` on `33` and release on `36`; `0x1000` on frame `39`), `stick_angle` (`1024`/`2048`), `stick_mag` (`256`/`0`), `dir_index` (`2`/`0`/`8`), and actual displacement `player=(12126208,249589,43272192) -> (12179456,288001,43196416)`, with `rng_a = 0x00003039` and `rng_b = 0x00000001` steady across the 45 in-level frames.
  3. **Live camera and WGEO shaders:** `cam_mode_dispatch` (`0x80026ca0`, `ra=0x80011b68, trans=5, mode=0, ctrl_scale=0x100`) during active gameplay and `zone_gfx_mode_apply` (`0x80020a24`, `ra=0x80017be0`, `zone_gfx=0x0` playing vs `0x10` in Pause, `wgeo_shaders=0x8003dd0c..0x80042818`).

- **Audit of `seeds/ghidra_funcs.txt` (`748` unique entries in `0x800111b0..0x8005b118`, read-only):**
  - **Coverage over `re/symbols.csv` + `re/provisional_symbols.csv`:** out of `105` unique code addresses (`< 0x8005b1d8`), **`89` are present** and **`16` are missing** from `seeds`:
    - **14 missing standalone function starts** (preceded by `jr ra`): `0x8003be88` (`rcnt2_tick_isr`, `symbols.csv`), `0x8001c718` (`gool_object_tick`, confirmed), `0x80044558` (`hud_transform_2d`, confirmed), `0x80044830` (`sprite_billboard_draw`), `0x800189c4` (`gool_on_entry_nop`), `0x8001ee64` (`opat_init`), `0x8001efd8` (`opat_fini`), `0x8001f018` (`opat_post_load`), `0x8001f9c4` (`ldat_post_load`), `0x8001fddc` (`zdat_on_entry`), `0x8001ff30` (`zdat_on_unload`), `0x8003147c` (`rng_a_mod`), `0x80031658` (`rng_b_init`), `0x8004a364` (`_SendPAD`).
    - **2 are not standalone functions:** `0x8003bea4` (`rcnt2_tick_count`, 4-byte data) and `0x8003aad4` (`gool_op49_exec_mips`, jump-table branch inside `0x8003a014`).
  - **Indirect pointer tables (`53` missing standalone starts + `8` internal stubs = `61` unique `< 0x8005b1d8`):** nearly all functions missing from `seeds` come from the same pattern (pointer tables not automatically followed by Ghidra):
    - `entry_type_handlers` (`0x8005b1d8`, **21**): `0x800161f8, 0x800162fc, 0x80017198, 0x80017358, 0x800189c4, 0x8001ee64, 0x8001efd8, 0x8001f018, 0x8001f9c4, 0x8001fddc, 0x8001ff30, 0x80024188, 0x80027a38, 0x80027b9c, 0x80029768, 0x800297c8, 0x8002cb14, 0x8002fcd0, 0x8002fce8, 0x800324a8, 0x80033d10`.
    - `render_prep` (`0x8005b650`, **3**): `0x8004400c, 0x80044178, 0x80044334`.
    - `render_xform` (`0x8005b690`, **9**): `0x800443ec, 0x80044434, 0x80044468, 0x800444e0, 0x80044534, 0x80044558, 0x80044594, 0x800446f0, 0x800447dc`.
    - `svtx_prep_draw` (`0x8005b6d0..af`, **20**): `0x8003dd0c, 0x8003ebc4, 0x8003fb84, 0x8003ff14, 0x80040948, 0x80040b44, 0x80040fc4, 0x800417b0, 0x80041b80, 0x800432f4, 0x80043310, 0x80043324, 0x80043374, 0x800434ec, 0x80043504, 0x8004351c, 0x80043554, 0x80043594, 0x8004380c, 0x80044830`.

---

## 5. Summary of Verified Findings

### Confirmed (`re/symbols.csv`, 60 symbols; structs in `re/structs.h`)

| Address | Symbol | Module | Experiment | Date |
|---|---|---|---|---|
| `0x8003bea4` | `rcnt2_tick_count` | `main` | `001`, `002` | 2026-11-15 |
| `0x8001645c` | `frame_end_sync` | `main` | `002` | 2026-11-15 |
| `0x8003be88` | `rcnt2_tick_isr` | `main` | `003` | 2026-11-15 |
| `0x8006ccf0` | `frame_counter` | `main` | `002`, `003` | 2026-11-15 |
| `0x8004a2ec` | `_patch_pad` | `main` | `004` | 2026-11-15 |
| `0x8004a38c` | `_send_pad` | `main` | `004` | 2026-11-15 |
| `0x8004a424` | `_remove_ChgclrPAD` | `main` | `004` | 2026-11-15 |
| `0x8004a354` | `FlushCache` | `main` | static (`NOTES.md`) | 2026-11-15 |
| `0x80016f04` | `quantize_frame_ticks` | `main` | `007` | 2026-11-15 |
| `0x80069034` | `disc_file_table` | `main` | `005` | 2026-11-15 |
| `0x80067588` | `nsd_paging_state` | `main` | `005` | 2026-11-15 |
| `0x8005f3ec` | `current_level_id` | `main` | `005` | 2026-11-15 |
| `0x8005f3f0` | `next_level_id` | `main` | `005` | 2026-11-15 |
| `0x8003a014` | `gool_interpret` | `main` | `006` | 2026-11-15 |
| `0x8003aad4` | `gool_op49_exec_mips` | `main` | `006` | 2026-11-15 |
| `0x8005c514` | `gool_opcode_table` | `main` | `006` | 2026-11-15 |
| `0x80016c58` | `draw_letterbox_and_fov` | `main` | `007` | 2026-11-15 |
| `0x80017af8` | `cam_matrix_aspect_scale` | `main` | `006` | 2026-11-15 |
| `0x80017bc4` | `cam_update` | `main` | `006` | 2026-11-15 |
| `0x8003d3cc` | `model_view_matrix_build` | `main` | `008` | 2026-11-15 |
| `0x80060884` | `geom_screen` | `main` | `006` | 2026-11-15 |
| `0x80060754` | `cam_rot_matrix` | `main` | `006` | 2026-11-15 |
| `0x80060774` | `cam_view_matrix` | `main` | `006` | 2026-11-15 |
| `0x800607f4` | `cam_pos` | `main` | `006` | 2026-11-15 |
| `0x80060800` | `cam_rot` | `main` | `006` | 2026-11-15 |
| `0x800608cc` | `current_zone_entry` | `main` | `006` | 2026-11-15 |
| `0x800608d4` | `current_cam_path` | `main` | `006` | 2026-11-15 |
| `0x800608e0` | `cam_path_progress` | `main` | `006` | 2026-11-15 |
| `0x8006cc20` | `geom_offset_x` | `main` | `006` | 2026-11-15 |
| `0x8006cc24` | `geom_offset_y` | `main` | `006` | 2026-11-15 |
| `0x8006cb78` | `cam_shake_y` | `main` | `006` | 2026-11-15 |
| `0x8006cc94` | `letterbox_level` | `main` | `006` | 2026-11-15 |
| `0x80063450` | `disp_ctx_front` | `main` | `006` | 2026-11-15 |
| `0x80063454` | `disp_ctx_draw` | `main` | `006` | 2026-11-15 |
| `0x80063458` | `disp_ctx_work` | `main` | `006` | 2026-11-15 |
| `0x8006345c` | `display_ctx_pool` | `main` | `006` | 2026-11-15 |
| `0x8006cb14` | `gool_object_pool` | `main` | `007` | 2026-11-15 |
| `0x8006cb10` | `gool_player_slot` | `main` | `007` | 2026-11-15 |
| `0x8006cb18` | `gool_root_buckets` | `main` | `007` | 2026-11-15 |
| `0x8005f38c` | `gool_player_ptr` | `main` | `007` | 2026-11-15 |
| `0x8001c718` | `gool_object_tick` | `main` | `007` | 2026-11-15 |
| `0x8001d63c` | `gool_physics_step` | `main` | `007` | 2026-11-15 |
| `0x8003db94` | `render_queue_flush` | `main` | `007` | 2026-11-15 |
| `0x8001bd84` | `draw_text_3d` | `main` | `008` | 2026-11-15 |
| `0x80043090` | `matrix_aspect_scale_local` | `main` | `007` | 2026-11-15 |
| `0x80044558` | `hud_transform_2d` | `main` | `007` | 2026-11-15 |
| `0x80016a60` | `draw_bg_tile` | `main` | `007` | 2026-11-15 |
| `0x8006cb58` | `gool_free_bucket` | `main` | `007` | 2026-11-15 |
| `0x8005f494` | `player_pos_copy` | `main` | `007` | 2026-11-15 |
| `0x8006cb94` | `level_flags` | `main` | `007` | 2026-11-15 |
| `0x8005f224` | `rng_b_seed` | `main` | `007` | 2026-11-15 |
| `0x80069920` | `pad_states` | `main` | `008` | 2026-11-15 |
| `0x8006991c` | `pad_count` | `main` | `007` | 2026-11-15 |
| `0x8006cd14` | `demo_mode` | `main` | `007` | 2026-11-15 |
| `0x80026ca0` | `cam_mode_dispatch` | `main` | `008` | 2026-11-15 |
| `0x80020a24` | `zone_gfx_mode_apply` | `main` | `008` | 2026-11-15 |
| `0x80062ad8` | `zone_gfx_flags` | `main` | `008` | 2026-11-15 |
| `0x800608f0` | `cam_submode` | `main` | `008` | 2026-11-15 |
| `0x8005b994` | `cam_trans_state` | `main` | `008` | 2026-11-15 |
| `0x8006cbb4` | `ctrl_scale` | `main` | `008` | 2026-11-15 |

### Ruled Out

| Address | Hypothesis | Module | Reason / Experiment | Date |
|---|---|---|---|---|
| `SCUS_941.54` + `.NSF` | "No dynamically loaded native MIPS blocks exist outside `SCUS_941.54`" | `main` / `.NSF` | They do exist in `sec[1]` of `GOOL` chunks (`type = 11`: 319/453 entries on disc), executed via `0x8003aad4: jalr s5` (live-confirmed in [006-gool-mips-y-camara.md](experiments/006-gool-mips-y-camara.md)) | 2026-11-15 |
| `0x8005b1e0` | Start of `entry_type_handlers` without name field and `[21]=0x8` | `main` | Table starts 8 B earlier (`0x8005b1d8`, `+0x00 char name[8]` `"NONE"`..`"VIDO"`, 22 entries up to `0x8005b43f`) | 2026-11-15 |
