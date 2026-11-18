# KERNEL_BUILD_FREEZE — E2 驱动与内核构建冻结说明

## 1. 冻结身份

| 件 | 值 |
|---|---|
| 内核版本 | `6.12.69-ophub`（源基线 linux-6.12.69-unifreq-cf31448c） |
| 内核镜像 | vmlinuz 38,996,480B，SHA256 `c6740dfda82e659161747aae411cd1696ab65a0e90839afc0ebf181e8ef3b16f`（构建 2026-11-04） |
| 内核配置 | 主仓 `compile-kernel/tools/config/config-6.12`（a81b5fd6 入库） |
| 工具链 | arm-gnu-toolchain-15.3.rel1-x86_64-aarch64-none-linux-gnu（SHA256 `ea12d99f…4d9`） |
| E2 模块 | rknpu.ko 2,469,512B，SHA256 `120e0240…e25ce3`；vermagic `6.12.69-ophub SMP mod_unload aarch64`；srcversion `3D2A681794D91035B698E9D` |

## 2. NPU 驱动构建宏（冻结）

启用：`CONFIG_ROCKCHIP_RKNPU_DRM_GEM=1`、`CONFIG_ROCKCHIP_RKNPU_DEBUG_FS=1`
未启用：`CONFIG_ROCKCHIP_RKNPU_DMA_HEAP`、`CONFIG_ROCKCHIP_RKNPU_FENCE`、`CONFIG_ROCKCHIP_RKNPU_SRAM`
（与 E2 构建时 `.cmd` 冻结宏一致；改动任一宏 = 新驱动身份 = 须重新全链验证）

## 3. 纪律

- 内核与模块**必须同源同配置构建**，vermagic 严格一致；禁止跨构建混用。
- 部署前必须核对三层哈希：vmlinuz（c6740dfd）/ rknpu.ko（120e0240）/ modules.dep（板端 d1d3179e → 部署后 a84187c7）。
- depmod 交叉生成说明：构建 VM kmod 34.2 对 aarch64 树 `depmod -b` 与板端 kmod 30 输出格式兼容（同条目逐字节抽检通过）。

## 4. 复现

见同目录上级 `BUILD_EA3588S.md`（含补丁链 apply_p3b_patches.py / apply_p3b_patch4.py 与 run-build.sh 参数）。
