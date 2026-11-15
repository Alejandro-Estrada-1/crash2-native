#!/usr/bin/env bash
# Respalda las partidas (memory cards y estados F5) con fecha y verifica hashes.
#
#   scripts/respaldar_partidas.sh
#
# Copia el contenido de saves/ (enlace a ../privado/partidas) a
#   ../privado/respaldos/partidas-AAAA-MM-DD-HHMMSS/
# y deja ahí un SHA256SUMS para verificarlo más tarde con:
#   (cd ../privado/respaldos/partidas-... && sha256sum -c SHA256SUMS)
#
# Se niega a correr si el juego está abierto: podría copiar una memory card a
# medio escribir. Nunca borra ni modifica las partidas ni respaldos anteriores.
#
# Variables (para pruebas): SAVES_DIR (saves/ por defecto) y
# RESPALDOS_DIR (../privado/respaldos por defecto).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

case "${1:-}" in
  "") ;;
  -h|--help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) echo "error: argumento desconocido: $1" >&2; exit 2 ;;
esac

info()  { printf '==> %s\n' "$*"; }
error() { printf 'error: %s\n' "$*" >&2; exit 1; }

SAVES_DIR="${SAVES_DIR:-saves}"
RESPALDOS_DIR="${RESPALDOS_DIR:-../privado/respaldos}"

# --- 1. El juego debe estar cerrado -----------------------------------------
# Nombres del ejecutable: el fijo del proyecto más los que haya publicado CMake
# en cada build (psxrecomp_exe_name-psx-runtime.txt).
nombres=(crash2_native)
for f in build-*/psxrecomp_exe_name-psx-runtime.txt; do
  [[ -f "$f" ]] && nombres+=("$(<"$f")")
done
for n in $(printf '%s\n' "${nombres[@]}" | sort -u); do
  # pgrep -x compara el nombre del proceso (comm, máximo 15 caracteres).
  if pids="$(pgrep -x "${n:0:15}")"; then
    error "el juego está abierto ($n, PID ${pids//$'\n'/ }). Ciérralo y vuelve a intentarlo."
  fi
done

# --- 2. Origen ---------------------------------------------------------------
[[ -e "$SAVES_DIR" ]] || error "no existe $SAVES_DIR/ (¿falta el enlace a ../privado/partidas?)"
origen="$(readlink -f "$SAVES_DIR")"
[[ -d "$origen" ]] || error "$SAVES_DIR no apunta a una carpeta: $origen"

# Manifiesto de hashes, con rutas relativas y orden estable.
manifiesto() {
  (cd "$1" && find . -type f ! -name SHA256SUMS -print0 | LC_ALL=C sort -z \
     | xargs -0 -r sha256sum)
}

antes="$(manifiesto "$origen")"
[[ -n "$antes" ]] || error "$origen está vacía: no hay nada que respaldar"
n_archivos="$(printf '%s\n' "$antes" | wc -l)"

# --- 3. Copia ----------------------------------------------------------------
mkdir -p "$RESPALDOS_DIR"
destino="$(readlink -f "$RESPALDOS_DIR")/partidas-$(date +%Y-%m-%d-%H%M%S)"
[[ ! -e "$destino" ]] || error "ya existe $destino"
case "$destino/" in
  "$origen"/*) error "el destino ($destino) está dentro del origen ($origen)" ;;
esac

info "Copiando $origen -> $destino ($n_archivos archivos)"
mkdir "$destino"
cp -a "$origen/." "$destino/"

# --- 4. Verificación ---------------------------------------------------------
printf '%s\n' "$antes" > "$destino/SHA256SUMS"
(cd "$destino" && sha256sum --quiet -c SHA256SUMS) \
  || error "la copia en $destino no coincide con el origen"

# Si algo escribió en el origen durante la copia, el respaldo no es coherente.
despues="$(manifiesto "$origen")"
[[ "$antes" == "$despues" ]] \
  || error "las partidas cambiaron durante la copia; el respaldo en $destino no es fiable. Repite con el juego cerrado."

info "Listo: $n_archivos archivos verificados en $destino"
