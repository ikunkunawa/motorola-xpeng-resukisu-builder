#!/usr/bin/env bash
# 用法: pack_boot.sh <官方boot.img> <新Image> <输出boot> <工作目录>
set -euo pipefail
BOOT_IN=$1; NEWKERNEL=$2; BOOT_OUT=$3; WORK=$4
TOOLS="$(cd "$(dirname "$0")" && pwd)"
rm -rf "$WORK"; mkdir -p "$WORK"

python3 "$TOOLS/unpack_bootimg.py" --boot_img "$BOOT_IN" --out "$WORK" | tee "$WORK/header.txt"

HV=$(grep -oP 'boot image header version: \K\d+' "$WORK/header.txt")
[ "$HV" = "3" ] || { echo "仅支持 header v3 (当前 v$HV)"; exit 1; }

ARGS=(--kernel "$NEWKERNEL" --ramdisk "$WORK/ramdisk" --header_version 3)
OSV=$(grep -oP 'os version: \K\S+' "$WORK/header.txt" || true)
OPL=$(grep -oP 'os patch level: \K\S+' "$WORK/header.txt" || true)
[ -n "$OSV" ] && ARGS+=(--os_version "$OSV")
[ -n "$OPL" ] && ARGS+=(--os_patch_level "$OPL")

python3 "$TOOLS/mkbootimg.py" "${ARGS[@]}" -o "$BOOT_OUT"

python3 "$TOOLS/unpack_bootimg.py" --boot_img "$BOOT_OUT" --out "$WORK/verify" > /dev/null
md5sum "$WORK/ramdisk" "$WORK/verify/ramdisk"
[ "$(md5sum < "$WORK/ramdisk")" = "$(md5sum < "$WORK/verify/ramdisk")" ] && echo "ramdisk 校验一致"
echo "OK: $BOOT_OUT"
