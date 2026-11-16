[English](AGENTS.md) | Español

# AGENTS.es.md — crash2-native (reglas comunes para todos los agentes)

Este archivo lo leen Claude Code (vía `CLAUDE.md`) y Antigravity. Cada agente
tiene además su rol en su propio archivo: `CLAUDE.md` (infraestructura) y
`GEMINI.md` (ingeniería inversa).

Port nativo para Linux de Crash Bandicoot 2 (PS1, `SCUS-94154`) sobre
**psxrecomp**. El mapa completo, las fases y el porqué de cada decisión están en
`docs/ROADMAP.es.md` (principal en inglés: `docs/ROADMAP.md`). Lee ese archivo
al empezar una sesión si la tarea no es trivial.

## Reglas que nunca se rompen

1. **Nada del juego entra a git.** Ni imágenes de disco, ni ejecutables
   extraídos, ni C generado (`generated/`), ni proyectos de Ghidra (`ghidra/`),
   ni memory cards, ni estados de guardado, ni capturas de memoria. Antes de
   cada commit, revisa `git status`. Si aparece algo así, detente y avisa.
2. **Clean-room respecto a Crash2Recomp (Zumbo06).** Su repo no tiene licencia.
   No copies su código, ni sus offsets, direcciones, estructuras o constantes.
   Puedes leer sus notas de versión para saber *qué* problemas existen; todo
   dato que entre a `re/` debe haberse observado y verificado de forma
   independiente en `SCUS-94154` con Ghidra y PCSX-Redux.
3. **psxrecomp es PolyForm Noncommercial 1.0.0.** Conserva sus avisos. Nada
   comercial.
4. **No se modifica `psxrecomp/` directamente.** Los cambios al framework van
   como parches en `patches/psxrecomp/`, explicados en el mensaje del commit.
   Si el cambio es genérico, márcalo como candidato a upstream.
5. **Nada es cierto hasta verificarse en el juego.** Ver "Ingeniería inversa"
   abajo.
6. **El disco del usuario solo se lee.** Nunca se modifica.

## Mapa del repo

| Ruta | Contenido | ¿En git? |
|---|---|---|
| `psxrecomp/`, `recomp-ui/` | Submódulos del framework | sí (como submódulo) |
| `game.toml`, `seeds/`, `CMakeLists.txt` | Configuración del juego y semillas | sí |
| `src/` | Nuestro código: hooks, interpolación, pantalla ancha, setup/menú | sí |
| `patches/psxrecomp/` | Cambios al framework | sí |
| `re/provisional_symbols.csv` | Propuestas del agente, sin verificar | sí |
| `re/symbols.csv`, `re/structs.h` | Solo datos verificados por el humano | sí |
| `re/NOTES.md`, `re/experiments/` | Bitácora y experimentos (`.gdb`, `.lua`, resúmenes) | sí |
| `tools/` | `ghidra/` (scripts), `verify-disc/` y `regress/` (Rust) | sí |
| `scripts/` | `setup.sh`, `build_linux.sh`, `gdb-psx`, `respaldar_partidas.sh` | sí |
| `packaging/appimage/` | `AppRun`, `.desktop`, ícono, script de empaquetado | sí |
| `.github/workflows/` | `ci.yml`, `release.yml` | sí |
| `README.md`, `LICENSE`, `NOTICE`, `docs/` | Documentación y avisos legales del proyecto | sí |
| `/disc` (enlace), `/generated`, `/build*`, `/ghidra` | Datos del juego y resultados | **no** |

El `.gitignore` ancla esas rutas a la raíz y sin barra final (`/ghidra`, no
`ghidra/`): así no ignora por accidente `tools/ghidra/` y sí ignora los enlaces
simbólicos. Si agregas una ruta ignorada, sigue el mismo formato.

### Ubicación en disco

```
Crash2CSB/
├── crash2-native/   # repo, rama main (humano)
├── c2-infra/        # worktree de Claude / Infra
├── c2-re/           # worktree de Antigravity / RE
└── privado/         # fuera de git: disc/, exe/ (SCUS_941.54), ghidra/ (proyecto), emu/
```

`disc` dentro del repo es un enlace simbólico a `../privado/disc`. Nunca copies
datos de `privado/` al repo. El ejecutable para análisis está en
`../privado/exe/SCUS_941.54`.

## Comandos

```bash
scripts/setup.sh                       # submódulos y dependencias
scripts/build_linux.sh                 # generar C desde disc/ y compilar
ninja -C build-release -j2             # recompilar tras un cambio (laptop: pocos jobs)
export PSX_GDB_PORT=<puerto>           # el que muestre PCSX-Redux en su configuración
scripts/gdb-psx -batch -x re/experiments/<exp>.gdb   # experimento contra PCSX-Redux (con timeout)
PSX_GDB_TIMEOUT=60 scripts/gdb-psx -batch -x ...     # más tiempo si el experimento lo requiere
```

Hardware de desarrollo: laptop Intel Tiger Lake (4 núcleos, Iris Xe). Usa `-j2`
o `-j4`; no lances compilaciones paralelas pesadas. Las compilaciones finales
las hace GitHub Actions.

## Ingeniería inversa: el ciclo obligatorio

Herramientas: Ghidra (con `ghidra_psx_ldr`; acceso por MCP de solo lectura),
PCSX-Redux con su servidor GDB y su consola Lua, `scripts/gdb-psx`.

**El proyecto de Ghidra lo modifica solo el humano.** El agente no renombra ni
comenta dentro de Ghidra, aunque la herramienta lo permita. Sus propuestas van a
`re/provisional_symbols.csv`, donde quedan como un diff revisable.

1. **Hipótesis.** Parte de funciones conocidas (PsyQ: `SetGeomScreen`,
   `DrawOTag`, `VSync`, `CdRead`...) y sigue las referencias cruzadas. Formula
   una hipótesis concreta: "la función en `0x8002xxxx` actualiza la cámara".
2. **Ubicación del código.** Antes de cualquier otra cosa, determina si la
   dirección pertenece al **ejecutable principal** (`main`) o a código/bloques
   cargados dinámicamente en RAM (p. ej. chunks `.NSF` `GOOL` tipo 11), y en qué
   momento están cargados.
3. **Evidencia estática.** Entrega direcciones, referencias cruzadas, el
   fragmento de pseudocódigo/desensamblado relevante y las constantes. Nunca
   solo una conclusión.
4. **Propuesta.** Agrega una fila a `re/provisional_symbols.csv`, con estado
   `propuesto`.
5. **Experimento dinámico.** Copia `re/experiments/000-plantilla.gdb` como
   `NNN-descripcion.gdb` y llena su encabezado: **precondición** (qué estado de
   guardado cargar o qué pantalla debe estar activa), **hipótesis**, **criterio
   de éxito** y **criterio de fallo** (incluido "el breakpoint no salta en N
   segundos"). Ejecútalo con `scripts/gdb-psx -batch`, que tiene timeout y
   reanuda el emulador al terminar.
   - Para observar varios cuadros seguidos (registrar un valor durante un nivel,
     por ejemplo), usa un script Lua corto en PCSX-Redux en lugar de
     breakpoints, para no detener el emulador en cada cuadro.
   - Antes de escribir en la memoria del juego, pide que se guarde un estado en
     el emulador.
   - Guarda junto al script un resumen del resultado (`NNN-descripcion.md` +
     `.es.md`).
6. **Registro.** Anota en `re/NOTES.md` (y `re/NOTES.es.md`): fecha, hipótesis,
   experimento, resultado (`confirmado` / `descartado` / `dudoso`). Actualiza
   el estado en `provisional_symbols.csv`.
7. **Promoción.** Solo el humano confirma. Al confirmarse: el humano lo pasa a
   `re/symbols.csv` con su evidencia, y si aplica a `re/structs.h` y a `seeds/`,
   y lo aplica en Ghidra (`tools/ghidra/`).

Si una hipótesis no se puede verificar, dilo explícitamente. No rellenes huecos
con suposiciones.

### Formato de `re/provisional_symbols.csv` y `re/symbols.csv`

```
address,name,module,hypothesis,evidence,experiment,status,date
0x8002xxxx,camera_update,main,"actualiza la cámara cada tick","xref desde ...","re/experiments/007-camara.gdb",propuesto,2026-11-15
```

- `module`: `main` o `overlay:<identificador>`.
- `status`: `propuesto`, `confirmado` o `descartado` (en `symbols.csv` solo
  `confirmado`).

## Prioridades técnicas

- **Pantalla ancha:** primero recortar la franja negra superior e inferior
  (`DRAWENV` `512x216` con `y=12`); luego "abrir poco la cámara y cerrar el
  hueco estirando un poco la imagen". No abrir mucho el FOV: los niveles no
  tienen escenario fuera del área 4:3. Verifica siempre las proporciones en las
  rutas `5/8` confirmadas (riesgo conocido de imagen estirada verticalmente).
- **FPS altos:** por **interpolación**. La lógica del juego sigue a 30 Hz; se
  guardan las posiciones de cámara y entidades activas (recorridas desde
  `gool_root_buckets`, nunca el pool plano) en cada tick y se interpola al
  dibujar. No dupliques el bucle del juego.
- **Regresión:** `tools/regress` compara el **estado lógico** (posiciones,
  estado de entidades, RNG, contadores), nunca la imagen, y es independiente de
  la resolución, el FOV y la interpolación. Con interpolación o pantalla ancha
  activadas, el estado lógico debe ser **idéntico bit a bit** al de referencia.
  Si cambia, algo tocó la lógica.

## Empaquetado y CI

- Releases compilados en `container: ubuntu:22.04` (glibc 2.35). Nunca publiques
  binarios compilados en el Arch local.
- El AppImage incluye Zig (`-target x86_64-linux-gnu.2.28`), CMake recortado,
  Ninja, emisores precompilados, dependencias vendorizadas y `tomli` para
  compilar el juego en la máquina del usuario (con respaldo al compilador del
  sistema si hace falta).
- El AppImage es de solo lectura: datos, juego compilado, caché y partidas van
  en `~/.local/share/crash2-native/`.
- La versión sale de la etiqueta de git. Cada release publica `SHA256SUMS`.
- Workflows con `permissions:` mínimos, versiones de actions fijadas por SHA y
  descargas verificadas con hash.
- El CI **no tiene acceso al juego**: compila herramientas y setup host, y corre
  pruebas que no necesitan el disco.

## Trabajo con varios agentes

| Rol | Agente | Rama / worktree | Puede escribir en |
|---|---|---|---|
| Infraestructura | Claude Code | `infra/...` en `../c2-infra` | `scripts/`, `.github/`, `packaging/`, `tools/verify-disc/`, `tools/regress/`, `src/`, `game.toml`, `CMakeLists.txt`, `patches/` |
| Ingeniería inversa | Antigravity | `re/...` en `../c2-re` | `re/provisional_symbols.csv`, `re/NOTES.md`, `re/NOTES.es.md`, `re/experiments/`, `tools/ghidra/` |
| Humano | — | `main` | `AGENTS.md`, `CLAUDE.md`, `GEMINI.md` (+ `.es.md`), `docs/ROADMAP.md` (+ `.es.md`), `README.md` (+ `.es.md`), `LICENSE`, `NOTICE`, `re/symbols.csv`, `re/structs.h`, `seeds/`, proyecto de Ghidra |

- **Fuera de tu columna, solo lectura.** Si necesitas un cambio en archivos de
  otro rol, descríbelo en el issue o en el resumen de tu tarea; no lo hagas tú.
- **Las tareas viven en GitHub Issues** con etiqueta `agente:claude` o
  `agente:agy`. Cada issue dice qué archivos se tocan y cuándo está terminado.
- **Los agentes no se pasan trabajo directamente.** El intercambio ocurre por
  archivos confirmados por el humano (`re/symbols.csv`, `re/structs.h`) y por
  los PR que el humano integra en `main`.
- **Recursos exclusivos:** el emulador y su servidor GDB son del agente de
  ingeniería inversa (`gdb-psx` además usa un candado). La compilación local
  pesada es del agente de infraestructura. Nunca dos compilaciones a la vez.
- **Revisión cruzada:** se puede pedir a un agente que revise el PR del otro y
  busque contraejemplos. Coincidir no es verificar: la verificación sigue siendo
  el experimento en el emulador.
- Mantente actualizado con `git rebase main` antes de abrir un PR.

## Estilo de trabajo

- Cambios pequeños y enfocados; un tema por commit, mensajes claros.
- Antes de una tarea grande, propón un plan corto y espera confirmación.
- Si una decisión afecta la licencia, la estructura del repo o el contenido que
  se publica, pregunta primero.
- **Idioma y formato:** identificadores de código, comentarios en código/scripts
  y la documentación Markdown principal (`.md`) van en **inglés**; `NOTICE`
  permanece solo en inglés. Cada documento `.md` debe tener su versión en
  español (`<nombre>.es.md`) en el mismo directorio con selector de idioma
  arriba. **Prohibido usar emojis** en documentación, comentarios o commits.
- Al terminar una tarea: qué cambió, cómo se probó y qué queda pendiente.
