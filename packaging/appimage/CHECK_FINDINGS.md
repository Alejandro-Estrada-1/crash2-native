English | [Español](CHECK_FINDINGS.es.md)

# Pre-Implementation Findings for `packaging/appimage/` and `release.yml` (`infra/appimage-check`)

Tests run on 2026-11-15 against `main` (`55631b1`) with
`patches/psxrecomp/0001-crash-trace-date-time.patch`, Zig `0.17.1`
(`Clang 22.1.8`, `-target x86_64-linux-gnu.2.28`), `CMake 3.31.6`,
`Ninja 1.12.1`, and a clean `ubuntu:22.04` Docker container.

---

## 1. Offline Build with `zig cc` Without Optional Dependencies (`psx-runtime` + `generated/*.c`)

- After staging source archives with `psxrecomp/tools/ci/vendor_deps.sh SDL3 psx_zlib psx_libwebp psx_libchdr` (`21 MiB` in `psxrecomp/third_party/`: `SDL3-3.4.10.tar.gz` `15M`, `libwebp` `3.7M`, `zlib-1.3.1.tar.gz` `1.5M`, `libchdr` `512K`, `libjuice` `108K`):
  - On Arch with `-DCMAKE_DISABLE_FIND_PACKAGE_SDL3=ON -DCMAKE_DISABLE_FIND_PACKAGE_OpenSSL=ON -DCMAKE_DISABLE_FIND_PACKAGE_Freetype=ON -DCMAKE_DISABLE_FIND_PACKAGE_PkgConfig=ON -DPSX_DEPS_OFFLINE=ON`: all `660` build steps of `crash2_native` compiled and linked (`137M` unstripped, `33M` after `strip --strip-unneeded`, static `libc++`, highest symbol version `GLIBC_2.27`).
  - `NEEDED` libraries observed without disabling `ZLIB`: `libz.so.1`, `libOpenGL.so.0`, `libm.so.6`, `libc.so.6`, `ld-linux-x86-64.so.2`, `libpthread.so.0`, `libdl.so.2`.
- Adding `-DCMAKE_DISABLE_FIND_PACKAGE_ZLIB=ON` (tested in `ubuntu:22.04` on both the full runtime and `--setup-host`) makes `psxrecomp` build static `zlib-1.3.1` (`libz.a`), eliminating `libz.so.1` from `NEEDED` (`ldd` of the `--setup-host` binary: `libGL.so.1`, `libm.so.6`, `libc.so.6`, `ld-linux-x86-64.so.2`, `libpthread.so.0`, `libdl.so.2`; no `OpenSSL`, `Freetype`, `HarfBuzz`, or `zlib`).

---

## 2. Actual Minimum Host Requirements on Clean `ubuntu:22.04`

When compiling `SDL3` + `recomp_gl.cmake` from source inside clean `ubuntu:22.04` using `zig cc`:

1. **`ar` / `ranlib` (`binutils`):** without `ar` in the container, `SDL_DetectTargetCPUArchitectures` fails (`CMAKE_AR-NOTFOUND`). Solved by wrapping `zig ar` and `zig ranlib` (`-DCMAKE_AR=...`, `-DCMAKE_RANLIB=...`, or `ar`/`ranlib` on `PATH`), requiring no host `binutils`.
2. **Debian/Ubuntu multiarch (`find_library`):** `zig cc` does not expose `/usr/lib/x86_64-linux-gnu` to CMake, so even when `/usr/include/{GL,X11,alsa}` exist, `find_library()` fails on `OPENGL_gl_LIBRARY`, `X11_X11_LIB`, and `ALSA_LIBRARY`. Passing `-DCMAKE_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu` fixes discovery.
3. **`-dev` headers/symlinks vs. `SDL_X11_SHARED=ON` / `SDL_ALSA_SHARED=ON`:**
   - Although `SDL3` loads `libX11.so.6` and `libasound.so.2` via `dlopen()` at runtime, CMake configure fails if X11/OpenGL dev packages are absent (`SDL could not find X11 or Wayland development libraries`, `Could NOT find OpenGL`), and without `libasound2-dev` it disables ALSA (`Audio drivers: disk dummy`).
   - **Measured minimal buildable set:** `libgl-dev libx11-dev libxext-dev libasound2-dev` (`55` packages from a bare container, `49.8 MB` download / `205 MB` on disk) + `-DSDL_X11_XCURSOR=OFF -DSDL_X11_XFIXES=OFF -DSDL_X11_XINPUT=OFF -DSDL_X11_XRANDR=OFF -DSDL_X11_XSCRNSAVER=OFF -DSDL_X11_XTEST=OFF -DSDL_X11_XSYNC=OFF` -> compiles and links `psx-runtime` + `generated/*.c` (`676` steps), and `--setup-host` (`116M` unstripped) starts inside `ubuntu:22.04`.
   - **With all SDL3 X11 sub-extensions enabled** (`+ libxcursor-dev libxfixes-dev libxi-dev libxrandr-dev libxss-dev libxtst-dev`): increases from `55` to `69` packages, **`50.3 MB` download / `207 MB` on disk** (`+0.5 MB` / `+2 MB` over the bare minimum while keeping `xrandr`/`xinput2`/`xcursor`/`xfixes`).

---

## 3. Portability of `zig`, `cmake`, `ninja`, and `psxrecomp_cli.py` Compatibility

### Measured Footprint and ELF Compatibility on `ubuntu:22.04`

| Component (SHA-256 verified) | Source archive | Uncompressed | SquashFS (`xz`) | `ubuntu:22.04` requirements |
|---|---|---:|---:|---|
| Zig `0.17.1` (`3581863e...9b17a`) | `55M` `.tar.xz` | `407M` | **`71M`** | Static binary (`not a dynamic executable`) |
| Trimmed CMake `3.31.6` (`bin/cmake` + `share/`, excluding `doc`/`man`/`gui`/`ccmake`/`cpack`/`ctest`) + Ninja `1.12.1` (`6f988056...30255`) | `53M` + `124K` | `38M` (`cmake` `17M`, `ninja` `268K`) | **`7.5M`** | `GLIBC_2.17` / `GLIBCXX_3.4.19`; runs directly |
| SDK (`psxrecomp` w/ `third_party` `21M` + `recomp-ui` + `src/` + `seeds/` + `patches/` + `psxrecomp-game` `2.1M` + `psxrecomp-bios` `1.8M`) | — | `~130M` | **`53M`** | `psxrecomp-game`/`bios` built in `ubuntu:22.04` with `zig` |

- `apt install cmake ninja-build` on `ubuntu:22.04` downloads `20.4 MB` (`74.7 MB` on disk) and installs CMake `3.22.1`. Bundling trimmed `cmake 3.31.6` + `ninja 1.12.1` adds only **`7.5 MiB`** to the AppImage, pins versions, and avoids issues from older distro CMake releases.

### Findings for `AppRun` / `CMakeLists.txt` / `release.yml`

1. **`host_system_toolchain_ready()` (`psxrecomp/host/psxrecomp_codegen_host.c:3091-3109`):** the Linux setup GUI checks `PATH` for `cmake`, `ninja`, `python3`/`python`, `cc`/`gcc`/`clang`, and `c++`/`g++`/`clang++`. With bundled `zig` + `cmake` + `ninja` and wrappers (`cc`/`clang`/`c++`/`clang++`/`ar`/`ranlib`), the only external build binary needed on the host is `python3` (installed by default on desktop distros).
2. **Python `3.10.12` (`ubuntu:22.04`) and read-only mount:** `psxrecomp_cli.py`, `probe_disc.py`, `toolchain_pack.py`, `disc_companion.py`, and `compile_overlays.py` pass `ast.parse` on Python `3.10.12`. However, `aot_static` (`psxrecomp_cli.py:1492`) and `compile_overlays.py` require `tomllib` (Python `3.11+`) or `tomli`; `AppRun` must also export `PYTHONDONTWRITEBYTECODE=1` when pointing into read-only `$APPDIR`.
3. **Automatic CMake setup during wizard rebuild:** `psxrecomp_cli.py rebuild` invokes `cmake` without passing `-DCMAKE_DISABLE_FIND_PACKAGE_*` or `-DCMAKE_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu`. Our `CMakeLists.txt` can apply those settings whenever `AppRun` exports an explicit environment variable (in addition to `PSX_DEPS_OFFLINE=1`, already honored by `psx_dependency_archive.cmake`).
