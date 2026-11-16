#!/usr/bin/env bash
# Package crash2-native into a portable AppImage built on the current host
# (must run inside ubuntu:22.04 for public releases targeting glibc >= 2.28).
#
# Bundles:
#   - usr/bin/crash2_native (--setup-host with optional system deps disabled)
#   - usr/bin/verify-disc, psxrecomp-game, psxrecomp-bios
#   - Zig 0.17.1, trimmed CMake 3.31.6, Ninja 1.12.1, and tomli 2.2.1 (Python 3.10)
#   - Minimal SDK tree + vendored third_party/*.tar.gz (no generated/, disc/, or .git/)
#   - Notices and licenses in licenses/ (never libGL/libOpenGL/libGLX/libdrm)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

VERSION=""
OUTPUT=""
WORK_DIR="${REPO_ROOT}/build-appimage/work"
TOOL_CACHE="${XDG_CACHE_HOME:-${HOME:?}/.cache}/crash2-native-appimage-tools"
JOBS="$(nproc 2>/dev/null || echo 2)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version) VERSION="${2:?}"; shift 2 ;;
    --output) OUTPUT="${2:?}"; shift 2 ;;
    --work-dir) WORK_DIR="${2:?}"; shift 2 ;;
    --tool-cache) TOOL_CACHE="${2:?}"; shift 2 ;;
    --jobs) JOBS="${2:?}"; shift 2 ;;
    -h|--help)
      sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "build-appimage.sh: unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

if [[ -z "${VERSION}" ]]; then
  if git -C "${REPO_ROOT}" describe --tags --exact-match >/dev/null 2>&1; then
    VERSION="$(git -C "${REPO_ROOT}" describe --tags --exact-match)"
  elif [[ -f "${REPO_ROOT}/VERSION" ]]; then
    VERSION="$(tr -d '[:space:]' < "${REPO_ROOT}/VERSION")"
  else
    sha="$(git -C "${REPO_ROOT}" rev-parse --short HEAD 2>/dev/null || echo dev)"
    VERSION="0.0.0-${sha}"
  fi
fi
VERSION="${VERSION#v}"
if [[ ! "${VERSION}" =~ ^[0-9A-Za-z._+-]+$ ]]; then
  echo "build-appimage.sh: invalid version '${VERSION}'" >&2
  exit 2
fi

if [[ -z "${OUTPUT}" ]]; then
  OUTPUT="${REPO_ROOT}/build-appimage/crash2-native-${VERSION}-x86_64.AppImage"
fi
case "${OUTPUT}" in
  /*) ;;
  *) OUTPUT="${PWD}/${OUTPUT}" ;;
esac
case "${WORK_DIR}" in
  /*) ;;
  *) WORK_DIR="${PWD}/${WORK_DIR}" ;;
esac
case "${TOOL_CACHE}" in
  /*) ;;
  *) TOOL_CACHE="${PWD}/${TOOL_CACHE}" ;;
esac
if [[ ! "${JOBS}" =~ ^[1-9][0-9]*$ ]]; then
  echo "build-appimage.sh: invalid --jobs '${JOBS}'" >&2
  exit 2
fi
if [[ "$(uname -s)" != "Linux" || "$(uname -m)" != "x86_64" ]]; then
  echo "build-appimage.sh: requires Linux x86_64." >&2
  exit 1
fi

# Official SHA-256 pinned tool and runtime downloads.
ZIG_URL="https://ziglang.org/download/0.17.1/zig-x86_64-linux-0.17.1.tar.xz"
ZIG_SHA256="3581863e3cbcfd0fce0efc682ce7e9e93da96668a977791d356a26d2a7e9b17a"

CMAKE_URL="https://github.com/Kitware/CMake/releases/download/v3.31.6/cmake-3.31.6-linux-x86_64.tar.gz"
CMAKE_SHA256="5a1133ff103c71eb5120e2cc3de922733e7d8a26a98ae716397e8676adb367bf"

NINJA_URL="https://github.com/ninja-build/ninja/releases/download/v1.12.1/ninja-linux.zip"
NINJA_SHA256="6f98805688d19672bd699fbbfa2c2cf0fc054ac3df1f0e6a47664d963d530255"

NINJA_COPYING_URL="https://raw.githubusercontent.com/ninja-build/ninja/v1.12.1/COPYING"
NINJA_COPYING_SHA256="eb7e9ab9690124c5c9f42bdc81383d886a3dede26345b6ed15bbad7caf81f7ea"

TOMLI_URL="https://files.pythonhosted.org/packages/6e/c2/61d3e0f47e2b74ef40a68b9e6ad5984f6241a942f7cd3bbfbdbd03861ea9/tomli-2.2.1-py3-none-any.whl"
TOMLI_SHA256="cb55c73c5f4408779d0cf3eef9f762b9c9f147a77de7b258bef0a5628adc85cc"

APPIMAGETOOL_URL="https://github.com/AppImage/appimagetool/releases/download/1.9.1/appimagetool-x86_64.AppImage"
APPIMAGETOOL_SHA256="ed4ce84f0d9caff66f50bcca6ff6f35aae54ce8135408b3fa33abfc3cb384eb0"

RUNTIME_URL="https://github.com/AppImage/type2-runtime/releases/download/20251108/runtime-x86_64"
RUNTIME_SHA256="2fca8b443c92510f1483a883f60061ad09b46b978b2631c807cd873a47ec260d"

RUNTIME_LICENSE_URL="https://raw.githubusercontent.com/AppImage/type2-runtime/20251108/LICENSE"
RUNTIME_LICENSE_SHA256="aa154fc9070614bbe7921f89db11efd1dba7a1f3a41685958110e2230f9c0ca1"

fetch_pinned() {
  local url="$1" sha="$2" dest="$3"
  if [[ -f "${dest}" ]]; then
    if echo "${sha}  ${dest}" | sha256sum -c - >/dev/null 2>&1; then
      return 0
    fi
    rm -f "${dest}"
  fi
  local tmp
  tmp="$(mktemp "${dest}.XXXXXX")"
  curl -fsSL --http1.1 --retry 5 --retry-all-errors --retry-delay 2 -L -o "${tmp}" "${url}"
  if ! echo "${sha}  ${tmp}" | sha256sum -c - >/dev/null 2>&1; then
    echo "build-appimage.sh: invalid SHA-256 for ${url}" >&2
    rm -f "${tmp}"
    exit 1
  fi
  mv -f "${tmp}" "${dest}"
  chmod 0644 "${dest}"
}

mkdir -p "${TOOL_CACHE}" "$(dirname "${OUTPUT}")"
rm -rf "${WORK_DIR}"
mkdir -p "${WORK_DIR}"

ZIG_ARCHIVE="${TOOL_CACHE}/zig-x86_64-linux-0.17.1.tar.xz"
CMAKE_ARCHIVE="${TOOL_CACHE}/cmake-3.31.6-linux-x86_64.tar.gz"
NINJA_ARCHIVE="${TOOL_CACHE}/ninja-linux-1.12.1.zip"
NINJA_COPYING="${TOOL_CACHE}/ninja-1.12.1-COPYING.txt"
TOMLI_WHEEL="${TOOL_CACHE}/tomli-2.2.1-py3-none-any.whl"
APPIMAGETOOL="${TOOL_CACHE}/appimagetool-1.9.1-x86_64.AppImage"
RUNTIME_FILE="${TOOL_CACHE}/runtime-x86_64-20251108"
RUNTIME_LICENSE="${TOOL_CACHE}/type2-runtime-20251108-LICENSE.txt"

echo "==> Downloading / verifying SHA-256 pinned tools"
fetch_pinned "${ZIG_URL}" "${ZIG_SHA256}" "${ZIG_ARCHIVE}"
fetch_pinned "${CMAKE_URL}" "${CMAKE_SHA256}" "${CMAKE_ARCHIVE}"
fetch_pinned "${NINJA_URL}" "${NINJA_SHA256}" "${NINJA_ARCHIVE}"
fetch_pinned "${NINJA_COPYING_URL}" "${NINJA_COPYING_SHA256}" "${NINJA_COPYING}"
fetch_pinned "${TOMLI_URL}" "${TOMLI_SHA256}" "${TOMLI_WHEEL}"
fetch_pinned "${APPIMAGETOOL_URL}" "${APPIMAGETOOL_SHA256}" "${APPIMAGETOOL}"
fetch_pinned "${RUNTIME_URL}" "${RUNTIME_SHA256}" "${RUNTIME_FILE}"
fetch_pinned "${RUNTIME_LICENSE_URL}" "${RUNTIME_LICENSE_SHA256}" "${RUNTIME_LICENSE}"
chmod 0755 "${APPIMAGETOOL}" "${RUNTIME_FILE}"

TOOLS_STAGE="${WORK_DIR}/tools"
mkdir -p "${TOOLS_STAGE}/zig" "${TOOLS_STAGE}/cmake-full" "${TOOLS_STAGE}/cmake" \
         "${TOOLS_STAGE}/ninja" "${TOOLS_STAGE}/bin" "${WORK_DIR}/python"

tar -xf "${ZIG_ARCHIVE}" --strip-components=1 -C "${TOOLS_STAGE}/zig"
tar -xf "${CMAKE_ARCHIVE}" --strip-components=1 -C "${TOOLS_STAGE}/cmake-full"
CMAKE_COPYRIGHT="${WORK_DIR}/CMake-Copyright.txt"
cp -f "${TOOLS_STAGE}/cmake-full/doc/cmake/Copyright.txt" "${CMAKE_COPYRIGHT}"

mkdir -p "${TOOLS_STAGE}/cmake/bin"
cp -a "${TOOLS_STAGE}/cmake-full/bin/cmake" "${TOOLS_STAGE}/cmake/bin/cmake"
cp -a "${TOOLS_STAGE}/cmake-full/share" "${TOOLS_STAGE}/cmake/share"
rm -rf "${TOOLS_STAGE}/cmake-full"

python3 -B -m zipfile -e "${NINJA_ARCHIVE}" "${TOOLS_STAGE}/ninja"
chmod 0755 "${TOOLS_STAGE}/ninja/ninja"

python3 -B -m zipfile -e "${TOMLI_WHEEL}" "${WORK_DIR}/python"

cat > "${TOOLS_STAGE}/bin/zig-cc" <<EOF
#!/usr/bin/env sh
exec "${TOOLS_STAGE}/zig/zig" cc -target x86_64-linux-gnu.2.28 "\$@"
EOF
cat > "${TOOLS_STAGE}/bin/zig-cxx" <<EOF
#!/usr/bin/env sh
exec "${TOOLS_STAGE}/zig/zig" c++ -target x86_64-linux-gnu.2.28 "\$@"
EOF
cat > "${TOOLS_STAGE}/bin/zig-ar" <<EOF
#!/usr/bin/env sh
exec "${TOOLS_STAGE}/zig/zig" ar "\$@"
EOF
cat > "${TOOLS_STAGE}/bin/zig-ranlib" <<EOF
#!/usr/bin/env sh
exec "${TOOLS_STAGE}/zig/zig" ranlib "\$@"
EOF
chmod 0755 "${TOOLS_STAGE}/bin/zig-cc" "${TOOLS_STAGE}/bin/zig-cxx" \
           "${TOOLS_STAGE}/bin/zig-ar" "${TOOLS_STAGE}/bin/zig-ranlib"

echo "==> Preparing clean SDK copy (excluding game files and .git)"
SDK_SRC="${WORK_DIR}/sdk-src"
mkdir -p "${SDK_SRC}"
tar -C "${REPO_ROOT}" \
  --exclude='./.git' \
  --exclude='*/.git' \
  --exclude='*/*/.git' \
  --exclude='__pycache__' \
  --exclude='*/__pycache__' \
  --exclude='./disc' \
  --exclude='./generated' \
  --exclude='./prepared_disc' \
  --exclude='./ghidra' \
  --exclude='./build' \
  --exclude='./build-*' \
  --exclude='./.cache' \
  --exclude='*.AppImage' \
  -cf - \
  psxrecomp recomp-ui src re/structs.h mods seeds patches CMakeLists.txt game.toml LICENSE NOTICE | tar -C "${SDK_SRC}" -xf -

find "${SDK_SRC}" -name '.git' -exec rm -rf {} + 2>/dev/null || true
find "${SDK_SRC}" -name '__pycache__' -exec rm -rf {} + 2>/dev/null || true

shopt -s nullglob
for p in "${SDK_SRC}/patches/psxrecomp/"*.patch; do
  if GIT_CEILING_DIRECTORIES="${WORK_DIR}" git -C "${SDK_SRC}/psxrecomp" apply --reverse --check "$p" >/dev/null 2>&1; then
    echo "    patch already applied in staging copy: $(basename "$p")"
  else
    GIT_CEILING_DIRECTORIES="${WORK_DIR}" git -C "${SDK_SRC}/psxrecomp" apply "$p"
  fi
done
shopt -u nullglob

printf '%s\n' "${VERSION}" > "${SDK_SRC}/VERSION"

echo "==> Vendoring dependencies under third_party/ (PSX_DEPS_OFFLINE=ON)"
"${SDK_SRC}/psxrecomp/tools/ci/vendor_deps.sh" SDL3 psx_zlib psx_libwebp psx_libchdr
"${SDK_SRC}/psxrecomp/tools/ci/vendor_deps.sh" --check SDL3 psx_zlib psx_libwebp psx_libchdr

export PATH="${TOOLS_STAGE}/cmake/bin:${TOOLS_STAGE}/ninja:${PATH}"
export PYTHONDONTWRITEBYTECODE=1

echo "==> Building setup-host with zig cc (isolated AppImage mode)"
BUILD_SETUP="${WORK_DIR}/build-setup"
CRASH2NATIVE_APPIMAGE_TOOLCHAIN=1 PSX_DEPS_OFFLINE=1 \
cmake -S "${SDK_SRC}" -B "${BUILD_SETUP}" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER="${TOOLS_STAGE}/bin/zig-cc" \
  -DCMAKE_CXX_COMPILER="${TOOLS_STAGE}/bin/zig-cxx" \
  -DCMAKE_AR="${TOOLS_STAGE}/bin/zig-ar" \
  -DCMAKE_RANLIB="${TOOLS_STAGE}/bin/zig-ranlib" \
  -DPSXRECOMP_FORCE_SETUP_HOST=ON \
  -DPSX_RECOMP_UI=ON \
  -DPSX_ENABLE_VULKAN=OFF
CRASH2NATIVE_APPIMAGE_TOOLCHAIN=1 PSX_DEPS_OFFLINE=1 \
cmake --build "${BUILD_SETUP}" --target psx-runtime -j "${JOBS}"

EXE_BASENAME="$(cat "${BUILD_SETUP}/psxrecomp_exe_name-psx-runtime.txt")"
SETUP_BIN="${BUILD_SETUP}/${EXE_BASENAME}"
SETUP_EXEC_MANIFEST="${BUILD_SETUP}/${EXE_BASENAME}.execution.json"
test -x "${SETUP_BIN}"
test -f "${SETUP_EXEC_MANIFEST}"

echo "==> Building prebuilt emitters (psxrecomp-game, psxrecomp-bios)"
BUILD_EMITTERS="${WORK_DIR}/build-emitters"
cmake -S "${SDK_SRC}/psxrecomp/recompiler" -B "${BUILD_EMITTERS}" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER="${TOOLS_STAGE}/bin/zig-cc" \
  -DCMAKE_CXX_COMPILER="${TOOLS_STAGE}/bin/zig-cxx" \
  -DCMAKE_AR="${TOOLS_STAGE}/bin/zig-ar" \
  -DCMAKE_RANLIB="${TOOLS_STAGE}/bin/zig-ranlib" \
  -DPSXRECOMP_ENABLE_CHD=OFF \
  -DBUILD_TESTING=OFF
cmake --build "${BUILD_EMITTERS}" --target psxrecomp-game psxrecomp-bios -j "${JOBS}"

echo "==> Building tools/verify-disc"
VERIFY_TARGET="${WORK_DIR}/target-verify-disc"
cargo build --locked --release \
  --manifest-path "${REPO_ROOT}/tools/verify-disc/Cargo.toml" \
  --target-dir "${VERIFY_TARGET}"
VERIFY_BIN="${VERIFY_TARGET}/release/verify-disc"
test -x "${VERIFY_BIN}"

echo "==> Assembling AppDir"
APPDIR="${WORK_DIR}/crash2-native.AppDir"
PAYLOAD="${APPDIR}/usr/share/crash2-native"
mkdir -p "${APPDIR}/usr/bin" "${PAYLOAD}/licenses" "${PAYLOAD}/toolchain"

cp -f "${SETUP_BIN}" "${APPDIR}/usr/bin/${EXE_BASENAME}"
cp -f "${VERIFY_BIN}" "${APPDIR}/usr/bin/verify-disc"
cp -f "${BUILD_EMITTERS}/psxrecomp-game" "${APPDIR}/usr/bin/psxrecomp-game"
cp -f "${BUILD_EMITTERS}/psxrecomp-bios" "${APPDIR}/usr/bin/psxrecomp-bios"

if command -v strip >/dev/null 2>&1; then
  strip --strip-unneeded \
    "${APPDIR}/usr/bin/${EXE_BASENAME}" \
    "${APPDIR}/usr/bin/verify-disc" \
    "${APPDIR}/usr/bin/psxrecomp-game" \
    "${APPDIR}/usr/bin/psxrecomp-bios"
fi
chmod 0755 \
  "${APPDIR}/usr/bin/${EXE_BASENAME}" \
  "${APPDIR}/usr/bin/verify-disc" \
  "${APPDIR}/usr/bin/psxrecomp-game" \
  "${APPDIR}/usr/bin/psxrecomp-bios"

PYTHONPATH="${WORK_DIR}/python${PYTHONPATH:+:${PYTHONPATH}}" \
python3 -B "${SDK_SRC}/psxrecomp/tools/release_stage.py" stage-execution \
  --binary "${APPDIR}/usr/bin/${EXE_BASENAME}" \
  --manifest "${SETUP_EXEC_MANIFEST}" \
  --output "${APPDIR}/usr/bin/${EXE_BASENAME}.execution.json"

cp -a "${BUILD_SETUP}/assets" "${PAYLOAD}/assets"
ln -sfn "../share/crash2-native/assets" "${APPDIR}/usr/bin/assets"
if [[ -d "${BUILD_SETUP}/bios" ]]; then
  cp -a "${BUILD_SETUP}/bios" "${PAYLOAD}/bios"
fi
if [[ -d "${BUILD_SETUP}/mods/bundled" ]]; then
  mkdir -p "${PAYLOAD}/mods"
  cp -a "${BUILD_SETUP}/mods/bundled" "${PAYLOAD}/mods/bundled"
fi

cp -a \
  "${SDK_SRC}/psxrecomp" \
  "${SDK_SRC}/recomp-ui" \
  "${SDK_SRC}/src" \
  "${SDK_SRC}/mods" \
  "${SDK_SRC}/seeds" \
  "${SDK_SRC}/patches" \
  "${SDK_SRC}/CMakeLists.txt" \
  "${SDK_SRC}/game.toml" \
  "${SDK_SRC}/VERSION" \
  "${SDK_SRC}/LICENSE" \
  "${SDK_SRC}/NOTICE" \
  "${PAYLOAD}/"
mkdir -p "${PAYLOAD}/re"
cp -a "${SDK_SRC}/re/structs.h" "${PAYLOAD}/re/structs.h"

cp -a "${WORK_DIR}/python" "${PAYLOAD}/python"
cp -a "${TOOLS_STAGE}/zig" "${PAYLOAD}/toolchain/zig"
cp -a "${TOOLS_STAGE}/cmake" "${PAYLOAD}/toolchain/cmake"
cp -a "${TOOLS_STAGE}/ninja" "${PAYLOAD}/toolchain/ninja"

# Full license texts and notices in licenses/.
cp -f "${SDK_SRC}/LICENSE" "${PAYLOAD}/licenses/LICENSE"
cp -f "${SDK_SRC}/NOTICE" "${PAYLOAD}/licenses/NOTICE"
cp -f "${SDK_SRC}/psxrecomp/LICENSE" "${PAYLOAD}/licenses/psxrecomp-LICENSE.txt"
cp -f "${SDK_SRC}/psxrecomp/bios/OpenBIOS.LICENSE" "${PAYLOAD}/licenses/OpenBIOS.LICENSE"
cp -a "${SDK_SRC}/psxrecomp/runtime/licenses/." "${PAYLOAD}/licenses/"
cp -f "${SDK_SRC}/recomp-ui/LICENSE" "${PAYLOAD}/licenses/recomp-ui-LICENSE.txt"
cp -f "${SDK_SRC}/recomp-ui/assets/common/fonts/NOTICE.md" "${PAYLOAD}/licenses/recomp-ui-fonts-NOTICE.md"
cp -f "${SDK_SRC}/recomp-ui/assets/common/img/NOTICE.md" "${PAYLOAD}/licenses/recomp-ui-img-NOTICE.md"
cp -f "${SDK_SRC}/recomp-ui/src/third_party/imgui/LICENSE.txt" "${PAYLOAD}/licenses/imgui-LICENSE.txt"
cp -f "${TOOLS_STAGE}/zig/LICENSE" "${PAYLOAD}/licenses/Zig-LICENSE.txt"
cp -f "${CMAKE_COPYRIGHT}" "${PAYLOAD}/licenses/CMake-Copyright.txt"
cp -f "${NINJA_COPYING}" "${PAYLOAD}/licenses/Ninja-COPYING.txt"
cp -f "${WORK_DIR}/python"/tomli-*.dist-info/LICENSE "${PAYLOAD}/licenses/tomli-LICENSE.txt"
cp -f "${RUNTIME_LICENSE}" "${PAYLOAD}/licenses/type2-runtime-LICENSE.txt"

install -m 0755 "${SCRIPT_DIR}/AppRun" "${APPDIR}/AppRun"
install -m 0644 "${SCRIPT_DIR}/crash2-native.desktop" "${APPDIR}/crash2-native.desktop"
install -m 0644 "${SCRIPT_DIR}/crash2-native.png" "${APPDIR}/crash2-native.png"
ln -sfn "crash2-native.png" "${APPDIR}/.DirIcon"

echo "==> Checking AppDir hygiene (zero libGL/libOpenGL/libGLX/libdrm or game data)"
sh -n "${APPDIR}/AppRun"
if [[ -e "${APPDIR}/usr/lib" ]]; then
  echo "build-appimage.sh: error: usr/lib must not exist in AppDir" >&2
  exit 1
fi
bad_gl="$(find "${APPDIR}" \( -iname 'libGL*' -o -iname 'libOpenGL*' -o -iname 'libGLX*' -o -iname 'libGLdispatch*' -o -iname 'libEGL*' -o -iname 'libdrm*' \) || true)"
if [[ -n "${bad_gl}" ]]; then
  echo "build-appimage.sh: error: forbidden graphics libraries found inside AppDir:" >&2
  printf '%s\n' "${bad_gl}" >&2
  exit 1
fi
bad_game="$(find "${APPDIR}" \
  \( -name 'prepared_disc' -o -name 'ghidra' -o -name 'SCUS_*' -o -iname 'SCPH*.BIN' -o -iname '*.cue' -o -iname '*.chd' -o -iname '*.iso' \
     -o \( -name 'generated' -not -path "${PAYLOAD}/psxrecomp/generated" -not -path "${PAYLOAD}/psxrecomp/recompiler/lib/rabbitizer/include/generated" -not -path "${PAYLOAD}/psxrecomp/recompiler/lib/rabbitizer/cplusplus/include/generated" \) \
     -o \( -name 'disc' -not -path "${PAYLOAD}/psxrecomp/tools/cycle_testrom/disc" \) \) || true)"
if [[ -d "${PAYLOAD}/psxrecomp/generated" ]]; then
  bad_openbios="$(find "${PAYLOAD}/psxrecomp/generated" -mindepth 1 -not -name 'OpenBIOS*' || true)"
  if [[ -n "${bad_openbios}" ]]; then
    bad_game="${bad_game:+${bad_game}$'\n'}${bad_openbios}"
  fi
fi
if [[ -n "${bad_game}" ]]; then
  echo "build-appimage.sh: error: game artifacts found inside AppDir:" >&2
  printf '%s\n' "${bad_game}" >&2
  exit 1
fi
for bin in "${APPDIR}/usr/bin/${EXE_BASENAME}" "${APPDIR}/usr/bin/verify-disc" "${APPDIR}/usr/bin/psxrecomp-game" "${APPDIR}/usr/bin/psxrecomp-bios"; do
  if env -u LD_LIBRARY_PATH ldd "${bin}" | grep -q 'not found'; then
    echo "build-appimage.sh: unresolved dependency in ${bin}" >&2
    exit 1
  fi
done

SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-$(git -C "${REPO_ROOT}" log -1 --format=%ct 2>/dev/null || echo 0)}"
[[ "${SOURCE_DATE_EPOCH}" =~ ^[0-9]+$ ]] || SOURCE_DATE_EPOCH=0
export SOURCE_DATE_EPOCH
find "${APPDIR}" -exec touch -h -d "@${SOURCE_DATE_EPOCH}" {} +

rm -f "${OUTPUT}" "${OUTPUT}.sha256"
echo "==> Packaging ${OUTPUT}"
ARCH=x86_64 "${APPIMAGETOOL}" --appimage-extract-and-run \
  --runtime-file "${RUNTIME_FILE}" \
  --mksquashfs-opt -processors --mksquashfs-opt "${JOBS}" \
  "${APPDIR}" "${OUTPUT}"
chmod 0755 "${OUTPUT}"
(
  cd "$(dirname "${OUTPUT}")"
  sha256sum "$(basename "${OUTPUT}")" > "$(basename "${OUTPUT}").sha256"
)
echo "AppImage generated: ${OUTPUT}"
