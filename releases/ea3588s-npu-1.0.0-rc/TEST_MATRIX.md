# TEST_MATRIX — EA3588S-Armbian-NPU-1.0.0-rc1 验证矩阵

验证等级说明：
- **实机**：在用 EA3588S 主板上实测（历史阶段 G/AUTH 系列）
- **VM-only**：构建/验证 VM 内完成（本轮 R/V/LB 系列，2026-11-18）
- **未验证**：无任何证据，如实标注

## 1. NPU 功能（实机，G5/G6 基线）

| 项 | 等级 | 结果 | 证据 |
|---|---|---|---|
| 驱动加载（E2 insmod） | 实机 | PASS | G2/G6 阶段；srcversion 3D2A68… |
| M1V 视觉推理 10 次 | 实机 | PASS | checksum `0x6ae6dc22ba88b5e7` 一致；807.7MiB；304ms init；IRQ 1232 |
| M1L 语言推理 | 实机 | PASS | 16 token；1640.8MiB；9.2s init；IRQ 3320；销毁回收 |
| 资源泄漏（长时间） | 实机 | PASS | G6 无泄漏结论 |
| 24h 稳定性（P8） | 实机 | **运行中** | tick 周期 5min；cycle 每 2h；预计 11-19T06:22Z 结束 |
| 72h 稳定性 | 未验证 | — | Stable 门槛，未启动 |
| 开机自动加载（W7） | **未验证** | — | 需授权重启；配置件 VM 已验 |

## 2. 驱动安全（AUTH-03 独立审查）

| 项 | 等级 | 结果 |
|---|---|---|
| 82 项逐项审查 | 实机+VM | PASS_WITH_WARNINGS（R-01/02/03 修复已入源） |
| 源码树与审查对象一致性 | VM | PASS（25/25 文件逐字节，@ e4629a6） |

## 3. Level A 完整恢复镜像（VM-only，本轮）

| 项 | 等级 | 结果 |
|---|---|---|
| 六组件身份终核（哈希闭环） | VM | PASS（MiniLoaderAll ac4fec13 / uboot 5e693c83=板端 p1 逐字节 / boot=β1 0187b515 / rootfs 71315182） |
| uboot.img ↔ 在用主板 p1 | 实机读 | PASS（逐字节一致） |
| parameter.txt ↔ 主板 GPT | 实机读 | PASS（p1/p2/p3 偏移容量精确吻合） |
| boot.img 内容（vmlinuz/DTB/extlinux） | VM | PASS（c6740dfd/l0 87dd7145/l1 a504ce4c/35170c8d；l1 cma=2048M） |
| p2 UUID ↔ parameter.txt | VM | PASS（7a3f0000-…-702f00006273） |
| rootfs 模块树=板端验证树 | VM | PASS（modules.dep d1d3179e 逐字节） |
| E2 注入 | VM | PASS（120e0240） |
| depmod rknpu 条目 | VM | PASS（新 modules.dep a84187c7；格式兼容抽检过） |
| P13 功能保留（XFCE/lightdm/8852bs/固件） | VM | PASS（抽检全在位） |
| 无凭据泄漏 | VM | PASS（NM 连接空、无密钥） |
| e2fsck | VM | PASS（-fn 五遍干净；首轮提示为日志重放交互假象） |
| xz 压缩完整性+往返 | VM | PASS（xz -t OK；解压哈希=71315182） |
| 实机整盘刷写 | **未验证** | —（主板保护约定；建议备用介质演练） |

## 4. Level B 系统更新包（VM-only，本轮夹具）

| 项 | 等级 | 结果 |
|---|---|---|
| 包完整性门 G0 | VM | PASS（13 件+哈希） |
| 错主机拦截 G1 | VM | PASS（非 EA3588S 主机 ABORT） |
| vermagic 双向校验 G2 | VM | PASS |
| 全流程安装（TESTMODE 夹具） | VM | PASS（W1-W8；p2 读回=0187b515） |
| 回滚往返 | VM | PASS（p2/文件/元数据全复原；modules.dep 回 d1d3179e） |
| DRYRUN | VM | PASS（8 写入步骤全跳过） |
| 实机执行 | **未验证** | —（P8 运行期禁止板端写；需授权窗口） |

## 5. 仓库与发布（本轮）

| 项 | 结果 |
|---|---|
| Git 工作区干净/分支/remote 审计 | PASS（main @ a81b5fd6 干净；origin=个人仓库） |
| git bundle 全引用备份 | PASS（`f41092b6…`） |
| RC 分支纯新增（零覆盖 main 路径） | PASS |
| 驱动源 25/25 入仓逐字节 | PASS |
| 制品 SHA256SUMS | PASS（Release 级+目录级） |
| 无许可 UNKNOWN 件入仓/入制品 | PASS（模型/runtime 隔离） |

## 6. 结论

- **VM-only 域：全 PASS**（本轮可完成的验证闭环完整）
- **实机域：G5/G6/AUTH 基线 PASS；P8 在途；制品实机刷写/部署未做**（如实，见 KNOWN_ISSUES K1-K4）
- 本 RC 定位成立：**Personal Recovery Candidate**（不得引用为 Stable）
