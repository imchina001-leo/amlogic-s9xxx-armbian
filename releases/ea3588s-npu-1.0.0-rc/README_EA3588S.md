# EA3588S 个人 NPU 稳定恢复固件 — 1.0.0-rc1（Personal Recovery Candidate）

本目录是 **imchina001-leo/amlogic-s9xxx-armbian** 个人仓库的 EA3588S NPU 适配发布树。
目标：为个人 EA3588S 主板提供**可长期保存、可重复刷写、可用于系统崩溃恢复**的 NPU 稳定基线。

- 版本：`EA3588S-Armbian-NPU-1.0.0-rc1`
- 定位：**Personal Recovery Candidate**（RC——正式 Stable 需满足第八节门槛，当前未达）
- 发布制品：GitHub Release（Level A 完整恢复镜像 + Level B 系统更新包，本仓库只入库源码/脚本/文档/哈希）

## 1. 目录导览

| 路径 | 内容 |
|---|---|
| `driver/rknpu/` | NPU 内核驱动源码（AUTH-03 审查通过版，25 文件，构建出 E2 模块） |
| `dts/rk3588s-ea3588s.dts` | 板级设备树源（P8-A 基线） |
| `dts/npu/` | NPU 设备树生成链（make_npu_dts.py + board-npu.dts） |
| `build/` | 内核/驱动构建脚本与补丁（P3-B 冻结链） |
| `install/p2/` | rootfs 侧驱动自动加载部署/回滚脚本（P2 W1-W8） |
| `install/level-b/` | Level B 系统更新包脚本（门禁+备份+DRYRUN+回滚） |
| `install/model-service/` | 模型服务层（modelctl + systemd 单元） |
| `docs/` | 审查报告（AUTH-03）、P9 构建报告、内核冻结说明等 |
| `BUILD_EA3588S.md` | 从源码复现构建的完整指南 |
| `INSTALL_EA3588S.md` | 两种制品的安装/更新指南 |
| `RECOVERY_EA3588S.md` | 系统崩溃恢复与回滚指南 |
| `COMPONENT_MANIFEST.md` | 全组件清单与 SHA256 |
| `TEST_MATRIX.md` | 验证矩阵（如实区分 VM-only / 实机已验证） |
| `RELEASE_NOTES.md` / `KNOWN_ISSUES.md` | 发布说明与已知问题 |
| `SHA256SUMS` | 本目录全文件校验 |

## 2. 系统身份（冻结值）

| 组件 | 身份 |
|---|---|
| 内核 | `6.12.69-ophub`（vmlinuz SHA256 `c6740dfda82e659161747aae411cd1696ab65a0e90839afc0ebf181e8ef3b16f`） |
| NPU 驱动 E2 | `rknpu.ko` SHA256 `120e0240ff7f091105b415ca05e20175eaf498a5ed4d53c2394ae9b477e25ce3`，srcversion `3D2A681794D91035B698E9D`，vermagic `6.12.69-ophub SMP mod_unload aarch64` |
| DTB | l0 板级 `87dd7145…` / l1 NPU `a504ce4c…` |
| 启动配置 | extlinux SHA256 `35170c8d…`，default=l0（P13 基线），l1=NPU+`cma=2048M` |
| U-Boot | `uboot.img` `5e693c832747389542a8cbaad7f4c6410518db238df0c098e01d77d9bf1271fe`（与在用主板 p1 逐字节一致） |
| 引导装载 | `MiniLoaderAll.bin` `ac4fec13…`（idblock，与作者发行固件一致） |
| 分区表 | p1 uboot 4M@0x4000 / p2 boot 128M@0x6000(ext2,UUID `7a3f0000-0000-446a-8000-702f00006273`) / p3 rootfs@0x4C800(ext4)；GPT `BE480000-0000-4D2D-8000-3F8A000039C5` |

## 3. 两种恢复制品（严格区分）

| | Level A 完整恢复镜像 | Level B 系统更新包 |
|---|---|---|
| 用途 | eMMC 损坏/系统无法启动时整盘重刷 | 系统可启动，升级 NPU 能力 |
| 形态 | RKDevTool rockdev 六件套（MiniLoaderAll+uboot+parameter+package-file+boot.img+rootfs.img.xz） | 脚本包（p2 镜像 + payload + 更新/回滚脚本） |
| 依赖 | MaskROM/Loader 模式 + RKDevTool/rkdeveloptool | 目标机本地 root 运行 |
| 详情 | `RECOVERY_EA3588S.md` | `install/level-b/README_UPDATE.md` |

## 4. NPU 验证状态（如实声明）

- **G6 实机通过**（l1 + cma=2048M + E2 Live）：
  - 视觉 M1V：`rknn_init` 304ms；807.7MiB 权重分配；10 次推理 checksum 一致 `0x6ae6dc22ba88b5e7`；IRQ 0→1232；无资源泄漏
  - 语言 M1L：`rkllm_init` 9.2s；1640.8MiB 单块权重分配；16 token 输出正常；IRQ 0→3320；销毁后回收正常
- **AUTH-03 独立审查**：PASS_WITH_WARNINGS（82/82 项，详见 `docs/`）
- **P8 24h 稳定性**：**运行中，未完成，不得按 PASS 引用**
- **自动加载（W7）**：配置就绪，**未实机验证**（需授权重启）
- **Level A/B 制品**：VM-only 验证（结构/哈希/夹具往返全过），**未实机刷写验证**

## 5. 模型层隔离（许可纪律）

模型权重（M1V/M1L）再分发许可 **UNKNOWN**、RKNN runtime 为厂商二进制——**均不入 Git、不入 Release 制品**。
恢复基线达到"驱动可加载 + 服务层就绪"；模型层部署见 `INSTALL_EA3588S.md` 第 7 节。

## 6. 当前主板保护约定

发布与验证过程**不触碰**在用主板（无 reboot/rmmod/extlinux/DTB/eMMC/U-Boot/saveenv 操作）。
板端验证须用户明确批准维护窗口，优先备用介质。

## 7. 快速上手

```bash
# 复现构建驱动（VM/独立环境）
cd releases/ea3588s-npu-1.0.0-rc && cat BUILD_EA3588S.md
# 现有系统升级 NPU
cat INSTALL_EA3588S.md   # Level B 流程
# 系统崩溃恢复
cat RECOVERY_EA3588S.md  # Level A 流程
```

## 8. 正式 Stable 门槛（当前全部未达，RC 期间逐项补齐）

1. P8 24h PASS；2. P8 72h PASS 或用户接受替代；3. P2 自动加载部署+重启验证；
4. P9 β3 板端验证；5. P13 原有功能回归；6. 完整镜像结构与哈希审计；
7. 两制品安装说明齐备；8. 独立审查无阻断项。
