# 模型服务长期化设计（MODEL_SERVICE_DESIGN）

| 项 | 内容 |
|---|---|
| 阶段 | POST-G6 / F |
| 日期 | 2026-11-18 |
| 目标 | 把"手动运行探针"升级为**可管理、可恢复、职责分离**的长期模型服务 |
| 状态 | 设计 + 资产（systemd 单元 ×3 + modelctl CLI）就绪；**板端部署属写入操作，随 P2 审批包之后的独立批次申请** |
| 硬约束 | 2GiB CMA 下 M1V（808MiB）+ M1L（1,640.8MiB）**不可共存**（合计 2,449MiB > 2,048MiB）→ 互斥加载是设计核心 |

---

## 1. 架构（F1：职责分离）

```text
systemd-modules-load.service（P2 W3：modprobe rknpu）
        ↓ After=
ea3588s-npu-verify.service（oneshot：NPU 就绪判定）
  判据：/dev/dri/renderD128 存在 + /sys/module/rknpu Live + debugfs power 可读
        ↓ （就绪后可调度，未就绪不阻塞系统）
ea3588s-model-vision.service ┐
ea3588s-model-llm.service   ┘（相互独立、互斥运行、按需启动——非开机自启）
        ↓ 调用
rknpu-modelctl（管理 CLI：flock 全局锁 + 互斥切换 + G6 探针复用）
```

**职责分离**：
- `ea3588s-npu-verify.service`：只做驱动就绪判定（P2 §7 原设计），零模型逻辑；
- `ea3588s-model-vision.service` / `ea3588s-model-llm.service`：各自只面向一个模型，ExecStart 调 modelctl（vision/llm），失败不级联；
- `rknpu-modelctl`：唯一资源仲裁者（flock 互斥、加载状态、CMA 预算核算）。

## 2. 启动策略（F2 分阶段）

| 阶段 | 内容 | 状态 |
|---|---|---|
| 第一阶段 | 开机自动加载 NPU 驱动 | = P2 W1–W8（审批包 A，在批） |
| 第二阶段 | NPU 初始化成功后自动启动模型**管理**服务（仅 verify + modelctl 就绪，**不加载模型**） | 本设计（verify 单元随 P2 后部署） |
| 第三阶段 | **按需加载模型**：阅卷/推理请求到达 → `systemctl start ea3588s-model-vision|llm` → modelctl 探针级推理 → 完成 `stop` 释放 CMA | 本设计（modelctl 已实现互斥与释放） |
| 第四阶段 | 本地阅卷程序调用接口 | P7 范围（接口口径预留：CLI `rknpu-modelctl infer <model> <input>`，进程级调用同一 flock 协议） |

**默认策略**：开机**不**自动加载任何模型（避免 CMA 长期占用 + 启动时间膨胀——M1L init 9.2s）；M1V/M1L 永不同时在线。

## 3. systemd 单元设计要点

| 单元 | 类型 | 关键属性 |
|---|---|---|
| `ea3588s-npu-verify.service` | oneshot | `After=systemd-modules-load.service`；`ConditionPathExists=/dev/dri/renderD128`；`ExecStart=modelctl verify`；失败 → 系统照常进桌面（`DefaultDependencies` 不拉关键链） |
| `ea3588s-model-vision.service` | oneshot | `After=ea3588s-npu-verify.service` + `ConditionPathExists=/dev/dri/renderD128`；`ExecStart=modelctl infer vision`；`TimeoutStartSec=120`；无 `Restart`（禁无限重启） |
| `ea3588s-model-llm.service` | oneshot | 同上，`infer llm`；`TimeoutStartSec=300`（init 9.2s + 生成） |

- 全部单元 `WantedBy=` **不设 multi-user.target**（非自启；由调用方显式 start）；
- `Restart=no`；`OOMScoreAdjust` 留默认（探针短生命周期，不需要）；
- 服务账户（阶段 2）：`npugrade`（`-r -s /usr/sbin/nologin -G render`）——随 P2 阶段 2 服务化实施（当前探针 root 运行沿用 G6 口径，最小变更）。

## 4. modelctl CLI 设计（核心仲裁器）

```text
用法：rknpu-modelctl <command> [args]
  verify                NPU 就绪判定（renderD128/Live/power 三验）
  status                模型与 CMA 状态
  infer vision|llm      探针级单次推理（G6 验证入口复用）→ 自动释放
  lock-status           全局锁持有状态
纪律：全局 flock（/var/lock/rknpu-model.lock）——任何 infer 期间他者等待而非并发；
     vision→llm 切换 = 前者退出（CMA 释放）→ 后者启动（探针生命周期天然保证）；
     CMA 预算核算：infer 前查 CmaFree ≥ 模型需求（vision 832MiB / llm 1664MiB）不足即拒。
```

**探针二进制部署位**（设计决定，随 P2 后批次部署）：`/opt/rknn-probe/{g6_vision_probe,g6_llm_probe}`（0755 root，哈希冻结 `bf324113…`/`6ebdb7cb…`）——摆脱 /tmp tmpfs 自清依赖；当前 P8 24h 继续用 /tmp/g6（不干扰进行中测试）。

## 5. 故障处理矩阵（F3）

| 故障 | 处置 | 禁止事项 |
|---|---|---|
| 模型初始化失败（rknn_init/rkllm_init ≠0） | 服务退出码非 0 + journal 记录；modelctl 报告 CMA 余量辅助诊断 | 不 rmmod、不重启 |
| NPU 设备不存在 | ConditionPathExists 短路 → 服务 skipped（非 failed）；桌面正常 | 不阻塞启动 |
| runtime ABI 不匹配（dlopen 失败/符号缺） | ldd/ldconfig 预检（modelctl verify 内含）→ 明确报错退出 | 不尝试降级加载 |
| CMA 不足 | 预算核算拒载 + 提示切换（"先 stop 另一模型"） | 不强载、不 OOM 重试 |
| 模型文件损坏 | SHA256 门（modelctl 内嵌冻结哈希比对）→ 拒载 | 不加载损坏文件 |
| 服务异常退出 | systemd 记录 + 无自动重启；人工/上层按需重启 | 不 Restart=always |
| 设备忙（flock 等待超时） | 排队超时退出码 + 诊断提示 | 不抢占 |
| 重复请求 | flock 天然串行化；同模型重复 infer 幂等（探针每次独立 init/destroy） | — |
| 任务超时 | systemd TimeoutStartSec + 探针内 timeout 双层 | 不留僵尸进程（timeout 杀进程组） |

## 6. 交付物（本目录，全部 VM_ONLY_READY）

| 文件 | 内容 |
|---|---|
| `MODEL_SERVICE_DESIGN.md` | 本设计 |
| `systemd/ea3588s-npu-verify.service` | 就绪判定单元 |
| `systemd/ea3588s-model-vision.service` | 视觉模型单元 |
| `systemd/ea3588s-model-llm.service` | LLM 单元 |
| `rknpu-modelctl` | 管理 CLI（bash，flock 互斥 + 哈希门 + CMA 预算） |
| `vm_tests/` | VM 隔离测试记录（mock 板端环境演练） |

## 7. 与既有体系的衔接

- 驱动前置：P2 W1–W8（审批包 A）；
- 探针身份：G6 冻结哈希（不重编译，只部署复制）；
- 监控衔接：P8 monitor 的 debugfs 白名单（version/load/power）同样适用 modelctl verify；
- 阅卷服务（P7）：未来在 modelctl 协议之上构建，不绕过互斥锁。
