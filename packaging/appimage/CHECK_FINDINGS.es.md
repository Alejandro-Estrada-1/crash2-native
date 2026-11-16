[English](CHECK_FINDINGS.md) | Español

# Hallazgos previos a `packaging/appimage/` y `release.yml` (`infra/appimage-check`)

Pruebas realizadas el 2026-11-15 sobre `main` (`55631b1`) con el parche `patches/psxrecomp/0001-crash-trace-date-time.patch`, Zig `0.17.1` (`Clang 22.1.8`, `-target x86_64-linux-gnu.2.28`), `CMake 3.31.6`, `Ninja 1.12.1` y un contenedor limpio `ubuntu:22.04` en Docker.

---

## 1. Build offline con `zig cc` sin dependencias opcionales (`psx-runtime` + `generated/*.c`)

- Tras preparar los archivos con `psxrecomp/tools/ci/vendor_deps.sh SDL3 psx_zlib psx_libwebp psx_libchdr` (`21 MiB` en `psxrecomp/third_party/`: `SDL3-3.4.10.tar.gz` `15M`, `libwebp` `3.7M`, `zlib-1.3.1.tar.gz` `1.5M`, `libchdr` `512K`, `libjuice` `108K`):
  - En Arch con `-DCMAKE_DISABLE_FIND_PACKAGE_SDL3=ON -DCMAKE_DISABLE_FIND_PACKAGE_OpenSSL=ON -DCMAKE_DISABLE_FIND_PACKAGE_Freetype=ON -DCMAKE_DISABLE_FIND_PACKAGE_PkgConfig=ON -DPSX_DEPS_OFFLINE=ON`: compilaron y enlazaron los `660` pasos de `crash2_native` (`137M` sin strip, `33M` tras `strip --strip-unneeded`, `libc++` estático, símbolo máximo `GLIBC_2.27`).
  - `NEEDED` observado sin desactivar `ZLIB`: `libz.so.1`, `libOpenGL.so.0`, `libm.so.6`, `libc.so.6`, `ld-linux-x86-64.so.2`, `libpthread.so.0`, `libdl.so.2`.
- Al añadir `-DCMAKE_DISABLE_FIND_PACKAGE_ZLIB=ON` (probado en `ubuntu:22.04` tanto en el runtime completo como en `--setup-host`), `psxrecomp` compila `zlib-1.3.1` estático (`libz.a`) y desaparece también `libz.so.1` de `NEEDED` (`ldd` del ejecutable `--setup-host`: `libGL.so.1`, `libm.so.6`, `libc.so.6`, `ld-linux-x86-64.so.2`, `libpthread.so.0`, `libdl.so.2`, sin `OpenSSL`, `Freetype`, `HarfBuzz` ni `zlib`).

---

## 2. Requisitos mínimos reales del host en `ubuntu:22.04` limpio

Al compilar desde fuente `SDL3` + `recomp_gl.cmake` dentro de `ubuntu:22.04` limpio con `zig cc`:

1. **`ar` / `ranlib` (`binutils`):** sin `ar` en el contenedor falla `SDL_DetectTargetCPUArchitectures` (`CMAKE_AR-NOTFOUND`). Se resuelve envolviendo `zig ar` y `zig ranlib` (`-DCMAKE_AR=...`, `-DCMAKE_RANLIB=...` o `ar`/`ranlib` en `PATH`), sin requerir `binutils` en el host.
2. **Multiarch Debian/Ubuntu (`find_library`):** `zig cc` no expone `/usr/lib/x86_64-linux-gnu` a CMake, de modo que aunque existan `/usr/include/{GL,X11,alsa}`, `find_library()` falla en `OPENGL_gl_LIBRARY`, `X11_X11_LIB` y `ALSA_LIBRARY`. Pasar `-DCMAKE_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu` corrige el descubrimiento.
3. **Cabeceras/enlaces `-dev` frente a `SDL_X11_SHARED=ON` / `SDL_ALSA_SHARED=ON`:**
   - Aunque en tiempo de ejecución `SDL3` carga `libX11.so.6` y `libasound.so.2` con `dlopen()`, en configuración de CMake falla si faltan X11/OpenGL (`SDL could not find X11 or Wayland development libraries`, `Could NOT find OpenGL`), y sin `libasound2-dev` desactiva ALSA dejando `Audio drivers: disk dummy`.
   - **Mínimo compilable medido:** `libgl-dev libx11-dev libxext-dev libasound2-dev` (`55` paquetes desde contenedor mínimo, `49.8 MB` descarga / `205 MB` en disco) + `-DSDL_X11_XCURSOR=OFF -DSDL_X11_XFIXES=OFF -DSDL_X11_XINPUT=OFF -DSDL_X11_XRANDR=OFF -DSDL_X11_XSCRNSAVER=OFF -DSDL_X11_XTEST=OFF -DSDL_X11_XSYNC=OFF` → compila y enlaza `psx-runtime` + `generated/*.c` (`676` pasos), y `--setup-host` (`116M` sin strip) arranca dentro de `ubuntu:22.04`.
   - **Con todas las sub-extensiones X11 de SDL3 activas** (`+ libxcursor-dev libxfixes-dev libxi-dev libxrandr-dev libxss-dev libxtst-dev`): pasa de `55` a `69` paquetes, **`50.3 MB` descarga / `207 MB` en disco** (`+0.5 MB` / `+2 MB` respecto al mínimo absoluto, conservando `xrandr`/`xinput2`/`xcursor`/`xfixes`).

---

## 3. Portabilidad de `zig`, `cmake`, `ninja` y compatibilidad de `psxrecomp_cli.py`

### Pesos medidos y compatibilidad ELF en `ubuntu:22.04`

| Componente (SHA-256 verificado) | Archivo origen | Sin comprimir | SquashFS (`xz`) | Requisitos en `ubuntu:22.04` |
|---|---|---:|---:|---|
| Zig `0.17.1` (`3581863e...9b17a`) | `55M` `.tar.xz` | `407M` | **`71M`** | Binario estático (`not a dynamic executable`) |
| CMake `3.31.6` recortado (`bin/cmake` + `share/`, sin `doc`/`man`/`gui`/`ccmake`/`cpack`/`ctest`) + Ninja `1.12.1` (`6f988056...30255`) | `53M` + `124K` | `38M` (`cmake` `17M`, `ninja` `268K`) | **`7.5M`** | `GLIBC_2.17` / `GLIBCXX_3.4.19`; corre directo |
| SDK (`psxrecomp` c/ `third_party` `21M` + `recomp-ui` + `src/` + `seeds/` + `patches/` + `psxrecomp-game` `2.1M` + `psxrecomp-bios` `1.8M`) | — | `~130M` | **`53M`** | `psxrecomp-game`/`bios` compilados en `ubuntu:22.04` con `zig` |

- `apt install cmake ninja-build` en `ubuntu:22.04` descarga `20.4 MB` (`74.7 MB` en disco) e instala CMake `3.22.1`. Incluir `cmake 3.31.6` recortado + `ninja 1.12.1` suma solo **`7.5 MiB`** al AppImage, garantiza versiones fijas y evita discrepancias por CMake antiguo.

### Hallazgos para `AppRun` / `CMakeLists.txt` / `release.yml`

1. **`host_system_toolchain_ready()` (`psxrecomp/host/psxrecomp_codegen_host.c:3091-3109`):** el asistente GUI en Linux verifica en `PATH` la presencia de `cmake`, `ninja`, `python3`/`python`, `cc`/`gcc`/`clang` y `c++`/`g++`/`clang++`. Con `zig` + `cmake` + `ninja` empaquetados y wrappers (`cc`/`clang`/`c++`/`clang++`/`ar`/`ranlib`), el único binario de compilación externo en el host es `python3` (presente por defecto en distros de escritorio).
2. **Python `3.10.12` (`ubuntu:22.04`) y montaje solo lectura:** `psxrecomp_cli.py`, `probe_disc.py`, `toolchain_pack.py`, `disc_companion.py` y `compile_overlays.py` pasan `ast.parse` en Python `3.10.12`. Sin embargo, `aot_static` (`psxrecomp_cli.py:1492`) y `compile_overlays.py` piden `tomllib` (Python `3.11+`) o `tomli`; además `AppRun` debe exportar `PYTHONDONTWRITEBYTECODE=1` al apuntar al `$APPDIR` de solo lectura.
3. **Configuración automática al recompilar desde el asistente:** `psxrecomp_cli.py rebuild` invoca `cmake` sin pasar `-DCMAKE_DISABLE_FIND_PACKAGE_*` ni `-DCMAKE_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu`. Nuestro `CMakeLists.txt` puede aplicar esos ajustes cuando el `AppRun` exporte una variable explícita (además de `PSX_DEPS_OFFLINE=1` que ya lee `psx_dependency_archive.cmake`).
