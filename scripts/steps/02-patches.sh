# 应用补丁（幂等：已应用跳过；上游上下文不存在也跳过）
cd "$KERNEL_DIR"

for p in "$REPO_DIR"/patches/*.patch; do
  pname="$(basename "$p")"
  if git apply --check "$p" 2>/dev/null; then
    git apply "$p"
    log "  $pname: 已应用"
  elif git apply --reverse --check "$p" 2>/dev/null; then
    log "  $pname: 已存在，跳过"
  else
    log "  $pname: 上下文不存在，跳过"
  fi
done
