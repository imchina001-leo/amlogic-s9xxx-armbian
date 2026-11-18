# FINDINGS_AND_WARNINGS.md — 问题与 WARNING 清单

- 审查日期：2026-11-17（UTC）
- 性质：独立审查（红队视角）新增登记 + 交付包既有登记的维持确认。**发现问题时只记录，未修改原始交付包。**

## 1. 独立审查新增登记（本审查发现）

| # | 发现 | 位置 | 严重性 | 状态与建议 |
|---|---|---|---|---|
| **F-01** | `CONFIG_ROCKCHIP_RKNPU_DMA_HEAP` 分支含与 R-01 同构的裸转型：`job.c:301` `(struct rknpu_mem_object *)(uintptr_t)args->task_obj_addr`（另 job.c:299-310/944+、rknpu_mem.c 同构面）。**本构建未编入该配置**（Makefile:27 条件编译；终态 .cmd 文件实测无该宏；仅 `-DCONFIG_ROCKCHIP_RKNPU_DRM_GEM=1 -DCONFIG_ROCKCHIP_RKNPU_DEBUG_FS=1`）→ 当前为**死代码**，风险不可达 | job.c:301（DMA_HEAP 分支） | LOW（本配置不可达）/ 结构性（若启用配置） | **WARNING 级补充登记**：交付包未显式点名此分支。任何未来启用 DMA_HEAP 的构建**必须**先对该分支做同构注册表化修复，否则 R-01 风险原样复活。建议进入硬件验证阶段前的配置冻结声明中显式禁止/声明此依赖 |
| **F-02** | create_ioctl find-then-use 窄竞态：`gem.c:986` `rknpu_gem_object_find` 返回后未持引用即访问 `rknpu_obj->size/obj_addr/dma_addr`（986-1010 行），并发 destroy 可使对象释放（窄窗口）。**原版既有，AUTH-03 未修**（交付包已登记同项，原登记行号 gem.c:904 已漂移至 986 附近，登记内容一致） | gem.c:986-1010 | LOW（窄窗口） | 维持既有登记；与 handle 化方案 A（见 §3）一并考虑根治 |
| **F-03** | `int_mask` 非 READ_ONCE：`job.c:426/428` 普通读 `last_task->int_mask`/`first_task->int_mask`，用户 mmap 并发可改写。**非地址截断面**（u32 值写 32 位寄存器无高位丢失；最多改变中断掩码语义，属"任务缓冲内容依赖用户态诚实"合约内行为） | job.c:426/428 | INFO | 维持交付包既有登记，不新增处置 |

**红队结论**：未发现三补丁引入的新缺陷（F-01/F-02 均为原版既有或死代码分支，F-03 为 INFO 级合约内行为）；三项修复设计在源码层自洽。

## 2. 交付包既有登记的维持确认（独立复核在位）

| 项 | 交付包登记 | 独立复核结果 |
|---|---|---|
| R-08 真实 NPU DMA 位宽 | UNKNOWN（03/08 层登记） | ✅ 在位（grep 实测命中登记），**本审查维持 UNKNOWN**——R-02 补丁未把未知当已知（fail-closed 保守方向定性准确），但位宽确认必须等待硬件证据 |
| R-09 RKNN runtime 真实使用形态 | UNKNOWN | ✅ 在位，**维持 UNKNOWN**——KV mapping/kernel mapping 真实调用形态须真实运行环境证据 |
| 7 项运行时验证 | `HARDWARE_VALIDATION_REQUIRED`（06 层 7 处） | ✅ 在位（grep 计数=7），**全部维持**：①ioctl 端到端 ②DMA 位宽实测 ③并发压力 ④fork mmap ⑤模块加载 ⑥srcversion 板端实测 ⑦runtime 回归 |
| obj_addr 地址泄露面（R-01 残余） | 已登记（handle 化方案 A 留后续版本） | ✅ 在位：gem.c:1005 ABI 回传设计保留（本次审查确认其为 ABI 兼容性权衡，见 05 报告 §5） |
| R-11 round_up 溢出类、R-04 其余面、R-07 FENCE 不可达 | OPEN/登记 | ✅ 抽查在位（gem.c:794/827 round_up 原样；FENCE 宏未编入实证） |

## 3. Handle 化方案 A（仅审查风险说明，不开发）

- 交付包对方案 A 的定位：**根除** obj_addr 地址泄露面的后续版本路径（用户态只见 GEM handle，内核侧 handle→object 查找，消除内核指针出入用户态）。
- 本审查仅核实其风险说明与后续计划登记在位（交付包 02/09 层）；**未做任何方案 A 开发**（按任务约束禁止）。
- 审查意见：方案 A 与 F-02（find-then-use）同源，实施时应一并引入引用持有语义；ABI 变更（0.9.8 厂商往返契约破坏）须配套 runtime 适配计划——此为后续版本审查事项，本轮不展开。

## 4. 对后续受控硬件验证计划的输入（建议，非授权）

1. **配置冻结**：硬件验证阶段构建须锁定 `CONFIG_ROCKCHIP_RKNPU_DRM_GEM=1` 且 DMA_HEAP/FENCE 关闭（与本次审查对象一致）；若变更配置，F-01 等登记项须先处置。
2. **验证顺序**：模块加载+srcversion 板端实测 → ioctl 端到端（MEM_CREATE/SYNC/SUBMIT 合法流量回归）→ 边界拒绝路径（>4GB/kv NULL/越界索引的 -EINVAL 实测）→ 并发/fork 压力 → R-08 位宽取证（TRM 或 DMA 实测）。
3. **携带项**：F-01/F-02/F-03、R-08/R-09 UNKNOWN、7 项 HARDWARE_VALIDATION_REQUIRED 全部带入验证计划闭环。
4. **回退预案**：R-03 可单独 reverse（本次实测 job.c 精确回退 dcd87ac 版）——板端异常时的已知回退点。

## 5. 审查过程零修改声明

- 原始交付包 82 文件：零修改（前后哈希全等，见 09 报告 §4）。
- auth03-patch/d4b1-patch/build-official 三树：零修改（git status 前后一致）。
- 所有独立复核在 `/tmp/opencode/rv/` 隔离目录进行；复核产物固化于本包 `06_TEST_EVIDENCE_REVIEW/RECHECK/`（标 INDEPENDENT_RECHECK）。
