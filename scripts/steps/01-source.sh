# 克隆内核源码
if [ ! -d "$KERNEL_DIR" ]; then
  log "克隆内核源码 (branch=$LOS_BRANCH)"
  retry git clone --depth=1 -b "$LOS_BRANCH" -q \
    https://github.com/LineageOS/android_kernel_motorola_sm7325.git "$KERNEL_DIR"
else
  log "内核源码已存在，跳过克隆"
fi
