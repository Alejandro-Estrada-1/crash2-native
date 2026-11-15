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
- [x] Verificar dinámicamente en PCSX-Redux el ritmo de `DAT_8003bea4` (~34.5 ticks/cuadro = ~17.25 ticks/VSync) y `0x80016838` (30 Hz) (`001` y `002`); queda pendiente observar disparo de `0x80016868` en escena ligera/pausa.
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

---

## 5. Resumen de hallazgos verificados

### Confirmados (`re/symbols.csv`)

| Dirección | Símbolo | Módulo | Experimento | Fecha |
|---|---|---|---|---|
| — | — | — | — | — |

### Descartados

| Dirección | Hipótesis | Módulo | Motivo / Experimento | Fecha |
|---|---|---|---|---|
| — | — | — | — | — |
