#!/usr/bin/env bash
# 构建入口调度器：按序执行 steps/ 下的编号脚本。
# 各步骤通过 source 执行，共享 shell 环境（PATH、工作目录、变量），
# 任一步骤失败即整体失败 (set -e)。
set -euo pipefail

STEPS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/steps"

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

shopt -s nullglob
steps=("$STEPS_DIR"/[0-9]*.sh)
shopt -u nullglob

[ "${#steps[@]}" -gt 0 ] || { echo "错误: 未找到任何步骤脚本 ($STEPS_DIR/[0-9]*.sh)"; exit 1; }

total=${#steps[@]}
i=0
for step in "${steps[@]}"; do
  i=$((i+1))
  log "──── [$i/$total] $(basename "$step") ────"
  # shellcheck disable=SC1090
  source "$step"
done

log "全部步骤完成。产物: $REPO_DIR/boot-ksu.img"
