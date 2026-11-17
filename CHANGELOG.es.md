[English](CHANGELOG.md) | Español

# Registro de cambios

Todos los añadidos y correcciones relevantes de cada versión se documentan en inglés en [CHANGELOG.md](CHANGELOG.md) (con esta traducción al español). Cada release en GitHub publica las notas correspondientes en inglés.

## [Unreleased]

### Agregado
- Trabajo en curso de ingeniería inversa para Fase 6 (`re/experiments/009`) sobre fronteras de captura e señales de discontinuidad para interpolación sobre lógica a 30 Hz.

---

## [v0.1.0] - 2026-11-16

Primer hito ejecutable cubriendo las fases 0 a 5: port nativo en Linux a 30 FPS, ingeniería inversa *clean-room* del motor principal, recorte de overscan en presentación, mod opcional 16:9, verificación estricta de disco, CI en Ubuntu 22.04 y empaquetado AppImage x86_64 portable.

### Agregado
- Port nativo en Linux de *Crash Bandicoot 2: Cortex Strikes Back* (`SCUS-94154`, EUA) sobre `psxrecomp` + `recomp-ui` conservando la lógica a 30 Hz, lanzador gráfico, asistente de primer uso (`Generate & rebuild`, `src/codegen_setup.c`) y menú dentro del juego (`F10` / `Ctrl+L` / `Select+L3`, `src/menu_provider.c`).
- Ingeniería inversa independiente en modo *clean-room* en `re/` (`experiments/001` a `008`, `60` símbolos confirmados en `re/symbols.csv`, estructuras C verificadas en `re/structs.h`) y `803` semillas verificadas (`seeds/ghidra_funcs.txt`).
- Recorte vertical de presentación eliminando las franjas negras superior e inferior de 12 líneas (`DRAWENV` `512x216` con `y=12`, imagen `40:27` sin estirar en `4:3`, desactivable con `CRASH2NATIVE_NO_CROP=1` en `src/widescreen.c`).
- Mod precargado opcional `Widescreen (16:9)` (`crash2.enhancement.widescreen`) con apertura horizontal seleccionable (`Balanced 1.125x` por defecto, `Conservative 1.10x`, `Full 1.20x`), preservando la escala vertical `5/8` GTE y manteniendo en `4:3` OpenBIOS y los videos MDEC de 24 bits.
- Verificador Redump independiente en Rust (`tools/verify-disc`) sin dependencias externas validando tamaño y hashes de `SCUS-94154` (`192,814,608` bytes, CRC-32 `395c0916`, MD5 `3c31b5e038f025098a2fdfa70c8213f2`, SHA-1 `3d37fe4288a83b01f1a0edbf78e76e0fede6bc22`).
- AppImage portable `x86_64` compilado en `ubuntu:22.04` (objetivo glibc `>= 2.28`) con OpenBIOS, Zig `0.17.1`, CMake `3.31.6` recortado, Ninja `1.12.1`, emisores precompilados `psxrecomp-game` y `psxrecomp-bios`, dependencias offline vendorizadas (`SDL3`, `zlib`, `libwebp`, `libchdr`) y `tomli` `2.2.1`, guardando datos y compilaciones del usuario en `~/.local/share/crash2-native/`.
- CI en GitHub Actions sobre `ubuntu:22.04` (`.github/workflows/ci.yml`) y workflow de release AppImage por etiqueta (`.github/workflows/release.yml`) con `SHA256SUMS`.

### Corregido
- Limpieza de `$APPIMAGE` (tras conservar su ruta en `CRASH2NATIVE_APPIMAGE_PATH` y `RECOMP_APPIMAGE_PATH`) dentro de `packaging/appimage/AppRun` para que el lanzamiento directo del `.AppImage`, vía `--appimage-extract-and-run` o desde lanzadores de escritorio (como Gear Lever y rofi) resuelva `bios/openbios.bin`, `game.toml` y `saves/` dentro de `CRASH2NATIVE_DATA_DIR` en lugar de abortar con `Bundled BIOS Missing`.
- Corrección de `[Errno 30] Read-only file system` durante `Generate & rebuild` dentro del AppImage haciendo que `ensure_emitters()` respete `PSXRECOMP_GAME` / `PSXRECOMP_BIOS` preinstalados (`patches/psxrecomp/0005-use-prestaged-emitters-from-env.patch`), creando directorios escribibles `project/psxrecomp/bios` y `project/psxrecomp/generated` en `AppRun` (migrando enlaces previos) y preservando `overlay_toolchain/` (`patches/psxrecomp/0002-preserve-prestaged-overlay-toolchain.patch`).
- Normalización de `SOURCE_DATE_EPOCH` a segundos Unix decimales en `.github/workflows/release.yml` y al inicio de `packaging/appimage/build-appimage.sh` antes de invocar `zig cc`, corrigiendo marcas de tiempo ISO-8601 en etiquetas `push` que Zig/Clang rechazaban.
- Uso explícito de `defaults.run.shell: bash` en los workflows y reemplazo de `actions/setup-python` por `python3.11` nativo de `ubuntu:22.04` en `ci.yml` evitando fallos con `dash` y `GLIBC_2.38`.
- Parches al framework `0001-crash-trace-date-time.patch` (portabilidad con Zig C), `0003-display-present-crop.patch` (hook de recorte `DRAWENV` `512x216`) y `0004-widescreen-projection-aspect.patch` (callback de proyección widescreen en vivo).

[Unreleased]: https://github.com/Alejandro-Estrada-1/crash2-native/compare/v0.1.0...HEAD
[v0.1.0]: https://github.com/Alejandro-Estrada-1/crash2-native/releases/tag/v0.1.0
