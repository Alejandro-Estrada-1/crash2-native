#!/usr/bin/env bash
# sync-ro.sh: sincroniza una copia aislada del proyecto de Ghidra para lectura
# headless (pyghidra-mcp) sin tocar ni bloquear privado/ghidra.
#
# Uso:
#   tools/ghidra/sync-ro.sh

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd -- "${SCRIPT_DIR}/../../.." && pwd)"
PRIVADO_DIR="${PRIVADO_DIR:-${BASE_DIR}/privado}"
SRC_DIR="${PRIVADO_DIR}/ghidra"
DST_DIR="${PRIVADO_DIR}/ghidra-ro"

if [ ! -f "${SRC_DIR}/crash2.gpr" ]; then
  echo "sync-ro: no encuentro ${SRC_DIR}/crash2.gpr; abortando." >&2
  exit 1
fi

if [ -e "${SRC_DIR}/crash2.lock" ]; then
  echo "sync-ro: existe ${SRC_DIR}/crash2.lock (Ghidra está abierto)." >&2
  echo "sync-ro: guarda cambios y cierra Ghidra antes de sincronizar." >&2
  exit 2
fi

if [ -d "${DST_DIR}" ] && find "${DST_DIR}" \( -name '*.lock' -o -name '*.lock~' \) -print -quit | grep -q .; then
  echo "sync-ro: existe un .lock en ${DST_DIR}; detén pyghidra-mcp antes de sincronizar." >&2
  exit 3
fi

rm -rf -- "${DST_DIR}"
cp -a -- "${SRC_DIR}" "${DST_DIR}"
find "${DST_DIR}" \( -name '*.lock' -o -name '*.lock~' \) -delete

echo "sync-ro: copia actualizada en ${DST_DIR}"
