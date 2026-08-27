# 安装工具链：clang/lld/llvm + 交叉编译工具链

log "工具链 (clang)"
if [ -n "${CLANG_DIR_OVERRIDE:-}" ]; then
  CLANGBIN="$CLANG_DIR_OVERRIDE/bin"
else
  sudo apt-get update -qq
  sudo apt-get install -y -qq clang lld llvm
  CLANGBIN="/usr/bin"
fi
export PATH="$CLANGBIN:$PATH"
clang --version | head -1

log "交叉工具链"
command -v aarch64-linux-gnu-ld >/dev/null || {
  sudo apt-get update -qq
  sudo apt-get install -y -qq gcc-aarch64-linux-gnu gcc-arm-linux-gnueabi
}
