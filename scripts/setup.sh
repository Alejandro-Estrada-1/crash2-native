#!/usr/bin/env bash
# Prepare the crash2-native development environment.
#
#   scripts/setup.sh              # full setup: deps, submodules, patches, disc
#   scripts/setup.sh --sin-disco  # same, without verifying the disc (CI)
#
# What it does:
#   1. Checks required host tools. If any are missing, prints the pacman
#      command and exits. Never installs packages or invokes sudo.
#   2. Initializes submodules (psxrecomp, recomp-ui, and psxrecomp's nested
#      submodules) at the commits pinned by this repository.
#   3. Applies patches/psxrecomp/*.patch to the submodule. Idempotent: patches
#      that are already applied are skipped.
#   4. Verifies the disc against game.toml [prepare_disc] hashes.
#      Read-only: disc/ is a symlink to ../privado/disc.
#
# Compiles nothing: use scripts/build_linux.sh for building.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CHECK_DISC=1
for arg in "$@"; do
  case "$arg" in
    --sin-disco) CHECK_DISC=0 ;;
    -h|--help) sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "error: unknown argument: $arg" >&2; exit 2 ;;
  esac
done

info()  { printf '==> %s\n' "$*"; }
warn()  { printf 'warning: %s\n' "$*" >&2; }
error() { printf 'error: %s\n' "$*" >&2; exit 1; }

# --- 1. Host dependencies ---------------------------------------------------
info "Checking dependencies"
missing=()
need() {  # need <command> <Arch package>
  command -v "$1" >/dev/null 2>&1 || missing+=("$2")
}
need git git
need cmake cmake
need ninja ninja
need pkg-config pkgconf
need python3 python
need gcc gcc
need g++ gcc

if ((${#missing[@]})); then
  # Deduplicate while preserving order.
  mapfile -t missing < <(printf '%s\n' "${missing[@]}" | awk '!seen[$0]++')
  error "missing required tools. Install them with:
    sudo pacman -S --needed ${missing[*]}"
fi

# Minimum versions: CMake 3.20 (psxrecomp/docs/BUILDING.md) and Python 3.11
# (psxrecomp_cli.py uses stdlib tomllib).
cmake_ver="$(cmake --version | awk 'NR==1 {print $3}')"
if ! printf '3.20\n%s\n' "$cmake_ver" | sort -V -C; then
  error "CMake >= 3.20 is required (found $cmake_ver)"
fi
if ! python3 -c 'import sys; sys.exit(sys.version_info < (3, 11))'; then
  error "Python >= 3.11 is required (found $(python3 --version 2>&1))"
fi

# Optional system libs: without them psxrecomp fetches pinned SDL3 or fails at
# renderer configure time; warn without aborting.
pkg-config --exists sdl3 || warn "system SDL3 not found; CMake will download the version pinned by psxrecomp (sudo pacman -S sdl3 to avoid it)"
pkg-config --exists gl || pkg-config --exists opengl || warn "OpenGL not found via pkg-config (mesa / libglvnd packages)"

# --- 2. Submodules ----------------------------------------------------------
info "Initializing submodules"
git submodule sync --recursive >/dev/null
git submodule update --init --recursive

# A leading '+' indicates a submodule is not on the pinned commit.
if git submodule status --recursive | grep -q '^+'; then
  warn "some submodules are not at their pinned commits:"
  git submodule status --recursive | grep '^+' >&2
fi

# --- 3. Framework patches ---------------------------------------------------
shopt -s nullglob
patches=(patches/psxrecomp/*.patch)
shopt -u nullglob
if ((${#patches[@]} == 0)); then
  info "No patches in patches/psxrecomp/"
else
  info "Applying ${#patches[@]} patch(es) to psxrecomp"
  for p in "${patches[@]}"; do
    name="$(basename "$p")"
    if git -C psxrecomp apply --reverse --check "$ROOT/$p" 2>/dev/null; then
      echo "    already applied: $name"
    elif git -C psxrecomp apply --check "$ROOT/$p" 2>/dev/null; then
      git -C psxrecomp apply "$ROOT/$p"
      echo "    applied:         $name"
    else
      error "patch $name failed to apply on psxrecomp $(git -C psxrecomp rev-parse --short HEAD)"
    fi
  done
fi

# --- 4. Disc verification ---------------------------------------------------
if ((CHECK_DISC == 0)); then
  info "Disc verification skipped (--sin-disco)"
  exit 0
fi

info "Verifying disc"
[[ -e disc ]] || error "missing disc/. Create symlink: ln -s ../privado/disc disc"

# Path to the .cue file from game.toml ([game] disc = "...").
cue="$(sed -n 's/^disc *= *"\(.*\)"$/\1/p' game.toml | head -n1)"
[[ -n "$cue" ]] || error "game.toml does not define [game] disc"
[[ -r "$cue" ]] || error "cannot read $cue"

# verify-disc only reads the image and checks size, MD5, SHA-1, and CRC-32.
python3 psxrecomp/psxrecomp_cli.py verify-disc \
  --config game.toml --project-root . --disc "$cue"

info "Ready. Next step: scripts/build_linux.sh"
