#!/usr/bin/env bash
set -euo pipefail

# When Buildroot executes POST_BUILD_SCRIPT, the first argument ($1) is always output/<project>/target
TARGET_DIR="$1"

# Relative path to lib.tar.bz2 within the Buildroot directory (working directory is Buildroot root)
DRIVER_ARCHIVE="board/rockchip/rk3588/lib.tar.bz2"

echo ">>> [Post-Build] Checking external driver archive: ${DRIVER_ARCHIVE}"

if [[ ! -f "${DRIVER_ARCHIVE}" ]]; then
    echo ">>> [Post-Build][WARN] ${DRIVER_ARCHIVE} not found, skipping driver injection!"
    exit 0
fi

# Create a temporary directory for extraction to avoid overwriting incorrect paths due to archive structure differences
TMP_EXTRACT=$(mktemp -d)
trap 'rm -rf "${TMP_EXTRACT}"' EXIT

tar -xjf "${DRIVER_ARCHIVE}" -C "${TMP_EXTRACT}"

# Check if the top level of the extracted archive already contains a lib/ directory
if [[ -d "${TMP_EXTRACT}/lib" ]]; then
    echo ">>> [Post-Build] Detected top-level lib/ structure, merging into ${TARGET_DIR}/lib/ ..."
    cp -af "${TMP_EXTRACT}/lib/." "${TARGET_DIR}/lib/"
else
    echo ">>> [Post-Build] Extracting contents directly into ${TARGET_DIR}/lib/ ..."
    mkdir -p "${TARGET_DIR}/lib"
    cp -af "${TMP_EXTRACT}/." "${TARGET_DIR}/lib/"
fi

# If kernel modules are present, regenerate modules.dep on the host so modprobe works out-of-the-box on target
if [[ -d "${TARGET_DIR}/lib/modules" ]]; then
    for kver_dir in "${TARGET_DIR}/lib/modules"/*; do
        if [[ -d "${kver_dir}" ]]; then
            kver=$(basename "${kver_dir}")
            echo ">>> [Post-Build] Generating module dependencies (depmod) for kernel ${kver}..."
            depmod -b "${TARGET_DIR}" "${kver}" || true
        fi
    done
fi

echo ">>> [Post-Build] Driver archive injection completed!"
