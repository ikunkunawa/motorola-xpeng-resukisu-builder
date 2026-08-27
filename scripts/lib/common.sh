#!/usr/bin/env bash
# 公共环境与工具函数（由 build.sh source，各步骤共享同一 shell 环境）
set -euo pipefail

export LOS_BRANCH="${LOS_BRANCH:-lineage-23.2}"
export KSU_REF="${KSU_REF:-main}"
export BOOT_URL="${BOOT_URL:?必须设置 BOOT_URL (官方 boot.img 直链或本地路径)}"

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
KERNEL_DIR="$REPO_DIR/kernel"
OUT_DIR="$KERNEL_DIR/out"
NPROC=$(nproc)
export REPO_DIR KERNEL_DIR OUT_DIR NPROC

# 内核 make 参数（步骤 05/06 共用）
KFLAGS="O=out ARCH=arm64 CC=clang CLANG_TRIPLE=aarch64-linux-gnu- CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi- LD=ld.lld"

log() { echo "[$(date +%H:%M:%S)] $*"; }

retry() {
  local n=1
  while :; do
    "$@" && return 0
    [ "$n" -ge 3 ] && return 1
    echo "重试 $n/3..."
    n=$((n+1))
    sleep 15
  done
}
