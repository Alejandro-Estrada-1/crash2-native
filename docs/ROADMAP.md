# crash2-native — Mapa del proyecto

Port nativo para Linux de *Crash Bandicoot 2: Cortex Strikes Back* (PS1, EUA, `SCUS-94154`),
construido sobre **psxrecomp**, con ingeniería inversa propia (Ghidra + agentes vía MCP),
distribuido como **AppImage** y automatizado con **GitHub Actions**.

> El nombre `crash2-native` es provisional. Cámbialo cuando quieras.

---

## 1. Por qué este enfoque

| Decisión | Razón |
|---|---|
| **Construir sobre psxrecomp, no sobre Crash2Recomp** | Crash2Recomp (Zumbo06) no tiene licencia propia: su launcher, scripts y parches son "todos los derechos reservados". psxrecomp sí tiene licencia (PolyForm Noncommercial 1.0.0) y está diseñado para que cada juego viva en su propio repo. |
| **Ingeniería inversa propia (Ghidra + REA/MCP)** | Para no depender del trabajo sin licencia de otro. Clean-room: de sus notas usamos *qué* problemas existen; ni su código ni sus offsets, direcciones o estructuras. Todo lo que publicamos lo observamos y verificamos nosotros en SCUS-94154. |
| **Linux primero** | psxrecomp ya funciona en Linux (RE3 y Hércules lo demuestran). Crash2Recomp solo existe para Windows. |
| **AppImage + Zig** | El juego se compila en la máquina del usuario. Zig da un compilador de C completo, portable y sin dependencias, y puede apuntar a una glibc vieja. |
| **GitHub Actions** | Compilación reproducible en un contenedor viejo (compatibilidad con más distros), releases automáticos con checksums, y cero carga para la laptop. |
| **Proyecto propio** | Todo el código es explicable línea por línea en una entrevista. Valor de portafolio (DevOps + ingeniería inversa). |

---

## 2. Lo que ya sabemos de otros proyectos

| Fuente | Lección | Cómo la aplicamos |
|---|---|---|
| **psxrecomp** (mstan) | Los juegos viven en su propio repo con `psxrecomp/` y `recomp-ui/` como submódulos. La pantalla ancha genérica se configura en `[widescreen]` del `game.toml`, localizando los puntos de recorte. Los overlays se capturan y compilan en tiempo de ejecución; el intérprete es la red de seguridad. | Estructura del repo, `game.toml`, seeds. |
| **Hercules Recompiled** | Port sobre psxrecomp que ya compila en Linux. Aplica sus cambios al framework como parches en `patches/psxrecomp/`. | Plantilla de referencia para la Fase 1. |
| **Mega Man X6 Recomp** | Seeds obtenidos con Ghidra. Bases de datos de Ghidra, binarios, código generado y memory cards **se quedan en local**. Los cambios al framework van upstream. | Reglas de qué se versiona y qué no. |
| **RE3 Recompiled** (lo usamos) | `recomp-ui` es un launcher nativo; Python solo hace falta al compilar. Un binario compilado en Arch (glibc 2.43) no corre en Ubuntu. | Usar `recomp-ui`; compilar releases contra glibc vieja. |
| **Crash2Recomp** (solo ideas) | Pantalla ancha: abrir mucho la cámara muestra escenario que no existe (los niveles terminan cerca del borde 4:3). Su solución: abrir poco y cerrar el hueco estirando la imagen (~2% de deformación). Hay una franja de líneas negras arriba y abajo que se debe recortar. Cuidado con proporciones (tuvo un bug de imagen 15% más alta). 60 FPS duplicando el bucle: hubo que corregir animaciones, plataformas y temporizadores, y aparecieron bugs por nivel (cámara en Air Crash). | Pantalla ancha inicial con su técnica (reimplementada); evitar su enfoque de 60 FPS. |
| **Crash 1 Launcher** (MIT) | 60/120/240 FPS por **interpolación**: la lógica sigue a 30 y se interpolan las posiciones de objetos y cámara, sin efectos en la física. Pantalla ancha real con arreglos a mano por nivel y un editor propio. La decompilación c1 fue el mapa, no el código. | FPS altos por interpolación; pantalla ancha real en una fase posterior. |
| **crash2-decomp** (Codeberg) | Decompilación *matching* de SCUS-94154, recién empezada. Usa IA, pero "nada depende de la palabra de la IA". | Fuente de nombres de funciones; destino de nuestras contribuciones. |
| **portcove** (catálogo) | Señaló en Crash2Recomp: sin hashes de imágenes aceptadas, sin rechazo de imágenes incorrectas, versión interna que no coincidía con el release, sin checksums. | Nuestras mejoras de infraestructura. |
| **Savage Wind / ZA Recomp** | Incluir el compilador (Zig) en el paquete para compilar en la máquina del usuario. | AppImage con Zig. |

---

## 3. Qué mejoramos respecto a Crash2Recomp

1. **Linux nativo** desde el primer día (AppImage).
2. **Licencia clara**: nuestro código bajo licencia propia + aviso de PolyForm NC de psxrecomp.
3. **Verificación de disco estricta**: tabla de hashes de Redump y rechazo de imágenes incorrectas con un mensaje claro.
4. **Releases verificables**: la versión sale de la etiqueta de git; `SHA256SUMS` en cada release.
5. **FPS altos por interpolación** en lugar de duplicar el bucle: la lógica queda idéntica a la de la PS1.
6. **Pruebas de regresión**: replays + comparación del estado del juego, para que ninguna mejora rompa la lógica.
7. **Conocimiento abierto**: símbolos y estructuras publicados y compartidos con crash2-decomp.

---

## 4. Estructura del repositorio

```
crash2-native/
├── psxrecomp/                 # submódulo: mstan/psxrecomp (PolyForm NC)
├── recomp-ui/                 # submódulo: launcher nativo de psxrecomp
├── game.toml                  # configuración del juego (runtime, video, widescreen)
├── seeds/                     # inicios de funciones (exportados desde Ghidra)
├── CMakeLists.txt
├── src/                       # NUESTRO código: hooks, interpolación, widescreen
├── patches/
│   └── psxrecomp/             # cambios al framework, como parches (candidatos a upstream)
├── re/                        # conocimiento de ingeniería inversa (SÍ se publica)
│   ├── provisional_symbols.csv # propuestas del agente, sin verificar (diff revisable)
│   ├── symbols.csv            # solo lo verificado por el humano, con módulo y evidencia
│   ├── structs.h              # estructuras confirmadas (Camera, Entity, ...)
│   ├── NOTES.md               # confirmado / descartado / pendiente, con fecha
│   └── experiments/           # .gdb / .lua con precondición y criterios + resúmenes
├── tools/
│   ├── ghidra/                # scripts: exportar seeds, importar symbols.csv
│   ├── verify-disc/           # (Rust) verificador de imágenes contra Redump
│   └── regress/               # (Rust) replays y comparación de estado
├── scripts/
│   ├── setup.sh               # dependencias y submódulos
│   ├── build_linux.sh         # generar + compilar
│   └── gdb-psx                # GDB conectado a PCSX-Redux, con timeout y detach
├── packaging/
│   └── appimage/              # AppRun, .desktop, ícono, build-appimage.sh
├── .github/workflows/
│   ├── ci.yml                 # cada push/PR: compilar herramientas, pruebas
│   └── release.yml            # cada etiqueta v*: AppImage + SHA256SUMS
├── docs/                      # ROADMAP.md (este archivo), BUILDING.md, ...
├── LICENSE                    # licencia de NUESTRO código
├── NOTICE                     # avisos de terceros (PolyForm NC, OpenBIOS, SDL3, Zig)
├── README.md
├── AGENTS.md                  # reglas comunes de los agentes
├── CLAUDE.md                  # rol de Claude Code: infraestructura
├── GEMINI.md                  # rol de Antigravity: ingeniería inversa
│
│   # --- Nunca en git (.gitignore, rutas ancladas y sin / final: /ghidra, /disc) ---
├── disc -> ../privado/disc     # enlace simbólico al disco
├── generated/                 # C generado a partir del juego
├── build/  build-release/
└── ghidra                     # ignorado por seguridad (el proyecto vive en ../privado/ghidra)
```

---

### Ubicación en disco

```
~/Descargas/PORTS/Crash2CSB/
├── crash2-native/        # repo principal (rama main)
├── c2-infra/             # worktree de Claude Code
├── c2-re/                # worktree de Antigravity
└── privado/              # NUNCA en git
    ├── disc/             # .bin + .cue verificados contra Redump
    ├── exe/              # SCUS_941.54 y SYSTEM.CNF
    ├── ghidra/           # proyecto de Ghidra "crash2" (respaldar en el disco externo)
    └── emu/              # estados de guardado y memory cards de PCSX-Redux
```

`crash2-native/disc` y `c2-infra/disc` son enlaces simbólicos a `../privado/disc`.

### Disco de referencia (Redump)

| Campo | Valor |
|---|---|
| Serial | SCUS-94154 (ediciones Original y Greatest Hits) |
| Tamaño | 192,814,608 bytes (81,979 sectores, 1 pista) |
| CRC-32 | `395c0916` |
| MD5 | `3c31b5e038f025098a2fdfa70c8213f2` |
| SHA-1 | `3d37fe4288a83b01f1a0edbf78e76e0fede6bc22` |
| LibCrypt | No |

---

## 5. Herramientas

| Herramienta | Para qué | Instalación (Arch) |
|---|---|---|
| psxrecomp + recomp-ui | Recompilador, runtime, launcher | submódulos de git |
| clang/gcc, CMake, Ninja, Python 3 | Compilar y generar | `pacman -S clang cmake ninja python` |
| Zig | Compilador portable para el AppImage; `-target x86_64-linux-gnu.2.28` | `pacman -S zig` |
| Ghidra + ghidra_psx_ldr | Análisis estático; cargador PSX y firmas de PsyQ | `pacman -S ghidra` + plugin de lab313ru |
| REA o GhidraMCP / pyghidra-mcp | Conectar el agente a Ghidra por MCP | según su documentación |
| PCSX-Redux | Emulador con depurador, servidor GDB y consola Lua (registrar datos de varios cuadros sin pausar) | AppImage o AUR |
| GDB (+ `scripts/gdb-psx`) | Depuración remota del juego; scripts en modo `-batch` con timeout | `pacman -S gdb` |
| mcp_server_gdb (opcional) | El agente controla GDB por MCP | release binario (pansila) |
| distrobox + Podman | Contenedor Ubuntu 22.04 para builds compatibles | `pacman -S distrobox podman` |
| act | Probar workflows de GitHub Actions en local | `pacman -S act docker` |
| appimagetool | Empaquetar el AppImage | release de AppImage/appimagetool |
| Rust (cargo) | Herramientas propias: verify-disc, regress | `pacman -S rustup` |

---

## 6. Fases

### Fase 0 — Preparación
- [ ] Resolver el kernel panic: descargar módulos de VirtualBox mientras trabajas; si persiste, probar `linux-lts`.
- [ ] Verificar el disco: serial `SCUS-94154` y hash contra Redump.
- [ ] Leer en psxrecomp: `docs/EXECUTION_MODEL.md`, `ARCHITECTURE.md`, `BUILDING.md`, `GAME_PROJECT_SETUP.md`.
- [ ] Decidir la licencia de nuestro código (p. ej. MIT) y redactar `NOTICE`.

**Listo cuando:** entorno instalado y disco verificado.

### Fase 1 — Aprender con una plantilla
- [ ] Clonar y compilar **Hercules Recompiled** en Linux.
- [ ] Entender su `game.toml`, sus seeds, sus parches y su CMake.

**Listo cuando:** Hércules corre en tu Arch y sabes qué hace cada archivo.

### Fase 2 — Crash 2 arranca (30 FPS)
- [ ] Crear el repo con la estructura de la sección 4 y los submódulos.
- [ ] `game.toml` mínimo para SCUS-94154; seeds iniciales.
- [ ] `scripts/build_linux.sh`: generar + compilar.
- [ ] Llegar a la pantalla de título; luego, jugar el primer nivel.

**Listo cuando:** se juega un nivel completo a 30 FPS en Linux.

### Fase 3 — Ingeniería inversa
- [ ] Proyecto de Ghidra con ghidra_psx_ldr y firmas PsyQ.
- [ ] Desde funciones conocidas (`SetGeomScreen`, `DrawOTag`, `VSync`): encontrar cámara, recorte, bucle principal y lista de objetos.
- [ ] Para cada dirección, determinar si es del ejecutable principal o de un overlay.
- [ ] Análisis dinámico con PCSX-Redux + `gdb-psx` (con timeout) y scripts Lua para observar varios cuadros.
- [ ] Propuestas del agente en `re/provisional_symbols.csv`; el humano promueve a `symbols.csv` y aplica en Ghidra.
- [ ] Mejorar seeds (menos intérprete, más código nativo).
- [ ] Publicar `re/symbols.csv` y `re/structs.h`; compartir con crash2-decomp.

**Listo cuando:** cámara, recorte y bucle principal están verificados en el emulador.

### Fase 4 — Infraestructura
- [ ] `tools/verify-disc` (Rust): hashes de Redump y rechazo de imágenes incorrectas.
- [ ] `ci.yml`: compilar en `container: ubuntu:22.04`; pruebas.
- [ ] AppImage con Zig, datos del usuario en `~/.local/share/crash2-native/`.
- [ ] `release.yml`: versión desde la etiqueta, AppImage + `SHA256SUMS`.

**Listo cuando:** una etiqueta `v0.1.0` produce un AppImage que corre en Arch y en Ubuntu 22.04.

### Fase 5 — Pantalla ancha
- [ ] Recortar la franja negra superior e inferior.
- [ ] Técnica "abrir poco y estirar" (reimplementada, no copiada).
- [ ] Después, nivel por nivel: ampliar el recorte de verdad donde el escenario lo permita.

### Fase 6 — FPS altos por interpolación
- [ ] Guardar posiciones de cámara y objetos en cada tick de lógica (30 Hz).
- [ ] Interpolar al dibujar (60/120/144 Hz).
- [ ] Verificar con `tools/regress` que la lógica queda idéntica.

### Fase 7 — Pruebas, release y contribución
- [ ] Replays de varios niveles como pruebas de regresión locales.
- [ ] Release público.
- [ ] Parches útiles del framework propuestos a mstan/psxrecomp.

---

## 7. Trabajo con dos agentes

| | Claude Code | Antigravity |
|---|---|---|
| Rol | Infraestructura | Ingeniería inversa |
| Worktree / rama | `../c2-infra`, `infra/...` | `../c2-re`, `re/...` |
| Recurso exclusivo | Compilación local | Emulador + servidor GDB |
| Reglas | `CLAUDE.md` (importa `AGENTS.md`) | `GEMINI.md` + `AGENTS.md` |

```bash
git worktree add ../c2-infra -b infra/inicio
git worktree add ../c2-re    -b re/inicio
```

Tareas en GitHub Issues (`agente:claude`, `agente:agy`). El humano integra los PR en `main` y es el único que
escribe en los archivos de "verdad" (`symbols.csv`, `structs.h`, `seeds/`, reglas).

---

## 8. Riesgos y dudas abiertas

| Riesgo | Mitigación |
|---|---|
| Crash 2 puede necesitar arreglos específicos del runtime que aún no conocemos | Fase 3 + leer las ideas de las notas de Crash2Recomp (sin copiar código) |
| La GPU simulada de psxrecomp limita la pantalla ancha completa | Empezar con "abrir poco y estirar"; extender el renderizador como trabajo upstream |
| No está confirmado que la generación de psxrecomp funcione con `zig cc` | Probarlo pronto (Fase 4); si no, pedir clang/gcc del sistema como hace RE3 |
| No sé si el juego necesita el disco al jugar (streaming) | Comprobarlo en la Fase 2 |
| El agente de IA puede equivocarse con seguridad | Nada se da por cierto sin verificación en el emulador; el agente no escribe en Ghidra (ver CLAUDE.md) |
| El MCP de Ghidra puede ser de solo lectura (REA) | Las propuestas van a `re/provisional_symbols.csv`; un script de `tools/ghidra/` las importa cuando el humano decide |
| Un breakpoint que nunca salta cuelga `gdb -batch` | `gdb-psx` con timeout y detach; cada experimento declara precondición y criterio de fallo |
| Overlays: la misma dirección contiene código distinto según el nivel | Columna `module` en los CSV; verificar qué está cargado antes de poner breakpoints |
| Pantalla ancha o interpolación alteran la lógica sin notarlo | `tools/regress` compara estado lógico (posiciones, entidades, RNG, contadores), no imagen |
| Código del juego enviado al proveedor del modelo | Decisión consciente; revisar términos; nunca publicar la base de Ghidra |
| Licencia PolyForm NC | El proyecto es y será gratuito; sin donaciones ligadas a los binarios |
