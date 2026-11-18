# P9 β1 固件构建报告（P9_FIRMWARE_BETA_BUILD_REPORT）

| 项 | 内容 |
|---|---|
| 阶段 | POST-G6 / E（P9 路线 β） |
| 日期 | 2026-11-18 |
| 授权依据 | 任务书 E4：本阶段允许 VM 构建、镜像检查和部署包准备；**不允许直接刷写板端**（β3 板端刷写待独立审批） |
| 构建产物 | `build/p2-boot-ea3588s-npu-1.0.0-rc1.img`（128MiB，SHA256 `0187b5158affe5a20b6d6859ee9c595ecda33e030aef912f88ec8bbc2cad2bf8`） |
| 判定 | `P9_BETA1_BUILD_OK_PENDING_BOARD_DEPLOYMENT_AUTHORIZATION` |

---

## 1. 版本一致性（E2 要求：五者身份闭合）

| 组件 | 值 | 哈希 | 验证途径 |
|---|---|---|---|
| kernel | 6.12.69-ophub（`c6740dfd…`，38,996,480B） | 基线镜像 dump 回读核验 | G5/G6 实测运行内核同版本 |
| DTB l0（兜底） | rk3588s-ea3588s.dtb（P13 基线） | `87dd7145…` | 镜像内 dump 回读 |
| DTB l1（NPU） | rk3588s-ea3588s-npu-test-g1.dtb（G1 构建） | `a504ce4c…` | 镜像内 dump 回读；G3–G6 实测同一 DTB（l1 四指纹） |
| E2 module | rknpu.ko | `120e0240…` / srcversion `3D2A68…` | 板端 Live 同一模块（G6 推理载体） |
| RKNN runtime | librknnrt.so + librkllmrt.so | `d31fc19c…` / `bbcf28a8…` | G6 M1V/M1L 实测同一 runtime |
| M1V / M1L 模型 | qwen3-vl vision / instruct w8a8 | `3d707ef5…` / `d5474340…` | G6 实测同一模型 |

**结论**：镜像内 boot 组件与板端 G6 已验证运行态**逐哈希闭合**——非混合未验证组件。

## 2. 构建过程（可复现记录）

| 步骤 | 内容 | 证据 |
|---|---|---|
| β1-0 | 基线镜像选取：`releases/ea3588s-v0.1.0/firmware/p2-boot-ea3588s-v0.1.0.img`（3 副本互证全部 `e90b3a90…`：releases + staging×2） | sha256sum 三方一致 |
| β1-1 | 复制基线 → `p2-boot-ea3588s-npu-1.0.0-rc1.img`（独立构建目录，零触碰基线/releases/staging 原件） | cp + 哈希 |
| β1-2 | 基线内部核验：vmlinuz `c6740dfd…` / l0 dtb `87dd7145…`（debugfs dump 回读） | 与 REPRODUCIBILITY_NOTES 冻结值一致 |
| β1-3 | debugfs 写入（脚本 `p9b1_debugfs.cmd` 存档）：删旧双位 extlinux.conf → 写入板端验证版 `35170c8d…`（l0+l1 双条目、default l0、timeout 300、l1 append `cma=2048M`）至 `/extlinux.conf` + `/extlinux/extlinux.conf`；新增 `/dtb/rk3588s-ea3588s-npu-test-g1.dtb`；全部 0664/1000:1000（与板端一致） | debugfs 会话日志 |
| β1-4 | e2fsck -fn 五遍只读检查：clean，无错误 | 输出存档 |
| β1-5 | 五组件回读哈希核验：双 extlinux `35170c8d…` / l1 dtb `a504ce4c…` / l0 dtb `87dd7145…` / vmlinuz `c6740dfd…` | 全过 |
| β1-6 | 终镜像哈希 `0187b515…`；free blocks 3,683（充足）；state clean | dumpe2fs |

**镜像内容摘要**（与板端 p2 现态逐项对拍）：

```text
/extlinux.conf            1059B  35170c8d…  （板端同哈希）
/extlinux/extlinux.conf   1059B  35170c8d…  （板端同哈希——U-Boot sysboot 实际读取位）
/dtb/rk3588s-ea3588s.dtb        149538B  87dd7145…  （l0，未动）
/dtb/rk3588s-ea3588s-npu-test-g1.dtb  148897B  a504ce4c…  （l1，新增）
/vmlinuz-6.12.69-ophub    38996480B  c6740dfd…  （未动）
```

## 3. 设计决策记录

1. **default 保持 l0**（BOOT_INTEGRATION 选项 A 现状复制）：β1 逐字节复刻板端已验证配置（G5/G6 全部在此配置上通过）。选项 B（default l1）留作用户决策变体——若选择，改一行 `default l0`→`default l1` 重新构建即可（流程已固化）。
2. **timeout 300 / cma=2048M 原样纳入**：D-5/D-5b 实测值（30 秒菜单窗口 + 2GiB CMA——M1L 1,640.8MiB 单块必需）。
3. **U-Boot 环境零触碰**：镜像仅 p2 文件系统内容；无 saveenv/fw_setenv（红线维持）。
4. p2 镜像 = boot 组件；rootfs 侧组件（E2 模块、runtime、模型、自动加载配置）**不在镜像内**，由既有验证过的部署件覆盖（P2 W1–W8 部署包 + /opt/rknn-runtime + ~/Downloads 模型清单）——完整固件 = 本镜像 + rootfs 部署包（见 §5）。

## 4. 与原 P9 草案 β 流程的对应

| 草案步骤 | 本轮状态 |
|---|---|
| β1 构建 | ✅ 完成（本报告 §2） |
| β2 镜像完整性验证 | ✅ 完成（β1-4/β1-5：e2fsck + 五组件回读哈希对拍；"干净虚拟启动预检"无可行 VM 手段，如实登记——真实启动验证属 β3 首启验收） |
| β3 板端刷写 | **未执行**（待独立授权：高风险级，覆盖 mmcblk0p2 全部 128MiB；前置 = 路线 α（P2 W1–W8）已验证 + P8 稳定验证完成） |
| β4 发布 | 待 1.0.0 解禁门槛（P8 24h/72h + 用户验收） |

**β 前置硬门重申**（P9 草案 §2）：路线 α 验证通过 + P8 稳定验证 → 才可请求 β3。当前 P2 执行与 P8 24h 均在进行/待批中，**本镜像仅构建就绪，不构成部署批准**。

## 5. 部署包准备（E4：刷写前须形成的人工审批清单——已备）

**镜像身份**：`p2-boot-ea3588s-npu-1.0.0-rc1.img` = `0187b515…`（128MiB，ext2，clean）。

**完整 1.0.0 固件栈（三层）**：

| 层 | 内容 | 状态 |
|---|---|---|
| L1 boot | 本镜像（β1） | 构建就绪待批 |
| L2 驱动自动加载 | P2 W1–W8 部署包（02_P2_DRIVER_AUTOLOAD/） | 写入清单待批 |
| L3 runtime+模型 | /opt/rknn-runtime 双库 + M1V/M1L（板端已部署且 G6 验证；新装机部署件 = MODEL_DOWNLOAD_MANIFEST + p3-runtime-staging） | 已验证 |

**写入目标**（β3 时）：`/dev/mmcblk0p2`（分区表零触碰）。
**备份**：基线镜像 4 副本（`e90b3a90…`：releases + staging×2 + p14-spk 备份位）+ 板端 p2 现态即时备份（β3 执行时先做）。
**回滚**：R-F = dd 刷回 `e90b3a90…` 基线（l1 条目丢失为已知代价，G2 部署脚本可重做）；或恢复 β3 前板端即时备份。
**启动验证**：S-1..S-6 + renderD128 + cmdline cma=2048M（同 G6 验证口径）。
**故障处理**：断电重启回 U-Boot 默认链 → l0（基线兜底逻辑不变）；p2 损坏 → R-F。

## 6. 构建资产清单（本目录）

| 文件 | 说明 |
|---|---|
| `build/p2-boot-ea3588s-npu-1.0.0-rc1.img` | β1 产物 |
| `build/extlinux.conf.new` | 写入源（= 板端验证版 `35170c8d…`） |
| `build/rk3588s-ea3588s-npu-test-g1.dtb` | l1 DTB 写入源（`a504ce4c…`） |
| `build/p9b1_debugfs.cmd` | debugfs 写入脚本（可复现） |
| 本报告 | 构建记录 |
