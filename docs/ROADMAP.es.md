[English](ROADMAP.md) | Español

# crash2-native — Mapa del proyecto

Port nativo para Linux de *Crash Bandicoot 2: Cortex Strikes Back* (PS1, EUA, `SCUS-94154`),
construido sobre **psxrecomp**, con ingeniería inversa propia (Ghidra + agentes vía MCP),
distribuido como **AppImage** y automatizado con **GitHub Actions**.

> El nombre `crash2-native` es provisional. Cámbialo cuando quieras.

---

## 1. Por qué este enfoque

| Decisión | Razón |
|---|---|
| **Construir sobre psxrecomp, no sobre Crash2Recomp** | Crash2Recomp (Zumbo06) no tiene licencia propia: su launcher, scripts y parches son "todos los derechos reservados". `psxrecomp` sí tiene licencia (PolyForm Noncommercial 1.0.0) y está diseñado para que cada juego viva en su propio repo. |
| **Ingeniería inversa propia (Ghidra + MCP)** | Para no depender del trabajo sin licencia de otro. Clean-room: de sus notas usamos *qué* problemas existen; ni su código ni sus offsets, direcciones o estructuras. Todo lo que publicamos lo observamos y verificamos nosotros en `SCUS-94154`. |
| **Linux primero** | `psxrecomp` ya funciona en Linux (RE3 y Hércules lo demuestran). Crash2Recomp solo existe para Windows. |
| **AppImage + Zig** | El juego se compila en la máquina del usuario. Zig da un compilador de C/C++ completo y portable apuntando a una glibc vieja (`x86_64-linux-gnu.2.28`), junto con CMake recortado, Ninja, emisores precompilados y dependencias offline. |
| **GitHub Actions** | Compilación reproducible en `ubuntu:22.04` (compatibilidad con más distros), releases automáticos con checksums, y cero carga para la laptop. |
| **Proyecto propio** | Todo el código es explicable línea por línea. Valor de portafolio (DevOps + ingeniería inversa). |

---

## 2. Lo que ya sabemos de otros proyectos

| Fuente | Lección | Cómo la aplicamos |
|---|---|---|
| **psxrecomp** (mstan) | Los juegos viven en su propio repo con `psxrecomp/` y `recomp-ui/` como submódulos. Los bloques dinámicos fuera del texto principal se capturan y compilan en tiempo de ejecución; el intérprete es la red de seguridad. | Estructura del repo, `game.toml`, `seeds/`, toolchain de overlays. |
| **Hercules Recompiled** | Port sobre psxrecomp que ya compila en Linux. Aplica sus cambios al framework como parches en `patches/psxrecomp/`. | Plantilla de referencia para la Fase 1. |
| **Mega Man X6 Recomp** | Seeds obtenidos con Ghidra. Bases de datos de Ghidra, binarios, código generado y memory cards **se quedan en local**. Los cambios al framework van upstream. | Reglas estrictas de higiene git. |
| **RE3 Recompiled** | `recomp-ui` es un launcher nativo; Python solo hace falta al compilar. Un binario compilado en Arch (glibc más nueva) no corre en Ubuntu. | Usar `recomp-ui`; compilar releases contra glibc vieja (`ubuntu:22.04`). |
| **Crash2Recomp** (solo ideas) | Pantalla ancha: abrir mucho la cámara muestra escenario que no existe cerca del borde 4:3; recortar las franjas negras de 12 líneas y cuidar proporciones evita el bug conocido de imagen estirada verticalmente. Evitar 60 FPS duplicando el bucle (rompe animaciones, temporizadores y cámara por nivel). | Pantalla ancha inicial respetando escala `5/8`; evitar duplicar el bucle a 60 FPS. |
| **Crash 1 Launcher** (MIT) | 60/120/240 FPS por **interpolación**: la lógica sigue a 30 Hz y se interpolan las posiciones de objetos y cámara al dibujar, sin efectos en la física. | FPS altos por interpolación en la Fase 6. |
| **crash2-decomp** (Codeberg) | Decompilación *matching* de `SCUS-94154`. Usa IA, pero "nada depende de la palabra de la IA". | Fuente de contexto de nombres; destino de contribuciones abiertas. |
| **portcove** (catálogo) | Señaló en Crash2Recomp: sin hashes de imágenes aceptadas, sin rechazo de imágenes incorrectas, versión interna que no coincidía con el release, sin checksums. | Nuestras prioridades de infraestructura (`verify-disc`, versiones por etiqueta, `SHA256SUMS`). |
| **Savage Wind / ZA Recomp** | Incluir Zig en el paquete para compilar en la máquina del usuario. | AppImage con Zig. |

---

## 3. Qué mejoramos respecto a Crash2Recomp

1. **Linux nativo** desde el primer día (AppImage).
2. **Licencia clara**: MIT para nuestro código + avisos PolyForm NC / terceros en `NOTICE`.
3. **Verificación de disco estricta**: tabla de hashes de Redump y rechazo claro de imágenes incorrectas (`tools/verify-disc` + `psxrecomp`).
4. **Releases verificables**: la versión sale de la etiqueta de git; `SHA256SUMS` en cada release.
5. **FPS altos por interpolación** en lugar de duplicar el bucle: la lógica queda idéntica bit a bit a la PS1.
6. **Pruebas de regresión**: replays + comparación del estado lógico, para que ninguna mejora rompa la lógica.
7. **Conocimiento abierto**: símbolos y estructuras verificados publicados en `re/`.

---

## 4. Estructura del repositorio

```
crash2-native/
├── psxrecomp/                 # submódulo: mstan/psxrecomp (PolyForm NC 1.0.0)
├── recomp-ui/                 # submódulo: launcher nativo de psxrecomp (MIT)
├── game.toml                  # configuración del juego (runtime, video, hashes Redump)
├── seeds/                     # inicios de funciones verificados para recompilación estática
├── CMakeLists.txt
├── src/                       # NUESTRO código: setup host, menú, hooks, interpolación, pantalla ancha
├── mods/preloaded/            # paquetes de mods precargados del título (conmutador 16:9, etc.)
├── patches/
│   └── psxrecomp/             # parches al framework (candidatos a upstream)
├── re/                        # conocimiento de ingeniería inversa (SÍ se publica)
│   ├── provisional_symbols.csv # propuestas sin verificar (diff revisable)
│   ├── symbols.csv            # solo lo verificado por el humano, con módulo y evidencia
│   ├── structs.h              # estructuras confirmadas (GoolObject, CameraTransformBlock, DisplayContext, PadState)
│   ├── NOTES.md               # bitácora confirmado / descartado / pendiente (+ NOTES.es.md)
│   └── experiments/           # .gdb / .lua con precondición y criterios + resúmenes
├── tools/
│   ├── ghidra/                # scripts: copia solo lectura, apoyo de exportación/importación
│   ├── verify-disc/           # (Rust) verificador independiente de imágenes contra Redump
│   └── regress/               # (Rust) herramienta de replays y comparación de estado lógico
├── scripts/
│   ├── setup.sh               # dependencias, submódulos, parches, verificación de disco
│   ├── build_linux.sh         # generar + compilar
│   ├── respaldar_partidas.sh  # respaldos de partidas con fecha y SHA256SUMS
│   └── gdb-psx                # wrapper GDB para PCSX-Redux con timeout y reanudación
├── packaging/
│   └── appimage/              # AppRun, .desktop, ícono, build-appimage.sh, CHECK_FINDINGS.md
├── .github/workflows/
│   ├── ci.yml                 # cada push/PR: setup-host, herramientas, sintaxis e higiene
│   └── release.yml            # etiquetas v* / dispatch: AppImage + SHA256SUMS
├── docs/                      # ROADMAP.md + ROADMAP.es.md (este archivo)
├── LICENSE                    # licencia MIT de nuestro código (+ aviso PolyForm NC)
├── NOTICE                     # avisos de terceros (PolyForm NC, OpenBIOS, SDL3, Zig, etc.)
├── README.md                  # portada del proyecto y guía rápida (+ README.es.md)
├── AGENTS.md                  # reglas comunes de los agentes (+ AGENTS.es.md)
├── CLAUDE.md                  # rol de infraestructura (+ CLAUDE.es.md)
├── GEMINI.md                  # rol de ingeniería inversa (+ GEMINI.es.md)
│
│   # --- Nunca en git (.gitignore, rutas ancladas y sin / final: /ghidra, /disc) ---
├── disc -> ../privado/disc     # enlace simbólico al disco legal
├── saves -> ../privado/partidas
├── generated/                 # C generado a partir del disco del juego
├── build/  build-release/  build-setup/
└── ghidra                     # ignorado (el proyecto de Ghidra vive en ../privado/ghidra)
```

### Ubicación en disco

```
~/Descargas/PORTS/Crash2CSB/
├── crash2-native/        # repo principal (rama main)
├── c2-infra/             # worktree de infraestructura
├── c2-re/                # worktree de ingeniería inversa
└── privado/              # NUNCA en git
    ├── disc/             # .bin + .cue verificados contra Redump
    ├── exe/              # SCUS_941.54 y SYSTEM.CNF
    ├── ghidra/           # proyecto de Ghidra "crash2"
    └── emu/              # estados de guardado y memory cards de PCSX-Redux
```

### Disco de referencia (Redump)

| Campo | Valor |
|---|---|
| Serial | `SCUS-94154` (ediciones Original y Greatest Hits) |
| Tamaño | `192,814,608` bytes (`81,979` sectores, 1 pista) |
| CRC-32 | `395c0916` |
| MD5 | `3c31b5e038f025098a2fdfa70c8213f2` |
| SHA-1 | `3d37fe4288a83b01f1a0edbf78e76e0fede6bc22` |
| LibCrypt | No |

---

## 5. Herramientas

| Herramienta | Para qué | Instalación (Arch) / Origen |
|---|---|---|
| `psxrecomp` + `recomp-ui` | Recompilador, runtime, launcher | submódulos de git |
| `clang`/`gcc`, CMake, Ninja, Python 3 | Compilar y generar | `pacman -S clang cmake ninja python` |
| Zig | Compilador portable para el AppImage; `-target x86_64-linux-gnu.2.28` | `pacman -S zig` |
| Ghidra + `ghidra_psx_ldr` | Análisis estático; cargador PSX y firmas de PsyQ | `pacman -S ghidra` + plugin de lab313ru |
| `pyghidra-mcp` | Lectura MCP solo lectura de copia del proyecto Ghidra | `pyghidra-mcp==0.3.0` |
| PCSX-Redux | Emulador con depurador, servidor GDB y consola Lua | AppImage o AUR |
| GDB (`+ scripts/gdb-psx`) | Depuración remota en modo `-batch` con timeout | `pacman -S gdb` |
| Docker / Podman | Contenedor `ubuntu:22.04` limpio para validar builds | `pacman -S docker` / `podman` |
| Rust (`cargo`) | Herramientas propias: `verify-disc`, `regress` | `pacman -S rustup` |

---

## 6. Fases

### Fase 0 — Preparación
- [x] Verificar el disco: serial `SCUS-94154` y hashes contra Redump.
- [x] Leer documentación de `psxrecomp` (`EXECUTION_MODEL.md`, `ARCHITECTURE.md`, `BUILDING.md`, `GAME_PROJECT_SETUP.md`, `config_schema.md`).
- [x] Decidir la licencia del proyecto (MIT) y redactar `NOTICE`.

**Listo cuando:** entorno instalado y disco verificado.

### Fase 1 — Plantilla y base del proyecto
- [x] Estudiar Hercules Recompiled (`game.toml`, seeds, parches, CMake) como referencia.
- [x] Crear estructura del repositorio, submódulos, `scripts/setup.sh` y `scripts/build_linux.sh`.

**Listo cuando:** base de compilación lista y verificada.

### Fase 2 — Crash 2 arranca (30 FPS)
- [x] `game.toml` mínimo para `SCUS-94154` y seeds iniciales.
- [x] Integrar launcher `recomp-ui`, menú dentro del juego (`src/menu_provider.c`) y asistente (`src/codegen_setup.c`).
- [x] Arrancar y jugar en Linux a 30 FPS con `803` semillas.

**Listo cuando:** se juega un nivel completo a 30 FPS en Linux.

### Fase 3 — Ingeniería inversa
- [x] Proyecto de Ghidra con `ghidra_psx_ldr` y firmas PsyQ 4.0.
- [x] Mapear funciones PsyQ (`SetGeomScreen`, `DrawOTag`, `PutDispEnv`, `PutDrawEnv`, `VSync`, `CdRead`) y referencias cruzadas.
- [x] Mapear carga CD (paginación `.NSD`/`.NSF`) y bloques nativos MIPS en `GOOL` (`type == 11`, `sec[1]`, `0x8003aad4`).
- [x] Verificar en vivo el bucle principal de 30 Hz, actualización de cámara, recorte `512x216` (`y=12`), tres rutas GTE `5/8`, recorrido de entidades (`gool_root_buckets` / `GoolObject`), `PadState` y `RNG` (`001`–`008`).
- [x] Promover 60 símbolos confirmados a `re/symbols.csv`, crear `re/structs.h` y ampliar `seeds/ghidra_funcs.txt` (`803` semillas únicas).

**Listo cuando:** cámara, recorte y bucle principal/entidades están verificados en el emulador.

### Fase 4 — Infraestructura
- [x] `tools/verify-disc` (Rust): hashes de Redump y rechazo de imágenes incorrectas.
- [x] `ci.yml`: compilar y probar sin disco en `container: ubuntu:22.04`.
- [x] AppImage con Zig `0.17.1`, CMake recortado, Ninja, `tomli`, `type2-runtime` fijado y datos de usuario en `~/.local/share/crash2-native/`.
- [x] `release.yml`: versión desde la etiqueta, AppImage + `SHA256SUMS`.
- [x] Ejecutar en remoto `ci.yml` y `release.yml` (dry-run con `workflow_dispatch`) en GitHub Actions y validar en Arch + Ubuntu 22.04.
- [ ] Crear etiqueta `v0.1.0` para publicar el AppImage hito en GitHub Releases y validar la versión etiquetada en Arch + Ubuntu 22.04.

**Listo cuando:** una etiqueta `v0.1.0` produce un AppImage en GitHub Actions que corre en Arch y en Ubuntu 22.04.

### Fase 5 — Pantalla ancha
- [x] Recortar las franjas negras superior e inferior de 12 líneas (`DRAWENV` `512x216` con `y=12`).
- [x] Reimplementar la técnica "abrir poco la cámara y estirar ligeramente" preservando la escala vertical `5/8` en las tres rutas GTE confirmadas (mod precargado `crash2.enhancement.widescreen`, apertura `1.125x` por defecto + `1.10x`/`1.20x`).
- [ ] Después, nivel por nivel: ampliar la proyección/recorte real donde el escenario lo permita.

### Fase 6 — FPS altos por interpolación
- [ ] Capturar posiciones de cámara y entidades activas (`gool_root_buckets`) en cada tick de lógica (30 Hz).
- [ ] Interpolar al dibujar (60/120/144 Hz).
- [ ] Verificar con `tools/regress` que la lógica queda idéntica bit a bit.

### Fase 7 — Pruebas, release y contribución
- [ ] Replays de varios niveles como pruebas de regresión sobre estado lógico.
- [ ] Release público.
- [ ] Proponer parches útiles del framework (`patches/psxrecomp/`) upstream a `mstan/psxrecomp`.

---

## 7. Trabajo con dos agentes

| | Claude Code / Infra | Antigravity / RE |
|---|---|---|
| Rol | Infraestructura | Ingeniería inversa |
| Worktree / rama | `../c2-infra`, `infra/...` | `../c2-re`, `re/...` |
| Recurso exclusivo | Compilación local | Emulador + servidor GDB |
| Reglas | `CLAUDE.md` (importa `AGENTS.md`) | `GEMINI.md` + `AGENTS.md` |

Tareas en GitHub Issues (`agente:claude`, `agente:agy`). El humano integra
los PR en `main` y es el único que escribe en los archivos canónicos
(`symbols.csv`, `structs.h`, `seeds/`, reglas).

---

## 8. Riesgos y dudas abiertas

| Riesgo | Mitigación |
|---|---|
| Crash 2 puede necesitar arreglos específicos del runtime | Hallazgos de Fase 3 + parches al framework en `patches/psxrecomp/` |
| Límites de GPU en `psxrecomp` para pantalla ancha completa | Empezar con FOV ligero + recorte/estirado respetando `5/8`; extender el renderizador upstream si hace falta |
| Compatibilidad de `zig cc` con el C generado / cabeceras del host | Verificado en `infra/appimage-check` (parches `0001`/`0002` + cabeceras mínimas X11/GL/ALSA); se mantiene respaldo de compilador del sistema (`CRASH2NATIVE_USE_SYSTEM_CC=1`) |
| Streaming de disco durante el juego | Verificado en `005`: páginas `.NSF` leídas de forma continua por máquina de estados asíncrona sobre `CdRead` |
| El agente de IA puede equivocarse con seguridad | Nada se da por cierto sin verificación en el emulador; los agentes no escriben en Ghidra |
| MCP de Ghidra en solo lectura | Las propuestas van a `re/provisional_symbols.csv`; el humano promueve y sincroniza |
| Un breakpoint que nunca salta cuelga `gdb -batch` | `gdb-psx` usa `timeout`, fallo rápido de conexión y reanudación con `$c#63`; cada experimento declara precondición y criterios |
| Código MIPS dinámico dentro de chunks `.NSF` `GOOL` (`sec[1]`) | Identificado en `006` (`0x8003aad4`); `AppRun` incluye `tomli` + `zig-cc` para recompilar overlays en tiempo de ejecución |
| Pantalla ancha o interpolación alteran la lógica sin notarlo | `tools/regress` compara estado lógico (`PadState`, `RNG`, `GoolObject`, contadores), nunca píxeles |
| Licencia PolyForm NC | El proyecto es y será gratuito y estrictamente no comercial |
