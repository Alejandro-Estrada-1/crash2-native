English | [Español](README.es.md)

# verify-disc

Independently verifies (read-only) that the disc image specified in `game.toml`
(or via `--disc`) matches the size, CRC-32, MD5, and SHA-1 Redump table
declared under `[prepare_disc]`.

Computes all three digests in a single sequential block-buffered pass, with zero
external crate dependencies and without modifying anything inside `disc/`.

## Usage

```bash
cargo run --manifest-path tools/verify-disc/Cargo.toml --
cargo run --manifest-path tools/verify-disc/Cargo.toml -- --disc "disc/Crash Bandicoot 2 - Cortex Strikes Back (USA).cue"
cargo run --manifest-path tools/verify-disc/Cargo.toml -- --config game.toml --json
```

Options:

- `--config <path>`: `game.toml` file to read (`game.toml` by default).
- `--disc <path>`: `.cue` or `.bin` image to verify (defaults to `[game] disc`
  in `game.toml`, resolved relative to the `game.toml` directory).
- `--json`: prints the verification report as single-line JSON.

## Exit Codes

- `0`: image matches the values declared under `[prepare_disc]`.
- `2`: argument, I/O, or parsing error (`game.toml` or `.cue`).
- `3`: image size or at least one expected hash does not match.

## Tests

Unit and integration tests use temporary synthetic files and do not require the
real game disc:

```bash
cargo test --manifest-path tools/verify-disc/Cargo.toml
```
