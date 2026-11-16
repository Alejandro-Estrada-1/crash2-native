#!/usr/bin/env bash
# Generate C sources for Crash 2 from the disc and compile the native runtime.
#
#   scripts/build_linux.sh                 # emitters + generate + rebuild
#   scripts/build_linux.sh --sin-generar   # rebuild only (C already generated)
#   scripts/build_linux.sh -j 4            # parallel jobs (also: JOBS=4)
#   scripts/build_linux.sh --sin-ui        # disable recomp-ui (no launcher/menu/OSD)
#   scripts/build_linux.sh --setup-host    # setup wizard only, without disc or
#                                          # generated C (used by CI)
#
# Variables: JOBS (default 6), BUILD_DIR (default build-release),
# SETUP_DIR (default build-setup, for --setup-host).
#
# Steps:
#   1. Recompiler emitters (psxrecomp-game / psxrecomp-bios) under
#      build-recompiler/ via the framework's tools/ci/build_emitters.sh. This
#      keeps them outside the submodule tree where the CLI picks them up first.
#      On the first run, generate recompiles them once more (with clang, writing
#      a toolchain stamp); subsequent runs reuse them.
#   2. psxrecomp_cli.py generate: verifies the disc, extracts the executable
#      into prepared_disc/, and writes generated C under generated/. None enter git.
#   3. psxrecomp_cli.py rebuild: configures and compiles psx-runtime under
#      BUILD_DIR and stages overlay_toolchain/ beside the executable (raw
#      cmake --build omits it, leaving overlays interpreted).
#
# Always passes --no-toolchain-download: uses the system compiler with zero
# hidden downloads. Requires running scripts/setup.sh first.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

JOBS="${JOBS:-6}"
BUILD_DIR="${BUILD_DIR:-build-release}"
SETUP_DIR="${SETUP_DIR:-build-setup}"
GENERATE=1
UI=ON
SETUP_HOST=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sin-generar) GENERATE=0; shift ;;
    --sin-ui) UI=OFF; shift ;;
    --setup-host) SETUP_HOST=1; shift ;;
    -j) JOBS="${2:?missing thread count}"; shift 2 ;;
    -j*) JOBS="${1#-j}"; shift ;;
    -h|--help) sed -n '2,27p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "error: unknown argument: $1" >&2; exit 2 ;;
  esac
done
[[ "$JOBS" =~ ^[1-9][0-9]*$ ]] || { echo "error: -j requires a positive integer" >&2; exit 2; }

info()  { printf '\n==> %s\n' "$*"; }
error() { printf 'error: %s\n' "$*" >&2; exit 1; }

# All CLI cmake --build invocations honor this variable.
export CMAKE_BUILD_PARALLEL_LEVEL="$JOBS"

[[ -f psxrecomp/psxrecomp_cli.py ]] || error "missing psxrecomp submodule: run scripts/setup.sh"

# --- Setup wizard host only -------------------------------------------------
# Without disc or generated C: PSXRECOMP_FORCE_SETUP_HOST tells CMake to ignore
# generated/ even if present. The setup wizard requires recomp-ui.
if ((SETUP_HOST)); then
  [[ "$UI" == ON ]] || error "--setup-host requires recomp-ui (cannot be combined with --sin-ui)"
  info "Building setup host in $SETUP_DIR/ (-j$JOBS)"
  cmake -S . -B "$SETUP_DIR" -G Ninja -DCMAKE_BUILD_TYPE=Release \
    -DPSX_RECOMP_UI=ON -DPSXRECOMP_FORCE_SETUP_HOST=ON
  cmake --build "$SETUP_DIR" --target psx-runtime --parallel "$JOBS"
  exe_name="$(cat "$SETUP_DIR/psxrecomp_exe_name-psx-runtime.txt" 2>/dev/null || echo psx-runtime)"
  info "Done: $SETUP_DIR/$exe_name"
  exit 0
fi

# Read value of `key = "value"` in game.toml (first match).
toml_value() { sed -n "s/^$1 *= *\"\(.*\)\"\$/\1/p" game.toml | head -n1; }

# --- Disc protection --------------------------------------------------------
# disc/ symlinks to ../privado/disc, which is strictly read-only. No CLI
# output path may point inside it.
for key in exe out_dir; do
  path_val="$(toml_value "$key")"
  case "$path_val" in
    disc|disc/*|./disc|./disc/*)
      error "game.toml: $key = \"$path_val\" would write inside disc/ (read-only)" ;;
  esac
done

cue="$(toml_value disc)"
[[ -n "$cue" ]] || error "game.toml does not define [game] disc"

if ((GENERATE)); then
  [[ -r "$cue" ]] || error "cannot read $cue (is the disc/ symlink present?)"

  info "1/3 Recompiler emitters (build-recompiler/, -j$JOBS)"
  psxrecomp/tools/ci/build_emitters.sh \
    --framework psxrecomp --build-dir build-recompiler --jobs "$JOBS"

  info "2/3 Generating C from disc (generated/)"
  python3 psxrecomp/psxrecomp_cli.py generate \
    --config game.toml --project-root . --disc "$cue" \
    --no-toolchain-download
else
  [[ -f generated/SCUS_941.54_dispatch.c ]] \
    || error "no generated C in generated/: run without --sin-generar"
  info "1-2/3 Code generation skipped (--sin-generar)"
fi

info "3/3 Building psx-runtime in $BUILD_DIR/ (recomp-ui $UI, -j$JOBS)"
# Pass PSX_RECOMP_UI explicitly so an already-configured build cache cannot
# retain an older option value.
python3 psxrecomp/psxrecomp_cli.py rebuild \
  --config game.toml --project-root . --build-dir "$BUILD_DIR" \
  --no-pgo --no-toolchain-download \
  --cmake-extra="-DPSX_RECOMP_UI=$UI"

# The framework tracks its generated OpenBIOS (psxrecomp/generated/OpenBIOS_*);
# warn if generate dirtied tracked submodule files.
if ! git -C psxrecomp diff --quiet -- generated; then
  printf '\nwarning: generate modified tracked files in psxrecomp/generated:\n' >&2
  git -C psxrecomp diff --stat -- generated >&2
fi

exe_name="$(cat "$BUILD_DIR/psxrecomp_exe_name-psx-runtime.txt" 2>/dev/null || echo psx-runtime)"
info "Done: $BUILD_DIR/$exe_name"
