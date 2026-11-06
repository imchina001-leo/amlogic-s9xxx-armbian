# tools/patch/linux-6.12.y/ — EA3588S 专用补丁目录（说明文件，无 .patch）

## 为什么本目录没有 .patch 文件

EA3588S 的 P3-A 源码集成采用**预集成源码树**方式（"构建脚本前钩子"），
而不是本目录的 `*.patch` 机制，原因：

1. `apply_patch()`（compile-kernel/tools/script/armbian_compile_kernel.sh L429-468）
   仅消费 `*.patch` 文件，且要求 `auto_patch=true`（默认 false）；
2. RTL8852BS OOT 驱动含 27.8MB 固件数组（`phl/hal_g6/mac/fw_ax/rtl8852b/hal8852b_fw.c`），
   以 diff 形式分发（约 30MB 文本、`patch -p1`）既低效又脆弱；
3. DTS 与驱动改动已直接落在预集成树 `compile-kernel/kernel/linux-6.12.y/`
   （由 P3-A 工作区 `/mnt/armbian-work/work/p3a/kernel/linux-6.12.y/` 复制或移入），
   `get_kernel_source()`（L476-507）检测到本地树存在即跳过克隆，直接使用。

## 预集成树的来源与内容（三次提交可审计）

| 提交 | 内容 |
|---|---|
| `0790f5c` | 上游基线：unifreq/linux-6.12.y @ `cf31448c797d9aa8304b9f821d957582cfbec386`（Linux 6.12.69） |
| `e0a9923` | EA3588S 板级 DTS `arch/arm64/boot/dts/rockchip/rk3588s-ea3588s.dts` + Makefile dtb 条目 |
| `062b0df` | armbian/wifi-rtl8852bs @ `643a4990…` 驱动注入（复刻 armbian/build `driver_rtl8852bs()`） |

## 使用前提与安全边界（P3-B 必读）

- 构建命令必须显式传 `-k 6.12.69`：使 `kernel_sub=69` 与本地树 SUBLEVEL 一致，
  走 "Use local source code" 分支（L497-505），**绝不触发** `git checkout/reset --hard/pull`
  （该分支会摧毁集成内容）。
- `ARCH=arm64 CROSS_COMPILE=…` 由 `MAKE_SET_STRING`（L603）置于 make 命令行，
  优先级高于驱动 `platform/arm_rk.mk` 内的 BSP 遗留赋值（`ARCH := arm`、
  Android SDK 路径），构建安全。
- 本目录若未来放置 `.patch`，仅在 `auto_patch=true` 时生效；当前留空即保持无操作。
