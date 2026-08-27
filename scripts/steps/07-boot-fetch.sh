# 获取官方 boot.img
# BOOT_URL 为 http(s)/ftp 直链则下载，否则视为本地路径复制
cd "$REPO_DIR"

case "$BOOT_URL" in
  http*|ftp*)
    retry curl -L --retry 3 -m 600 -fsSL "$BOOT_URL" -o boot_official.img ;;
  *)
    cp "$BOOT_URL" boot_official.img ;;
esac
log "官方 boot 就绪: $REPO_DIR/boot_official.img"
