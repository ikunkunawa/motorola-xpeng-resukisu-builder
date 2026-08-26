# Motorola Edge S30 (xpeng) ReSukiSU 内核构建

基于 LineageOS 23.2 的自动化内核 CI，集成 [ReSukiSU](https://github.com/ReSukiSU/ReSukiSU)（KernelSU fork），支持 GitHub Actions 手动触发构建。

## 特性

- **Clang 构建**：使用 LineageOS 官方 clang 工具链（自动检测版本）
- **ThinLTO + CFI**：与 LineageOS 官方内核一致的编译配置
- **ReSukiSU 集成**：通过官方 setup.sh 拉取最新 ReSukiSU，手动钩子模式（兼容 5.4 内核）
- **自动化换核**：从官方 boot.img 提取 ramdisk，替换内核，重新打包
- **回环校验**：构建完成后自动验证 ramdisk MD5 与官方一致

## 快速开始

### 1. 配置仓库变量

进入仓库 **Settings → Secrets and variables → Actions → Variables → New repository variable**：

| 变量名 | 必填 | 说明 |
|--------|------|------|
| `BOOT_URL` | 是 | 官方 OTA 中提取的 `boot.img` 直链（或原始 OTA zip 链接） |

### 2. 触发构建

进入 **Actions → Build ReSukiSU kernel → Run workflow**：

- **boot_url**：填入官方 boot.img 链接（留空则使用仓库变量 `BOOT_URL`）
- 点击 **Run workflow**

### 3. 获取产物

构建完成后，在 workflow 运行记录底部的 **Artifacts** 区域下载 `boot-ksu.zip`，解压得到 `boot-ksu.img`。

### 4. 刷入

```bash
adb reboot bootloader
fastboot flash boot boot-ksu.img
fastboot reboot
```

开机后安装 ReSukiSU 管理器 APK 即可获取 root 权限。

## 构建参数

| 参数 | 值 |
|------|-----|
| 内核版本 | 5.4.302 |
| 目标架构 | arm64 |
| 芯片平台 | Qualcomm SM7325 (lahaina) |
| 内核格式 | Image（未压缩，boot header v3） |
| 内核配置 | lahaina-qgki_defconfig + lineage_moto-lahaina.config + lineage_xpeng.config |
| ReSukiSU | main 分支，手动钩子模式（CONFIG_KSU_MANUAL_HOOK=y） |
| 编译选项 | ThinLTO + CFI + LD=ld.lld + -Werror |

## 本地构建

```bash
git clone git@github.com:ikunkunawa/motorola-xpeng-resukisu-builder.git
cd motorola-xpeng-resukisu-builder

# 设置官方 boot.img（本地路径或直链均可）
export BOOT_URL=/path/to/boot_official.img

# 可选：指定 clang 跳过 GitHub 下载（加速本地测试）
export CLANG_DIR_OVERRIDE=/path/to/prebuilts/clang/host/linux-x86/clang-r563880c

bash scripts/build.sh
```

产物：`boot-ksu.img`（当前目录）。

## 获取官方 boot.img

从 LineageOS OTA 包提取：

```bash
pip install payload-dumper-go
payload-dumper -o payload_out lineage-23.2-nightly-xpeng.zip
# 产物在 payload_out/boot.img
```

或将 OTA zip 链接直接填入 `BOOT_URL`，`build.sh` 会自动下载并提取。

## 仓库结构

```
├── .github/workflows/kernel.yml   # GitHub Actions 工作流
├── patches/
│   ├── 0001-fix-werror-unused.patch  # sde_color_processing -Werror 修复
│   └── 0002-resukisu-hooks.patch     # ReSukiSU 手动钩子 + 内核配置
├── scripts/
│   └── build.sh                   # 构建流水线（克隆、补丁、编译、打包）
├── tools/
│   ├── mkbootimg.py               # AOSP boot 镜像打包
│   ├── unpack_bootimg.py          # AOSP boot 镜像解包
│   └── pack_boot.sh               # 内核替换 + 回环校验
└── README.md
```

## 补丁说明

### 0001-fix-werror-unused.patch

修复 `techpack/display/msm/sde/sde_color_processing.c` 中 `#ifdef CONFIG_GTP_FOD` 代码块内的 `-Werror=unused-variable` 编译错误，对三个变量添加 `__maybe_unused`。

### 0002-resukisu-hooks.patch

集成 ReSukiSU 手动钩子（LSM 方式，兼容 5.4 内核）：

- `fs/exec.c`：execve 钩子
- `fs/open.c`：faccessat 钩子
- `kernel/reboot.c`：reboot 钩子
- `fs/stat.c`：stat 钩子
- 内核配置：`CONFIG_KSU=y` + `CONFIG_KSU_MANUAL_HOOK=y`

## 注意事项

- **BOOT_URL 必须填写**，否则 workflow 会失败
- 构建耗时约 10-20 分钟（GitHub Actions 4 核）
- 产物不含 dtb/dtbo（xpeng 使用 boot header v3，dtb 在单独分区）
- 官方 boot.img 可通过 OTA zip 链接或提取后的直链提供
