# TEST_MATRIX — 持久化基线验收矩阵（2026-11-18 实测）

## 部署验收（重启前静态 16 项）

| # | 项 | 结果 |
|---|---|---|
| 1-3 | 模块哈希/vermagic/depmod 元数据 | ✅ |
| 4-7 | modules-load/modprobe.d/udev/MANIFEST 内容 | ✅ |
| 8-9 | extlinux 唯一差异 default l1；l0 入口完整 | ✅ |
| 10 | 双模型哈希 = G6 | ✅ |
| 11-13 | 单元启用状态/modelctl 权限/systemd verify | ✅ |
| 14-16 | Live E2 不受影响/网络 SSH/CMA | ✅ |
| — | 回滚脚本 DRYRUN | ✅ rc=0 |

## 重启验收（第二次受控重启后 12:05-12:08Z）

| 域 | 项 | 结果 |
|---|---|---|
| A 启动 | 无人工干预自动进 l1 | ✅ |
| A | l0 入口保留 | ✅ |
| B 内存 | CmaTotal=2,097,152kB | ✅ |
| C 驱动 | 自动加载（modules-load 路径）| ✅ |
| C | 模块 SHA/vermagic 一致 | ✅ |
| C | fdab0000.npu 绑定 + renderD128 | ✅ |
| C | IRQ 81/82/83 注册 + idle power off | ✅ |
| D 服务 | verify 单元 Finished(MODELCTL_VERIFY_OK) | ✅ |
| D | 开机不自动加载模型（无进程/无 CMA 占用/锁空闲）| ✅ |
| D | 零 failed 单元、无重启循环 | ✅ |
| E 硬件 | eth0/wlan0/lightdm/HDMI/USB(9)/蓝牙 | ✅ |

## 模型重载验收（12:10-12:14Z，串行）

| 项 | M1V | M1L |
|---|---|---|
| 哈希门 | ✅ 3d707ef5 | ✅ d5474340 |
| init | ✅ 347ms | ✅ 1336ms |
| 推理 | ✅ checksum `0x6ae6dc22ba88b5e7`（=G6 逐字） | ✅ 16 token 连贯输出（≤16 纪律） |
| NPU 使用 | ✅ IRQ81 +112 | ✅ IRQ81/82/83 → 3432/3320/3264 |
| 释放 | ✅ destroy + CMA 回收 99.97% | ✅ destroy + CMA 回收 |
| 锁 | ✅ 无残留 | ✅ 无残留 |

## 过程记录（如实）

- 第一次受控重启（08:53Z）：A 项失败（自动进 l0）——根因 p2 双份 extlinux.conf 只改了目录份；其余全 PASS（驱动自动加载/失败隔离/网络桌面全回归）。修复 + 用户授权第二次重启后闭环。
- P8 24h 稳定性：`INTERRUPTED_BY_AUTHORIZED_DEPLOYMENT`（tick 30/288、cycle 01+02 PASS、零异常）——不标 PASS，可重新安排。
- 串口观察由用户侧 screen 会话承担（板端 console=ttyS2,1500000）；本任务未发送任何串口字符。

## 未验证项（不标 PASS）

- 72h+ 长稳（未启动）· Release rc1 制品实机全量刷写（未做）· 并发推理（按纪律禁止，互斥仅以 flock 设计+VM 测试+锁状态证据）· 蓝牙外设功能细节（仅服务态验证）
