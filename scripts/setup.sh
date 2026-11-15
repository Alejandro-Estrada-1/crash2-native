#!/usr/bin/env bash
# Prepara el entorno de desarrollo de crash2-native.
#
#   scripts/setup.sh              # todo: dependencias, submódulos, parches, disco
#   scripts/setup.sh --sin-disco  # igual, pero sin revisar el disco (CI)
#
# Qué hace:
#   1. Revisa las herramientas necesarias. Si falta alguna, muestra el comando
#      de pacman y termina. Nunca instala nada ni usa sudo.
#   2. Inicializa los submódulos (psxrecomp, recomp-ui y los internos de
#      psxrecomp) en los commits fijados por este repo.
#   3. Aplica patches/psxrecomp/*.patch sobre el submódulo. Es idempotente: un
#      parche ya aplicado se salta.
#   4. Verifica el disco contra los hashes de game.toml [prepare_disc].
#      Solo lee: disc/ es un enlace a ../privado/disc.
#
# No compila nada: para eso está scripts/build_linux.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

REVISAR_DISCO=1
for arg in "$@"; do
  case "$arg" in
    --sin-disco) REVISAR_DISCO=0 ;;
    -h|--help) sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "error: argumento desconocido: $arg" >&2; exit 2 ;;
  esac
done

info()  { printf '==> %s\n' "$*"; }
aviso() { printf 'aviso: %s\n' "$*" >&2; }
error() { printf 'error: %s\n' "$*" >&2; exit 1; }

# --- 1. Dependencias ---------------------------------------------------------
info "Revisando dependencias"
faltan=()
necesita() {  # necesita <comando> <paquete de Arch>
  command -v "$1" >/dev/null 2>&1 || faltan+=("$2")
}
necesita git git
necesita cmake cmake
necesita ninja ninja
necesita pkg-config pkgconf
necesita python3 python
necesita gcc gcc
necesita g++ gcc

if ((${#faltan[@]})); then
  # quitar duplicados conservando el orden
  mapfile -t faltan < <(printf '%s\n' "${faltan[@]}" | awk '!visto[$0]++')
  error "faltan herramientas. Instálalas con:
    sudo pacman -S --needed ${faltan[*]}"
fi

# Versiones mínimas: CMake 3.20 (psxrecomp/docs/BUILDING.md) y Python 3.11
# (psxrecomp_cli.py usa tomllib).
cmake_ver="$(cmake --version | awk 'NR==1 {print $3}')"
if ! printf '3.20\n%s\n' "$cmake_ver" | sort -V -C; then
  error "se necesita CMake >= 3.20 (hay $cmake_ver)"
fi
if ! python3 -c 'import sys; sys.exit(sys.version_info < (3, 11))'; then
  error "se necesita Python >= 3.11 (hay $(python3 --version 2>&1))"
fi

# Opcionales: sin ellas el framework descarga SDL3 (con hash fijo) o falla al
# configurar el renderizador; se avisa pero no se detiene.
pkg-config --exists sdl3 || aviso "no se encontró SDL3 del sistema; CMake descargará la versión fijada por psxrecomp (sudo pacman -S sdl3 para evitarlo)"
pkg-config --exists gl || pkg-config --exists opengl || aviso "no se encontró OpenGL por pkg-config (paquetes mesa / libglvnd)"

# --- 2. Submódulos -----------------------------------------------------------
info "Inicializando submódulos"
git submodule sync --recursive >/dev/null
git submodule update --init --recursive

# Un '+' al inicio indica que el submódulo no está en el commit fijado.
if git submodule status --recursive | grep -q '^+'; then
  aviso "hay submódulos fuera del commit fijado:"
  git submodule status --recursive | grep '^+' >&2
fi

# --- 3. Parches al framework -------------------------------------------------
shopt -s nullglob
parches=(patches/psxrecomp/*.patch)
shopt -u nullglob
if ((${#parches[@]} == 0)); then
  info "Sin parches en patches/psxrecomp/"
else
  info "Aplicando ${#parches[@]} parche(s) a psxrecomp"
  for p in "${parches[@]}"; do
    nombre="$(basename "$p")"
    if git -C psxrecomp apply --reverse --check "$ROOT/$p" 2>/dev/null; then
      echo "    ya aplicado: $nombre"
    elif git -C psxrecomp apply --check "$ROOT/$p" 2>/dev/null; then
      git -C psxrecomp apply "$ROOT/$p"
      echo "    aplicado:    $nombre"
    else
      error "el parche $nombre no aplica sobre psxrecomp $(git -C psxrecomp rev-parse --short HEAD)"
    fi
  done
fi

# --- 4. Disco ----------------------------------------------------------------
if ((REVISAR_DISCO == 0)); then
  info "Revisión del disco omitida (--sin-disco)"
  exit 0
fi

info "Verificando el disco"
[[ -e disc ]] || error "no existe disc/. Crea el enlace: ln -s ../privado/disc disc"

# Ruta del .cue según game.toml ([game] disc = "...").
cue="$(sed -n 's/^disc *= *"\(.*\)"$/\1/p' game.toml | head -n1)"
[[ -n "$cue" ]] || error "game.toml no define [game] disc"
[[ -r "$cue" ]] || error "no se puede leer $cue"

# verify-disc solo lee la imagen y compara tamaño, MD5, SHA-1 y CRC-32.
python3 psxrecomp/psxrecomp_cli.py verify-disc \
  --config game.toml --project-root . --disc "$cue"

info "Listo. Siguiente paso: scripts/build_linux.sh"
