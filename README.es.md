[English](README.md) | Español

# crash2-native

[![Última release](https://img.shields.io/github/v/release/Alejandro-Estrada-1/crash2-native?label=Release)](https://github.com/Alejandro-Estrada-1/crash2-native/releases)
![Plataforma: Linux x86_64 | AppImage](https://img.shields.io/badge/Platform-Linux%20x86__64%20%7C%20AppImage-blue)
[![Último commit](https://img.shields.io/github/last-commit/Alejandro-Estrada-1/crash2-native?label=Last%20Commit)](https://github.com/Alejandro-Estrada-1/crash2-native/commits/main)

Port nativo para Linux de *Crash Bandicoot 2: Cortex Strikes Back* (PS1, EUA, `SCUS-94154`) construido sobre **[psxrecomp](https://github.com/mstan/psxrecomp)** y **[recomp-ui](https://github.com/mstan/recomp-ui)**, con ingeniería inversa propia en modo *clean-room*.

> [!IMPORTANT]
> **No incluye datos del juego ni BIOS de Sony.** Este repositorio y sus releases AppImage no contienen imágenes de disco (`.bin`, `.cue`, `.chd`, `.iso`), ejecutables extraídos ni activos protegidos. Debes aportar tu propia copia legítima de EUA de *Crash Bandicoot 2* (`SCUS-94154`), verificada estrictamente contra los hashes de Redump (`CRC-32: 395c0916`, `MD5: 3c31b5e038f025098a2fdfa70c8213f2`, `SHA-1: 3d37fe4288a83b01f1a0edbf78e76e0fede6bc22`, `192,814,608` bytes).

> [!WARNING]
> **En desarrollo activo y uso estrictamente no comercial.** Las fases 0 a 5 (base de compilación, ingeniería inversa *clean-room* de tiempo/cámara/entidades, `verify-disc`, CI, empaquetado AppImage, recorte `512x216` y mod `16:9`) están completas en local; siguen interpolación de FPS altos (Fase 6) y pruebas de regresión deterministas (Fase 7). Todo binario enlazado con `psxrecomp` queda regido por **PolyForm Noncommercial License 1.0.0**.

> [!NOTE]
> **Hecho con apoyo de IA y verificado por una persona.** El código del port, la infraestructura y las notas de ingeniería inversa se producen con agentes de IA bajo revisión humana, siguiendo las reglas *clean-room* de [`AGENTS.es.md`](AGENTS.es.md). Nada se publica solo porque un agente lo afirme: únicamente el responsable promueve un símbolo, y solo tras confirmarlo en el emulador. Ver [Desarrollo asistido por IA](#desarrollo-asistido-por-ia).

---

## Objetivos y diseño técnico

- **Port nativo para Linux:** usa `psxrecomp` + `recomp-ui` con lanzador nativo en OpenGL, menú dentro del juego (`F10` / `Ctrl+L` / `Select+L3`) y asistente de primer uso (`Generate & rebuild`).
- **Ingeniería inversa *clean-room*:** todos los nombres de funciones, direcciones y estructuras en [re/symbols.csv](re/symbols.csv), [re/structs.h](re/structs.h) y [re/NOTES.es.md](re/NOTES.es.md) se observaron de forma independiente en `SCUS_941.54` con Ghidra (`ghidra_psx_ldr`) y se verificaron dinámicamente en PCSX-Redux (`re/experiments/001` a `008`).
- **Verificación estricta del disco:** tanto `psxrecomp` como la herramienta independiente en Rust [tools/verify-disc](tools/verify-disc/README.es.md) rechazan imágenes que no coincidan antes de generar código.
- **AppImage portable con compilación en destino:** incluye el asistente (`setup-host`), emisores precompilados (`psxrecomp-game`, `psxrecomp-bios`), dependencias offline vendorizadas (`SDL3`, `zlib`, `libwebp`, `libchdr`), Zig `0.17.1` (`-target x86_64-linux-gnu.2.28`), CMake `3.31.6` recortado, Ninja `1.12.1` y `tomli` (compatibilidad con Python 3.10 al compilar bloques MIPS de GOOL en tiempo de ejecución).
- **Mejoras planificadas (Fases 5–7):**
  - **Pantalla ancha:** recortar las franjas negras superior e inferior de 12 líneas (`DRAWENV` `512x216` con `y=12`) y ampliar el encuadre horizontal preservando la escala vertical `5/8` (`512/320`) confirmada en las tres rutas GTE del juego.
  - **FPS altos por interpolación:** mantener la lógica a 30 Hz originales (`RCntCNT2` / `quantize_frame_ticks`) e interpolar cámara y entidades `GoolObject` activas recorridas desde las 8 cubetas raíz (`gool_root_buckets`), verificando identidad bit a bit mediante [tools/regress](tools/regress/README.es.md).

---

## Estado del proyecto

Consulta [docs/ROADMAP.es.md](docs/ROADMAP.es.md) para ver el detalle completo de fases y decisiones.

| Fase | Hito | Estado |
|---|---|---|
| 0–2 | Estructura del repo, integración de `psxrecomp` + `recomp-ui`, configuración Redump y compilación a 30 FPS en Linux | Completa |
| 3 | Ingeniería inversa *clean-room* (`001`–`008`): reloj, paginación NSD/NSF, bloques MIPS en GOOL, cámara, escala `5/8`, `GoolObject`, `PadState`, `RNG`, 60 símbolos confirmados, `re/structs.h` y 803 semillas | Completa |
| 4 | `tools/verify-disc` (Rust), `LICENSE`/`NOTICE`, CI en `ubuntu:22.04`, AppImage autocontenido + `release.yml` | Completa en local (validación en GitHub Actions pendiente de desbloqueo de cuenta) |
| 5 | Pantalla ancha: recorte `512x216` (`40:27`) + mod `Widescreen (16:9)` (apertura `1.125x`/`1.10x`/`1.20x`) preservando escala `5/8` | Completa |
| 6–7 | Interpolación de cuadros (60/120/144 Hz), pruebas en `tools/regress` y release público | Planificada |

---

## Uso del AppImage

Descarga el `.AppImage` y `SHA256SUMS` desde Releases, verifica el hash y dale permisos de ejecución:

```bash
sha256sum -c SHA256SUMS
chmod +x crash2-native-*-x86_64.AppImage
```

> [!NOTE]
> El AppImage incluye Zig, CMake, Ninja, emisores precompilados y archivos offline de dependencias, y nunca empaqueta bibliotecas gráficas del sistema (`libGL`, `libOpenGL`, `libGLX`, `libdrm`). Solo necesita **Python 3** y las cabeceras mínimas de **OpenGL / X11 / ALSA** en tu sistema para enlazar SDL3 y OpenGL contra tus drivers nativos en la primera compilación.

Comprueba los requisitos previos o valida tu imagen antes de abrir el asistente:

```bash
./crash2-native-*-x86_64.AppImage --check-prereqs
./crash2-native-*-x86_64.AppImage --verify-disc --disc "/ruta/a/Crash Bandicoot 2 - Cortex Strikes Back (USA).cue"
./crash2-native-*-x86_64.AppImage
```

En la primera ejecución, el asistente extrae `SCUS_941.54`, genera el código C y compila el binario nativo dentro de `~/.local/share/crash2-native/` (configurable con `CRASH2NATIVE_DATA_DIR`). Opciones y variables útiles:

- `--setup`: vuelve a abrir el asistente de generación/compilación aunque ya exista un binario compilado.
- `CRASH2NATIVE_DISC=/ruta/al/disco.cue`: preselecciona la ruta al disco en `game.toml`.
- `CRASH2NATIVE_USE_SYSTEM_CC=1`: usa `cc`/`c++`/`cmake`/`ninja` del sistema en lugar del Zig empaquetado.

Si `--check-prereqs` indica paquetes faltantes, instálalos según tu distribución:

- **Ubuntu / Debian:**
  ```bash
  sudo apt update && sudo apt install -y \
    python3 libgl-dev libx11-dev libxext-dev libxcursor-dev libxfixes-dev \
    libxi-dev libxrandr-dev libxss-dev libxtst-dev libasound2-dev
  ```
- **Arch Linux / derivadas:**
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

## Compilación desde código fuente (Linux)

1. Clona el repositorio con submódulos y verifica herramientas + imagen de disco (`disc/` debe apuntar a tu `.bin` + `.cue` de Redump):
   ```bash
   git clone --recursive https://github.com/Alejandro-Estrada-1/crash2-native.git
   cd crash2-native
   ./scripts/setup.sh
   ```
   *(Usa `./scripts/setup.sh --sin-disco` para preparar el entorno sin disco o en CI.)*

2. Genera el C desde el disco y compila el runtime nativo:
   ```bash
   ./scripts/build_linux.sh -j 4
   ```
   *(Usa `--sin-generar` para recompilar cambios en C/C++ sin regenerar, `--sin-ui` para compilar sin `recomp-ui`, o `--setup-host` para compilar solo el asistente sin disco.)*

3. Ejecuta las pruebas unitarias del verificador de disco (sin disco del juego):
   ```bash
   cargo test --manifest-path tools/verify-disc/Cargo.toml
   ```

4. Opcional: generar el AppImage en local sobre Ubuntu 22.04:
   ```bash
   ./packaging/appimage/build-appimage.sh --jobs 4
   ```

---

## Estructura y documentación

| Ruta | Descripción | Documentación |
|---|---|---|
| `src/` | Asistente de código, proveedor de menú en `recomp-ui` y hooks de pantalla ancha | — |
| `mods/preloaded/` | Paquetes de mods precargados del título (p. ej., `Widescreen (16:9)` con opciones de FOV `1.125x`/`1.10x`/`1.20x`) | — |
| `re/` | Símbolos confirmados (`symbols.csv`), estructuras (`structs.h`), bitácora y experimentos GDB/Lua | [re/NOTES.es.md](re/NOTES.es.md) |
| `seeds/` | Direcciones de inicio de funciones verificadas para recompilación estática (`ghidra_funcs.txt`) | — |
| `patches/psxrecomp/` | Parches mínimos al framework y notas para upstream | [UPSTREAM.es.md](patches/psxrecomp/UPSTREAM.es.md) |
| `tools/verify-disc/` | Verificador Redump en Rust sin dependencias externas | [README.es.md](tools/verify-disc/README.es.md) |
| `tools/regress/` | Verificador planificado de regresión sobre estado lógico | [README.es.md](tools/regress/README.es.md) |
| `packaging/appimage/` | Empaquetado AppImage, `AppRun`, archivo `.desktop` y hallazgos en Ubuntu 22.04 | [CHECK_FINDINGS.es.md](packaging/appimage/CHECK_FINDINGS.es.md) |
| `scripts/` | Scripts de entorno, compilación en Linux, wrapper GDB para PCSX-Redux y respaldo de partidas | — |
| `docs/` | Decisiones de arquitectura, referencia Redump y hoja de ruta | [ROADMAP.es.md](docs/ROADMAP.es.md) |
| `AGENTS.md`, `CLAUDE.md`, `GEMINI.md` | Reglas de trabajo para personas y agentes de IA: política *clean-room*, alcance por rol y ciclo obligatorio de verificación | [AGENTS.es.md](AGENTS.es.md) |

---

## Desarrollo asistido por IA

Este proyecto lo desarrolla un responsable humano trabajando con agentes de IA. Se dice abiertamente a propósito: es parte del método, no algo que ocultar.

- **Infraestructura** (scripts de compilación, CI, empaquetado, herramientas en Rust y el código del port en `src/`): la escribe un agente de IA bajo revisión humana en un worktree dedicado.
- **Ingeniería inversa:** también asistida por agentes, pero con una regla *clean-room* estricta. Cada dirección, estructura y constante publicada en `re/` se observó en `SCUS-94154` con Ghidra y después se confirmó dinámicamente en PCSX-Redux con un experimento reproducible que declara precondiciones y criterios de éxito y fallo. Las propuestas se quedan en [`re/provisional_symbols.csv`](re/provisional_symbols.csv); solo el humano las promueve a [`re/symbols.csv`](re/symbols.csv).
- **Nada de datos del juego generados por IA.** Los modelos nunca reciben el disco, el ejecutable, volcados de BIOS ni tarjetas de memoria, y nada derivado de ellos se versiona.
- **Las reglas son públicas.** [`AGENTS.es.md`](AGENTS.es.md), [`CLAUDE.es.md`](CLAUDE.es.md) y [`GEMINI.es.md`](GEMINI.es.md) documentan roles, acciones prohibidas y ciclo de verificación, de modo que cualquier hallazgo se puede auditar o reproducir. Son documentación de proceso: puedes ignorarlas si solo te interesa el port.

Los agentes son herramientas. Cada dato publicado lo comprueba el responsable contra el juego, y cualquier error que quede es responsabilidad suya.

---

## Licencias

- El código fuente, herramientas, notas de ingeniería inversa y scripts propios de este repositorio se publican bajo la **licencia MIT** ([LICENSE](LICENSE)).
- Los binarios enlazados y distribuciones AppImage dependen de **psxrecomp**, regido por **PolyForm Noncommercial License 1.0.0** (uso exclusivamente no comercial).
- Los avisos y licencias de terceros (`recomp-ui`, OpenBIOS, SDL3, Zig, CMake, Ninja, `tomli` y AppImage `type2-runtime`) están completos en [NOTICE](NOTICE).
