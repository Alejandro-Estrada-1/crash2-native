[English](README.md) | Español

# verify-disc

Verifica de forma independiente (solo lectura) que la imagen de disco indicada
en `game.toml` (o con `--disc`) coincide en tamaño, CRC-32, MD5 y SHA-1 con
la tabla Redump declarada en `[prepare_disc]`.

Calcula los tres resúmenes en una sola pasada secuencial por bloques, sin
dependencias externas y sin modificar ningún archivo de `disc/`.

## Uso

```bash
cargo run --manifest-path tools/verify-disc/Cargo.toml --
cargo run --manifest-path tools/verify-disc/Cargo.toml -- --disc "disc/Crash Bandicoot 2 - Cortex Strikes Back (USA).cue"
cargo run --manifest-path tools/verify-disc/Cargo.toml -- --config game.toml --json
```

Opciones:

- `--config <ruta>`: archivo `game.toml` a leer (`game.toml` por defecto).
- `--disc <ruta>`: imagen `.cue` o `.bin` a verificar (por defecto `[game] disc`
  de `game.toml`, resuelto respecto al directorio del `game.toml`).
- `--json`: imprime el reporte en formato JSON en una línea.

## Códigos de salida

- `0`: la imagen coincide con los valores declarados en `[prepare_disc]`.
- `2`: error de argumentos, lectura o análisis (`game.toml` o `.cue`).
- `3`: la imagen no coincide con el tamaño o con algún hash esperado.

## Pruebas

Las pruebas unitarias y de integración usan archivos temporales sintéticos y no
requieren el disco real del juego:

```bash
cargo test --manifest-path tools/verify-disc/Cargo.toml
```
