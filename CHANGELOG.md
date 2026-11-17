English | [Español](CHANGELOG.es.md)

# Changelog

All notable additions and fixes for each release are documented in this file in English (with a Spanish translation in [CHANGELOG.es.md](CHANGELOG.es.md)). Every GitHub Release entry mirrors its corresponding version section here.

## [Unreleased]

### Added
- Ongoing Phase 6 reverse engineering (`re/experiments/009`) for 30 Hz snapshot interpolation boundaries and discontinuity signals.

---

## [v0.1.0] - 2026-11-16

First runnable milestone covering Phases 0 through 5: native Linux 30 FPS execution, clean-room reverse engineering of core engine systems, presentation overscan crop, opt-in 16:9 widescreen mod, disc verification, Ubuntu 22.04 CI, and portable x86_64 AppImage packaging.

### Added
- Native Linux port of *Crash Bandicoot 2: Cortex Strikes Back* (`SCUS-94154`, USA) on `psxrecomp` + `recomp-ui` preserving 30 Hz gameplay timing, startup launcher, first-run `Generate & rebuild` wizard (`src/codegen_setup.c`), and in-game menu (`F10` / `Ctrl+L` / `Select+L3`, `src/menu_provider.c`).
- Independent clean-room reverse engineering in `re/` (`experiments/001` through `008`, `60` confirmed symbols in `re/symbols.csv`, verified C structs in `re/structs.h`) and `803` verified function seeds (`seeds/ghidra_funcs.txt`).
- Presentation-only vertical overscan crop removing the 12-line top and bottom black borders (`DRAWENV` `512x216` at `y=12`, unstretched `40:27` image in `4:3`, toggleable with `CRASH2NATIVE_NO_CROP=1` via `src/widescreen.c`).
- Opt-in preloaded `Widescreen (16:9)` mod (`crash2.enhancement.widescreen`) with selectable horizontal FOV opening (`Balanced 1.125x` default, `Conservative 1.10x`, `Full 1.20x`), preserving `5/8` GTE vertical scaling and keeping OpenBIOS and 24-bit MDEC FMVs in `4:3`.
- Zero-dependency Rust Redump disc verifier (`tools/verify-disc`) validating `SCUS-94154` size and digests (`192,814,608` bytes, CRC-32 `395c0916`, MD5 `3c31b5e038f025098a2fdfa70c8213f2`, SHA-1 `3d37fe4288a83b01f1a0edbf78e76e0fede6bc22`).
- Portable `x86_64` AppImage built on `ubuntu:22.04` (targeting glibc `>= 2.28`) bundling OpenBIOS, Zig `0.17.1`, trimmed CMake `3.31.6`, Ninja `1.12.1`, prebuilt `psxrecomp-game` and `psxrecomp-bios`, vendored offline dependency archives (`SDL3`, `zlib`, `libwebp`, `libchdr`), and `tomli` `2.2.1`, storing user data and builds in `~/.local/share/crash2-native/`.
- GitHub Actions `ubuntu:22.04` CI (`.github/workflows/ci.yml`) and tag-driven AppImage release workflow (`.github/workflows/release.yml`) with `SHA256SUMS`.

### Fixed
- Cleared `$APPIMAGE` (after preserving it in `CRASH2NATIVE_APPIMAGE_PATH` and `RECOMP_APPIMAGE_PATH`) inside `packaging/appimage/AppRun` so running the `.AppImage` directly, via `--appimage-extract-and-run`, or via desktop launchers (such as Gear Lever and rofi) resolves `bios/openbios.bin`, `game.toml`, and `saves/` under `CRASH2NATIVE_DATA_DIR` instead of aborting with `Bundled BIOS Missing`.
- Fixed `[Errno 30] Read-only file system` during `Generate & rebuild` inside the AppImage by honoring explicit pre-staged `PSXRECOMP_GAME` / `PSXRECOMP_BIOS` environment overrides in `ensure_emitters()` (`patches/psxrecomp/0005-use-prestaged-emitters-from-env.patch`), creating writable `project/psxrecomp/bios` and `project/psxrecomp/generated` directories in `AppRun` (migrating previous symlinks), and preserving pre-staged `overlay_toolchain/` (`patches/psxrecomp/0002-preserve-prestaged-overlay-toolchain.patch`).
- Normalized `SOURCE_DATE_EPOCH` to decimal Unix seconds in `.github/workflows/release.yml` and at the start of `packaging/appimage/build-appimage.sh` before invoking `zig cc`, fixing ISO-8601 `push` tag timestamps rejected by Clang/Zig.
- Enforced `defaults.run.shell: bash` across workflows and replaced `actions/setup-python` in `ci.yml` with `ubuntu:22.04` native `python3.11` to avoid `dash` and host `GLIBC_2.38` container mismatches.
- Applied framework patches `0001-crash-trace-date-time.patch` (Zig C portability), `0003-display-present-crop.patch` (`DRAWENV` `512x216` crop hook), and `0004-widescreen-projection-aspect.patch` (live widescreen projection callback).

[Unreleased]: https://github.com/Alejandro-Estrada-1/crash2-native/compare/v0.1.0...HEAD
[v0.1.0]: https://github.com/Alejandro-Estrada-1/crash2-native/releases/tag/v0.1.0
