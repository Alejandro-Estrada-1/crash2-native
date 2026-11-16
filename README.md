English | [Español](README.es.md)

# crash2-native

[![Latest Release](https://img.shields.io/github/v/release/Alejandro-Estrada-1/crash2-native?label=Release)](https://github.com/Alejandro-Estrada-1/crash2-native/releases)
![Platform: Linux x86_64 | AppImage](https://img.shields.io/badge/Platform-Linux%20x86__64%20%7C%20AppImage-blue)
[![Last Commit](https://img.shields.io/github/last-commit/Alejandro-Estrada-1/crash2-native?label=Last%20Commit)](https://github.com/Alejandro-Estrada-1/crash2-native/commits/main)

Native Linux port of *Crash Bandicoot 2: Cortex Strikes Back* (PS1, USA, `SCUS-94154`) built on **[psxrecomp](https://github.com/mstan/psxrecomp)** and **[recomp-ui](https://github.com/mstan/recomp-ui)**, backed by independent clean-room reverse engineering.

> [!IMPORTANT]
> **No game data or Sony BIOS is included.** This repository and its AppImage releases contain zero disc images (`.bin`, `.cue`, `.chd`, `.iso`), extracted executables, or copyrighted assets. You must provide your own legitimate USA copy of *Crash Bandicoot 2* (`SCUS-94154`), strictly verified against Redump digests (`CRC-32: 395c0916`, `MD5: 3c31b5e038f025098a2fdfa70c8213f2`, `SHA-1: 3d37fe4288a83b01f1a0edbf78e76e0fede6bc22`, `192,814,608` bytes).

> [!WARNING]
> **Active development & noncommercial restriction.** Phases 0 through 4 (base compilation, clean-room reverse engineering of timing/camera/entities, `verify-disc`, CI, and AppImage packaging) are complete locally; widescreen (Phase 5), high-FPS interpolation (Phase 6), and deterministic regression tests (Phase 7) are next. Any binary linked against `psxrecomp` is subject to the **PolyForm Noncommercial License 1.0.0**.

---

## Project Goals & Technical Design

- **Linux-first native port:** Uses `psxrecomp` + `recomp-ui` with a native OpenGL launcher, in-game menu (`F10` / `Ctrl+L` / `Select+L3`), and first-run setup wizard (`Generate & rebuild`).
- **Clean-room reverse engineering:** All function names, addresses, and memory layouts in [re/symbols.csv](re/symbols.csv), [re/structs.h](re/structs.h), and [re/NOTES.md](re/NOTES.md) are independently observed on `SCUS_941.54` in Ghidra (`ghidra_psx_ldr`) and verified dynamically in PCSX-Redux (`re/experiments/001` through `008`).
- **Strict disc validation:** Both `psxrecomp` and the standalone Rust tool [tools/verify-disc](tools/verify-disc/README.md) reject mismatched or altered disc images before code generation.
- **Portable AppImage with user-side compilation:** Bundles a setup host, prebuilt recompiler emitters (`psxrecomp-game`, `psxrecomp-bios`), vendored offline dependencies (`SDL3`, `zlib`, `libwebp`, `libchdr`), Zig `0.17.1` (`-target x86_64-linux-gnu.2.28`), trimmed CMake `3.31.6`, Ninja `1.12.1`, and `tomli` (for Python 3.10 compatibility during runtime GOOL MIPS block compilation).
- **Planned enhancements (Phases 5–7):**
  - **Widescreen:** Crop the 12-line top/bottom black borders (`DRAWENV` `512x216` at `y=12`) and expand horizontal framing while preserving the engine's `5/8` (`512/320`) vertical scaling across all three confirmed GTE paths.
  - **High FPS via interpolation:** Keep game logic at the original 30 Hz (`RCntCNT2` / `quantize_frame_ticks`) and interpolate camera and active `GoolObject` transforms walked via the 8 root buckets (`gool_root_buckets`), verified bit-for-bit against stock logic by [tools/regress](tools/regress/README.md).

---

## Status

See [docs/ROADMAP.md](docs/ROADMAP.md) for the full phase breakdown and rationale.

| Phase | Milestone | Status |
|---|---|---|
| 0–2 | Repo layout, `psxrecomp` + `recomp-ui` integration, Redump config, 30 FPS Linux build | Complete |
| 3 | Clean-room RE (`001`–`008`): timing, NSD/NSF paging, GOOL MIPS blocks, camera, `5/8` scaling, `GoolObject`, `PadState`, `RNG`, 60 confirmed symbols, `re/structs.h`, 803 seeds | Complete |
| 4 | `tools/verify-disc` (Rust), `LICENSE`/`NOTICE`, `ubuntu:22.04` CI, self-contained AppImage + `release.yml` | Complete locally (GitHub Actions validation pending push) |
| 5–7 | Widescreen, frame interpolation, `tools/regress` replay checks, public release | Planned |

---

## Running the AppImage

Download the `.AppImage` and `SHA256SUMS` from Releases, verify the checksum, and make the file executable:

```bash
sha256sum -c SHA256SUMS
chmod +x crash2-native-*-x86_64.AppImage
```

> [!NOTE]
> The AppImage bundles Zig, CMake, Ninja, prebuilt emitters, and offline dependency archives, and never packages host GL/DRM libraries (`libGL`, `libOpenGL`, `libGLX`, `libdrm`). You only need **Python 3** and minimal **OpenGL / X11 / ALSA** development headers on the host so SDL3 and the OpenGL target can link cleanly against your system drivers on first build.

Check host prerequisites or verify your disc before launching:

```bash
./crash2-native-*-x86_64.AppImage --check-prereqs
./crash2-native-*-x86_64.AppImage --verify-disc --disc "/path/to/Crash Bandicoot 2 - Cortex Strikes Back (USA).cue"
./crash2-native-*-x86_64.AppImage
```

On first launch, the setup wizard extracts `SCUS_941.54`, generates C code, and compiles the native binary into `~/.local/share/crash2-native/` (override with `CRASH2NATIVE_DATA_DIR`). Useful options and environment variables:

- `--setup`: Re-open the setup/rebuild wizard even if a compiled binary already exists.
- `CRASH2NATIVE_DISC=/path/to/disc.cue`: Pre-select the disc path in `game.toml`.
- `CRASH2NATIVE_USE_SYSTEM_CC=1`: Use system `cc`/`c++`/`cmake`/`ninja` instead of the bundled Zig toolchain.

If `--check-prereqs` reports missing packages, install them for your distribution:

- **Ubuntu / Debian:**
  ```bash
  sudo apt update && sudo apt install -y \
    python3 libgl-dev libx11-dev libxext-dev libxcursor-dev libxfixes-dev \
    libxi-dev libxrandr-dev libxss-dev libxtst-dev libasound2-dev
  ```
- **Arch Linux / derivatives:**
  ```bash
  sudo pacman -S --needed \
    python libglvnd libx11 libxext libxcursor libxfixes libxi libxrandr \
    libxss libxtst alsa-lib
  ```
- **Fedora:**
  ```bash
  sudo dnf install -y \
    python3 mesa-libGL-devel libX11-devel libXext-devel libXcursor-devel \
    libXfixes-devel libXi-devel libXrandr-devel libXScrnSaver-devel \
    libXtst-devel alsa-lib-devel
  ```

---

## Building from Source (Linux)

1. Clone with submodules and verify tool dependencies + disc image (`disc/` must point to a directory containing your Redump `.bin` + `.cue`):
   ```bash
   git clone --recursive https://github.com/Alejandro-Estrada-1/crash2-native.git
   cd crash2-native
   ./scripts/setup.sh
   ```
   *(Use `./scripts/setup.sh --sin-disco` for disc-less setup or CI environments.)*

2. Generate C code from the disc and compile the native runtime:
   ```bash
   ./scripts/build_linux.sh -j 4
   ```
   *(Pass `--sin-generar` to rebuild C/C++ changes without regenerating, `--sin-ui` to build without `recomp-ui`, or `--setup-host` to build only the setup wizard without a disc.)*

3. Run the disc verifier unit tests (no game disc required):
   ```bash
   cargo test --manifest-path tools/verify-disc/Cargo.toml
   ```

4. Optional: build an AppImage locally on Ubuntu 22.04:
   ```bash
   ./packaging/appimage/build-appimage.sh --jobs 4
   ```

---

## Repository Structure & Documentation

| Path | Description | Docs |
|---|---|---|
| `src/` | Title setup host and `recomp-ui` in-game menu provider | — |
| `re/` | Clean-room symbols (`symbols.csv`), verified C structs (`structs.h`), logs, and GDB/Lua experiments | [re/NOTES.md](re/NOTES.md) |
| `seeds/` | Verified function start addresses for static recompilation (`ghidra_funcs.txt`) | — |
| `patches/psxrecomp/` | Minimal framework patches and upstream issue notes | [UPSTREAM.md](patches/psxrecomp/UPSTREAM.md) |
| `tools/verify-disc/` | Zero-dependency Rust Redump verifier | [README.md](tools/verify-disc/README.md) |
| `tools/regress/` | Planned deterministic logical-state regression verifier | [README.md](tools/regress/README.md) |
| `packaging/appimage/` | Portable AppImage builder, `AppRun`, desktop entry, and Ubuntu 22.04 check findings | [CHECK_FINDINGS.md](packaging/appimage/CHECK_FINDINGS.md) |
| `scripts/` | Setup, Linux build, PCSX-Redux GDB wrapper, and save backup utilities | — |
| `docs/` | Architecture decisions, Redump reference, and roadmap | [ROADMAP.md](docs/ROADMAP.md) |

---

## Licensing

- Original code, tools, reverse engineering notes, and scripts in this repository are licensed under the **MIT License** ([LICENSE](LICENSE)).
- Linked binaries and AppImage distributions rely on **psxrecomp**, governed by the **PolyForm Noncommercial License 1.0.0** (noncommercial use only).
- Full third-party notices and licenses for `recomp-ui`, OpenBIOS, SDL3, Zig, CMake, Ninja, `tomli`, and AppImage `type2-runtime` are documented in [NOTICE](NOTICE).
