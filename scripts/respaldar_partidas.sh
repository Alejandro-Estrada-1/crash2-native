#!/usr/bin/env bash
# Back up save files (memory cards and F5 states) with timestamps and SHA-256 verification.
#
#   scripts/respaldar_partidas.sh
#
# Copies saves/ (symlink to ../privado/partidas) into
#   ../privado/respaldos/partidas-YYYY-MM-DD-HHMMSS/
# and writes SHA256SUMS so backups can be verified later with:
#   (cd ../privado/respaldos/partidas-... && sha256sum -c SHA256SUMS)
#
# Refuses to run while the game is open to avoid copying a partially written
# memory card. Never deletes or modifies save files or previous backups.
#
# Variables (for testing): SAVES_DIR (default: saves/) and
# RESPALDOS_DIR (default: ../privado/respaldos).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

case "${1:-}" in
  "") ;;
  -h|--help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) echo "error: unknown argument: $1" >&2; exit 2 ;;
esac

info()  { printf '==> %s\n' "$*"; }
error() { printf 'error: %s\n' "$*" >&2; exit 1; }

SAVES_DIR="${SAVES_DIR:-saves}"
RESPALDOS_DIR="${RESPALDOS_DIR:-../privado/respaldos}"

# --- 1. Ensure the game is closed -------------------------------------------
# Candidate binary names: fixed project name plus names recorded by CMake in
# each build directory (psxrecomp_exe_name-psx-runtime.txt).
names=(crash2_native)
for f in build-*/psxrecomp_exe_name-psx-runtime.txt; do
  [[ -f "$f" ]] && names+=("$(<"$f")")
done
for n in $(printf '%s\n' "${names[@]}" | sort -u); do
  # pgrep -x matches process comm name (15-character limit).
  if pids="$(pgrep -x "${n:0:15}")"; then
    error "the game is running ($n, PID ${pids//$'\n'/ }). Close it and retry."
  fi
done

# --- 2. Source directory ----------------------------------------------------
[[ -e "$SAVES_DIR" ]] || error "$SAVES_DIR/ does not exist (missing symlink to ../privado/partidas?)"
src_dir="$(readlink -f "$SAVES_DIR")"
[[ -d "$src_dir" ]] || error "$SAVES_DIR does not point to a directory: $src_dir"

# Hash manifest with relative paths in deterministic sort order.
manifest() {
  (cd "$1" && find . -type f ! -name SHA256SUMS -print0 | LC_ALL=C sort -z \
     | xargs -0 -r sha256sum)
}

before="$(manifest "$src_dir")"
[[ -n "$before" ]] || error "$src_dir is empty: nothing to back up"
file_count="$(printf '%s\n' "$before" | wc -l)"

# --- 3. Copy ----------------------------------------------------------------
mkdir -p "$RESPALDOS_DIR"
dest_dir="$(readlink -f "$RESPALDOS_DIR")/partidas-$(date +%Y-%m-%d-%H%M%S)"
[[ ! -e "$dest_dir" ]] || error "$dest_dir already exists"
case "$dest_dir/" in
  "$src_dir"/*) error "destination ($dest_dir) is inside source ($src_dir)" ;;
esac

info "Copying $src_dir -> $dest_dir ($file_count files)"
mkdir "$dest_dir"
cp -a "$src_dir/." "$dest_dir/"

# --- 4. Verification --------------------------------------------------------
printf '%s\n' "$before" > "$dest_dir/SHA256SUMS"
(cd "$dest_dir" && sha256sum --quiet -c SHA256SUMS) \
  || error "backup in $dest_dir does not match source"

# If saves changed mid-copy, the snapshot is inconsistent.
after="$(manifest "$src_dir")"
[[ "$before" == "$after" ]] \
  || error "save files changed during copy; backup in $dest_dir may be inconsistent. Retry with the game closed."

info "Done: verified $file_count files in $dest_dir"
