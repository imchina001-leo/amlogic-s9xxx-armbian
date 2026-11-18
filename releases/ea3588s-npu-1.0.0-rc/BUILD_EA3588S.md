# BUILD_EA3588S — EA3588S NPU 固件从源码复现构建指南

适用版本：`EA3588S-Armbian-NPU-1.0.0-rc1`。本指南在**独立构建环境**（VM/另一台 Linux x86_64）执行，绝不触碰在用主板。

## 0. 构建产物与已验证基线的对应

| 产物 | 验证基线身份 |
|---|---|
| `vmlinuz-6.12.69-ophub` | SHA256 `c6740dfd…f3b16f`（38,996,480B） |
| `rknpu.ko`（E2） | SHA256 `120e0240…e25ce3`，vermagic `6.12.69-ophub SMP mod_unload aarch64` |
| `rk3588s-ea3588s.dtb`（l0） | `87dd7145…` |
| `rk3588s-ea3588s-npu-test-g1.dtb`（l1） | `a504ce4c…` |

内核与驱动必须同树同配置构建，vermagic 严格一致；**禁止混用未经验证的旧构建**。

## 1. 环境

- x86_64 Linux（Ubuntu 22.04+ 验证过），磁盘 ≥ 60G
- 交叉工具链：`arm-gnu-toolchain-15.3.rel1-x86_64-aarch64-none-linux-gnu`（SHA256 `ea12d99f87848009270277afe5d03fac873cb869784a39387183835f743014d9`）
- 内核源：`linux-6.12.69-unifreq-cf31448c.tar.gz`（P3-A 基线 tar）
- kmod（depmod 用，VM 侧版本 34.2 与板端 30 输出格式兼容已抽检）

## 2. 内核构建（复现 c6740dfd）

```bash
# 1) 解压内核源
tar xf linux-6.12.69-unifreq-cf31448c.tar.gz
# 2) 应用 P3-B 补丁集（本目录 build/patches/）
python3 build/patches/apply_p3b_patches.py      # 打入 EA3588S 适配 diff
python3 build/patches/apply_p3b_patch4.py       # 第 4 号补丁（rknpu 集成）
# 3) 配置 = 冻结 config（主仓 compile-kernel/tools/config/config-6.12，a81b5fd6 已入库）
cp compile-kernel/tools/config/config-6.12 .config
# 4) 交叉编译（用 build/run-build.sh 的冻结参数，或等价命令行）
make ARCH=arm64 CROSS_COMPILE=<toolchain-prefix> -j$(nproc)
```

冻结宏（与 E2 `.cmd` 一致，详见 `docs/KERNEL_BUILD_FREEZE.md`）：
`CONFIG_ROCKCHIP_RKNPU_DRM_GEM=1`、`CONFIG_ROCKCHIP_RKNPU_DEBUG_FS=1`；**未启用** DMA_HEAP/FENCE/SRAM。

## 3. NPU 驱动构建（复现 120e0240）

```bash
# 驱动源 = 本目录 driver/rknpu/（AUTH-03 审查通过版 @ e4629a6）
make -C <kernel-src> M=$PWD/releases/ea3588s-npu-1.0.0-rc/driver/rknpu \
     ARCH=arm64 CROSS_COMPILE=<toolchain-prefix> modules
# 产物 rknpu.ko 校验：
sha256sum rknpu.ko   # 期望 120e0240ff7f091105b415ca05e20175eaf498a5ed4d53c2394ae9b477e25ce3
modinfo -F vermagic rknpu.ko   # 期望 6.12.69-ophub SMP mod_unload aarch64
modinfo -F srcversion rknpu.ko # 期望 3D2A681794D91035B698E9D
```

## 4. DTB 构建链

```bash
# l0 板级 DTB：直接 dtc 编译 dts/rk3588s-ea3588s.dts
dtc -I dts -O dtb -o rk3588s-ea3588s.dtb dts/rk3588s-ea3588s.dts
# l1 NPU DTB：用生成链（从运行内核导出的基板 + NPU 节点注入）
python3 dts/npu/make_npu_dts.py   # 输入 board.dts（导出） → board-npu.dts
dtc -I dts -O dtb -o rk3588s-ea3588s-npu-test-g1.dtb dts/npu/board-npu.dts
```

## 5. boot 分区镜像（Level B 的 p2 件）

128MiB ext2，UUID `7a3f0000-0000-446a-8000-702f00006273`，内容：
`vmlinuz-6.12.69-ophub` + `System.map` + `config` + `dtb/{l0,l1}.dtb` + `extlinux/extlinux.conf`（default=l0，l1 含 `cma=2048M`）。
构建基线 = P9 β1 镜像（SHA256 `0187b5158affe5a20b6d6859ee9c595ecda33e030aef912f88ec8bbc2cad2bf8`）。

## 6. rootfs 与完整恢复包（Level A）

完整恢复镜像以作者 rockdev 包为基底（MiniLoaderAll/uboot/parameter 与作者发行件一致，uboot 与板端 p1 逐字节核验）：
rootfs = 作者 rootfs 基底 + 板端验证模块树（`modules.dep d1d3179e…`）+ E2 + 配置四件套 + 模型服务层 + depmod（新 `modules.dep a84187c7…`，差异=rknpu 条目）。
逐层构建过程与哈希链见发布报告 `FIRMWARE_BUILD_REPORT.md`（Release 附档）。
**rootfs 分层纪律**：runtime 与模型权重不入镜像（许可隔离）；镜像只到"驱动可加载"。

## 7. 构建后自检（最低要求）

```bash
sha256sum vmlinuz-6.12.69-ophub rknpu.ko *.dtb   # 对照第 0 节冻结值
modinfo -F vermagic rknpu.ko
depmod -b <rootfs-mount> 6.12.69-ophub && grep rknpu <rootfs>/lib/modules/6.12.69-ophub/modules.dep
```

任何一项不符 → 该构建不可用于部署（以冻结哈希为准，不以"能编译"为准）。
