# RELEASE_NOTES — EA3588S-Armbian-NPU-1.0.0-rc1

- 发布性质：**Personal Recovery Candidate**（个人恢复候选版）
- 发布仓库：imchina001-leo/amlogic-s9xxx-armbian（个人仓库，RC 分支 `release/ea3588s-npu-stable-1.0.0-rc`）
- 发布时间：2026-11-18
- 前置成果：G5 PASS / G6 三模型 PASS（实机）/ AUTH-03 独立审查 PASS_WITH_WARNINGS / P9 β1 / POST-G6 VM-only 全套

## 本版内容

### 制品一：Level A 完整恢复镜像（rockdev 六件套）

| 组件 | 说明 |
|---|---|
| `MiniLoaderAll.bin` | idblock（DDR+SPL+usbplug），与作者发行固件一致 |
| `uboot.img` | U-Boot FIT，**与在用主板 p1 逐字节核验一致** |
| `parameter.txt` | 分区表（与主板实际 GPT 精确吻合） |
| `boot.img` | 128MiB ext2：内核 c6740dfd + l0/l1 DTB + extlinux（default=l0；l1 NPU cma=2048M） |
| `rootfs.img.xz` | 884MiB（解压 4.26G）：Armbian 26.02.0-trunk bookworm 基底 + 板端验证模块树 + E2 驱动 + 自动加载配置 + 模型服务层 |
| `package-file` | RKDevTool 打包清单 |

用途：系统崩溃后整盘恢复（RKDevTool MaskROM 路径或 rkdeveloptool/dd）。详见 `RECOVERY_EA3588S.md`。

### 制品二：Level B 系统更新包

门禁（设备/内核/vermagic/DTB/p2 容量）→ 备份（p2 整分区 + depmod 元数据）→ 安装（rootfs 纯新增 + p2 刷写读回校验）→ 不重启/不切默认项。回滚脚本配套。VM 夹具全流程+回滚往返实测通过。详见 `install/level-b/README_UPDATE.md`。

### 仓库资产（RC 分支 `releases/ea3588s-npu-1.0.0-rc/`）

NPU 驱动源码（AUTH-03 修订版 25 文件）、板级/NPU DTS 与生成链、内核构建脚本与补丁、P2 部署/回滚、Level B 脚本、模型服务层（modelctl+单元）、审查/构建报告、全套指南文档、SHA256SUMS。

## NPU 能力（实机 G6 验证基线，本制品继承）

- M1V 视觉：304ms init / 807.7MiB / 10 次推理 checksum `0x6ae6dc22ba88b5e7` / IRQ 1232 / 零泄漏
- M1L 语言：9.2s init / 1640.8MiB / 16 token / IRQ 3320 / 销毁回收正常
- 前提：l1 启动（cma=2048M）+ E2 驱动（120e0240…）+ 模型层（**许可隔离，不随制品分发**）

## 重要声明（如实）

1. **P8 24h 稳定性测试进行中（未完成）**——本版不声称稳定性 PASS。
2. **Level A/B 制品未经实机刷写验证**（VM-only 验证全过；在用主板保护约定）。
3. 自动加载（W7）配置就绪但**未实机验证**（需授权重启）。
4. 正式 Stable 需另过 8 项门槛（README §8）。
5. 模型权重与 runtime 许可状态未知/不可再分发——不在 Git 与 Release 制品中。

## 升级/回退路径

- 自 v0.1.0（无 NPU 基线）：Level B 直接升级（门禁通过后）。
- 回退：Level B 回滚脚本 → p2 回 v0.1.0 镜像（e90b3a90…）→ 整盘 Level A（本版）→ 原厂发行镜像。
