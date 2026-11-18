# INSTALL_EA3588S — EA3588S NPU 固件安装/更新指南

版本 `EA3588S-Armbian-NPU-1.0.0-rc1`。**先选场景**：

| 场景 | 用法 |
|---|---|
| 系统正常，想加 NPU 能力 | 第 1-3 节（Level B） |
| 系统可启动但 rootfs/boot 旧 | 仍走 Level B（它同时更新 p2 与 rootfs 侧） |
| 系统崩溃/无法启动/eMMC 损坏 | `RECOVERY_EA3588S.md`（Level A，勿用本指南） |

## 1. 前置确认（Level B 门禁，脚本会逐项重查）

- 设备为 EA3588S：`grep BOARD_NAME /etc/armbian-release` → `EA_3588S`
- 内核：`uname -r` → `6.12.69-ophub`
- DTB 兼容：`cat /proc/device-tree/model` 含 EA3588S/rk3588
- p2：`lsblk /dev/mmcblk0` → p2 为 128M
- 空间：rootfs 剩余 ≥ 256MB（备份 p2 需 128MB）

## 2. 获取与校验更新包

从 GitHub Release 下载 `ea3588s-npu-1.0.0-rc1-update.tar`（或目录形式制品），解包后：

```bash
cd ea3588s-npu-1.0.0-rc1-update
sha256sum -c SHA256SUMS        # 全部 OK 才继续
```

## 3. 执行更新（门禁→备份→安装→验证，全程不重启）

```bash
sudo DRYRUN=1 bash ea3588s-npu-update.sh    # 演练：门禁照跑，零写入
sudo bash ea3588s-npu-update.sh             # 实际执行
# 检查输出无 ABORT；备份目录形如 /var/backups/ea3588s-npu-update-<TS>/
```

脚本行为（设计承诺，已在 VM 夹具实测）：
- 备份当前 p2 整分区 + depmod 元数据 9 件 + 既有件
- 纯新增 rootfs 侧文件（驱动/配置/modelctl/单元/探针），不动无关配置
- dd 新 p2 镜像并**读回校验**（128MiB 全量哈希）
- **不重启**、**不切默认启动项**（新 extlinux default=l0 与 P13 一致）

## 4. 激活 NPU（更新后，用户手动）

1. 选择维护窗口，重启系统。
2. U-Boot 菜单选 **l1**（`Armbian bookworm 6.12.69-ophub NPU test DTB`，含 `cma=2048M`）。
3. 首次验证：

```bash
rknpu-modelctl verify          # 应报 module=power= 就绪
ls /dev/dri/renderD128         # 应存在
dmesg | grep -i rknpu          # 应见 rknpu drm 初始化
```

**保守回退**：重启时仍选 l0（默认）即回到无 NPU 基线，rootfs 侧新增件不影响 l0 运行。

## 5. 验证模型推理（已部署模型层时）

```bash
rknpu-modelctl start vision    # M1V
rknpu-modelctl infer vision    # 10 次推理 checksum（G6 基线 0x6ae6dc22ba88b5e7）
rknpu-modelctl stop vision
rknpu-modelctl start llm && rknpu-modelctl infer llm && rknpu-modelctl stop llm
```

服务单元为**按需服务**（未 enable）：`systemctl start ea3588s-model-vision` 或用 modelctl。

## 6. 回滚（如需撤销更新）

```bash
sudo bash ea3588s-npu-rollback.sh /var/backups/ea3588s-npu-update-<TS>
```

恢复 p2 备份镜像 + 移除全部新增文件 + 恢复 depmod 元数据；同样不重启。详见 `ROLLBACK` 章节（RECOVERY_EA3588S.md §4）。

## 7. 模型层部署（许可隔离件，不随制品分发）

恢复/更新后的系统具备"驱动可加载 + 服务层就绪"。启用推理还需（用户自备，来源登记于模型资产清单）：

1. **runtime**（厂商二进制 `librknnrt-2.3.2` / `librkllmrt-1.2.3`）→ 部署到 `/opt/rknn-runtime/`（探针 rpath 指向此路径）。部署后按 `MODEL_DOWNLOAD_MANIFEST` 的 SHA256 校验。
2. **模型权重**（M1V `qwen3-vl-2b_vision_rk3588.rknn` / M1L `qwen3-vl-2b-instruct_w8a8_rk3588.rkllm`）→ 按清单哈希校验后放 `~/Downloads/`（modelctl 默认搜索路径）。
3. `rknpu-modelctl verify` 确认模型层就绪。

> 许可说明：模型权重再分发许可 UNKNOWN，runtime 为厂商不可再分发二进制。**不要**把它们提交进任何仓库或公开 Release。

## 8. 常见问题

| 症状 | 处置 |
|---|---|
| 更新脚本 G1 拦截 | 确认设备/内核/DTB——本包仅适用 6.12.69-ophub 的 EA3588S |
| W8 读回哈希不符 | 脚本已 ABORT 且提示勿重启；立即回滚恢复 p2 |
| l1 启动后无 renderD128 | 查 `dmesg | grep -iE "rknpu|cma"`；确认选了 l1（cma=2048M） |
| 模型加载失败 | `rknpu-modelctl verify` 看模型层是否部署（第 7 节） |
