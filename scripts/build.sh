#!/usr/bin/env bash
# 环境变量: BOOT_URL(必填) LOS_BRANCH KSU_REF CLANG_DIR_OVERRIDE(本地测试用)
set -euo pipefail
LOS_BRANCH="${LOS_BRANCH:-lineage-23.2}"
KSU_REF="${KSU_REF:-main}"
BOOT_URL="${BOOT_URL:?必须设置 BOOT_URL (官方 boot.img 直链或本地路径)}"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
NPROC=$(nproc)

retry() { local n=1; while :; do "$@" && return 0; [ $n -ge 3 ] && return 1; echo "重试 $n/3..."; n=$((n+1)); sleep 15; done; }

echo "[1/9] 克隆内核源码 ($LOS_BRANCH)"
[ -d kernel ] || retry git clone --depth=1 -b $LOS_BRANCH -q \
  https://github.com/LineageOS/android_kernel_motorola_sm7325.git kernel

echo "[2/9] 应用补丁"
cd kernel
for p in ../patches/*.patch; do
  pname="$(basename "$p")"
  if git apply --check "$p" 2>/dev/null; then
    git apply "$p"
    echo "  $pname: 已应用"
  elif git apply --reverse --check "$p" 2>/dev/null; then
    echo "  $pname: 已存在，跳过"
  else
    echo "  $pname: 上下文不存在，跳过"
  fi
done

echo "[3/9] 集成 ReSukiSU (官方 setup.sh, ref=$KSU_REF)"
retry curl -m 60 -fsSL \
  "https://raw.githubusercontent.com/ReSukiSU/ReSukiSU/$KSU_REF/kernel/setup.sh" -o /tmp/ksu_setup.sh
bash /tmp/ksu_setup.sh "$KSU_REF"

echo "[4/9] 工具链 (clang)"
if [ -n "${CLANG_DIR_OVERRIDE:-}" ]; then
  CLANGBIN="$CLANG_DIR_OVERRIDE/bin"
else
  sudo apt-get update -qq
  sudo apt-get install -y -qq clang lld llvm
  CLANGBIN="/usr/bin"
fi
export PATH="$CLANGBIN:$PATH"
clang --version | head -1

echo "[5/9] 交叉工具链"
command -v aarch64-linux-gnu-ld >/dev/null || {
  sudo apt-get update -qq
  sudo apt-get install -y -qq gcc-aarch64-linux-gnu gcc-arm-linux-gnueabi
}

echo "[6/9] 生成配置 (LOS 官方配方)"
KFLAGS="O=out ARCH=arm64 CC=clang CLANG_TRIPLE=aarch64-linux-gnu- CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi- LD=ld.lld"
make $KFLAGS vendor/lahaina-qgki_defconfig > /dev/null
make $KFLAGS olddefconfig > /dev/null
scripts/kconfig/merge_config.sh -m -O out out/.config arch/arm64/configs/vendor/lineage_moto-lahaina.config > /dev/null
make $KFLAGS olddefconfig > /dev/null
scripts/kconfig/merge_config.sh -m -O out out/.config arch/arm64/configs/vendor/lineage_xpeng.config > /dev/null
make $KFLAGS olddefconfig > /dev/null
scripts/config --file out/.config -e LTO_CLANG -d LTO_NONE -e LTO_CLANG_THIN -d LTO_CLANG_FULL -e THINLTO
make $KFLAGS olddefconfig > /dev/null
grep -q '^CONFIG_KSU_MANUAL_HOOK=y' out/.config || { echo "错误: KSU 配置缺失"; exit 1; }

echo "[7/9] 编译内核 (-j$NPROC, ThinLTO)"
make $KFLAGS -j"$NPROC" Image

echo "[8/9] 获取官方 boot"
cd "$WORKDIR"
case "$BOOT_URL" in
  http*|ftp*) retry curl -L --retry 3 -m 600 -fsSL "$BOOT_URL" -o boot_official.img ;;
  *) cp "$BOOT_URL" boot_official.img ;;
esac

echo "[9/9] 换核合成"
bash "$REPO_DIR/tools/pack_boot.sh" boot_official.img \
     kernel/out/arch/arm64/boot/Image boot-ksu.img "$WORKDIR/bootwork"
echo "产物: $WORKDIR/boot-ksu.img"
