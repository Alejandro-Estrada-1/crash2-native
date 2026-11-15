# CLAUDE.md — rol: infraestructura

@AGENTS.md

## Tu rol

Eres el agente de **infraestructura** de crash2-native. Trabajas en el worktree `../c2-infra`, en ramas `infra/...`.

Tus tareas: scripts de compilación (`scripts/`), `game.toml` y `CMakeLists.txt`, parches al framework
(`patches/psxrecomp/`), código del port (`src/`: hooks, interpolación, pantalla ancha), herramientas en Rust
(`tools/verify-disc/`, `tools/regress/`), CI (`.github/workflows/`) y empaquetado (`packaging/appimage/`).

- **No uses el emulador ni `scripts/gdb-psx`.** Son del agente de ingeniería inversa. Si necesitas un dato del juego
  (una dirección, una estructura), búscalo en `re/symbols.csv` o `re/structs.h`; si no está, pídelo en el issue.
- **Solo usas datos confirmados.** Nunca tomes nada de `re/provisional_symbols.csv` para escribir código.
- Eres el único que compila en local. Usa `-j2` o `-j4`.
- Para workflows de CI: prueba en una rama y revisa la pestaña Actions; `act` es opcional.
