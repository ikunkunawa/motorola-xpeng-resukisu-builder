# ReSukiSU Kernel CI 项目交接文档

## 项目概览

为 Motorola Edge S30 (代号 `xpeng`, SoC SM7325/lahaina) 构建 LineageOS 23.2 内核，集成 ReSukiSU (KernelSU 分支) root 方案。当 LineageOS 发布官方更新时，自动构建可刷入的 `boot-ksu.img`。

**仓库**: `https://github.com/ikunkunawa/motorola-xpeng-resukisu-builder`

## 核心参数

| 参数 | 值 |
|---|---|
| 设备 | Motorola Edge S30 (`xpeng`) |
| SoC | Qualcomm SM7325 (lahaina) |
| 内核版本 | 5.4.302 (非 GKI) |
| LOS 分支 | `lineage-23.2` |
| ReSukiSU ref | `main` |
| Clang | 系统包 `clang lld llvm` (Ubuntu 22.04 = clang 14) |
| CI Runner | `ubuntu-22.04` |
| 编译参数 | ThinLTO + CFI + LD=ld.lld |
| 内核产物 | `Image` (未压缩，非 Image.gz) |
| Boot header | v3，无 dtb |
| 官方 boot.img | https://mirrorbits.lineageos.org/full/xpeng/20260822/boot.img |

## 仓库结构

```
.github/workflows/kernel.yml   # CI 工作流，workflow_dispatch 手动触发
scripts/build.sh                # 主构建脚本（9 步流程）
patches/
  0001-fix-werror-unused.patch  # sde_color_processing.c __maybe_unused 修复
  0002-resukisu-hooks.patch     # KSU 手动 hook 补丁（exec/faccessat/stat/reboot）
tools/
  pack_boot.sh                  # 换核合成脚本（解包→替换内核→重打包→md5校验）
  mkbootimg.py                  # AOSP boot 镜像打包器
  unpack_bootimg.py             # AOSP boot 镜像解包器
  gki/                          # gki 桩模块（mkbootimg 依赖，空实现）
    __init__.py
    generate_gki_certificate.py
```

## 构建流程 (build.sh, 9 步)

```
[1/9] 克隆内核源码    git clone --depth=1 -b lineage-23.2 LineageOS/android_kernel_motorola_sm7325
[2/9] 应用补丁        patches/ 下的 .patch，幂等（已应用跳过，上下文不存在也跳过）
[3/9] 集成 ReSukiSU   curl 官方 setup.sh 执行
[4/9] 工具链          apt install clang lld llvm（或 CLANG_DIR_OVERRIDE 本地路径）
[5/9] 交叉工具链      apt install gcc-aarch64-linux-gnu gcc-arm-linux-gnueabi
[6/9] 生成配置        defconfig → merge xpeng.config → 启用 ThinLTO → 校验 KSU=y
[7/9] 编译内核        make -j$(nproc) Image
[8/9] 获取官方 boot   下载或复制官方 boot.img
[9/9] 换核合成        pack_boot.sh: 解包官方 boot → 替换内核 → 重打包 → ramdisk md5 校验
```

## pack_boot.sh 合成流程

1. `unpack_bootimg.py` 解包官方 `boot_official.img`，提取 ramdisk + 元信息 (os version, patch level)
2. `mkbootimg.py` 用新内核 `Image` + 原始 ramdisk + header v3 重打包
3. `unpack_bootimg.py` 解包产出的 boot，md5 校验 ramdisk 一致性

## 补丁说明

### 0001-fix-werror-unused.patch
`techpack/display/msm/sde/sde_color_processing.c` 中三个变量声明未使用导致 `-Werror` 编译失败，加 `__maybe_unused`。补丁幂等——如果上游已修复，`git apply` 会检测到上下文不匹配并跳过。

### 0002-resukisu-hooks.patch
ReSukiSU 在 Linux <6.8 不支持 LSM，需要 4 个手动 hook 点：
- `fs/exec.c`: `ksu_handle_execveat` — 进程执行
- `fs/open.c`: `ksu_handle_faccessat` — 权限检查
- `fs/stat.c`: `ksu_handle_stat` + `ksu_handle_newfstat_ret` — 文件状态
- `kernel/reboot.c`: `ksu_handle_sys_reboot` — 重启拦截

同时在 `lineage_xpeng.config` 添加 `CONFIG_KSU=y` 和 `CONFIG_KSU_MANUAL_HOOK=y`。

## 环境变量

| 变量 | 必填 | 默认值 | 说明 |
|---|---|---|---|
| `BOOT_URL` | 是 | — | 官方 boot.img 直链或本地路径 |
| `LOS_BRANCH` | 否 | `lineage-23.2` | LineageOS 分支 |
| `KSU_REF` | 否 | `main` | ReSukiSU 仓库 ref |
| `CLANG_DIR_OVERRIDE` | 否 | — | 本地 clang 目录（跳过 apt install） |

## 已知坑 & 调试记录

### CI 历次修复 (按时间顺序)

| 问题 | 修复 |
|---|---|
| Runner `ubuntu-24.04` 无限排队 | → `ubuntu-22.04` |
| Swap step 报 "Text file busy" | 移除 swap step，runner 自带 swap |
| 补丁 0001 上下文不匹配时报错退出 | 改为检测不存在时跳过 |
| clang 版本检测 URL 指向 `android_build` 404 | → `android_build_soong` |
| clang 从 googlesource 下载 (10GB 仓库, 超时) | → `apt install clang lld` |
| `llvm-ar`/`llvm-nm` not found | 加装 `llvm` 包 |
| `WORKDIR: unbound variable` | 添加 `WORKDIR="${REPO_DIR}"` 定义 |
| `mkbootimg.py` 缺少 `gki` 模块 | 添加 `tools/gki/` 空桩模块 |

### OUT_DIR 绝对路径问题

**绝对不要** 在 bashrc 或环境中 export `OUT_DIR` 为绝对路径。soong 的 `ci_test_package_zip.go` 有 `HasPrefix(f,"out")` 启发式检查，绝对路径会导致测试失败。

### Clang 版本

不要硬编码 clang 版本号。构建系统通过 `build/soong/cc/config/global.go` 的 `ClangDefaultVersion` 动态决定。CI 使用系统 apt 的 clang 即可自动适配。

## 本地测试方法

```bash
# 在服务器上
cd /home/kun/TEST
BOOT_URL=boot_official/boot.img CLANG_DIR_OVERRIDE=/home/kun/lineage-24.1/prebuilts/clang/host/linux-x86/clang-r563880c bash /home/kun/TEST/repo/scripts/build.sh
```

## 触发 CI

GitHub Actions 页面：`Actions → Build ReSukiSU kernel → Run workflow`

可选填 `boot_url` 覆盖默认官方镜像链接。

## 设备刷入验证

已验证 `boot-ksu-test.img` 可在设备上正常启动并获得 root 权限。

## 当前状态

- CI 工作流已推送，最近一次 push 触发的构建在进行中
- 如果构建成功，`Actions` 页面可下载 `boot-ksu` artifact（即 `boot-ksu.img`）
- 官方更新时手动触发 workflow 即可获得新内核
