[English](UPSTREAM.md) | Español

# Candidatos a reportar o parchear en psxrecomp (upstream)

Problemas del framework observados en este port. Cada entrada dice qué se vio,
dónde y con qué evidencia. Cuando un problema lleva parche local, el `.patch`
va en este directorio (lo aplica `scripts/setup.sh`) y se enlaza aquí.

Framework: `psxrecomp` en `b263b855` (master del 2026-11-10).
Entorno: Arch Linux, GCC 16.2.1, Clang 23.1.4, Python 3.14.

---

## 1. `realpath` / `lstat` sin declarar con `-std=c11` (GCC ≥ 14)

- **Dónde:** `host/psxrecomp_codegen_host.c` (setup host del asistente de primer uso).
  Usa `realpath` (líneas 354, 969, 971, 2321, 2718-2719, 4411-4412) y `lstat` (2804)
  sin definir una macro de características (`_DEFAULT_SOURCE`, `_XOPEN_SOURCE 700`...).
- **Qué pasa:** con `-std=c11` estricto, glibc no declara esas funciones. GCC 14+
  convierte la declaración implícita y `-Wint-conversion` en errores:
  `la inicialización de 'char *' desde 'int' crea un puntero desde un entero`.
- **Dónde se ve:** la prueba `codegen_host_bios_stems`
  (`runtime/tests/test_codegen_host_bios_stems.py`, compila con `cc -std=c11`).
- **¿Nos afecta?** No. Comprobado el 2026-11-15 con `-fsyntax-only` sobre el archivo:
  0 errores con `-std=gnu11` en GCC 16 y Clang 23, contra 12 y 20 con `-std=c11`.
  Nuestra compilación no pasa ningún `-std=` (`build-release/build.ninja`), así que usa
  el dialecto GNU por defecto del compilador. Solo falla la prueba upstream, que fuerza
  `-std=c11`. No hace falta parche local.
- **Arreglo propuesto:** `#define _DEFAULT_SOURCE` (o `_XOPEN_SOURCE 700`) antes de
  los `#include` del archivo. Genérico, candidato a upstream.

## 2. Fragmentos de overlay: datos decodificados como código ("unsupported")

- **Qué se vio:** en la primera corrida, 19 fragmentos de overlay no compilaron con
  `generated-c-audit: 0 unknown_bad, N unsupported`, y uno más con
  `delay-slot-identity: ... reserved/unsupported branch encoding`. Se quedan en el
  intérprete: el juego funciona, más lento.
- **Reproducción sin ventana:** `tools/compile_overlays.py --check --only-region`
  sobre las capturas de esas regiones. Mismo resultado.
- **Qué palabras son:** los opcodes "no manejados" no existen en el R3000A de la PS1,
  y las páginas mezclan código con datos (`ffffffff`, `fffffffd`, `fffce000`...).
  No falta soporte de instrucciones; el recorrido del fragmento entra a datos.

  | Región (captura) | Fragmentos fallidos | Palabras (dirección: valor, opcode primario) |
  |---|---|---|
  | `0x800F5000` (0x1000) | `0x800F5EF4`, `…5F20`, `…5F44`, `…5F84` (1 c/u) | `0x800F5FE8: 46404281` COP1 (0x11) |
  | `0x80191000` (0x2000) | `0x80192954`, `…299C`, `…2A88` (29 c/u) | en la página hay 51 palabras con opcodes inexistentes en R3000A (0x18 DADDI ×23, 0x3B SWC3 ×9, 0x11 COP1 ×3, 0x3C ×3, 0x3F SD ×2…), p. ej. `0x80191084: 5c07000e`, `0x801910B8: ffffffff` |
  | `0x80195000` (0x3000) | 13 fragmentos (1, 2 u 8 c/u) | `0x80195F1C: 4cb03e1f` COP3, `0x80195F44: 4de25800` COP3 |
  | `0x80195000` | `0x8019526C` (branch reservado) | `0x80195278: 411be0d1` = `BC0x` (salto condicional de COP0) en un delay slot |

- **Limitación:** `compile_overlays.py` borra el C temporal, así que no se puede
  asignar cada palabra a su fragmento con certeza. La tabla toma la ventana entre la
  primera entrada fallida y 0x200 bytes después de la última.
- **Para el reporte:** pedir que el recorrido de fragmentos se detenga ante opcodes
  que no existen en R3000A (o los trate como límite de función), en lugar de
  descartar el fragmento entero. Y una opción para conservar el C temporal al
  diagnosticar.

## 3. Aviso engañoso de autocompilación de overlays

- **Mensaje:** `WARNING: overlay autocompile has failed 3 consecutive runs (last exit 2).
  Nothing is being compiled to native code ... Check [runtime] overlay_autocompile_cmd`.
- **Realidad:** la misma pasada compiló 64 fragmentos y la caché tenía 272 `.so`. El
  código de salida 2 significa "algunos fragmentos fallaron" (ver punto 2), no que la
  autocompilación esté mal configurada.
- **Para el reporte:** distinguir "fallo parcial" de "no se compiló nada" en el aviso.

## 4. El asistente no pasa `--no-toolchain-download` (solo afecta a Windows)

- **Dónde:** `host/psxrecomp_codegen_host.c` llama a `psxrecomp_cli.py generate` y
  `rebuild` sin `--no-toolchain-download`.
- **En Linux y macOS no descarga nada:** `ensure_toolchain()` en
  `tools/toolchain_pack.py` usa `cmake`, `ninja`, `python3` y el compilador del PATH, y
  si falta alguno lanza "Native build tools are missing". Comprobado con una prueba que
  bloquea `urllib` (se había planeado un parche `PSXRECOMP_NO_TOOLCHAIN_DOWNLOAD` y se
  descartó: no tendría efecto en Linux).
- **En Windows** sí descarga el paquete `releases/latest` de
  `RetroPortingToolKit/RetroPorting-Toolchains`, sin versión fija ni hash.
- **Para el reporte (si algún día hay build de Windows):** fijar la versión del paquete
  y verificar su SHA-256, o permitir que el título desactive la descarga.
- **Consecuencia para nuestra Fase 4:** el AppImage tiene que traer (o pedir) cmake,
  ninja, python3 y un compilador; el asistente no los consigue solo.

## 5. `ctest` del recompilador: 15 de 164 pruebas fallan en `b263b855`

Compilado fuera del árbol (`build-recompiler/`). Casi todas parecen pruebas
desfasadas del código, no fallos del entorno:

- Inspeccionan el fuente y ya no coinciden: `mod_owned_display_controls`,
  `frame_interpolation_flip_source`, `gl_internal_scale_guards`,
  `native_wide_line_batching`, `overlay_candidate_capacity`, `bundled_release_layout`.
- Arneses que no enlazan (símbolos sin definir: `host_span_end`,
  `psx_mod_function_entry_has_hook`, `psx_mod_memory_address`...):
  `overlay_segment_keys`, `overlay_segment_gate`, `interp_refused_game_text`.
- Necesitan un runtime ya compilado (`overlay_codegen_hash.h` en 0, "STALE RECOMPILER
  BINARY"): `bios_module_build`, `compile_overlays_static_tail`.
- Otras: `ws_cull_screen_x_hi_codegen_test` ("unlisted lui stays vanilla"; el commit
  fijado toca la emisión de LUI), `aot_overlay_discovery` (`assert total == 2`),
  `interp_cop0_read_sample` (aborta a `-O0`, rc=-6), `codegen_host_bios_stems` (punto 1).

Antes de reportar: repetir en el pin de Hércules (`2a4824f`) para ver cuáles son
regresiones recientes. `docs/BUILDING.md` todavía dice "38 tests".

## 6. Rangos `install_slots` de BIOS de Sony medidos solo con PsyQ 3.70

- **Dónde:** `bios/SCPH1001.toml` (y `SCPH5500.toml` / `SCPH5501.toml`) declaran el
  rango del pad `ram_addr = 0x4964`, `len = 0x2C` ("RemovePatchPad / ChgclrPAD
  family"), medido con Breath of Fire III (SLPS-00990, PsyQ 3.70). Los propios
  perfiles dicen "Re-measure per SDK version before trusting the numbers".
- **Qué falta:** según el agente de ingeniería inversa, el `_patch_pad` de PsyQ 4.0
  (el que usa Crash 2) parchea además `base+0x3D8`, `+0x4E0` y `+0x62C`. **Sin
  verificar:** no tenemos BIOS de Sony, y no está comprobado respecto a qué base se
  miden.
- **Efecto esperado si faltan:** esos cuerpos del kernel no pasan la comparación con
  la ROM y se interpretan siempre ("Undeclared means that body keeps interpreting"):
  más lento, no incorrecto.
- **No afecta a OpenBIOS:** OpenBIOS desactiva esos parches en el código del juego.
  `getB0table` (`0xBFC05BB0`) llama a `patch_hook(a0 = $ra del llamador)`
  (`0xBFC07E84`), que escribe `nop; nop` en `$ra` y el `*_execute` correspondiente
  pone `b +N; nop` en `$ra+8`. En Crash 2 esto explica las tres funciones del juego
  reescritas en RAM (`_patch_pad` 0x8004A2EC → `patch_pad_2_execute`, `b +10`;
  `_send_pad` 0x8004A38C → `send_pad_2_execute`, `b +12`; `_remove_ChgclrPAD`
  0x8004A424 → `remove_ChgclrPAD_2_execute`, `b +5`). Evidencia: desensamblado de
  los comentarios de `generated/OpenBIOS_full.c` y símbolos ELF de
  `recompiler/seeds/openbios_elf_seeds.json` (pcsx-redux `55fbf04`).
- **Para el reporte:** pedir que se midan los rangos con PsyQ 4.0 o que se declare la
  unión de versiones, como permite el esquema.

## 7. Compilación con `zig cc -target x86_64-linux-gnu.2.28` (validación para AppImage)

Probado el 2026-11-15 con Zig `0.17.1` (Clang `22.1.8`) sobre el runtime de
`psxrecomp` (`b263b855`), `recomp-ui` (`3c641560`), `src/`, los 29 archivos en
`generated/` (`SCUS_941.54_dispatch.c` y `SCUS_941.54_full_00..27.c`) y los
emisores en `psxrecomp/recompiler`.

- **Resultado general:** sí compilan y enlazan el runtime completo (`crash2_native`,
  139 MiB), la variante `--setup-host` (`-DPSXRECOMP_FORCE_SETUP_HOST=ON`) y los
  emisores (`psxrecomp-game` y `psxrecomp-bios`, probados con
  `-DPSXRECOMP_ENABLE_CHD=OFF`). `libc++` queda enlazado estáticamente y la versión
  máxima de símbolo en `readelf -V` fue `GLIBC_2.27` en `crash2_native` (`GLIBC_2.16`
  en `psxrecomp-game`).
- **Fallo de compilación — `runtime/src/crash_trace.c` (`-Werror,-Wdate-time`):**
  las líneas 59 y 61 usan `__DATE__` y `__TIME__`. Zig 0.17.1 activa `-Werror=date-time`
  por defecto y aborta la compilación (`expansion of date or time macro is not reproducible`).
  - **Parche local (candidato a upstream):** [`0001-crash-trace-date-time.patch`](0001-crash-trace-date-time.patch),
    que envuelve `kBuildId` con `#pragma GCC diagnostic push / ignored "-Wdate-time" / pop`
    bajo `#if defined(__clang__) || defined(__GNUC__)`. Verificado con `zig cc` (0.17.1),
    `clang -Wdate-time -Werror` y `gcc -std=gnu11 -Wdate-time -Werror`.
- **Fallo de configuración CMake cuando el host tiene SDL3 — `runtime/runtime.cmake:265-284`:**
  si el sistema anfitrión tiene `/usr/lib/cmake/SDL3` (Arch Linux, etc.),
  `find_package(SDL3)` lo detecta y `_psx_header_compiles("SDL3/SDL.h")` falla porque
  `zig cc` usa su propio sysroot en lugar de `/usr/include` y CMake omite `-I/usr/include`.
  En lugar de recurrir a `PSX_SDL3_FETCH=ON`, `runtime.cmake:271` aborta con `FATAL_ERROR`.
  - **Sin parche en `runtime.cmake` (intencional para `cmake-clang-v1`):** al invocar
    CMake con `zig cc`, pasar `-DCMAKE_DISABLE_FIND_PACKAGE_SDL3=ON` fuerza el fallback a
    `FetchContent` (`SDL3 3.4.10` estático).
- **Dependencias del anfitrión enlazadas si no se desactivan (`ldd` / `readelf -d`):**
  en el build completo en Arch, CMake enlazó `libcrypto.so.4` (`OpenSSL`),
  `libfreetype.so.6` (`Freetype`) y `libharfbuzz.so.0` (`PkgConfig` + `harfbuzz`), lo
  que rompería portabilidad entre distros (p. ej. Ubuntu 22.04 usa `libcrypto.so.3`).
  Probado `--setup-host` con `-DCMAKE_DISABLE_FIND_PACKAGE_SDL3=ON`,
  `-DCMAKE_DISABLE_FIND_PACKAGE_ZLIB=ON`, `-DCMAKE_DISABLE_FIND_PACKAGE_OpenSSL=ON` y
  `-DCMAKE_DISABLE_FIND_PACKAGE_PkgConfig=ON`: `psx_sha256_file.cpp` usa la ruta
  portable sin `libcrypto`, `zlib` compila estático vía `FetchContent`, y solo quedan
  `NEEDED` `libfreetype.so.6` (opcional en `recomp-ui`; también desactivable),
  `libOpenGL.so.0`, `libm.so.6`, `libc.so.6`, `ld-linux-x86-64.so.2`, `libpthread.so.0`
  y `libdl.so.2`. Sin `PkgConfig`, SDL3 desactiva Wayland/Pulse/PipeWire y mantiene
  `x11(dynamic)` + `alsa(dynamic)`. `FindOpenGL` sigue requiriendo biblioteca y
  cabecera GL del sistema (`libglvnd` / `libgl-dev`) salvo que el entorno empaquetado
  aporte cabeceras GL.

---

## 8. `stage_overlay_toolchain_for_product()` borra `overlay_toolchain/python` e intenta descargar aunque el empaquetador ya lo preparó

- **Dónde:** `psxrecomp_cli.py` (`stage_overlay_toolchain_for_product` → `tools/release_stage.py`, `stage_toolchain`).
- **Qué pasa:** al terminar `psxrecomp_cli.py rebuild` tras la primera compilación del usuario,
  `stage_toolchain()` ejecuta `shutil.rmtree(overlay_toolchain/python)` antes de intentar descargar
  `python-build-standalone` (~30 MB) y TinyCC + cabeceras `musl`. En un AppImage offline (o tras un
  fallo de red), deja `build-release/overlay_toolchain/python/bin/python3` borrado justo antes de que
  `psx_game_codegen_relaunch_or_exit` haga `execv` directo al binario recién compilado. Con conexión,
  repite una descarga innecesaria cuando el entorno empaquetado ya aporta `python3` + `tomli` y `zig cc`.
- **Parche local (candidato a upstream):**
  [`0002-preserve-prestaged-overlay-toolchain.patch`](0002-preserve-prestaged-overlay-toolchain.patch),
  que ante `PSXRECOMP_PRESERVE_OVERLAY_TOOLCHAIN=1` (cuando ya existen
  `overlay_toolchain/python/bin/python3` y `compile_overlays.py`) conserva el directorio ya montado,
  actualiza `overlay_codegen_hash.h` si apunta a una copia distinta y reescribe `compiler.txt` con el
  compilador resuelto en `PATH`. Sin esa variable (p. ej. `scripts/build_linux.sh`), el comportamiento
  del framework no cambia.
