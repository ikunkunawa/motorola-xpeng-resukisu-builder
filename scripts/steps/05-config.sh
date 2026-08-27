# 生成内核配置（LOS 官方配方）
# 流程: lahaina-qgki_defconfig → merge lineage_moto-lahaina.config
#       → merge lineage_xpeng.config → 启用 ThinLTO → 校验 KSU 已启用
cd "$KERNEL_DIR"

make $KFLAGS vendor/lahaina-qgki_defconfig > /dev/null
make $KFLAGS olddefconfig > /dev/null

scripts/kconfig/merge_config.sh -m -O out out/.config \
  arch/arm64/configs/vendor/lineage_moto-lahaina.config > /dev/null
make $KFLAGS olddefconfig > /dev/null

scripts/kconfig/merge_config.sh -m -O out out/.config \
  arch/arm64/configs/vendor/lineage_xpeng.config > /dev/null
make $KFLAGS olddefconfig > /dev/null

scripts/config --file out/.config \
  -e LTO_CLANG -d LTO_NONE -e LTO_CLANG_THIN -d LTO_CLANG_FULL -e THINLTO
make $KFLAGS olddefconfig > /dev/null

grep -q '^CONFIG_KSU_MANUAL_HOOK=y' out/.config || {
  echo "错误: KSU 配置缺失 (CONFIG_KSU_MANUAL_HOOK!=y)"; exit 1;
}
log "配置生成完毕，KSU 校验通过"
