# 换核合成 boot-ksu.img
# pack_boot.sh 内部流程: 解包官方 boot → 替换内核 → 重打包 → ramdisk md5 回环校验
cd "$REPO_DIR"

bash "$REPO_DIR/tools/pack_boot.sh" boot_official.img \
     "$KERNEL_DIR/out/arch/arm64/boot/Image" boot-ksu.img "$REPO_DIR/bootwork"
