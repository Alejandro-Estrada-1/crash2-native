# Bitácora de ingeniería inversa — crash2-native (`SCUS-94154`)

Registro vivo del análisis estático y dinámico de *Crash Bandicoot 2: Cortex Strikes Back* (EUA, `SCUS-94154`).

> **Reglas de esta bitácora (ver `AGENTS.md` y `GEMINI.md`):**
> - **Clean-room:** todo dato registrado proviene exclusivamente de observaciones propias sobre `SCUS_941.54` en Ghidra y PCSX-Redux.
> - **Nada es cierto hasta verificarse en el juego:** toda hipótesis estática pasa por `re/provisional_symbols.csv` y un experimento reproducible en `re/experiments/`.
> - **Módulo obligatorio:** indicar siempre si una dirección pertenece a `main` o a `overlay:<id>` y en qué pantalla/nivel está cargado.

---

## 1. Estado del entorno

| Componente | Estado observado | Notas |
|---|---|---|
| Ejecutable principal | Listo | `../privado/exe/SCUS_941.54` (disco verificado contra Redump) |
| Ghidra | Proyecto creado | Versión `12.2` en `/opt/ghidra` (`application.java.min=25`); proyecto `../privado/ghidra/crash2` |
| `ghidra_psx_ldr` | Cargado en proyecto | Release `2026.11.08` (PSX loader, PsyQ `4.0` detectado) |
| JVM del sistema | Configurada por entorno | Por defecto `java-21-openjdk` (sin cambiar); `JAVA_HOME=/usr/lib/jvm/java-27-openjdk` solo para REA |
| MCP de Ghidra | Activo (`pyghidra-mcp==0.3.0`) | Headless sobre copia `../privado/ghidra-ro/crash2.gpr` (`JAVA_HOME=/usr/lib/jvm/java-27-openjdk`); `PSX:LE:32:default (1.5)` verificado |
| PCSX-Redux | Listo y validado | Build `561`, commit `61e3086f` (2026-11-14); CPU en intérprete, depurador activo, servidor GDB en puerto `3333` |
| `gdb` + `scripts/gdb-psx` | Verificado contra emulador | `GNU gdb (GDB) 18.1` (`mips:3000`); experimentos `001` y `002` ejecutados limpiamente (`exit 0`, `detach` correcto) |

---

## 2. Objetivos abiertos (Fase 3)

- [x] Crear proyecto de Ghidra (`../privado/ghidra/crash2`) con `ghidra_psx_ldr` (PsyQ 4.0 detectado).
- [x] Instalar y configurar MCP de Ghidra (`pyghidra-mcp==0.3.0`, `tools/ghidra/sync-ro.sh`, `../privado/ghidra-ro/crash2.gpr`) y verificar lectura de `SCUS_941.54` con lenguaje `PSX:LE:32:default (1.5)`.
- [x] Primera tarea estática con el MCP: localizar quién escribe en `DAT_8003bea4` y qué función se registra con `VSyncCallback`; propuestas registradas en `re/provisional_symbols.csv`.
- [x] Verificar dinámicamente en PCSX-Redux el ritmo de `DAT_8003bea4` (~34.5 ticks/cuadro = ~17.25 ticks/VSync), `0x80016838` (30 Hz) y la ISR `0x8003be88` 1:1 por cuadro (`001`, `002`, `003`); `0x80016868` dio `0/23` en pausa (queda pendiente solo si se prueba pantalla más ligera como título/carga).
- [x] Instalar y configurar PCSX-Redux (Build `561`, commit `61e3086f`, intérprete + GDB puerto `3333`) y validar conexión con `scripts/gdb-psx`.
- [ ] Localizar funciones PsyQ base (`SetGeomScreen`, `DrawOTag`, `VSync`, `CdRead`) y mapear XREFs.
- [ ] Identificar sistema de carga de overlays (`CdRead` / tabla de módulos).
- [ ] Localizar bucle principal (30 Hz), actualización de cámara, parámetros de proyección/recorte y lista de entidades.

---

## 3. Plantilla de entrada

```markdown
### YYYY-MM-DD — <Título corto>

- **Módulo:** `main` | `overlay:<id>` | `entorno`
- **Hipótesis:** <qué creemos o qué se evalúa>
- **Evidencia estática:** <direcciones, XREFs, constantes o comprobaciones locales>
- **Experimento:** `re/experiments/NNN-nombre.gdb` (o `.lua` / prueba manual)
- **Resultado:** `confirmado` | `descartado` | `dudoso` | `pendiente`
- **Siguiente paso:** <acción concreta>
```

---

## 4. Registro cronológico

### 2026-11-15 — Preparación: evaluación de MCP para Ghidra 12.2 y servidor GDB de PCSX-Redux

- **Módulo:** `entorno`
- **Hipótesis:** Se requiere un MCP de solo lectura capaz de consultar un proyecto existente de Ghidra 12.2 creado con `ghidra_psx_ldr` sin modificar `../privado/ghidra`, además de definir la configuración del servidor GDB en PCSX-Redux.
- **Evidencia observada (sistema local + documentación):**
  - `/opt/ghidra/Ghidra/application.properties` declara `application.version=12.2`, `application.java.min=25` y `application.java.compiler=25`.
  - `archlinux-java status` muestra `java-21-openjdk (default)` y `java-27-openjdk` disponible. Cualquier herramienta headless/Gradle fuera del lanzador de Ghidra necesita `JAVA_HOME=/usr/lib/jvm/java-27-openjdk`.
  - Herramientas ya presentes en `PATH`: `node`, `npm`, `npx`, `python3`, `uv`, `pipx`, `gdb` (`GNU gdb (GDB) 18.1`, probado con `set architecture mips:3000`). No están instalados `gradle` ni `pcsx-redux`.
  - **Comparativa MCP de Ghidra (solo lectura sobre proyecto existente 12.2 + `ghidra_psx_ldr`):**
    1. **`REA` (`morluto/rea` / `rea-agents`):** CLI/MCP en Node.js (`npx rea-agents`) que envuelve `analyzeHeadless` de Ghidra usando `GHIDRA_INSTALL_DIR` y `JAVA_HOME`. Al recibir `REA_GHIDRA_PROJECT_PATH`, copia el proyecto a un espacio propio y lo abre con `-readOnly` y `-noanalysis` validando el SHA-256 del binario: protege `../privado/ghidra` a nivel de sistema, evita conflictos de bloqueo con la GUI y no requiere compilar plugins Java con Gradle. Queda por verificar en prueba real que `analyzeHeadless` cargue el lenguaje `PSX` de `ghidra_psx_ldr` desde `~/.config/ghidra/ghidra_12.2_DEV/Extensions/`.
    2. **`ReVa` (`cyberkaida/reverse-engineering-assistant`):** Extensión Java nativa de Ghidra (GUI o headless, Java 25+ en 12.2+). Expone herramientas de escritura/scripting (no es de solo lectura por defecto) y exige versión exacta para Ghidra 12.2 o compilar con `gradle build`. Al correr dentro de Ghidra, hereda `ghidra_psx_ldr` directamente.
    3. **`GhidraMCP` (`LaurieWired/GhidraMCP` / `bethington/ghidra-mcp`):** Plugin Java en GUI (`127.0.0.1:8080`) + puente Python vía `uvx`. Hereda `ghidra_psx_ldr` en la GUI abierta, pero tampoco es de solo lectura (expone mutaciones salvo bloqueo en el cliente) y el plugin depende de la versión exacta de Ghidra (releases v2.0 apuntan a 12.1.4; para 12.2 puede requerir compilación).
    4. **`pyghidra-mcp` / `re-mcp-ghidra`:** Basados en `pyghidra` + `JPype` (headless; `pyghidra-mcp` tiene `--gui`). `pyghidra-mcp` incluye herramientas de escritura, bloquea `.gpr` en headless y crea índices (ChromaDB) junto al proyecto; `re-mcp-ghidra` prioriza recursos de lectura. Ambos dependen de `JAVA_HOME` >= 25 y de que la JVM cargue la extensión `ghidra_psx_ldr` para leer el lenguaje `PSX`.
  - **PCSX-Redux (servidor GDB):**
    - Se activa en la GUI mediante `Configuration -> Emulation` (o `Emulator -> Settings` según versión): marcar **Enable Debugger**, marcar **Enable GDB Server** y **desactivar Dynarec CPU** (usar el intérprete para que los breakpoints y pasos sean fiables).
    - Puerto TCP por defecto: **`3333`** (`localhost:3333`, configurable según compilación). En este repositorio se enlaza con `export PSX_GDB_PORT=3333` para `scripts/gdb-psx`.
- **Experimento:** No ejecutado (solo preparación; proyecto de Ghidra aún en creación y PCSX-Redux aún sin instalar).
- **Resultado:** `pendiente` (propuesta de configuración lista para revisión del humano).
- **Siguiente paso:** Confirmar qué MCP instalar (recomendado: `rea-agents` con `JAVA_HOME=/usr/lib/jvm/java-27-openjdk` y `GHIDRA_INSTALL_DIR=/opt/ghidra`) una vez terminado el proyecto `../privado/ghidra`, y validar en primera prueba la lectura del lenguaje `PSX` y firmas PsyQ.

### 2026-11-15 — Verificación previa de `rea-agents@6.9.0` (descartado para `SCUS_941.54`)

- **Módulo:** `entorno`
- **Hipótesis:** `rea-agents@6.9.0` (`REA`) puede abrir `~/Descargas/PORTS/Crash2CSB/privado/ghidra/crash2.gpr` (programa `SCUS_941.54`, lenguaje `PSX` de `ghidra_psx_ldr`) en solo lectura mediante `REA_GHIDRA_PROJECT_PATH`.
- **Evidencia observada (sin instalar paquetes, inspeccionando el tarball npm de `rea-agents@6.9.0` y los archivos locales):**
  - `SCUS_941.54` tiene cabecera `PS-X EXE` (`50 53 2d 58 20 45 58 45`).
  - El proyecto verificado es `../privado/ghidra/crash2.gpr` y el programa en `crash2.rep/idata/00/*.prp` es `SCUS_941.54`.
  - En `rea-agents@6.9.0`:
    - `GhidraClient.js` y `GhidraSessionRoot.js` crean copias temporales en `os.tmpdir()` (`/tmp/rea-ghidra-*`, fuera de los worktrees) y las borran al cerrar.
    - Sin embargo, `package/dist/artifacts/artifactFormats.js` solo admite `mach-o`, `elf`, `pe`, `dos-mz`, `dos-com`, `raw-binary` y `gamecube-dol` (no `psx-exe`).
    - `package/dist/ghidra/GhidraProvider.js` (líneas 269–277) rechaza `REA_GHIDRA_PROJECT_PATH` para todo formato distinto de `elf`, `pe` o `mach-o` (`existingProjectUnsupported()`).
    - `package/dist/ghidra/GhidraRawBinaryLanguage.js` tampoco incluye `mips`.
- **Experimento:** Inspección estática del paquete `rea-agents@6.9.0` antes de instalarlo.
- **Resultado:** `descartado` (`rea-agents@6.9.0` no admite `PS-X EXE` ni proyectos con `ghidra_psx_ldr`).
- **Siguiente paso:** Elegir entre `ReVa v7.3.2` (extensión precompilada para Ghidra `12.2` en modo asistente GUI) o `pyghidra-mcp==0.3.0` (headless con `JAVA_HOME=/usr/lib/jvm/java-27-openjdk` sobre una copia en `../privado/ghidra-ro`).

### 2026-11-15 — Hipótesis inicial (análisis estático del humano): `FUN_8001645c` (fin de cuadro)

- **Módulo:** `main` (pendiente de confirmar en el proyecto `../privado/ghidra/crash2` con REA)
- **Hipótesis:** `FUN_8001645c` corresponde al fin de cuadro / sincronización de buffers de pantalla.
- **Evidencia estática (observada por el humano en Ghidra, pendiente de verificación en REA y emulador):**
  - Llamada a `DrawSync(0)`.
  - Rotación de tres punteros/estructuras en `DAT_80063450`, `DAT_80063454` y `DAT_80063458`.
  - Llamada a `VSync(0)` en `0x80016838`.
  - Llamada condicional a `VSync(0)` en `0x80016868` cuando `(DAT_8003bea4 - *(DAT_80063450 + 0xc)) < 0x19`.
  - Incógnita abierta: qué rutina escribe/incrementa `DAT_8003bea4` (posible contador de VSync/ticks).
- **Experimento:** No ejecutado (pendiente de instalar REA y posteriormente configurar PCSX-Redux).
- **Resultado:** `pendiente` (solo análisis estático; sin verificar en el juego).
- **Siguiente paso:** Tras confirmar la instalación de `REA`, consultar `../privado/ghidra/crash2` en solo lectura para localizar qué escribe en `DAT_8003bea4` y qué función se registra en `VSyncCallback`, registrando las propuestas en `re/provisional_symbols.csv`.

### 2026-11-15 — Activación de `pyghidra-mcp==0.3.0`, escrituras en `DAT_8003bea4` y callback de `VSyncCallback`

- **Módulo:** `main` (`SCUS_941.54`, verificado en `../privado/ghidra-ro/crash2.gpr` con `Language ID: PSX:LE:32:default (1.5)`, `PsyQ Version: 4.0.0`, `Executable Format: PSX Executables Loader`)
- **Hipótesis:**
  1. `DAT_8003bea4` es un contador de tiempo/VSync incrementado por una interrupción periódica.
  2. `VSyncCallback` registra la rutina encargada de avanzar dicho contador.
- **Evidencia estática (vía `pyghidra-mcp==0.3.0`, solo lectura):**
  - **Escrituras a `DAT_8003bea4` (`0x8003bea4`):**
    1. **`0x8003be88` (`LAB_8003be88`, rutina hoja aún sin función en Ghidra) en `0x8003bea0`:** incrementa `DAT_8003bea4` en `+1`:
       `8003be88 lui v1,0x8004; 8003be8c addiu v1,v1,-0x415c; 8003be90 lw v0,0(v1); 8003be98 addiu v0,v0,1; 8003be9c jr ra; 8003bea0 _sw v0,0(v1)`.
       Está registrada en `FUN_80015614` (`0x80015704`–`0x8001570c`) mediante `OpenEvent(0xf2000002, 2, 0x1000, &LAB_8003be88)`, seguido de `EnableEvent()`, `SetRCnt(0xf2000002, 0x1000, 0x1000)` (`0x80015724`–`0x80015734`) y `StartRCnt(0xf2000002)`.
       - **Base y supuesto sobre el divisor `/8`:** al inspeccionar `SetRCnt` (`0x80049dcc`, PsyQ 4.0) en el binario, para `param_1 == 2` (`0xf2000002 & 0xffff`) y `(param_3 & 1) == 0` (`RCntMdSC` desactivado, caso `param_3 = 0x1000`), `SetRCnt` parte de `uVar3 = 0x48`, lo cambia a `0x248` (`if (param_1 == 2 && (param_3 & 1) == 0)`) y como `(param_3 & 0x1000) != 0` aplica `uVar3 |= 0x10`, escribiendo **`0x258`** (`0x0200 | 0x0040 | 0x0010 | 0x0008`) en el registro de modo del contador 2 (`*(PTR_TMR_DOTCLOCK_VAL_8005cb4c + 0x24)`) y `0x1000` como target (`+0x28`). **Supuesto:** siguiendo la especificación hardware del registro `T2_MODE` de PS1 (donde los bits 8–9 seleccionan la fuente de reloj y el bit 9 = `0x200` corresponde a `SysClk/8`) y la coherencia con los umbrales `0x11` (17) y `0x22` (34) del juego, asumimos una tasa de `~33.8688 MHz / 8 / 0x1000 ≈ 1033.6 Hz` (~17.2 ticks por VSync NTSC de 60 Hz y ~34.4 por cuadro de 30 Hz). **Falta verificar dinámicamente en PCSX-Redux** que efectivamente sube ~17 ticks por VSync (`re/experiments/001-ticks-rcnt2-vsync.gdb`).
    2. **`FUN_8001645c` en `0x800168d8`:** cuando `(DAT_8006cb94 & 0x200000) != 0`, detiene `StopRCnt(0xf2000002)` y suma manualmente `DAT_8003bea4 += 0x22`.
    3. **`FUN_8001645c` en `0x80016940`:** si `DAT_8006cd14 == 2`, asigna `DAT_8003bea4 = *DAT_8005f374`.
    4. **`FUN_80011800` en `0x80011990`:** restaura `DAT_8003bea4 = DAT_8005f2c4` (en un flujo ligado a `DAT_8005f180`).
    5. **`FUN_80037698` en `0x80037e10`:** asigna `DAT_8003bea4 = *puVar1` (despachador de opcodes `case 0xc`, subcaso `0xd`; subcaso `0xc` lo lee).
  - **`VSyncCallback` (`0x8004a708`):**
    - Solo tiene 2 XREFs, ambos dentro de PsyQ `libsnd` 4.0:
      - `SSSTART_OBJ_18C` (`0x80054d58`, llamada en `0x80054d7c`): registra `SsSeqCalledTbyT` (`0x80054f04`, leído de `PTR_SsSeqCalledTbyT_8005efe0 = 0x80054f04`) si `DAT_8005efe8 != 0`.
      - `SsEnd` (`0x80052b80`, llamada en `0x80052bcc`): pasa `(f *)0x0` para desregistrar el callback.
    - **Resultado parcial sobre `VSyncCallback`:** el juego no usa `VSyncCallback` para su contador de cuadro; ese callback es exclusivamente de audio (`SsSeqCalledTbyT`), mientras que el reloj de cuadro del juego es la interrupción de `RCntCNT2` (`0x8003be88`).
  - **Confirmación estática adicional de `FUN_8001645c` y `FUN_80016f04`:**
    - En `FUN_8001645c`: confirmado `DrawSync(0)`, rotación `DAT_80063450`/`54`/`58`, `VSync(0)` en `0x80016838`, `VSync(0)` condicional en `0x80016868` con `(uint)(DAT_8003bea4 - *(int *)(DAT_80063450 + 0xc)) < 0x19`, escritura de la marca de cuadro en `*(DAT_80063454 + 0xc)` (`0x80016958`), `PutDispEnv`, `PutDrawEnv` y `DrawOTag`, llamado al final del bucle `FUN_80011800`.
    - **`FUN_80016f04` (`quantize_frame_ticks`, `0x80016f04`–`0x80016f40`):**
      - Único XREF en el binario: `FUN_8001645c` en `0x80016974` (`jal 0x80016f04`), pasándole `a0 = *(int *)(DAT_80063454 + 0xc) - *(int *)(DAT_80063450 + 0xc)` (`0x80016978 _subu a0,v0,a0`) y almacenando su retorno en `*(DAT_80063450 + 0x14)` (`0x80016988 sw v0,0x14(v1)`).
      - Desensamblado/pseudocódigo verificado: si `param_1 < 0` devuelve `0x22`; si `< 0x13` devuelve `0x11`; si `< 0x24` devuelve `0x22`; si `< 0x35` devuelve `0x33`; si `>= 0x35` devuelve `param_1` sin cuantizar (múltiplos de `0x11` = 17 ticks). Queda pendiente revisar qué funciones leen el campo `+0x14` de la estructura de `DAT_80063450`.
    - **Nota sobre nombres provisionales (`sys_init` y `main_loop`):** `FUN_80015614` (`sys_init`) y `FUN_80011800` (`main_loop`) se mantienen en `re/provisional_symbols.csv` como `propuesto` con etiqueta de nombre provisional; todavía falta verificar sus llamadores y alcance completo antes de fijar esos nombres.
- **Experimento:** Preparados sin ejecutar [001-ticks-rcnt2-vsync.gdb](re/experiments/001-ticks-rcnt2-vsync.gdb) y [002-frecuencia-vsync-extra.gdb](re/experiments/002-frecuencia-vsync-extra.gdb) (ver resultados dinámicos abajo).
- **Resultado:** `propuesto` (análisis estático completado; verificación dinámica registrada en la entrada siguiente).
- **Siguiente paso:** Promoción humana en `re/symbols.csv` cuando corresponda y probar `0x80016868` en una escena ligera o pausa.

### 2026-11-15 — Experimentos 001 y 002 en PCSX-Redux (tasa de `DAT_8003bea4` y frecuencia de `0x80016838` / `0x80016868`)

- **Módulo:** `main` (`0x80016838`, `0x80016840`, `0x80016868`, `0x80016870`, `0x8003bea4`, `0x8006ccf0`)
- **Precondición:** PCSX-Redux Build `561` (`61e3086f`, 2026-11-14), CPU en intérprete, depurador activo, GDB en `localhost:3333`; slot 1 cargado dentro del primer nivel con Crash quieto.
- **Hipótesis:**
  1. Bajo el supuesto `SysClk/8` en `RCntCNT2`, `DAT_8003bea4` avanza ~17 ticks por VSync (~34.4 por cuadro de 30 Hz).
  2. `FUN_8001645c` ejecuta `VSync(0)` en `0x80016838` una vez por cuadro (~30 Hz) y llama al `VSync(0)` extra en `0x80016868` cuando `delta < 0x19`.
- **Experimentos:** [001-ticks-rcnt2-vsync.gdb](re/experiments/001-ticks-rcnt2-vsync.gdb) ([resumen](re/experiments/001-ticks-rcnt2-vsync.md)) y [002-frecuencia-vsync-extra.gdb](re/experiments/002-frecuencia-vsync-extra.gdb) ([resumen](re/experiments/002-frecuencia-vsync-extra.md)).
- **Resultados observados (ambos terminaron con `exit 0` y `detach` limpio):**
  - **Experimento 001 (12 cuadros en `0x80016840`):** `DAT_8003bea4` pasó de `0x0002459a` (`148890`) a `0x00024738` (`149304`), con `delta_frame` alternando estrictamente entre `34` y `35` ticks (`35, 34, 35, 34, 34, 35, 34, 35, 34, 35, 34, 35`; promedio **`414 / 12 = 34.50` ticks/cuadro**). El breakpoint `0x80016868` no saltó ninguna vez en esos 12 cuadros.
  - **Experimento 002 (60 cuadros entre paso 1 y paso 61 de `0x80016838`):**
    - `cuadros medidos (0x80016838) = 60`, `delta DAT_8006ccf0 = 60` (exactamente 1 llamada a `0x80016838` por cuadro de `FUN_8001645c`).
    - `delta DAT_8003bea4 = 2071` ticks (`2071 / 60 = 34.52` ticks/cuadro; división entera GDB = `34`).
    - `disparos 0x80016868 (VSync extra) = 0`.
- **Resultado:** `confirmado` parcialmente (`DAT_8003bea4` avanza a `34.5` ticks por cuadro de 30 Hz = **`~17.25` ticks por VSync**, validando el supuesto `SysClk/8` / `~1033.6 Hz` y el ritmo 30 Hz de `0x80016838`; en el primer nivel con Crash quieto cada cuadro tarda > 1 VSync en completarse antes de `0x80016838`, por lo que `delta >= 0x19` al volver de `0x80016838` y `0x80016868` dio `0` disparos, quedando pendiente verificar un escenario ligero como pausa o mapa para observar `0x80016868` activo y medir 1 VSync directo).
- **Siguiente paso:** Repetir `001`/`002` en pantalla de mapa o menú de pausa si se quiere observar disparos de `0x80016868` (>0) y la delta directa de 1 VSync (~17 ticks) entre `0x80016840` y `0x80016870`.

### 2026-11-15 — Lectores de `*(DAT_80063450 + 0x14)`, propuesta de `frame_counter` y preparación de `003`

- **Módulo:** `main` (`0x80063450`, `0x8006ccf0`, `0x80019f08`, `0x8001d2c4`, `0x8001d63c`, `0x8001e3dc`, `0x8001e544`)
- **Hipótesis:**
  1. `*(DAT_80063450 + 0x14)` (calculado por `quantize_frame_ticks` en `frame_end_sync`) es el `dt` variable por cuadro usado para escalar física, movimiento y rotaciones (con `0x22 / 1024 ≈ 1/30 s` nominal y tope `0x66` = 102).
  2. `DAT_8006ccf0` es el contador global de cuadros lógicos (`frame_counter`).
  3. En el menú de pausa (escena ligera), `0x80016868` debería dispararse al menos parte de los cuadros y la ISR `0x8003be88` debería ejecutarse ~34–35 veces por cuadro, igualando `delta DAT_8003bea4`.
- **Evidencia estática (vía `pyghidra-mcp==0.3.0`, solo lectura):**
  - **Escritores de `*(DAT_80063450 + 0x14)`:**
    - `FUN_800160b0` (`0x800161b0`, init de doble búfer de `DAT_8006344c = 2` estructuras): inicializa `piVar2[5]` (`+0x14`) a `0x22` y `piVar2[3]` (`+0xc`) a `DAT_8003bea4`.
    - `frame_end_sync` (`0x80016974`–`0x80016988`): actualiza `*(DAT_80063450 + 0x14) = quantize_frame_ticks(*(DAT_80063454 + 0xc) - *(DAT_80063450 + 0xc))`.
    - `FUN_800158e0` (`0x80015cc8`): cuando `DAT_8006cd14 == 2` y `piVar1 == piVar7 + 0x424` (reproducción de demo/entrada), fija `*(int *)(DAT_80063450 + 0x14) = piVar7[0x423]`.
  - **Lectores de `*(DAT_80063450 + 0x14)` (todos los XREFs de `0x80063450`, aplicando tope `<= 0x66`):**
    1. **`FUN_80019f08` (`0x80019f0c`, llamada desde `FUN_8001c29c` en `0x8001c2e8` y `FUN_8001d63c` en `0x8001df84`):** copia `*(uint *)(DAT_80063450 + 0x14)` (con tope `0x66`) a la palabra de scratchpad `DAT_1f800054` (junto a `DAT_1f800050 = DAT_80060944` y `DAT_1f800058 = &DAT_8006cb70`) antes de llamar a `FUN_8003b940`. (Nota: si otras rutinas acceden a scratchpad por puntero base `0x1f800000`, Ghidra no lista XREF directo a `0x1f800054`).
    2. **`FUN_8001e3dc` (`0x8001e3e0`) y `FUN_8001e544` (`0x8001e548`):** interpolación/avance angular en base `0xfff`; calculan `(param_3 * dt) >> 10` (con tope `0x66` en `dt`) para avanzar ángulos.
    3. **`FUN_8001d2c4` (`0x8001d400`):** integración de velocidad/dirección horizontal; multiplica `*param_2 * dt` (tope `0x66`), hace `>> 10` y aplica el desplazamiento a `param_1 + 0x84`/`+0x8c`.
    4. **`FUN_8001d63c` (`0x8001d9d4`, `0x8001dadc`, `0x8001db50`, `0x8001dbf8`, `0x8001de08`, `0x8001e290`):** actualización de física/movimiento de entidad (`param_1`):
       - Aceleración y desaceleración de velocidad escalar (`+0x104`) en `0x8001d9d4`, `0x8001dadc`, `0x8001db50`, `0x8001dbf8` (`>> 10`, tope `0x66`).
       - Integración de posición X/Y/Z (`+0x60`, `+0x64`, `+0x68`) a partir de velocidades (`+0x84`, `+0x88`, `+0x8c`) multiplicadas por `dt` (`>> 10`, tope `0x66`) en `0x8001de08` (3 lecturas consecutivas).
       - Gravedad sobre velocidad Y (`+0x88`) en `0x8001e290`: `*(param_1 + 0x88) += dt * -4000` (tope `0x66`, velocidad terminal `-0x2ee000`).
    - **Observación clave para interpolación / 60+ FPS:** que la física del juego escale explícitamente por `*(DAT_80063450 + 0x14)` (cuantizado a `0x11`/`0x22`/`0x33` y limitado a `0x66`) confirma por qué la lógica no debe alterarse ni duplicarse: cualquier cambio en `rcnt2_tick_count` o `quantize_frame_ticks` afectaría directamente las velocidades, rotaciones y gravedad en `FUN_8001d63c` y `FUN_8001d2c4`.
  - **Propuesta `DAT_8006ccf0` (`frame_counter`):** solo tiene 3 XREFs: lectura y escritura `+1` al inicio de `frame_end_sync` (`0x8001647c`/`0x80016490`) y reinicio a `0` en `FUN_8002efe4` (`0x8002f088`); en `002` dio `delta == 60` en 60 cuadros.
- **Experimento:** [003-pausa-vsync-extra-e-isr.gdb](re/experiments/003-pausa-vsync-extra-e-isr.gdb) ([resumen](re/experiments/003-pausa-vsync-extra-e-isr.md)) ejecutado en menú de pausa (`exit 0`, `detach` limpio).
  - **Fase A (20 cuadros en pausa):** `disparos 0x80016868 = 0 / 20`, `delta frame_counter (0x8006ccf0) = 20`, `delta rcnt2_tick_count (0x8003bea4) = 691 ticks` (`34.55` ticks/cuadro).
  - **Fase B (3 cuadros en pausa con breakpoint en `0x8003be88`):**
    - Cuadro 1: `hits_isr(0x8003be88)=34`, `delta_0x8003bea4=34`, `extra_0x80016868=0`.
    - Cuadro 2: `hits_isr(0x8003be88)=35`, `delta_0x8003bea4=35`, `extra_0x80016868=0`.
    - Cuadro 3: `hits_isr(0x8003be88)=34`, `delta_0x8003bea4=34`, `extra_0x80016868=0`.
- **Resultado:**
  - `confirmado` dinámicamente (listo para revisión humana): `rcnt2_tick_isr` (`0x8003be88`) coincide 1:1 con `rcnt2_tick_count` (`34/34`, `35/35`, `34/34`) y `frame_counter` (`0x8006ccf0`) coincide 1:1 con los cuadros (`20/20` en `003`, `60/60` en `002`).
  - `descartado` para el menú de pausa: `0x80016868` no se dispara ahí (`0 / 23`), porque el menú de pausa mantiene el render del fondo por encima de 1 VSync.
- **Siguiente paso:** Revisión humana para promover `rcnt2_tick_isr` (`0x8003be88`) y `frame_counter` (`0x8006ccf0`) a `re/symbols.csv`; si interesa ver `0x80016868` activo (>0), probar en una pantalla 2D pura (p. ej. pantalla de título / carga).

### 2026-11-15 — Análisis estático de `0x8004A3xx` y rutinas de parcheo en RAM (PsyQ 4.0)

- **Módulo:** `main` (`SCUS_941.54`, rango de imagen `[0x80010000, 0x8005f800)`).
- **Hipótesis / Pregunta:** Qué código vive en `0x8004A3xx`, si ese rango se modifica a sí mismo en RAM o si modifica otro código en memoria en tiempo de ejecución.
- **Evidencia estática (Ghidra `ghidra_psx_ldr` + inspección del binario `SCUS_941.54`):**
  - El rango `0x8004a2b4..0x8004a47c` corresponde a funciones de `libapi` (PsyQ 4.0) enlazadas en `main`:
    - `0x8004a2ec..0x8004a34c` (`_patch_pad`, llamada por `InitPAD` en `0x8004a034` y `PAD_init` en `0x80049f98`): llama a `EnterCriticalSection` (`0x80049d1c`), invoca `B0:57` (`GetB0Table`), lee `base = *(B0Table + 0x16c)`, guarda `base + 0x884` en `DAT_8005f32c` (usado por `EnablePAD` `0x8004a2c4`) y `base + 0x894` en `DAT_8005f330` (usado por `DisablePAD` `0x8004a2d8`), **escribe `0` en 11 palabras (`0x2c` bytes) en `base + 0x594..0x5bc`** y llama a `FlushCache` (`0x8004a354`). (`ExitCriticalSection` lo ejecuta el llamador justo después).
    - `0x8004a354..0x8004a360` (`FlushCache`, `A0:44`): `li t2,0xa0; jr t2; _li t1,0x44`. Unica implementación de `li t1,0x44` en todo `SCUS_941.54`, con 5 XREFs de llamada: `_patch_pad` (`0x8004a338`), `_send_pad` (`0x8004a3e0`), `_remove_ChgclrPAD` (`0x8004a45c`), `_patch_gte` (`0x8004f23c`) y `FUN_8005b118` (`0x8005b15c`).
    - `0x8004a364..0x8004a388` (`_SendPAD`): llama indirectamente vía `*DAT_8005f338` (0 XREFs de llamada en el binario).
    - `0x8004a38c..0x8004a420` (`_send_pad`, llamada por `InitPAD` en `0x8004a068` y `PAD_init` en `0x80049fcc`): llama a `EnterCriticalSection`, invoca `B0:57`, lee `base = *(B0Table + 0x16c)`, guarda `base + 0x7a0` en `DAT_8005f338`, **copia las 4 palabras (`0x10` bytes) de `0x8004a408..0x8004a414` (`0x00551024`, `0`, `0`, `0`) en dos zonas del controlador PAD en BIOS RAM (`base + 0x3d8` y `base + 0x4e0`)**, llama a `FlushCache` y `ExitCriticalSection`.
    - `0x8004a424..0x8004a47c` (`_remove_ChgclrPAD`, llamada por `InitPAD` en `0x8004a024` y `PAD_init` en `0x80049f88`): invoca `B0:57`, lee `base = *(B0Table + 0x16c)`, **escribe `0` en 9 palabras (`0x24` bytes) en `base + 0x62c..0x64c`**, llama a `FlushCache` y `ExitCriticalSection`.
  - Cadena de llamada en arranque del juego: `start` (`0x80049b2c`) -> `main` (`0x800117bc`) -> `FUN_80015614` (`0x800156d4`) -> `FUN_80015828(2)` (`0x80015890`) -> `InitPAD` (`0x8004a000`) -> `_remove_ChgclrPAD`, `_patch_pad`, `_send_pad`.
  - Otras rutinas del binario que parchean RAM del kernel vía `GetC0Table` (`B0:56`) y llaman a `FlushCache` (`0x8004a354`):
    - `_patch_gte` (`0x8004f1f8`, llamada por `InitGeom` `0x8004ec38`): copia 14 palabras (`0x38` bytes, `0x8004f260..0x8004f297`) sobre `*(C0Table + 0x18)` antes de `FlushCache`.
    - `FUN_8005b118` (`0x8005b118`, posible `_ExitCard`, llamada por `StopCARD` `0x8005b0c0` <- `FUN_80036304`): copia 3 palabras (`0x0c` bytes en `0x8005b180..0x8005b18b`, `0` en el binario) hacia `*(C0Table + 0x18) + 0x70` antes de `FlushCache`.
  - **Escrituras sobre `0x8004A3xx` (análisis estático):** un barrido completo de `SCUS_941.54` (`0x80010000..0x8005f800`) no encontró ninguna pareja `lui`/`addiu|sw|sh|sb` ni puntero de 32 bits en tablas que apunte a `0x8004a200..0x8004a4ff` para escritura; las referencias a `0x8004a000..0x8004afff` son solo lecturas de constantes/tablas (`0x8004a408..0x8004a418` en `_send_pad`, `_Pad1`, `_IsVSync`) o llamadas `jal`. Sus únicas escrituras dentro de la imagen `[0x80010000, 0x8005f800)` caen en variables de estado/punteros en `0x8005f324..0x8005f344`.
  - **Mecanismo real en ejecución con OpenBIOS (hallazgo clave, corrige la hipótesis anterior):**
    - Aunque estáticamente en `SCUS_941.54` nadie escribe en `0x8004A3xx`, en tiempo de ejecución **OpenBIOS sí reescribe `0x8004a308`, `0x8004a3a8` y `0x8004a440`** (es código modificado por el BIOS, no automodificación del juego).
    - En `psxrecomp` (`generated/OpenBIOS_full.c` y `recompiler/seeds/openbios_elf_seeds.json`, OpenBIOS `55fbf04`), `getB0table` (`0xBFC05BB0`, syscall `B0:57`) pasa `$ra` del llamador a `patch_hook` (`0xBFC07E84`). Según la firma del código en `$ra`, `patch_hook` delega en:
      - `patch_pad_2_execute` (`0xBFC0817C`): parchea los punteros de juego (`DAT_8005f32c`/`DAT_8005f330`) y reescribe desde `$ra = 0x8004a308` con `nop; nop; b +10; nop` (`0x00000000, 0x00000000, 0x1000000a, 0x00000000`, saltando a `0x8004a33c`, después de `FlushCache`).
      - `send_pad_2_execute` (`0xBFC082DC`): parchea el puntero de `_SendPAD` (`DAT_8005f338`, `0x000040b0` observado en `OpenBIOS_full.c`) y reescribe desde `$ra = 0x8004a3a8` con `nop; nop; b +12; nop` (`0x1000000c`, saltando a `0x8004a3e4`, después de `FlushCache`).
      - `remove_ChgclrPAD_2_execute` (`0xBFC08254`): reescribe desde `$ra = 0x8004a440` con `nop; nop; b +5; nop` (`0x10000005`, saltando a `0x8004a460`, después de `FlushCache`).
    - Nota sobre `SCPH1001.toml` / BIOS retail vs. OpenBIOS: en un BIOS retail no existe este hook sobre el llamador (por eso `SCUS_941.54` trae los parches hacia `*(B0Table + 0x16c)`), mientras que en OpenBIOS (tanto `psxrecomp` como PCSX-Redux) sí se reescribe la página `0x8004A000` en RAM. A partir de aquí, todo experimento en `re/experiments/` registra explícitamente la BIOS usada.
- **Experimento ejecutado (PCSX-Redux + OpenBIOS):** [004-codigo-modificado-8004a3xx.gdb](re/experiments/004-codigo-modificado-8004a3xx.gdb) ([resumen](re/experiments/004-codigo-modificado-8004a3xx.md)) — solo lectura, `exit 0`, `[Inferior 1 (process 1) detached]`.
  - **Observado en RAM viva (`0x8004a2ec..0x8004a47f`, 101 palabras):**
    - `0x8004a308` (`_patch_pad`): `00000000 00000000 1000000a 00000000` (`nop; nop; b +10; nop`, exactamente lo esperado; EXE original `8c42016c...`).
    - `0x8004a3a8` (`_send_pad`): `00000000 00000000 1000000c 00000000` (`nop; nop; b +12; nop`).
    - `0x8004a440` (`_remove_ChgclrPAD`): `00000000 00000000 10000005 00000000` (`nop; nop; b +5; nop`).
    - Las otras 89 palabras del bloque coinciden palabra por palabra con `SCUS_941.54`.
  - **Punteros poblados en `0x8005f324..0x8005f344`:**
    - `DAT_8005f32c` (`EnablePAD`) = `0xbfc088f4`, `DAT_8005f330` (`DisablePAD`) = `0xbfc08904`, `DAT_8005f338` (`_SendPAD`) = `0x00003f88`.
    - Retornos de `InitPAD` guardados: `DAT_8005f324 = 0x8004a03c`, `DAT_8005f334 = 0x8004a070`, `DAT_8005f344 = 0x8004a02c`.
- **Resultado:** `confirmado` dinámicamente que **OpenBIOS** (`getB0table` → `patch_hook`) es el autor de las reescrituras en `0x8004a308/a3a8/a440`, descartando que el juego (`SCUS_941.54`) modifique su propio código en `0x8004A3xx`. Promovidos a `re/symbols.csv`: `_patch_pad` (`0x8004a2ec`), `_send_pad` (`0x8004a38c`), `_remove_ChgclrPAD` (`0x8004a424`) y `FlushCache` (`0x8004a354`); `_SendPAD` (`0x8004a364`) y `_patch_gte` (`0x8004f1f8`) quedan como `propuesto` (sin prueba en vivo).

### 2026-11-15 — Discrepancia entre versiones de OpenBIOS y propuesta para identificar la BIOS

- **Entorno / Hallazgo:** al comparar los punteros instalados en RAM por OpenBIOS en `004` (PCSX-Redux) contra los observados en el OpenBIOS de `psxrecomp` (`OpenBIOS_full.c`, commit `55fbf04`), las direcciones no coinciden:

| Puntero en juego | PCSX-Redux (`004`) | `psxrecomp` (`55fbf04`, `OpenBIOS_full.c`) |
|---|---|---|
| `DAT_8005f32c` (`EnablePAD`) | `0xbfc088f4` | `0xbfc07734` |
| `DAT_8005f330` (`DisablePAD`) | `0xbfc08904` | `0xbfc07744` |
| `DAT_8005f338` (`_SendPAD`) | `0x00003f88` | `0x000040b0` |

- **Hipótesis:** PCSX-Redux incluye una versión/compilación distinta de OpenBIOS que la fijada por `psxrecomp` (`55fbf04`); el mecanismo `getB0table` → `patch_hook` es equivalente, pero cambian los desplazamientos internos de la ROM/kernel.
- **Resultado (`confirmado` por hashes SHA-256 de 512 KiB):**
  - PCSX-Redux Build `561` (`resources/openbios.bin`): `8a8925807952965c4a116239a21903476c5c585387a1d4778a90b9b9c01804ee`
  - `psxrecomp` (`build-release/bios/openbios.bin`, OpenBIOS `55fbf04`): `fabe498fbf224e4721f12f31b6f5fe0659205e341dc4e5c5f91b9bd1a1011c57`
  - Los hashes son distintos: queda confirmado que son versiones diferentes de OpenBIOS, lo que explica la discrepancia de punteros observada en `004`.
  - **Regla operativa de comparación:** para comparar emulador y port de forma exacta (p. ej. direcciones dentro de ROM/kernel o parches de BIOS), PCSX-Redux debe configurarse para cargar la misma ROM de OpenBIOS que `psxrecomp` (`sha256: fabe498fbf224e4721f12f31b6f5fe0659205e341dc4e5c5f91b9bd1a1011c57`).
- **Propuesta de registro exacto de la BIOS por experimento (sin versionar binarios):**
  - Leer la ROM mapeada en `0xbfc00000..0xbfc80000` (512 KiB) de forma temporal y de solo lectura —por ejemplo, en GDB `dump binary memory /tmp/psx_bios.bin 0xbfc00000 0xbfc80000`, calcular `sha256sum /tmp/psx_bios.bin` (o `crc32`) y borrar `/tmp/psx_bios.bin` de inmediato, o calcular el hash desde consola Lua en PCSX-Redux— y anotar en `# BIOS:` del `.gdb` (ver [000-plantilla.gdb](re/experiments/000-plantilla.gdb)) y en el resumen `.md` el nombre de la BIOS, la build del emulador y ese hash (además de cualquier cadena de versión/build presente en la ROM si aplica).

### 2026-11-15 — PsyQ base, ausencia de overlays MIPS nativos y sistema de paginación NSD/NSF

- **Objetivo (inicio de Fase 3, bloque PsyQ + overlays):** localizar `SetGeomScreen`, `DrawOTag`, `PutDispEnv`, `PutDrawEnv`, `VSync` y `CdRead` en `SCUS_941.54` (`main`), mapear sus XREFs, determinar qué overlays existen y cómo/dónde se cargan en RAM, y revisar si `sys_init`, `main_loop` y `quantize_frame_ticks` quedan listos para verificación/promoción.
- **Arranque y heap del ejecutable (`SCUS_941.54`, `pc0=0x80049b2c`, `t_addr=0x80010000`, `t_size=0x4f800`):**
  - `start` (`0x80049b2c`, `SNMAIN.OBJ/__SN_ENTRY_POINT`) limpia BSS de `DAT_8005f2a4` hasta `&DAT_8006f1f0`, fija `DAT_8005cb28 = &DAT_8006f1f0`, inicializa el asignador propio con `FUN_8001144c(&DAT_8006f1f4)` e invoca `main` (`0x800117bc`) en `0x80049bc8`.
  - `main` (`0x800117bc`) fija `DAT_8005f1a4 = 1` (modo CD; en `0` existen cadenas de desarrollo `"c:/src/crash2/target/"` + `"streams/"` en `0x80010000..0x8001006f`), invoca `sys_init` (`0x800117d8`), entra a `main_loop(0x3c)` (`0x800117e0`) y termina en `sys_shutdown` (`0x800157a0` en `0x800117e8`).
  - Asignador dinámico propio sobre la arena posterior al BSS (entre `0x8006f1f4` y `DAT_8005f2b4`, con cabeza en `DAT_80062bac` y centinela `0xfffffffe`): `heap_alloc` (`0x8001148c`, 11 XREFs), `heap_free` (`0x800116c0`, 9 XREFs) y `heap_realloc` (`0x800116d4`, 2 XREFs).
- **Funciones PsyQ base y XREFs mapeados (`SCUS_941.54`):**

| Dirección | Símbolo PsyQ | XREFs en juego | XREFs internos PsyQ / notas |
|---|---|---|---|
| `0x8004f008` | `SetGeomScreen` | **4**: `FUN_80016c58` (`0x80016ec4`), `FUN_8001798c` (`0x800179c0`), `FUN_800200a8` (`0x80020890`), `FUN_8002f6c8` (`0x8002f8b4`) | `gte_ldH a0; jr ra; _nop`. Vecinas: `InitGeom` (`0x8004ec30`, `sys_init` en `0x80015640`), `SetGeomOffset` (`0x8004efe8`, `FUN_8001798c` en `0x800179cc` y `FUN_80017bc4` en `0x80017f70`). Además lecturas `cfc2` (`gte_stH t7`) en `0x8004457c`/`0x800447c4`. |
| `0x8004c644` | `DrawOTag` | **1**: `frame_end_sync` (`0x80016a18`) | Único llamador del binario (`DrawOTagEnv` `0x8004c7bc` tiene 0 XREFs). Envía `DAT_80063454 + 0x18` cuando `DAT_800675ac == 0`. |
| `0x8004c910` | `PutDispEnv` | **2**: `FUN_800160b0` (`0x800161b4`), `frame_end_sync` (`0x800169ac`) | `FUN_800160b0` define 2 buffers `512x240` (`SetDefDispEnv`). |
| `0x8004c6b8` | `PutDrawEnv` | **3**: `FUN_8001601c` (`0x8001604c`), `FUN_800160b0` (`0x800161c4`), `frame_end_sync` (`0x800169bc`) | `FUN_8001601c` limpia `0,0..1024,512`; `FUN_800160b0` fija `SetDefDrawEnv(..., iVar1, 0xc, 0x200, 0xd8)` (`512x216` con `y=12`, origen de las franjas negras de 12 líneas; `FUN_80016c58` dibuja 3 `POLY_F4` y recalcula `SetGeomScreen`). |
| `0x8004a484` | `VSync` | **11** en 4 sitios: `frame_end_sync` x2 (`0x80016838`, `0x80016868`), `FUN_80036164` x4 (`0x8003625c..8c`, MC), `FUN_80035444` x3 (`0x80035540/5c/d0`, MC) y código MC sin función en `0x80034b44`/`0x80034b64` x2 | **+19 en PsyQ** (`CD_cw` x2, `CD_sync` x2, `CD_datasync` x2, `CDREAD_OBJ_6B8` x1, `cd_read_retry` x3, `CdReadSync` x2, `CD_ready` x2, `CDREAD_OBJ_1A4` x3, `set_alarm` x1, `get_alarm` x1). `VSyncCallback` (`0x8004a708`) solo tiene 2 XREFs en `libsnd` (`SsEnd` y `SSSTART_OBJ_18C`). |
| `0x80048f74` | `CdRead` | **3**: `cd_read_file_sync` (`0x800123f0` en `0x800124c4`), `cd_read_sectors_sync` (`0x80031680` en `0x800316bc`) y `cd_async_read_page` (`0x80012f24` en `0x80013008`) | **0 en PsyQ.** Vecinas usadas por el juego: `CdReadSync` (`0x80049078`, XREFs `0x80012ee4` y `0x800316c8`), `CdControl` (`0x80046b50`, 3 en juego + 3 `cd_read_retry`), `CdControlF` (`0x80046c88`, 2 en juego + 5 `libcd`), `CdSync` (`0x80046ae0`, 4 en juego), `CdIntToPos` (`0x80046f9c`, 4 en juego). `CdSearchFile` no está enlazada. |

- **Conclusión sobre overlays y código en RAM (corregida — SÍ existe código MIPS nativo dinámico dentro de chunks `GOOL` `.NSF`):**
  1. **Disco ISO9660 (`Crash Bandicoot 2 - Cortex Strikes Back (USA).bin`, PVD `CD001`, volumen `SCUS-94154`):** efectivamente no existen `.BIN`, `.OVL` ni ejecutables secundarios aparte de `/SYSTEM.CNF;1` (LBA `23`, `66` B), `/SCUS_941.54;1` (LBA `81669`, `327680` B) y **38 pares `.NSD`/`.NSF`**.
  2. **`FlushCache` (`0x8004a354`):** confirmado **0 llamadas en código del juego** (`0x80010000..0x80049174`); los 53 stubs BIOS `A0/B0/C0` y los 5 únicos XREFs de `FlushCache` (`A0:0x44`) pertenecen a inicialización PsyQ (`_patch_pad`, `_send_pad`, `_remove_ChgclrPAD`, `_patch_gte`, `FUN_8005b118`).
  3. **Corrección de base/layout de `entry_type_handlers` (`0x8005b1d8..0x8005b43f`, 22 entradas × `0x1c` B):** la tabla empieza 8 bytes antes (`0x8005b1d8` con `"NONE\0\0\0\0"`), no en `0x8005b1e0`. Layout real: `+0x00 char name[8]` (`[0]="NONE"`, `[1]="SVTX"`, `[2]="TGEO"`, `[3]="WGEO"`, `[4]="SLST"`, `[5]="TPAG"`, `[6]="LDAT"`, `[7]="ZDAT"`, `[8]="CPAT"`, `[9]="BINF"`, `[10]="OPAT"`, `[11]="GOOL"`, `[12]="ADIO"`, `[13]="MIDI"`, `[14]="INST"`, `[15]="VCOL"`, `[16]="LINK"`, `[17]="MDAT"`, `[18]="IPAL"`, `[19]="PBAK"`, `[20]="SDIO"`, `[21]="VIDO"`), `+0x08 init` (`0x8005b1e0`), `+0x0c post_load`, `+0x10 on_entry`, `+0x14 on_unload`, `+0x18 fini`. La palabra `0x00000008` en `0x8005b440` ya queda fuera de la tabla. Además, `0x8001ee64`/`0x8001efd8`/`0x8001f018` pertenecen a `[10]="OPAT"`, mientras `[11]="GOOL"` solo registra `on_entry = 0x800189c4` (`li v0,-0xff; jr ra`, nop OK).
  4. **Fe de erratas (origen real del código MIPS en heap):** la conclusión anterior de "no existen overlays MIPS nativos" queda **descartada**. Sí se ejecuta código MIPS R3000 nativo desde las páginas de heap `.NSF`, **embebido directamente dentro de la sección `sec[1]` de chunks `type = 11` (`"GOOL"`)** y despachado por el intérprete GOOL (ver sección siguiente).
- **Cómo funciona el sistema real de carga CD (paginación NSD/NSF y direcciones en RAM):**
  - **Tabla de disco `disc_file_table` (`0x80069034`, stride `12` bytes):** `iso9660_scan_levels` (`0x800316ec`, llamada en `sys_init @ 0x80015760`) lee PVD (LBA `0x10`), Path Table (`+0x8c`) y directorios `S0..S3` vía `cd_read_sectors_sync` (`0x80031680`), guardando por cada `level_id`: `+0x00 & 0x7fffff = nsd_lba`, `+0x04 & 0x1ffff = nsd_size`, `+0x08 & 0xffffff = nsf_lba`. Muestras verificadas en el disco:
    - `0x02` (`S0/S0000002`, offset `0x8006904c`): `nsd_lba=57385 (0xe029)`, `nsd_size=5844 (0x16d4)`, `nsf_lba=57388 (0xe02c)` (`pages=0xd6`, `eids=0x19b`)
    - `0x10` (`S1/S0000010`, offset `0x800690f4`): `nsd_lba=25 (0x19)`, `nsd_size=5412 (0x1524)`, `nsf_lba=28 (0x1c)` (`pages=0x4a`, `eids=0x1aa`)
    - `0x3c` (`S3/S000003C`, offset `0x80069304`): `nsd_lba=56422 (0xdc66)`, `nsd_size=3284 (0xcd4)`, `nsf_lba=56424 (0xdc68)` (`pages=0x1e`, `eids=0xb5`)
  - **Ciclo de nivel y direcciones dinámicas en RAM (`nsd_paging_state` en `0x80067588`):**
    - `main_loop` llama `level_load(&DAT_80067588, 0x3c)` al arrancar (`0x8001182c`) y realiza transición (`level_unload` en `0x80011ad0`/`0x80011df8` -> `level_load` en `0x80011b10`) cuando `next_level_id` (`0x8005f3f0`) cambia (p. ej. vía `FUN_80037698` en `0x80037dc8`, que también preposiciona la lente con `cd_preseek_level` `0x80012e4c`).
    - **Destino en RAM:** `level_load` carga el `.NSD` de forma síncrona con `cd_read_file_sync` (`0x800123f0`) hacia un bloque asignado por `heap_alloc` y reajustado por `heap_realloc`, asigna la LUT de EIDs en `DAT_80067fc4` (`nsd[0x400]*4`) y asigna un pool contiguo de hasta **21 páginas físicas de `64 KiB`** (`iVar3 << 16`, intentando desde `0x15` hacia abajo hasta caber en el heap entre `0x8006f1f4` y `DAT_8005f2b4`). No hay direcciones fijas por nivel: las direcciones dependen de las asignaciones previas en `heap_alloc`.
    - **Paginación continua por cuadro:** `main_loop` llama cada cuadro (`0x80011b48`) a `nsf_paging_pump(-1)` (`0x80012bc4`) (y zonas bloqueantes llaman `nsf_paging_wait_idle` en `0x80012dc0`), avanzando hasta `21` descriptores físicos (`0x800675b4`, stride `0x2c`) y `37` (`0x25`) virtuales (`0x80067954`, stride `0x2c`) mediante la máquina de estados `nsf_page_state_step` (`0x80013200`, 30 entradas en `PTR_LAB_80010138`) → `cd_async_read_page` (`0x80012f24`, lee en tramos de `0x20` sectores = 64 KiB desde `DAT_800675a8`) → `cd_async_sync` (`0x80012ed0`) → `nsf_page_relocate` (`0x8001254c`, relocaliza punteros si `*buf==0x1234` y `type!=1`) → `nsf_page_finish` (`0x800125f8`, registra en `DAT_80067590`/`DAT_80067fc4`, invoca `entry_type_handlers+0x8` o sube texturas `type==1` a VRAM vía `LoadImage`).
- **Revisión secundaria (`sys_init`, `main_loop`, `quantize_frame_ticks`):**
  - `sys_init` (`0x80015614`): 1 XREF exacto (`main @ 0x800117d8`); además de lo ya descrito, invoca `iso9660_scan_levels` (`0x80015760`). Listo a nivel estático; verificación en vivo en arranque en frío o indirecta por sus efectos (`0x8005cb28`, `0x80069034`, `0x8003be88`, `0x8005f1a4`).
  - `main_loop` (`0x80011800`): 1 XREF exacto (`main @ 0x800117e0` con `a0 = 0x3c`). Alcance de bucle principal completado estáticamente (`level_load`/`level_unload`/`nsf_paging_pump`/`frame_end_sync`). Queda listo para verificación en vivo (pila/estado activo en Experimento `005` y/o breakpoint sin `SIGTRAP` en transición).
  - `quantize_frame_ticks` (`0x80016f04`): 1 único XREF confirmado en `frame_end_sync @ 0x80016974` (`*(uint*)(DAT_80063450 + 0x14)`), y los 5 lectores en el binario ya mapeados (`FUN_80019f08`, `FUN_8001e3dc`, `FUN_8001e544`, `FUN_8001d2c4`, `FUN_8001d63c`). Listo para observación dinámica directa del campo cuantizado en [005-tabla-discos-y-paginas-nsf.gdb](re/experiments/005-tabla-discos-y-paginas-nsf.gdb) (quedan como `propuesto` los 3 hasta que el humano ejecute/evalúe `005` o decida si basta verificación de lectura viva).
- **Experimento (`confirmado` en vivo):** [005-tabla-discos-y-paginas-nsf.md](re/experiments/005-tabla-discos-y-paginas-nsf.md) (verificación solo-lectura en PCSX-Redux sobre nivel `0x1e`).

### 2026-11-15 — Análisis estático Frente 1 (código MIPS nativo en GOOL `sec[1]`) y Frente 2 (Cámara / Proyección / Recorte)

- **Motivación del contraejemplo (Frente 1):** las notas del port (`patches/psxrecomp/UPSTREAM.md` §2, con fragmentos recompilados en `0x800F5000`/`0x80191000`/`0x80195000` y 272 `.so`) y pistas en `overlay_captures.json` (`0x800BF000` / `0x800BFFA4` / `0x800BFFD0` y `0x80171000` / `0x801716C4` / `0x80171708`) mostraban ejecución de código MIPS en páginas del heap de RAM. Todo lo documentado abajo se verificó de forma independiente en `SCUS_941.54` (`../privado/ghidra-ro`) y la imagen ISO del juego, y quedó confirmado en vivo en [006-gool-mips-y-camara.md](re/experiments/006-gool-mips-y-camara.md).
- **Origen en disco del código MIPS en heap (`type = 11`, `"GOOL"`):**
  - En los **38 archivos `.NSF`** del disco ISO9660 existen **453** entradas con `type = 11` (`"GOOL"`), de las cuales **319** contienen bloques de instrucciones MIPS R3000 nativas embebidas en `sec[1]` que terminan en `0x03e0a809` (`jalr s5, ra`) o en `0x03e00008; 0x34150000` (`jr ra; ori s5, zero, 0`). En todas las entradas con `type != 11` de los 38 `.NSF` el conteo es **0**.
  - Muestras verificadas en el ISO coincidiendo con las regiones observadas en heap:
    - `S3/S000003C.NSF`, página `1` (`pid=3`, `lba=56456`, `ecnt=7`), `entry[2]` (`off=0x7984..0xa090`, `eid=0x6e93b94d`, `type=11`, `secs=6`, `sec_offs=['0x2c','0x44','0x1cc8','0x1ef0','0x1fc4','0x21c4','0x270c']`): su sección **`sec[1]` (`0x1c84` B)** contiene 10 bloques MIPS precedidos por la palabra `0x49be0be0`, incluyendo `sec1+0x3c4` (`page_off=0x7d8c`) y `sec1+0x3f0`.
    - `S1/S0000010.NSF`, página `16` (`lba=540`), `entry[4]` (`off=0x7648..0xb5e4`, `eid=0x66536ecd`, `type=11`), su sección **`sec[1]` (`0x31cc` B)** contiene 102 bloques MIPS precedidos por `0x49be0be0`, incluyendo `sec1+0x8c4` (`page_off=0x7f50`) y `sec1+0x920`.
- **Despacho desde `SCUS_941.54` (`gool_interpret @ 0x8003a014`):**
  - `gool_interpret` lee `a1 = *s5++` (`s5 = *(obj + 0xc0)`, cursor de bytecode GOOL), fija `$s8 = 0x1f800000`, consulta el puntero de tabla `*(0x1f80005c)` (`gool_opcode_table` en `0x8005c514..0x8005c64f`, 79 entradas) y despacha según `(a1 >> 24) & 0xff`.
  - El **opcode `0x49`** salta a **`0x8003aad4`**: `jalr s5; nop; bne s5, zero, 0x8003a06c`. Al encontrar `0x49be0be0` dentro de `sec[1]`, `$s5` apunta ya a la palabra siguiente (inicio del bloque MIPS nativo en la página de 64 KiB en heap), y la CPU salta directo al heap.
  - Los bloques MIPS de `sec[1]` examinados en `S3/p01[2]` y `S1/p16[4]` tienen **0** `jal` de regreso a `SCUS_941.54` y **0** accesos a `$gp`; manipulan `$s0` (`object*`) y `$s8` (`0x1f800000`), y salen mediante `0x03e0a809; nop` (`jalr s5, ra`, cargando en `$s5` el siguiente bytecode tras el bloque y retomando el bucle en `0x8003a06c`) o mediante `0x03e00008; 0x34150000` (`jr ra; ori s5, zero, 0`, devolviendo `$s5 = 0` para cerrar el paso en `0x8003abe8`).
  - El resto de opcodes GOOL (`0x00..0x48`, `0x4a..0x4e`) saltan únicamente a manejadores estáticos dentro de `SCUS_941.54` (`0x80037440..0x80039c08` vía `0x80039fcc`/`0x80039ff4`).
  - **Auditoría del resto de `jalr` y llamadas BIOS de `SCUS_941.54`:** de las 152 palabras `jalr` detectadas en el ejecutable, 15 caen en constantes `.rodata`/datos (`>= 0x8005b56c`); en `.text`, aparte de `0x8003aad4`, los despachos indirectos revisados usan tablas/funciones estáticas en `SCUS_941.54` (`entry_type_handlers`, árboles `0x80018aa8..0x80018dd0`, tablas `0x8005b650`/`0x8005c514`, clipping `0x80044aa0/aa8/b00` en `0x80044e84..4f30`, callbacks `FUN_800349f8` y `FUN_8003cd0c`; en `FUN_80041e5c @ 0x80041f34` `DAT_80062a18+0x10..+0x20` confirmado en vivo en `006` con punteros estáticos de `SCUS_941.54`). Los 53 stubs BIOS `A0/B0/C0` están confinados a `0x80049174..0x8005b108` y el único `FlushCache` (`A0:0x44` en `0x8004a354`) solo tiene 5 XREFs de arranque.
  - **Explicación de los artefactos en `UPSTREAM.md` §2 ("BC0x / instrucciones inválidas en heap"):** la misma sección `sec[1]` intercala bytecode GOOL (p. ej. `0x49be0be0`, cuyo nibble superior `0x12` corresponde al opcode MIPS `COP2`) entre los bloques MIPS, y comparte página de 64 KiB con otras secciones y datos no ejecutables; desensamblar linealmente toda la página interpreta datos/bytecode como instrucciones rotas.
  - **Coherencia de I-cache sin `FlushCache` en runtime:** el motor lee páginas `.NSF` por DMA (`CdRead`) sin llamadas posteriores a `FlushCache`, y `nsf_page_relocate` (`0x8001254c`) solo relocaliza tablas/punteros del chunk (sin modificar las instrucciones MIPS de `sec[1]`). El asignador de páginas (`nsf_page_alloc_evict @ 0x800136c8`) bloquea la expulsión de páginas físicas mientras su byte de fijación/refcount `+0x0f` (`DAT_800675c3`, incrementado por `eid_pin_or_load @ 0x80013f5c` / `eid_wait_and_pin @ 0x80013fd8` / `nsd_resolve_eid @ 0x80014260` y liberado por `eid_unpin @ 0x80014078` / `nsd_release_eid @ 0x800143c0`) sea `> 0`. En PS1 hardware, la caché de instrucciones de 4 KiB de mapeo directo se renueva de forma natural al ejecutarse código extenso del bucle principal/PsyQ entre recargas de páginas/niveles; en recompilación estática (`psxrecomp`), al no haber `FlushCache`, el runtime debe descubrir/invalidar cachés `.so` cuando entra código nuevo en direcciones ya vistas del heap.
- **Mapa estático de Pantalla, Recorte, Proyección y Cámara (Frente 2):**
  - **Resolución y recorte de bandas (`display_init @ 0x800160b0`, `frame_end_sync @ 0x8001645c`):** `display_init` (invocada en `sys_init @ 0x80015674`) prepara 2 contextos de `0x2094` B en `display_ctx_pool` (`0x8006345c`) rotados por `disp_ctx_front/draw/work` (`0x80063450/54/58`), con `SetDefDispEnv(..., i*0x200, 0, 0x200, 0xf0)` (`512x240`) y `SetDefDrawEnv(..., i*0x200, 0xc, 0x200, 0xd8)` (`512x216` con `y=12`). En cada cuadro, `frame_end_sync` llama a `draw_letterbox_and_fov` (`0x80016c58(DAT_8006cc94, DAT_8005f1d4)`) que dibuja 3 `POLY_F4` negros de recorte adicional, ajusta `DrawEnv` `ofs` (`0x80d`/`0x2036`), lee FOV base y reduce `H` en `(H/24)*param_1`. Luego `frame_end_sync` dibuja el fondo/horizonte con `POLY_F4` de anchura `0x200` (`512`) y altura `216`, calculando corte en `Y = (DAT_80060884 * sin(DAT_80060800) * 0xaa >> 0x14) - (unaff_s2 - 0x6c)`.
  - **Llamadores de `SetGeomScreen` (`0x8004f008`) y `SetGeomOffset` (`0x8004efe8`):**
    - `cam_init` (`0x8001798c`): fija `geom_screen` (`0x80060884`) = `0x120` (`288`), `SetGeomScreen(0x120)`, `SetGeomOffset(0,0)`, matriz de color `0x8006088c`, `cam_state_zero(&DAT_800607f4)` (`z = 0x1f400`), `DAT_80060840 = 0xe1000`, `DAT_80060844 = 0x5dc000` y limpia `geom_offset_x/y` (`0x8006cc20/24`).
    - `cam_zone_switch` (`0x800200a8`, 14 llamadores): selecciona zona `current_zone_entry` (`0x800608cc`), camino `current_cam_path` (`0x800608d4`) y progreso `cam_path_progress` (`0x800608e0`), evalúa el spline/ruta con `cam_eval_path` (`0x80026a08` → `0x80060818..38` → `0x800607f4..814`), lee la propiedad **`0x130`** vía `cam_fov_read` (`0x80023d7c`, por defecto `0x120`), y si difiere de `0x80060884` invoca `SetGeomScreen`.
    - `cam_spawn_reset` (`0x8002f6c8`, 3 llamadores): restaura `SetGeomScreen(DAT_80060884)`, resetea `cam_shake_y` (`0x8006cb78 = 0`), reinicia zona y entidad Crash (`DAT_8005f38c`).
    - `draw_letterbox_and_fov` (`0x80016c58`): modula `geom_screen` durante bandas negras llamando también a `cam_fov_read`.
    - `cam_update` (`0x80017bc4`): llama `FUN_80020a24()`, arma `cam_rot_matrix` (`0x80060754`) desde `-cam_rot` (`0x80060800..08`, orden Z→X→Y), aplica traslación `-cam_pos>>8` (`0x800607f4..fc`), genera `cam_view_matrix` (`0x80060774`) vía `cam_matrix_aspect_scale` (`0x80017af8`), aplica **`SetGeomOffset(0x100 + DAT_8006cc20, 0x6c + (DAT_8006cb78 >> 8) + DAT_8006cc24)`** (centro `256, 108` + sacudida/desplazamiento), amortigua `0x8006cb78` y sincroniza `0x8006cc04..18`.
  - **Compensación crítica de aspecto `5/8` (`0.625`, `512`px vs `320`px) para Fase 5:** tanto **`cam_matrix_aspect_scale` (`0x80017af8`)** (sobre `cam_view_matrix`: fila 1 `* -5 >> 3`, fila 2 negada) como **`model_view_matrix_build` (`0x8003d3cc`, única llamada desde `FUN_8001bd84`)** (fila 1 `* 5 >> 3`) compensan en GTE el ancho de framebuffer de `512` píxeles (`320 / 512 = 5 / 8`). Además `world_to_screen` (`0x8001ed60`) proyecta respecto a centro `(0x100, 0x6c)`. Cualquier cambio futuro de FOV/widescreen en `SetGeomScreen` sin preservar o reajustar esa razón `5/8` en ambas matrices estiraría o aplastaría la geometría respecto al fondo/2D.
- **Experimento (`confirmado` en vivo):** [006-gool-mips-y-camara.md](re/experiments/006-gool-mips-y-camara.md) ([006-gool-mips-y-camara.gdb](re/experiments/006-gool-mips-y-camara.gdb)).

### 2026-11-15 — Verificación viva de `005` y `006`, y Frente 3: Entidades GOOL, Cámara (`structs.h`) y dependencias `512x216` / `5/8`

- **Resultados dinámicos (`005` y `006`, BIOS `870563ba...`, `OpenBIOS PCSX-Redux build 561`, nivel activo `0x1e`):**
  - **`005` (`confirmado`):** `disc_file_table` (`0x80069034`) coincide exactamente con el ISO (`0x02`, `0x10`, `0x3c` y activo `0x1e` en `0x8006919c`: `nsd_lba=29760, nsd_size=5124, nsf_lba=29763`); `nsd_paging_state` (`0x80067588`) activo con `21` slots físicos (`0x800ad844..`, stride `0x10000`, `magic=0x1234`, `type=0`), `37` virtuales y `*(disp_ctx+0x14) = 0x22` (`34`, `2×0x11` por `quantize_frame_ticks`).
  - **`006` (`confirmado`):**
    1. En `0x8003aad4` (`gool_op49_exec_mips`) saltó el `tbreak` en vivo (`hops1=0`, `$ra=0x8003a574`, `$s0=0x800a0770`, `$s8=0x1f800000`) con **`$s5 = 0x8019da70`** (dentro de `phys[15]`, `EID=0x4e938ccd sec[1]=0x8019d8b4`). `x/16i 0x8019da70` mostró el bloque MIPS nativo terminando en `0x8019da84: jalr s5, ra; nop`, seguido por `.word 0x1c300e4b` y `.word 0x49be0be0` (opcode `0x49` intercalado) y el siguiente bloque MIPS en `0x8019da94`.
    2. **Auditoría BSS `DAT_80062a18`:** `0x80062a28..0x80062a38` (`+0x10..+0x20`) contiene exclusivamente punteros estáticos de `SCUS_941.54` (`0x8003dd0c`, `0x80042420`, `0x800426a0`, `0x80042548`, `0x80042818`), descartando ejecución en heap vía `0x80041f34`.
    3. `cam_matrix_aspect_scale` (`0x80017af8`) verificada palabra por palabra en RAM (`cam_rot_matrix 0x80060754` vs `cam_view_matrix 0x80060774`: fila 1 `* -5 >> 3`, fila 2 negada, traslación preservada) y `tbreak` en `SetGeomOffset` (`0x8004efe8`, `ra=0x80017f78`) midió `$a0=256 (0x100), $a1=108 (0x6c)` con `geom_screen=288`.

- **Frente 3.1 — Pool y lista activa de entidades GOOL por cuadro (Fase 6 / interpolación):**
  - **Pools y cubetas raíz (`opat_init @ 0x8001ee64`):**
    - `gool_object_pool` (`0x8006cb14`): `heap_alloc(0xd680)` = **96 slots (`0x60`) × `0x23c` (`572`) bytes**, con subestructura de metadatos enlazada en `+0x08`.
    - `gool_player_slot` (`0x8006cb10`): `heap_alloc(0x33c)` (`828` B) dedicado para Crash (`gool_player_ptr` en `0x8005f38c`).
    - `gool_root_buckets` (`0x8006cb18..0x8006cb57`): **8 cubetas raíz** (`stride 8` B, `+0x00=2, +0x04=first_child`; cubeta 4 en `0x8006cb38` para objetos tipo `0x300`/HUD, cubeta 6 en `0x8006cb48` para jugador, lista libre en `0x8006cb58..5f`).
  - **Ciclo por cuadro en `main_loop` (`0x80011800`):**
    1. `0x80011d84` llama `gool_tick_all` (`0x8001c29c(active)`), que llama `0x80018dd0(&LAB_80018cac, &gool_object_tick, active)` recorriendo en pre-orden las **8 cubetas** (`0x8006cb18..57`).
    2. `gool_object_tick` (`0x8001c718`) procesa todo nodo con `+0x04 == 3`: guarda `pos/rot` previos en pila (`+0x60..+0x74`), avanza `gool_interpret` (`0x8003a014`), llama `gool_physics_step` (`0x8001d63c` — integra velocidades con `dt = *(disp_ctx_front + 0x14)` acotado a `0x66`, `(vel * dt) >> 10`), `gool_render_prep` (`0x8001aa80`) y, según flags de visibilidad, `gool_render_enqueue` (`0x8001abf8`, agrega nodos a `*(disp_ctx_work + 0x2088)`/`+0x2090`).
    3. `0x80011d94` llama `render_queue_flush` (`0x8003db94`), que vacía `*(disp_ctx_work + 0x2088)` invocando transform, prep y draw por cada nodo encolado.

- **Frente 3.2 — Layouts observados para proponer a `re/structs.h` (no editado por agente RE):**
  - **`GoolObject` (`0x23c` B; jugador `0x33c` B en `0x8006cb10`):**
    - `+0x00`: `int32 handle` (`0` libre, `1` objeto, `2` cubeta) | `+0x04`: `int32 node_kind` (`3` objeto activo)
    - `+0x08`: `void *meta_ptr` (matriz local `0x00..0x1c`, datos SVTX `+0x20..+0x2c`, bbox `+0x30..+0x44`)
    - `+0x0c`: `void *gool_entry` | `+0x18`: `void *zone_entry` | `+0x20..+0x3f`: tint/color RGB
    - `+0x40`: `self` | `+0x44`: `parent` | `+0x48`: `next_sibling` | `+0x4c`: `first_child` | `+0x58`: `rider_or_child`
    - **`+0x60, +0x64, +0x68`**: `int32 pos[3]` (`x, y, z` fijo `<< 8`)
    - **`+0x6c, +0x70, +0x74`**: `int32 rot[3]` (`rx, ry, rz`, vuelta = `4096`)
    - **`+0x78, +0x7c, +0x80`**: `int32 scale[3]` (`sx, sy, sz`, unidad = `0x1000`)
    - `+0x84..+0x8c`: `int32 vel[3]` | `+0x90..+0x98`: ángulos/topes objetivo | `+0xa8/+0xac`: flags estado
    - `+0xb8`: `int32 entity_id` (`>>8` índice bitfield `0x8006b1c4`) | `+0xbc`: `uint32 *gool_sp` | `+0xc0`: `uint32 *gool_pc` (`$s5`) | `+0xc8`: `pending_pc`
    - `+0xe8`: `uint8 *anim_seq` (`*anim_seq`: `1` SVTX, `2` sprite, `4` texto 3D, `5` fragmentos) | **`+0xec`: `int32 anim_frame`** (`>> 8`, `0x8001a90c` ya interpola cuando flag bit 0)
    - `+0xf0`: `spawn_subentry` | `+0xf8`: `path_len` | `+0xfc`: `floor_y` | `+0x100..+0x108`: flags/speed/tint | `+0x118`: `ot_depth_bias` | `+0x120..+0x122`: `render_mode, draw_type, light_mode`.
  - **`CameraState` (`0x80060754..0x80060958` + auxiliares):**
    - `0x80060754` (`0x20` B): `MATRIX cam_rot_matrix` | `0x80060774` (`0x20` B): `MATRIX cam_view_matrix` (`-5/8` Y)
    - `0x80060794` (`0x20` B): `cam_view_matrix_copy` | `0x800607b4` / `0x800607d4`: matrices alt (`0x8001bd84`)
    - `0x800607f4..0x80060814` (`9×int32`): `pos[3]` (`7f4..7fc`), `rot[3]` (`800..808`), `scale[3]` (`80c..814`)
    - `0x80060818..0x80060838`: `cam_target_state` (`cam_eval_path` → `cam_zone_switch`) | `0x8006083c..44`: `cam_render_pos`
    - `0x80060884`: `geom_screen` (`H`) | `0x800608cc/d4/e0`: zona/camino/progreso | `0x8006cc20/24` + `0x8006cb78`: offsets y sacudida Y.
  - **`DisplayContext` (`0x8006345c`, `2` × `0x2094` B):** `+0x00` id (`0/1`), `+0x04` ot/buf base, `+0x08` `prim_ptr`, `+0x0c` `raw_ticks`, `+0x10` `draw_end_ticks`, `+0x14` `quant_ticks`, `+0x18..+0x2017` OT (`2048` words), `+0x2018` `DISPENV` (`20` B), `+0x202c` `DRAWENV` (`92` B), `+0x2088..+0x2090` cola/arena de nodos de entidades.

- **Frente 3.3 — Dependencias adicionales de `512x216` y `5/8` en HUD / sprites / fondo (Fase 5):**
  - **Tres sitios independientes con factor `5/8` en Y:** (1) `cam_matrix_aspect_scale` (`0x80017af8`, `* -5 >> 3`), (2) `model_view_matrix_build` (`0x8003d3cc` para texto 3D/HUD, `* 5 >> 3`), y (3) **`matrix_aspect_scale_local` (`0x80043090`, `-((val * 0xa0) >> 8) = -5/8` en fila Y y negación de fila Z)**, clon inline usado por **`hud_transform_2d` (`0x80044558`)** y modos `0x800443ec`/`0x800444bc`/`0x800447a4` (`0x8005b690`). `hud_transform_2d` fija `TR = (x>>8, -(y>>8), gte_stH())`, proyectando HUD respecto a `SetGeomOffset(256, 108)` sin depender de `H`, pero manteniendo escala Y `-5/8` respecto al ancho `512px`.
  - **Sprites, fondo, fundidos y recorte hardware `512x216`:**
    - `sprite_billboard_draw` (`0x80044830`, `0x8005b708[3]`): genera quad `POLY_FT4` proyectado por GTE con centro/vista activos.
    - `draw_bg_tile` (`0x80016a60`): fondo/horizonte `TILE` `512x216` usando `horizon_y` con `0xaa` (`DAT_80060884 * sin(rx) * 0xaa >> 0x14`), `0x6c` y `letterbox_level * 0x78 >> 3`.
    - `draw_screen_fade` (`0x80016b08`): `POLY_F4` de fundido sobre `0..512 × -12..228` relativo al `DrawEnv` `y=12`.
    - **4 límites de clipping pantalla `0x00d90200` (`512 × 217`):** `0x80041bf0`, `0x80041fa0` (`FUN_80041e5c`), `0x80045154` (`FUN_80044f54`) y `0x800453dc` (`draw_particles` `0x80045218`).

### 2026-11-15 — Verificación viva del Experimento `007` y cierre estático de Fase 3 (`RNG`, `PadState`, cámaras/renders especiales)

- **Resultados dinámicos de [007-gool-hud-y-entidades.md](re/experiments/007-gool-hud-y-entidades.md) (BIOS `870563ba...`, `OpenBIOS PCSX-Redux build 561`, nivel `0x1e`):**
  - **Entidades GOOL y delta por movimiento:** `gool_player_ptr` (`0x8005f38c`) == `gool_player_slot` (`0x8006cb10`) = `0x800ad504`, `gool_object_pool` (`0x8006cb14`) = `0x8009fe80`. Al desplazar a Crash entre Pasada 1 y Pasada 2 (`Start`/Pausa):
    - `zone`: `0x800d5830 -> 0x800fd860`
    - `pos (+0x60..+0x68)`: `(9414656, 1723645, 14018560) -> (10926080, 2287103, 9566208)` (reflejado idéntico en `player_pos_copy` `0x8005f494..9c`)
    - `rot (+0x6c..+0x74)`: `(0, 442, 0) -> (0, 3936, 0)` | `anim_seq (+0xe8)`: `0x80184300 -> 0x801841d4` | `anim_frame (+0xec)`: `2560 -> 5376 -> 17664` (`>>8 = 69`).
  - **REGLA OBLIGATORIA PARA FASE 6 (interpolación):** aunque un barrido plano de los 96 slots de `gool_object_pool` (`0x8009fe80`, stride `0x23c`) contó **55** slots con `+0x04 == 3` en ambas pasadas, el recorrido real del árbol arrojó cuentas exactas contra los `96 + 1 = 97` objetos totales: **15** activos en `gool_root_buckets` (`0x8006cb18..0x8006cb57`) + **82** en `gool_free_bucket` (`0x8006cb58`) = `97` en reposo; y **33** activos (incluidos nodos UI en `bucket[7]`) + **64** en `0x8006cb58` = `97` en Pausa. Como confirma estáticamente `FUN_80019e08` (`0x80019e08`), liberar un objeto lo devuelve a `0x8006cb58` **sin limpiar `+0x04`** (`= 3`). **En Fase 6 es obligatorio recorrer las 8 cubetas raíz (`0x8006cb18..0x8006cb57`) siguiendo `+0x4c first_child` / `+0x48 next_sibling`** y nunca escanear `gool_object_pool` por `+0x04 == 3`, para no interpolar objetos liberados. *(Nota de precisión: en `gool_physics_step(obj, a1, a2)`, `a1` `sp+0x18` solo contiene datos previos válidos en la rama de objeto portador/vehículo; para nodos ordinarios conserva contenido de pila).*
  - **`DisplayContext`, HUD 2D y aspecto `-5/8`:**
    - `DISPENV (+0x2018)`: `512x240` verificados en buffer `0` (`0x8006345c`, `x=0`) y `1` (`0x800654f0`, `x=512`); `DRAWENV (+0x202c)`: `clip=(0|512, 12, 512, 216)`, `ofs=(0|512, 12)`, `isbg=1`; `quant_ticks (+0x14) = 34 (0x22)`.
    - `tbreak` confirmados en vivo: `gool_object_tick` (`0x8001c718`), `gool_physics_step` (`0x8001d63c`), `render_queue_flush` (`0x8003db94`), `draw_letterbox_and_fov` (`0x80016c58`, `geom_screen=288`), `quantize_frame_ticks` (`0x80016f04`, `a0=34/35`), `draw_bg_tile` (`0x80016a60` en nivel con `level_flags=0x0c01ffff`, `a2=512, a3=216`, omitido en Pausa `0x0401dffe`), **`hud_transform_2d` (`0x80044558`)** en Pausa (`ra=0x8003dc9c, gp=0x800a2fa8`) y **`matrix_aspect_scale_local` (`0x80043090 -> 0x80043088`)** encadenada (`ra=0x800444c8` y `ra=0x80044564`) escalando la matriz GTE exactamente por `-5/8` en fila Y (`0x0d80 -> 0xf790`, `-3456*5/8 = -2160`; `0x055b -> 0xfca8`, `-1371*5/8 = -856`) y negando fila Z (`0x1333 -> 0xffffeccd`, `0x0640 -> 0xfffff9c0`).

- **Cierre estático de Fase 3 — Generadores aleatorios (`RNG` para `tools/regress`):**
  - Dos LCG idénticos estilo POSIX (`seed = seed * 0x41c64e6d + 0x3039; u = (seed / 0xf) % 0x7ffffff; return (int)u % mod`, `0` si `mod == 0`):
    - **LCG A (`rng_a_seed @ 0x8005f220`, `.sdata=1`):** `rng_a_init` (`0x8003155c`, llamada en `sys_init @ 0x8001567c`, fija `0x3039`), `rng_a_seed_set` (`0x8003156c`, llamada en `demo_playback_init @ 0x8002fd24` con `*(DAT_8005f3d8 + 4)`) y `rng_a_mod` (`0x8003147c`). En `SCUS_941.54` no hay llamadas directas (`jal`/punteros) a `0x8003147c`, y en vivo en nivel `0x1e` (`007`) `0x8005f220` se mantuvo en `0x00003039`.
    - **LCG B (`rng_b_seed @ 0x8005f224`, `.sdata=1`):** `rng_b_init` (`0x80031658`, `= 0x3039`, `0` xrefs en `SCUS`) y **`rng_b_mod` (`0x80031578`)** con 6 llamadores en `SCUS_941.54`: `demo_attract_pick` (`0x8002fef4`), prioridad/selección SPU (`0x80032a5c`), nombre/ID aleatorio de guardado Memory Card `0..999998` (`0x800354b8`, `0x8003699c`) y helpers MC (`0x80035ac4`, `0x80035bc4`). En vivo en `007`, `0x8005f224` cambió entre sesiones (`0x237c228a -> 0xaf1cf0fb`). *(Nota de auditoría: `0x8003df10..0x800417c8` y `0x80043778/8c` usan `+0xa8($gp)` sobre `$gp` = contexto local/scratchpad de renderizado SVTX/WGEO, no `0x8005f224`.)*
    - **LCG visual aislado:** `draw_water_ripples` (`0x80044f54`) y `draw_particles` (`0x80045218`) usan constantes visuales fijas locales por cuadro (`0x30125400`/`0x493583fe`) sin estado persistente de juego.

- **Cierre estático de Fase 3 — Entrada procesada (`PadState`) y reproducción de demos:**
  - `pad_init` (`0x80015828(2)`, llamada desde `sys_init 0x80015614`) fija `pad_count` (`0x8006991c`) = `2`, limpia estructuras y registra `InitPAD(&0x80069920, 0x22, &0x8006996c, 0x22)`, `StartPAD()` y `ChangeClearPAD(0)`.
  - **`PadState` (`2` × `0x4c` = `76` B, en `0x80069920` Pad 1 y `0x8006996c` Pad 2):** actualizado por `pad_update` (`0x800158e0`):
    - `+0x00..+0x21` (`34` B): buffer DMA crudo (`+0x00 raw_stat`, `+0x01 pad_type`, `+0x02..+0x03` botones crudos activo-bajo, `+0x06/+0x07` analógico Y/X calibrado con `0x8006cdd0..0x8006cde4`).
    - `+0x24` (`0x80069944`): `buttons_pressed` (`held & ~prev1 & 0xffff`).
    - `+0x28` (`0x80069948`): `buttons_held` (activo-alto, remapeo DualShock `'S'`, máscara `0x0f17` si entrada congelada, acoplo D-pad↔`0xf000` con tabla `0x8005b440`).
    - `+0x2c`: `buttons_prev1` | `+0x30`: `buttons_pressed_prev` | `+0x34`: `buttons_prev2`.
    - `+0x38`: `stick_angle` (`0..4095`) | `+0x3c`: `stick_mag` (`<0x66 -> 0`) | `+0x40`: `dir_index` (`0..7`, `8` neutro).
  - Pad 1 refleja `mag/angle` en `0x8006cd60`/`0x8006cd64`. Con **`demo_mode` (`0x8006cd14`)**: `0` juego normal (`007`), `2` reproducción (`demo_playback_init 0x8002fcf8` carga `DAT_8005f3d8`, siembra `0x8005f220`, inyecta entradas desde cursor `0x8005f374` y restaura `*(disp_ctx_front+0x14)` / `rcnt2_tick_count`), `3` selección aleatoria (`demo_attract_pick 0x8002fe58`). Lectores principales de `+0x24/+0x28`: `main_loop`, `0x80026ca0`, `0x800237f8`, `0x80036fac`.

- **Cierre estático de Fase 3 — Cámaras especiales, shaders WGEO y pasadas condicionales:**
  - **Barrido completo PsyQ en `SCUS_941.54` (`0x80010000..0x80046800`):** todos los modos (niveles a pie, vehículos, persecuciones, bonus y jefes) pasan por el mismo camino de salida (`DrawOTag` 1 xref, `PutDispEnv` 2, `PutDrawEnv` 3, `SetGeomScreen` 4, `SetGeomOffset` 2).
  - **Máquina de estados de cámara (`cam_mode_dispatch @ 0x80026ca0`, llamada en `main_loop 0x80011b60`):**
    - `DAT_8005b994`: `5` normal; `6` `0x80022a5c` (paneo interpolado multicuadro `0x8005ba14/18/1c..`); `7` `0x80022e74` (hold/warp); `9` `0x80022f58`.
    - Con `DAT_8005b994 == 5`, `switch (DAT_800608f0)` (prop `0x29`): `0` `0x8002271c`; `2` `cam_mode_rail_chase` (`0x80022878`, lookahead/persecución con prop `0x160`); `3` `cam_mode_scaled_follow` (`0x80022314`, escala X `*5>>3` si `*(DAT_8006759c+8)==3`); `4` `cam_mode_polar_360` (`0x80021a08`, polar 360°/jefes en torno a `0x8005bb00/08`); `8` `0x800225c0`; `10` `cam_mode_fixed_aim` (`0x80021f4c`, fijo/torreta con `ratan2` sobre `0x8005bb3c/44`); `default` `cam_zone_switch` (`0x800200a8`).
    - Matrices espejo/reflejo opcionales `0x800607b4`/`0x800607d4` cuando `*(current_zone_entry+0x10)+0x29c & 0x1000`, y override de control vehículo `DAT_8006cbb4` (`0` si `DAT_80062ad8 & 0x400`, vs `0x100` normal en `gool_physics_step`).
  - **Shaders WGEO y pasadas especiales (`zone_gfx_mode_apply @ 0x80020a24`, prop `0x185` -> `DAT_80062ad8` y `level_flags 0x8006cb94`):** conmuta los 5 punteros estáticos en `DAT_80062a28..38` (incluyendo oscuridad/luciérnaga `&0x100` con `0x8006cd50`, flags `0x800004`, `0x200`, `0x8000`, `8`, `0x20`, `0x200000`, `0x40` y rayos `DirnD` `level_flags & 0x1000000`) y controla tres pasadas condicionales de render: `draw_water_ripples` (`0x80044f54`, `&0x10`, clip `0xd90200`), `draw_particles` (`0x80045218`, `&0x400000`, clip `0xd90200`) y `vram_backbuf_copy` (`0x8002706c`, `level_flags & 0x40000`, `MoveImage` `(0,0x108,w,0xf0)` en `frame_end_sync`).

- **Propuesta de estructuras para `re/structs.h` (pendiente de promoción humana):**
  ```c
  /* PadState (0x4c bytes): 0x80069920 (Pad 1), 0x8006996c (Pad 2) */
  typedef struct PadState {
      uint8_t  raw[0x22];              /* +0x00: +0x00 raw_stat, +0x01 pad_type, +0x02..03 digital, +0x06..07 analogo Y/X */
      uint16_t _pad22;
      uint32_t buttons_pressed;        /* +0x24: held & ~prev1 & 0xffff */
      uint32_t buttons_held;           /* +0x28 */
      uint32_t buttons_prev1;          /* +0x2c */
      uint32_t buttons_pressed_prev;   /* +0x30 */
      uint32_t buttons_prev2;          /* +0x34 */
      int32_t  stick_angle;            /* +0x38: 0..4095 */
      int32_t  stick_mag;              /* +0x3c: <0x66 -> 0 */
      int32_t  dir_index;              /* +0x40: 0..7, 8 = neutro */
      uint32_t _unk44;                 /* +0x44 */
      uint32_t _unk48;                 /* +0x48 */
  } PadState;

  /* GoolObject (0x23c bytes en 0x8006cb14; jugador 0x33c bytes en 0x8006cb10).
     IMPORTANTE Fase 6: iterar las 8 cubetas 0x8006cb18..0x8006cb57, nunca el pool plano. */
  typedef struct GoolObject {
      int32_t  handle;                 /* +0x00: 0 libre, 1 objeto, 2 cubeta */
      int32_t  node_kind;              /* +0x04: 3 activo (no se limpia al liberar) */
      void    *meta_ptr;               /* +0x08 */
      void    *gool_entry;             /* +0x0c */
      uint8_t  _unk10[0x08];
      void    *zone_entry;             /* +0x18 */
      uint8_t  _unk1c[0x24];           /* +0x20..+0x3f color/tinte */
      struct GoolObject *self;         /* +0x40 */
      struct GoolObject *parent;       /* +0x44 */
      struct GoolObject *next_sibling; /* +0x48 */
      struct GoolObject *first_child;  /* +0x4c */
      uint8_t  _unk50[0x08];
      struct GoolObject *rider;        /* +0x58 */
      uint32_t _unk5c;
      int32_t  pos[3];                 /* +0x60..+0x68: fijo << 8 */
      int32_t  rot[3];                 /* +0x6c..+0x74: 4096 = vuelta */
      int32_t  scale[3];               /* +0x78..+0x80: 0x1000 = 1.0 */
      int32_t  vel[3];                 /* +0x84..+0x8c */
      int32_t  target_rot[3];          /* +0x90..+0x98 */
      uint8_t  _unk9c[0x0c];
      uint32_t status_flags_a;         /* +0xa8 */
      uint32_t status_flags_b;         /* +0xac */
      uint8_t  _unkb0[0x08];
      int32_t  entity_id;              /* +0xb8 */
      uint32_t *gool_sp;               /* +0xbc */
      uint32_t *gool_pc;               /* +0xc0 */
      uint32_t _unkc4;
      uint32_t *pending_pc;            /* +0xc8 */
      uint8_t  _unkcc[0x1c];
      uint8_t *anim_seq;               /* +0xe8: *anim_seq = 1 SVTX, 2 sprite, 4 texto3D, 5 frag */
      int32_t  anim_frame;             /* +0xec: fijo << 8 */
      uint8_t  _unkf0[0x28];           /* +0xf0 subentry, +0xfc floor_y */
      int32_t  ot_depth_bias;          /* +0x118 */
      uint32_t _unk11c;
      uint8_t  render_mode;            /* +0x120 */
      uint8_t  draw_type;              /* +0x121 */
      uint8_t  light_mode;             /* +0x122 */
      uint8_t  _unk123[0x119];
  } GoolObject;
  ```

---

## 5. Resumen de hallazgos verificados

### Confirmados (`re/symbols.csv`)

| Dirección | Símbolo | Módulo | Experimento | Fecha |
|---|---|---|---|---|
| `0x8003bea4` | `rcnt2_tick_count` | `main` | `001`, `002` | 2026-11-15 |
| `0x8001645c` | `frame_end_sync` | `main` | `002` | 2026-11-15 |
| `0x8003be88` | `rcnt2_tick_isr` | `main` | `003` | 2026-11-15 |
| `0x8006ccf0` | `frame_counter` | `main` | `002`, `003` | 2026-11-15 |
| `0x8004a2ec` | `_patch_pad` | `main` | `004` | 2026-11-15 |
| `0x8004a38c` | `_send_pad` | `main` | `004` | 2026-11-15 |
| `0x8004a424` | `_remove_ChgclrPAD` | `main` | `004` | 2026-11-15 |
| `0x8004a354` | `FlushCache` | `main` | estático (`NOTES.md`) | 2026-11-15 |

### Descartados

| Dirección | Hipótesis | Módulo | Motivo / Experimento | Fecha |
|---|---|---|---|---|
| `SCUS_941.54` + `.NSF` | "No existen bloques MIPS nativos cargados dinámicamente fuera de `SCUS_941.54`" | `main` / `.NSF` | Sí existen en `sec[1]` de chunks `GOOL` (`type = 11`: 319/453 entradas en disco), ejecutados vía `0x8003aad4: jalr s5` (confirmado en vivo en [006-gool-mips-y-camara.md](re/experiments/006-gool-mips-y-camara.md)) | 2026-11-15 |
| `0x8005b1e0` | Inicio de `entry_type_handlers` sin campo nombre y tipo `[21]=0x8` | `main` | La tabla empieza 8 B antes (`0x8005b1d8`, `+0x00 char name[8]` `"NONE"`..`"VIDO"`, 22 entradas hasta `0x8005b43f`) | 2026-11-15 |
