# EA3588S NPU 系统更新包（Level B）— v1.0.0-rc1

包身份：`EA3588S-Armbian-NPU-1.0.0-rc1-update`
适用对象：**能正常启动的现有 EA3588S 系统**（不需要重刷 eMMC）。

## 用途与边界

| 制品 | 用途 |
|---|---|
| 本包（Level B） | 系统可启动，仅需升级内核启动配置 + NPU 驱动自动加载 |
| 完整恢复镜像（Level A） | eMMC 损坏/系统无法启动时的整盘重刷基线（另行发布） |

**不适用于**：已无法启动、分区表损坏、rootfs 损坏的系统——请使用 Level A 完整恢复镜像。

## 适用版本（门禁逐项校验）

- 设备：EA3588S（`/etc/armbian-release` 中 `BOARD_NAME=EA_3588S`）
- 系统：Armbian 26.02.0-trunk bookworm（P13 基线 / v0.1.0 / Level A 1.0.0-rc1）
- 内核：`6.12.69-ophub`（运行中内核，与模块 vermagic 严格一致）
- DTB：设备树 model 含 EA3588S 或 compatible 含 rk3588s
- p2 分区：`/dev/mmcblk0p2` 存在且容量恰为 128MiB

## 更新内容

1. **rootfs 侧（纯新增）**：E2 NPU 驱动 `rknpu.ko`（SHA256 `120e0240…e25ce3`）→ `/lib/modules/6.12.69-ophub/updates/drm/rknpu/`；`modules-load.d`/`modprobe.d`/udev 三配置；安装清单；`rknpu-modelctl` + 3 个 systemd 单元 + 双探针；`depmod`（先备份 9 件元数据）。
2. **boot 侧**：dd 新 p2 镜像（128MiB，SHA256 `0187b515…d2bf8`）。extlinux 含 l0（P13 基线，**默认项不变**）与 l1（NPU，`cma=2048M`，U-Boot 菜单手动选择）。

## 使用方法

```bash
sha256sum -c SHA256SUMS          # 1. 校验包完整性
sudo DRYRUN=1 bash ea3588s-npu-update.sh   # 2. 演练（门禁照跑，零写入）
sudo bash ea3588s-npu-update.sh            # 3. 实际执行
# 4. 脚本不会重启系统。确认日志无 ABORT 后由你决定何时重启
# 5. 重启后在 U-Boot 菜单选 l1 激活 NPU（默认 l0 保持 P13 基线）
```

## 安全设计（任务书六-B 逐条落实）

| 要求 | 落实 |
|---|---|
| 明确适用原始版本 | 门禁 G1（BOARD_NAME/内核/DTB/p2 容量） |
| 检查内核版本 | G1 `uname -r` = 6.12.69-ophub |
| 检查模块 vermagic | G2 包模块与板上既有模块 vermagic 双向校验 |
| DTB 兼容性 | G1 device-tree model/compatible 检查 |
| 备份被替换文件 | B1：p2 整分区 dd 备份 + depmod 元数据 9 件 + 既有件 |
| 失败可恢复 | 任一步失败即 ABORT（现场保持）；配套 rollback 脚本 |
| 不覆盖无关配置 | 仅写 NPU 专属路径 + p2；不动其他设备配置 |
| 不自动重启 | 脚本无任何 reboot 调用 |
| 不切换默认启动项 | 新 extlinux default=l0，与 P13 基线一致 |

## 回滚

```bash
sudo bash ea3588s-npu-rollback.sh /var/backups/ea3588s-npu-update-<TS>
# 恢复 p2 备份镜像 + 移除全部新增文件 + 恢复 depmod 元数据；同样不重启
```

## 已验证项（VM 夹具，2026-11-18）

- 更新脚本全流程（TESTMODE 夹具）：门禁/W1-W8/读回校验全过；p2 写入哈希 = 包哈希
- 回滚往返：p2/新增文件/depmod 元数据全部复原（modules.dep 回到板端原始 `d1d3179e…`）
- 错主机保护：非 EA3588S 主机在 G1 拒绝
- DRYRUN：8 个写入步骤全部演练跳过
- **未实机验证**：本包尚未在真实 EA3588S 上执行（P8 24h 稳定性测试运行期间禁止板端写操作；实机部署需用户批准维护窗口）

## 模型层说明（不随包分发）

runtime（`librknnrt`/`librkllmrt`，厂商二进制）与模型权重**许可状态未知/不可再分发**，不包含在本包与任何发布制品中。恢复/更新后的系统具备"驱动可加载"基线；模型层部署方法见 INSTALLATION_GUIDE 第 7 节。
