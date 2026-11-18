# FINAL_REVIEW_REPORT.md — AUTH-03 独立审查最终报告

- 审查阶段：`EA3588S-P2-AUTH03-INDEPENDENT-REVIEW`
- 审查日期：2026-11-17（UTC）
- 审查身份：独立审查者（不采信被审方口头结论，全部从原始源码/补丁/RAW/构建证据反向核实）
- 执行范围：VM-only、证据审查、有限隔离复核（重跑 152 项检查、独立克隆 apply/reverse、二进制对象级重算）——**全程零板端接触、零修改被审资产**

---

## 1. 最终判定

```
AUTH03_INDEPENDENT_REVIEW_PASS_WITH_WARNINGS
```

**判定依据**：
- 12 项检查：0 FAIL / 0 BLOCKED / 0 NOT_VERIFIABLE；5 PASS + 7 PASS_WITH_WARNING。
- WARNING 构成：①F-01（DMA_HEAP 死分支同构风险补充登记）②F-02（create 窄竞态维持）③F-03（int_mask，INFO 级维持）④7 项运行时验证 HARDWARE_VALIDATION_REQUIRED 维持 ⑤R-08/R-09 UNKNOWN 维持。
- 三项风险的 VM-only 修复成果及证据链经独立重算后**成立且可复现**，但运行时有效性未经任何真实硬件检验。

**判定的准确含义（边界声明）**：

> 本判定仅表明：AUTH-03 的 VM-only 修复成果及其证据链通过独立审查，**具备申请后续受控硬件验证的条件**。

不得据此宣布：
- R-01 已运行时 CLOSED ❌（源码修复成立+VM 测试通过 ≠ ioctl 端到端/并发/加载已验）
- R-02 已运行时 CLOSED ❌（真实 NPU 位宽与拒绝行为未实测，R-08 仍 UNKNOWN）
- R-03 已运行时 CLOSED ❌（RKNN runtime 真实形态未取证，R-09 仍 UNKNOWN）
- NPU 驱动已具备生产使用安全性 ❌
- 板端部署已获授权 ❌

---

## 2. 三项风险各自的审查结论

| 风险 | 源码修复 | VM 测试证据 | 对象/构建证据 | 运行时状态 | 综合审查结论 |
|---|---|---|---|---|---|
| **R-01**（CRITICAL：mem_create 用户指针） | ✅ 成立：活跃路径（DRM_GEM=y）全部收敛注册表（gem.c:1804/job.c:160/297/102），注册表锁/引用/注销序正确，sync 4 出口+job_alloc 3 出口引用配平 | ✅ 88/0 可复现（重跑逐字节一致），提取保真（函数体=源码） | ✅ 7 新符号+内联证据成立 | `HARDWARE_VALIDATION_REQUIRED` | **源码级修复成立，具备硬件验证条件**；F-01/F-02 登记 |
| **R-02**（HIGH：dma-buf DMA 截断） | ✅ 成立：三注入点（job.c:836/405、gem.c:1546）全守卫，写入点全景无遗漏，READ_ONCE 消 TOCTOU，u64 界检无溢出 | ✅ 16/0 可复现，边界/回绕用例属实，size==0 实证 | ✅ 守卫矩阵 8/8/0/0 | `HARDWARE_VALIDATION_REQUIRED`（含 R-08 位宽取证） | **源码级修复成立（保守 fail-closed，无越权声明）**；F-03 登记 |
| **R-03**（HIGH：kv_addr 合约） | ✅ 成立：e4629a6↔补丁↔源码三方一致，kv 唯一读点守卫无绕过，u64 界检算术独立推演通过，int 陷阱不可达使用点 | ✅ 48/0 可复现，边界/错误路径断言全覆盖 | ✅ 对象级最小变化全部声明独立重算证实（drv.o 2 指令差异=task_obj 位移；29 节 SAME；handle_create=内联） | `HARDWARE_VALIDATION_REQUIRED`（R-09 形态取证） | **源码级修复成立，对象级证据链为三项中最强** |

---

## 3. 12 项检查表汇总（详见 07_12_ITEM_CHECKLIST/IR_CHECKLIST.md）

| IR-01 | IR-02 | IR-03 | IR-04 | IR-05 | IR-06 | IR-07 | IR-08 | IR-09 | IR-10 | IR-11 | IR-12 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| PASS | PASS | P_W_W | P_W_W | P_W_W | P_W_W | P_W_W | PASS | PASS | PASS | P_W_W | P_W_W |

（P_W_W = PASS_WITH_WARNING；FAIL=0）

---

## 4. 独立复核方法与零修改证明

| 复核动作 | 结果 |
|---|---|
| 交付包 82 文件 `sha256sum -c`（审查前后两次） | 82/82 OK（零修改证明） |
| 三 harness 隔离重跑（/tmp/opencode/rv） | 152 项与 RAW 逐字节一致，rc=0，输出固化于 `06_TEST_EVIDENCE_REVIEW/RECHECK/`（标 INDEPENDENT_RECHECK） |
| 提取守卫重跑 + 函数体 python 精确抽取比对 | EXTRACTION_OK；三函数定义体与源树逐字节一致 |
| 独立克隆 R01→R02→R03 顺序 apply | 4 文件与 e4629a6 逐字节一致；reverse R-03=dcd87ac 版 |
| .o/.ko 对象级独立重算（冻结工具链 readelf/nm/objdump/strings） | debugger/iommu/reset 全代码节 IDENTICAL；drv.o .text 仅 2 指令差异；BL vs D4-B1 29 节 SAME+恰 3 节路径差异；守卫矩阵/符号差全吻合 |
| 对照树状态 | d4b1-patch/build-official/auth03-patch 三树零改动（2 个 untracked .d 为 D4-B1 历史残留，非本次引入） |

---

## 5. 维持的 UNKNOWN 与待硬件项（强制保留，未被本审查关闭）

- **R-08（真实 NPU DMA 位宽）：UNKNOWN —— 维持**
- **R-09（RKNN runtime 真实使用形态）：UNKNOWN —— 维持**
- **7 项运行时验证：`HARDWARE_VALIDATION_REQUIRED` —— 全部维持**（ioctl 端到端 / DMA 位宽实测 / 并发压力 / fork mmap / 模块加载 / srcversion 板端实测 / runtime 回归）
- Handle 化方案 A：仅风险说明审查（登记在位），未开发。

## 6. 对下一步的建议（仅为建议，非授权）

**建议进入下一阶段（受控硬件验证）的申请**，前置条件已具备：
1. 证据链完整可复现（本审查独立重算闭环）。
2. 补丁冻结可回退（R-03 可单独精确 reverse）。
3. 风险登记如实（F-01~F-03/R-08/R-09/7 项 HW 全部带入验证计划，见 08 报告 §4）。

后续板端部署、模块加载、NPU 冒烟测试**必须另行形成具体执行计划并取得用户明确新授权**。

---

## 7. 审查包交付清单（本包）

| 目录 | 内容 |
|---|---|
| 00_INPUT_INTEGRITY | 输入包完整性核验报告（IR-01） |
| 01_SOURCE_AND_BUILD_IDENTITY | 源码与构建身份核验（IR-02） |
| 02_R01_REVIEW | R-01 独立审查（IR-03/IR-04） |
| 03_R02_REVIEW | R-02 独立审查（IR-05/IR-06） |
| 04_R03_REVIEW | R-03 独立审查（IR-07/IR-08） |
| 05_PATCH_CROSS_REVIEW | 补丁组合与顺序审查（IR-09） |
| 06_TEST_EVIDENCE_REVIEW | 测试证据审查 + `RECHECK/`（INDEPENDENT_RECHECK 重跑输出） |
| 07_12_ITEM_CHECKLIST | 12 项检查表 |
| 08_FINDINGS_AND_WARNINGS | 问题与 WARNING 清单（F-01/F-02/F-03 + 维持项 + 硬件验证输入建议） |
| 09_FINAL_REVIEW_REPORT | 本报告 |
| 根 SHA256SUMS | 全包哈希清单（自校验 100% OK） |

---

## 8. STOP 声明

```
本独立审查到此完成并停止。
不连接 EA3588S、不部署板端、不加载模块、不执行任何 NPU 操作。
等待用户新的明确授权后再规划受控硬件验证阶段。
```
