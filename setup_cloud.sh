#!/usr/bin/env bash
# ==============================================================================
# ATK-DLRK3588 Buildroot 雲端教學環境初始化腳本
# 適用環境：GitHub Codespaces Ubuntu 20.04
# ==============================================================================

set -euo pipefail

# 請將上傳至 GitHub Release 或 雲端空間的直接下載網址填入下方：
TOOLCHAIN_URL="https://github.com/xlloss/atk3588-buildroot-lab/releases/download/v1.0/atk-dlrk3588-toolchain-aarch64-buildroot-linux-gnu-x86_64_5_10_r6-20240506-v1.0.run"

# 目標目錄設定（對應 defconfig 中的 $(TOPDIR)/toolchain/atk-dlrk3588-toolchain）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILDROOT_DIR="${SCRIPT_DIR}/buildroot"
TOOLCHAIN_DIR="${BUILDROOT_DIR}/toolchain/atk-dlrk3588-toolchain"
TMP_DIR="/tmp/atk3588_setup"
DL_DIR="${BUILDROOT_DIR}/dl"
DEFCONFIG_NAME="rockchip_atk_dlrk3588_lite_defconfig"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; exit 1; }

# ------------------------- 2. 基礎環境與路徑檢查 -------------------------
info "開始檢查雲端工作區環境..."

# 檢查是否在正確的專案根目錄
[[ -d "${BUILDROOT_DIR}" ]] || error "找不到 buildroot/ 目錄！請確認您在倉庫根目錄執行此腳本。"
[[ -f "${BUILDROOT_DIR}/configs/${DEFCONFIG_NAME}" ]] || error "找不到配置檔 buildroot/configs/${DEFCONFIG_NAME}！"


# 檢查必要系統指令是否存在
for cmd in wget tar gzip make gcc g++; do
    command -v "${cmd}" >/dev/null 2>&1 || error "系統缺少必要指令 '${cmd}'，請確認 devcontainer 或系統依賴已安裝完成。"
done

# 檢查剩餘磁碟空間（至少需保留 12GB 供解壓與編譯）
FREE_KB=$(df -k "${SCRIPT_DIR}" | awk 'NR==2 {print $4}')
FREE_GB=$((FREE_KB / 1024 / 1024))
if [[ "${FREE_GB}" -lt 12 ]]; then
    error "目前磁碟剩餘空間僅 ${FREE_GB}GB（建議至少 12GB），可能導致編譯中斷！請清理無用容器或檔案後再試。"
fi
info "磁碟空間檢查通過（剩餘可用：${FREE_GB}GB）。"

# 檢查 defconfig 內的外部工具鏈路徑是否為相對變數 $(TOPDIR)
if grep -q "/opt/atk-dlrk3588-toolchain" "${BUILDROOT_DIR}/configs/${DEFCONFIG_NAME}"; then
    warn "偵測到 ${DEFCONFIG_NAME} 仍寫死本地路徑 /opt/atk-dlrk3588-toolchain，自動修正為 \$(TOPDIR)/toolchain/atk-dlrk3588-toolchain..."
    sed -i 's|/opt/atk-dlrk3588-toolchain|$(TOPDIR)/toolchain/atk-dlrk3588-toolchain|g' "${BUILDROOT_DIR}/configs/${DEFCONFIG_NAME}"
fi

mkdir -p "${TMP_DIR}" "${DL_DIR}"

# ------------------------- 3. 下載並安裝正點原子工具鏈 -------------------------
GCC_BIN="${TOOLCHAIN_DIR}/bin/aarch64-buildroot-linux-gnu-gcc"

if [[ -x "${GCC_BIN}" ]]; then
    info "偵測到交叉編譯器已存在 (${GCC_BIN})，跳過重複安裝。"
else
    info "正在下載正點原子 ATK-DLRK3588 交叉編譯工具鏈..."
    TOOLCHAIN_RUN="${TMP_DIR}/atk-dlrk3588-toolchain-aarch64-buildroot-linux-gnu-x86_64_5_10_r6-20240506-v1.0.run"
    wget -c --tries=3 --timeout=30 "${TOOLCHAIN_URL}" -O "${TOOLCHAIN_RUN}" || error "工具鏈下載失敗！請檢查網路連線或 TOOLCHAIN_URL 是否有效"

    # 防呆：檢查下載到的檔案大小（避免抓到 404 HTML 錯誤網頁）
    FILE_SIZE=$(stat -c%s "${TOOLCHAIN_RUN}")
    if [[ "${FILE_SIZE}" -lt 50000000 ]]; then
        rm -f "${TOOLCHAIN_RUN}"
        error "下載的工具鏈檔案異常過小（小於 50MB），可能是網址權限非公開（Private Repo）或連結失效"
    fi

    chmod +x "${TOOLCHAIN_RUN}"
    mkdir -p "${TOOLCHAIN_DIR}"

    info "正在靜默解壓並安裝工具鏈至 ${TOOLCHAIN_DIR}（約需 30 ~ 60 秒）"
    # 正點原子 .run 安裝檔支援 -d 指定目錄與 -y
    if ! "${TOOLCHAIN_RUN}" -d "${TOOLCHAIN_DIR}" -y >/dev/null 2>&1; then
        printf "%s\nY\n" "${TOOLCHAIN_DIR}" | "${TOOLCHAIN_RUN}" >/dev/null 2>&1 || error "工具鏈靜默安裝失敗！"
    fi

    # 驗證編譯器是否可正常執行
    [[ -x "${GCC_BIN}" ]] || error "安裝完成但找不到 ${GCC_BIN}，請檢查工具鏈壓縮包結構。"
    "${GCC_BIN}" --version | head -n 1
    rm -f "${TOOLCHAIN_RUN}"
    info "交叉編譯工具鏈安裝驗證成功！"
fi

# ------------------------- 4. 下載並解壓精簡版 dl 套件包 -------------------------

info "正在載入預設配置 ${DEFCONFIG_NAME}..."
make -C "${BUILDROOT_DIR}" "${DEFCONFIG_NAME}"

echo ""
echo -e "${GREEN}======================================================================${NC}"
echo -e "${GREEN} ✅ ATK-DLRK3588 Buildroot 雲端編譯環境初始化 OK ${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo "接下來只需執行以下指令即可開始自訂與編譯："
echo "  1. cd buildroot"
echo "  2. make menuconfig          # option: 勾選教學指定套件"
echo "  3. make -j 4                # 開始編譯 rootfs.ext2"
echo "======================================================================"
