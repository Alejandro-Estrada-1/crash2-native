#!/usr/bin/env bash
# Genera el C de Crash 2 desde el disco y compila el runtime nativo.
#
#   scripts/build_linux.sh                 # emisores + generar + compilar
#   scripts/build_linux.sh --sin-generar   # solo recompilar (C ya generado)
#   scripts/build_linux.sh -j 4            # hilos (también: JOBS=4)
#
# Variables: JOBS (6 por defecto), BUILD_DIR (build-release por defecto).
#
# Pasos:
#   1. Emisores (psxrecomp-game / psxrecomp-bios) en build-recompiler/, con
#      tools/ci/build_emitters.sh del framework. Así quedan fuera del árbol
#      del submódulo y el CLI los encuentra primero. La primera vez, generate
#      los recompila una vez más (con clang, y deja una marca de toolchain);
#      después ese paso ya no repite trabajo.
#   2. psxrecomp_cli.py generate: verifica el disco, extrae el ejecutable a
#      prepared_disc/ y escribe el C en generated/. Ninguno entra a git.
#   3. psxrecomp_cli.py rebuild: configura y compila psx-runtime en BUILD_DIR y
#      deja overlay_toolchain/ junto al ejecutable (un cmake --build a secas
#      no lo hace y los overlays se quedarían en el intérprete).
#
# Siempre con --no-toolchain-download: se usa el compilador del sistema, sin
# descargas ocultas. Requiere haber corrido scripts/setup.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

JOBS="${JOBS:-6}"
BUILD_DIR="${BUILD_DIR:-build-release}"
GENERAR=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sin-generar) GENERAR=0; shift ;;
    -j) JOBS="${2:?falta el número de hilos}"; shift 2 ;;
    -j*) JOBS="${1#-j}"; shift ;;
    -h|--help) sed -n '2,23p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "error: argumento desconocido: $1" >&2; exit 2 ;;
  esac
done
[[ "$JOBS" =~ ^[1-9][0-9]*$ ]] || { echo "error: -j necesita un número" >&2; exit 2; }

info()  { printf '\n==> %s\n' "$*"; }
error() { printf 'error: %s\n' "$*" >&2; exit 1; }

# Todos los cmake --build del CLI respetan esta variable.
export CMAKE_BUILD_PARALLEL_LEVEL="$JOBS"

[[ -f psxrecomp/psxrecomp_cli.py ]] || error "falta el submódulo psxrecomp: corre scripts/setup.sh"

# Valor de una clave "clave = \"valor\"" en game.toml (primera aparición).
valor_toml() { sed -n "s/^$1 *= *\"\(.*\)\"\$/\1/p" game.toml | head -n1; }

# --- Protección del disco ----------------------------------------------------
# disc/ es un enlace a ../privado/disc, que solo se lee. Ninguna ruta donde el
# CLI escribe puede apuntar ahí.
for clave in exe out_dir; do
  ruta="$(valor_toml "$clave")"
  case "$ruta" in
    disc|disc/*|./disc|./disc/*)
      error "game.toml: $clave = \"$ruta\" escribiría dentro de disc/ (solo lectura)" ;;
  esac
done

cue="$(valor_toml disc)"
[[ -n "$cue" ]] || error "game.toml no define [game] disc"

if ((GENERAR)); then
  [[ -r "$cue" ]] || error "no se puede leer $cue (¿existe el enlace disc/?)"

  info "1/3 Emisores del recompilador (build-recompiler/, -j$JOBS)"
  psxrecomp/tools/ci/build_emitters.sh \
    --framework psxrecomp --build-dir build-recompiler --jobs "$JOBS"

  info "2/3 Generando C desde el disco (generated/)"
  python3 psxrecomp/psxrecomp_cli.py generate \
    --config game.toml --project-root . --disc "$cue" \
    --no-toolchain-download
else
  [[ -f generated/SCUS_941.54_dispatch.c ]] \
    || error "no hay C generado en generated/: corre sin --sin-generar"
  info "1-2/3 Generación omitida (--sin-generar)"
fi

info "3/3 Compilando psx-runtime en $BUILD_DIR/ (-j$JOBS)"
python3 psxrecomp/psxrecomp_cli.py rebuild \
  --config game.toml --project-root . --build-dir "$BUILD_DIR" \
  --no-pgo --no-toolchain-download

# El framework versiona su BIOS generada (psxrecomp/generated/OpenBIOS_*);
# si generate la reescribió, el submódulo queda modificado. Avisar.
if ! git -C psxrecomp diff --quiet -- generated; then
  printf '\naviso: generate modificó archivos versionados de psxrecomp/generated:\n' >&2
  git -C psxrecomp diff --stat -- generated >&2
fi

exe_name="$(cat "$BUILD_DIR/psxrecomp_exe_name-psx-runtime.txt" 2>/dev/null || echo psx-runtime)"
info "Listo: $BUILD_DIR/$exe_name"
