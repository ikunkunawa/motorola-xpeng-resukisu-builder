# 集成 ReSukiSU (官方 setup.sh)
cd "$KERNEL_DIR"

log "拉取 ReSukiSU setup.sh (ref=$KSU_REF)"
retry curl -m 60 -fsSL \
  "https://raw.githubusercontent.com/ReSukiSU/ReSukiSU/$KSU_REF/kernel/setup.sh" -o /tmp/ksu_setup.sh
bash /tmp/ksu_setup.sh "$KSU_REF"
