English | [Español](UPSTREAM.es.md)

# Upstream Candidates and Local Patches for `psxrecomp`

Framework issues observed in this port. Each entry states what was observed,
where, and with what evidence. Whenever an issue carries a local patch, the
`.patch` file lives in this directory (applied by `scripts/setup.sh`) and is
linked here.

Framework: `psxrecomp` at `b263b855` (master as of 2026-11-10).
Environment: Arch Linux, GCC 16.2.1, Clang 23.1.4, Python 3.14.

---

## 1. Undeclared `realpath` / `lstat` under `-std=c11` (GCC >= 14)

- **Where:** `host/psxrecomp_codegen_host.c` (first-run setup wizard host).
  Uses `realpath` (lines 354, 969, 971, 2321, 2718-2719, 4411-4412) and `lstat`
  (2804) without defining a feature test macro (`_DEFAULT_SOURCE`,
  `_XOPEN_SOURCE 700`, ...).
- **What happens:** under strict `-std=c11`, glibc omits these declarations.
  GCC 14+ turns implicit declaration and `-Wint-conversion` into errors:
  `initialization of 'char *' from 'int' makes pointer from integer without a cast`.
- **Where seen:** the `codegen_host_bios_stems` test
  (`runtime/tests/test_codegen_host_bios_stems.py`, compiled with `cc -std=c11`).
- **Does it affect us?** No. Verified on 2026-11-15 with `-fsyntax-only` on the
  file: 0 errors with `-std=gnu11` on GCC 16 and Clang 23, versus 12 and 20 under
  `-std=c11`. Our build passes no `-std=` flag (`build-release/build.ninja`), so
  it uses the compiler's default GNU dialect. Only the upstream test fails by
  forcing `-std=c11`. No local patch is needed.
- **Proposed fix:** `#define _DEFAULT_SOURCE` (or `_XOPEN_SOURCE 700`) before
  the file's `#include` directives. Generic, upstream candidate.

## 2. Overlay chunks: trailing data decoded as code ("unsupported")

- **What was seen:** on the first run, 19 overlay fragments failed to compile
  with `generated-c-audit: 0 unknown_bad, N unsupported`, plus one more with
  `delay-slot-identity: ... reserved/unsupported branch encoding`. They stay in
  the interpreter: the game works, just slower.
- **Headless reproduction:** `tools/compile_overlays.py --check --only-region`
  on the captured dumps for those regions produces the same result.
- **What words they are:** the "unsupported" opcodes do not exist in the PS1
  R3000A, and the pages mix code with data (`ffffffff`, `fffffffd`, `fffce000`,
  ...). Instruction decoding is not missing; fragment traversal walks into
  data.

  | Region (capture) | Failed fragments | Words (address: value, primary opcode) |
  |---|---|---|
  | `0x800F5000` (0x1000) | `0x800F5EF4`, `…5F20`, `…5F44`, `…5F84` (1 each) | `0x800F5FE8: 46404281` COP1 (0x11) |
  | `0x80191000` (0x2000) | `0x80192954`, `…299C`, `…2A88` (29 each) | the page contains 51 words with nonexistent R3000A opcodes (0x18 DADDI x23, 0x3B SWC3 x9, 0x11 COP1 x3, 0x3C x3, 0x3F SD x2…), e.g., `0x80191084: 5c07000e`, `0x801910B8: ffffffff` |
  | `0x80195000` (0x3000) | 13 fragments (1, 2, or 8 each) | `0x80195F1C: 4cb03e1f` COP3, `0x80195F44: 4de25800` COP3 |
  | `0x80195000` | `0x8019526C` (reserved branch) | `0x80195278: 411be0d1` = `BC0x` (COP0 conditional branch) inside a delay slot |

- **Limitation:** `compile_overlays.py` deletes the temporary C file, so each
  word cannot be attributed to its exact fragment with certainty. The table
  takes the window from the first failing entry through `0x200` bytes past the
  last one.
- **For the report:** ask fragment traversal to stop at opcodes that do not
  exist in R3000A (or treat them as function boundaries) instead of discarding
  the whole fragment, plus an option to keep temporary C files for diagnostics.

## 3. Misleading overlay autocompile warning

- **Message:** `WARNING: overlay autocompile has failed 3 consecutive runs (last exit 2).
  Nothing is being compiled to native code ... Check [runtime] overlay_autocompile_cmd`.
- **Reality:** the same run compiled 64 fragments and the cache contained 272
  `.so` files. Exit code 2 means "some fragments failed" (see item 2), not that
  autocompile is misconfigured.
- **For the report:** distinguish "partial failure" from "nothing compiled" in
  the warning message.

## 4. Setup wizard does not pass `--no-toolchain-download` (affects Windows only)

- **Where:** `host/psxrecomp_codegen_host.c` invokes `psxrecomp_cli.py generate`
  and `rebuild` without `--no-toolchain-download`.
- **On Linux and macOS it downloads nothing:** `ensure_toolchain()` in
  `tools/toolchain_pack.py` uses `cmake`, `ninja`, `python3`, and the compiler
  on `PATH`, failing with `"Native build tools are missing"` if any is missing.
  Verified with a test that blocks `urllib` (a planned
  `PSXRECOMP_NO_TOOLCHAIN_DOWNLOAD` patch was dropped because it would have no
  effect on Linux).
- **On Windows**, however, it downloads the `releases/latest` bundle from
  `RetroPortingToolKit/RetroPorting-Toolchains` with no pinned version or hash.
- **For the report (if a Windows build is ever added):** pin the bundle version
  and verify its SHA-256, or let the title disable downloads.
- **Implication for Phase 4:** the AppImage must either bundle or require
  cmake, ninja, python3, and a compiler; the wizard will not fetch them on Linux.

## 5. Recompiler `ctest`: 15 of 164 tests fail on `b263b855`

Built out-of-tree (`build-recompiler/`). Almost all appear to be tests out of
sync with the code rather than environment issues:

- Inspect source text that no longer matches: `mod_owned_display_controls`,
  `frame_interpolation_flip_source`, `gl_internal_scale_guards`,
  `native_wide_line_batching`, `overlay_candidate_capacity`, `bundled_release_layout`.
- Harnesses that fail to link (undefined symbols: `host_span_end`,
  `psx_mod_function_entry_has_hook`, `psx_mod_memory_address`, ...):
  `overlay_segment_keys`, `overlay_segment_gate`, `interp_refused_game_text`.
- Require an already-built runtime (`overlay_codegen_hash.h` is 0, `"STALE
  RECOMPILER BINARY"`): `bios_module_build`, `compile_overlays_static_tail`.
- Others: `ws_cull_screen_x_hi_codegen_test` (`"unlisted lui stays vanilla"`;
  the pinned commit touches LUI emission), `aot_overlay_discovery` (`assert
  total == 2`), `interp_cop0_read_sample` (aborts at `-O0`, rc=-6),
  `codegen_host_bios_stems` (item 1).

Before reporting: re-run on the Hercules pin (`2a4824f`) to separate recent
regressions. `docs/BUILDING.md` still says "38 tests".

## 6. Sony BIOS `install_slots` ranges measured only with PsyQ 3.70

- **Where:** `bios/SCPH1001.toml` (and `SCPH5500.toml` / `SCPH5501.toml`)
  declare pad range `ram_addr = 0x4964`, `len = 0x2C` (`"RemovePatchPad /
  ChgclrPAD family"`), measured on Breath of Fire III (SLPS-00990, PsyQ 3.70).
  The profiles themselves note: `"Re-measure per SDK version before trusting
  the numbers"`.
- **What is missing:** according to the reverse-engineering agent, PsyQ 4.0's
  `_patch_pad` (used by Crash 2) also patches `base+0x3D8`, `+0x4E0`, and
  `+0x62C`. **Unverified:** we have no Sony BIOS, and the base used by those
  offsets is not confirmed.
- **Expected effect if missing:** those kernel bodies fail the ROM hash match
  and always run interpreted (`"Undeclared means that body keeps
  interpreting"`): slower, not wrong.
- **Does not affect OpenBIOS:** OpenBIOS disables those patches inside game
  code. `getB0table` (`0xBFC05BB0`) calls `patch_hook(a0 = caller $ra)`
  (`0xBFC07E84`), writing `nop; nop` at `$ra`, and the corresponding
  `*_execute` writes `b +N; nop` at `$ra+8`. In Crash 2 this explains the three
  game functions rewritten in RAM (`_patch_pad` `0x8004A2EC` ->
  `patch_pad_2_execute`, `b +10`; `_send_pad` `0x8004A38C` ->
  `send_pad_2_execute`, `b +12`; `_remove_ChgclrPAD` `0x8004A424` ->
  `remove_ChgclrPAD_2_execute`, `b +5`). Evidence: disassembly comments in
  `generated/OpenBIOS_full.c` and ELF symbols in
  `recompiler/seeds/openbios_elf_seeds.json` (`pcsx-redux 55fbf04`).
- **For the report:** ask to measure ranges under PsyQ 4.0 or declare the union
  of versions, as supported by the schema.

## 7. Building with `zig cc -target x86_64-linux-gnu.2.28` (AppImage validation)

Tested on 2026-11-15 with Zig `0.17.1` (Clang `22.1.8`) against `psxrecomp`
(`b263b855`), `recomp-ui` (`3c641560`), `src/`, the 29 files in `generated/`
(`SCUS_941.54_dispatch.c` and `SCUS_941.54_full_00..27.c`), and the emitters in
`psxrecomp/recompiler`.

- **Overall result:** the full runtime (`crash2_native`, 139 MiB), the
  `--setup-host` variant (`-DPSXRECOMP_FORCE_SETUP_HOST=ON`), and the emitters
  (`psxrecomp-game` and `psxrecomp-bios`, built with
  `-DPSXRECOMP_ENABLE_CHD=OFF`) compile and link cleanly. `libc++` links
  statically and the highest symbol version in `readelf -V` was `GLIBC_2.27`
  in `crash2_native` (`GLIBC_2.16` in `psxrecomp-game`).
- **Compile failure — `runtime/src/crash_trace.c` (`-Werror,-Wdate-time`):**
  lines 59 and 61 use `__DATE__` and `__TIME__`. Zig 0.17.1 enables
  `-Werror=date-time` by default and aborts compilation (`expansion of date or
  time macro is not reproducible`).
  - **Local patch (upstream candidate):**
    [`0001-crash-trace-date-time.patch`](0001-crash-trace-date-time.patch),
    wrapping `kBuildId` with `#pragma GCC diagnostic push / ignored
    "-Wdate-time" / pop` under `#if defined(__clang__) || defined(__GNUC__)`.
    Verified with `zig cc` (0.17.1), `clang -Wdate-time -Werror`, and
    `gcc -std=gnu11 -Wdate-time -Werror`.
- **CMake configure failure when the host has SDL3 — `runtime/runtime.cmake:265-284`:**
  if the host system has `/usr/lib/cmake/SDL3` (Arch Linux, etc.),
  `find_package(SDL3)` detects it and `_psx_header_compiles("SDL3/SDL.h")` fails
  because `zig cc` uses its own sysroot instead of `/usr/include` and CMake
  omits `-I/usr/include`. Instead of falling back to `PSX_SDL3_FETCH=ON`,
  `runtime.cmake:271` aborts with `FATAL_ERROR`.
  - **No patch in `runtime.cmake` (intentional for `cmake-clang-v1`):** when
    invoking CMake with `zig cc`, pass `-DCMAKE_DISABLE_FIND_PACKAGE_SDL3=ON`
    to force fallback to `FetchContent` (static `SDL3 3.4.10`).
- **Host dependencies linked unless disabled (`ldd` / `readelf -d`):**
  in the full Arch build, CMake linked `libcrypto.so.4` (`OpenSSL`),
  `libfreetype.so.6` (`Freetype`), and `libharfbuzz.so.0` (`PkgConfig` +
  `harfbuzz`), which breaks portability across distributions (e.g., Ubuntu 22.04
  uses `libcrypto.so.3`). Tested `--setup-host` with
  `-DCMAKE_DISABLE_FIND_PACKAGE_SDL3=ON`, `-DCMAKE_DISABLE_FIND_PACKAGE_ZLIB=ON`,
  `-DCMAKE_DISABLE_FIND_PACKAGE_OpenSSL=ON`, and
  `-DCMAKE_DISABLE_FIND_PACKAGE_PkgConfig=ON`: `psx_sha256_file.cpp` uses the
  portable fallback without `libcrypto`, `zlib` builds statically via
  `FetchContent`, leaving `NEEDED` entries `libfreetype.so.6` (optional in
  `recomp-ui`; also disableable), `libOpenGL.so.0`, `libm.so.6`, `libc.so.6`,
  `ld-linux-x86-64.so.2`, `libpthread.so.0`, and `libdl.so.2`. Without
  `PkgConfig`, SDL3 disables Wayland/Pulse/PipeWire while keeping
  `x11(dynamic)` + `alsa(dynamic)`. `FindOpenGL` still requires system GL
  libraries and headers (`libglvnd` / `libgl-dev`) unless provided by the
  packaged environment.

---

## 8. `stage_overlay_toolchain_for_product()` deletes `overlay_toolchain/python` and attempts downloads even when pre-staged

- **Where:** `psxrecomp_cli.py` (`stage_overlay_toolchain_for_product` ->
  `tools/release_stage.py`, `stage_toolchain`).
- **What happens:** at the end of `psxrecomp_cli.py rebuild` after the user's
  first build, `stage_toolchain()` runs `shutil.rmtree(overlay_toolchain/python)`
  before attempting to download `python-build-standalone` (~30 MB) plus TinyCC
  and `musl` headers. In an offline AppImage (or on network failure), this
  leaves `build-release/overlay_toolchain/python/bin/python3` missing right
  before `psx_game_codegen_relaunch_or_exit` calls `execv` directly on the newly
  built binary. When online, it repeats an unnecessary download even when the
  packaged environment already provides `python3` + `tomli` and `zig cc`.
- **Local patch (upstream candidate):**
  [`0002-preserve-prestaged-overlay-toolchain.patch`](0002-preserve-prestaged-overlay-toolchain.patch),
  which, when `PSXRECOMP_PRESERVE_OVERLAY_TOOLCHAIN=1` is set (and
  `overlay_toolchain/python/bin/python3` + `compile_overlays.py` already exist),
  preserves the staged directory, updates `overlay_codegen_hash.h` if it
  points to a separate copy, and updates `compiler.txt` with the compiler
  resolved from `PATH`. Without that variable (e.g., `scripts/build_linux.sh`),
  framework behavior is unchanged.

---

## 9. Presentation-only vertical crop for 15-bit CRT overscan borders

- **Where:** `runtime/include/display_scanout.h`, `runtime/include/gpu.h`,
  `runtime/src/gpu.c`, `runtime/src/gpu_gl_renderer.c`,
  `runtime/src/gpu_vk_renderer.c`, `runtime/src/main.cpp`.
- **What happens:** on 15-bit modes, `gpu_get_display_info()` always exposes
  the full `DispEnv` rectangle and native-aspect presentation paths (`force_4_3`
  in OpenGL/Vulkan and `640x480` in software SDL) hardcode `4:3` regardless of
  cropped height. Titles that intentionally render only a centered band inside
  `DispEnv` (e.g., `512x216` at `y=12` inside `512x240`) keep top/bottom black
  borders inside `4:3`, and trimming `di.height` alone would vertically stretch
  `216` lines back into `4:3`.
- **Local patch (upstream candidate):**
  [`0003-display-present-crop.patch`](0003-display-present-crop.patch), which
  adds a generic presentation-only crop hook (`gpu_set_present_crop_callback`
  and `gpu_apply_present_crop`), derives the exact cropped presentation aspect
  (`psx_present_cropped_aspect`: `(4 * 240) / (3 * 216) = 40:27`) without altering
  `gpu_get_display_info()`, `depth24`, VRAM, savestates, or GTE projection, and
  threads packed per-frame aspect overrides (`psx_present_aspect_pack` /
  `psx_present_aspect_unpack`) through OpenGL (including render thread,
  interpolation, hold-last, frame-gen, and CPU fallback), Vulkan, and software
  SDL while keeping legacy `0`/`1` behavior unchanged when no hook is registered.
