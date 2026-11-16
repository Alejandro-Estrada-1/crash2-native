#!/usr/bin/env bash
# sync-ro.sh: sync an isolated copy of the Ghidra project for headless
# read-only access (pyghidra-mcp) without touching or locking privado/ghidra.
#
# Usage:
#   tools/ghidra/sync-ro.sh

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd -- "${SCRIPT_DIR}/../../.." && pwd)"
PRIVADO_DIR="${PRIVADO_DIR:-${BASE_DIR}/privado}"
SRC_DIR="${PRIVADO_DIR}/ghidra"
DST_DIR="${PRIVADO_DIR}/ghidra-ro"

if [ ! -f "${SRC_DIR}/crash2.gpr" ]; then
  echo "sync-ro: ${SRC_DIR}/crash2.gpr not found; aborting." >&2
  exit 1
fi

if [ -e "${SRC_DIR}/crash2.lock" ]; then
  echo "sync-ro: ${SRC_DIR}/crash2.lock exists (Ghidra is open)." >&2
  echo "sync-ro: save changes and close Ghidra before syncing." >&2
  exit 2
fi

if [ -d "${DST_DIR}" ] && find "${DST_DIR}" \( -name '*.lock' -o -name '*.lock~' \) -print -quit | grep -q .; then
  echo "sync-ro: a .lock exists in ${DST_DIR}; stop pyghidra-mcp before syncing." >&2
  exit 3
fi

rm -rf -- "${DST_DIR}"
cp -a -- "${SRC_DIR}" "${DST_DIR}"
find "${DST_DIR}" \( -name '*.lock' -o -name '*.lock~' \) -delete

echo "sync-ro: synced copy updated at ${DST_DIR}"
