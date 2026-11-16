[English](README.md) | Español

# tools/regress — pruebas de regresión por estado lógico

Herramienta en Rust (pendiente, Fase 6/7) que reproduce replays y compara el
**estado lógico** del juego (posiciones, estado de entidades, RNG, contadores)
contra una referencia. Nunca compara imágenes. Con interpolación o pantalla
ancha activadas, el estado debe ser idéntico bit a bit al de referencia
(`AGENTS.es.md`, "Prioridades técnicas").

## Condiciones fijas de cada referencia

Una referencia solo es comparable con corridas hechas en las mismas condiciones.
Cada referencia debe registrar estas, y la herramienta debe negarse a comparar si
alguna difiere:

- **BIOS: hoy, OpenBIOS** (la que trae psxrecomp, `bios/openbios.bin`). Con otra
  BIOS el código del juego en RAM no es el mismo: OpenBIOS reescribe al arrancar
  las funciones PsyQ `_patch_pad`, `_send_pad` y `_remove_ChgclrPAD`
  (`0x8004A2EC`–`0x8004A47C`) para que salten el parche del kernel; con una BIOS
  de Sony esas funciones corren sin cambios y parchean el kernel. El manejo del
  pad puede diferir. Detalle y evidencia: `patches/psxrecomp/UPSTREAM.es.md`, punto 6.
  Registrar también si la BIOS fue saltada (`bios_boot=HLE`) o no.
- Disco (SHA-1 de Redump) y commit del framework (`psxrecomp`).
- Seeds y C generado (hash de `generated/`).
- Configuración que afecte la lógica (`game.toml`, mods activos).
