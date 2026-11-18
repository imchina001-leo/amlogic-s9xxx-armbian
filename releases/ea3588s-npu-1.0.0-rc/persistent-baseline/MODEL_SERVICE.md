# MODEL_SERVICE — 模型管理服务（板端实测态）

## 组件与落位

| 件 | 路径 | SHA256 |
|---|---|---|
| modelctl | /usr/local/sbin/rknpu-modelctl（0755 root） | `e494cf0715781addeb6c4c274e710c5d06cd6017aec6c7523d6552c65b2a946b` |
| 就绪单元 | /etc/systemd/system/ea3588s-npu-verify.service | `8a2023cb92bbefaa9fcdb94b480967cb6186c7ba8a4ea8e68a76cbab034e5f8c` |
| 视觉单元 | /etc/systemd/system/ea3588s-model-vision.service | `54f5ceea372b81ccc51ca62be00717430dc4d8b2c42eb88d75cfec4b8aaa1bc7` |
| LLM 单元 | /etc/systemd/system/ea3588s-model-llm.service | `a886a3b1948a539973fa147bb914aa8852eac7a720ffa5778785fe4603d61f71` |
| 探针 | /opt/rknn-probe/g6_{vision,llm}_probe（0755） | `bf324113…` / `6ebdb7cb…` |

## 命令接口（VM 实测版，勿发明参数）

```bash
rknpu-modelctl verify          # 就绪判定（模块+设备+CMA+runtime）
rknpu-modelctl status          # NPU/模型/预算/锁状态
rknpu-modelctl infer vision    # M1V：加载+G6参数推理(校验和)+destroy
rknpu-modelctl infer llm       # M1L：加载+16token短链推理+destroy
```

也可经 systemd 按需启动：`systemctl start ea3588s-model-vision|ea3588s-model-llm`（oneshot）。

## 开机行为（实测）

系统启动 → 驱动自动加载 → renderD128 出现 → `ea3588s-npu-verify`（ConditionPathExists 门 + oneshot）自检 → Finished。
**模型单元不随开机启动**（static 未启用）→ 开机不加载大模型。verify 失败仅本单元 skip/fail，不拖垮桌面与网络（实测 l0 场景验证了隔离语义）。

启用方式说明：verify 单元按 VM 测试设计无 [Install] 节，采用 `multi-user.target.wants/` 符号链接静态启用（单元文件本体零改动）。

## 安全机制（全部实测/VM 验证）

- **互斥**：flock(/var/lock/rknpu-model.lock, -w 600)——vision/llm 不可并行
- **CMA 预算门**：vision 需 851968kB / llm 需 1736704kB，不足即拒
- **双哈希门**：模型+探针 SHA256 逐一比对
- **无无限重启**：模型单元 Restart=no、TimeoutStartSec=120/300
- **即用即释**：探针含 destroy，推理后 CMA 回收（实测 M1V 后 99.97% 回收）

## 低权限说明（如实记录）

按 VM 测试设计以 root 运行（探针需 mmap CMA 权重段 + renderD128；root+render 通道）。未改运行身份以免引入未测变量；权限最小化由哈希门+只读探针+单元无外部输入保证。后续如需降权，可在下一基线以专用系统账号重测后切换。

## 验收摘录（重启后）

M1V checksum `0x6ae6dc22ba88b5e7`（=G6）· M1L 16 token 正常输出 · 三核 IRQ 增长 · 锁无残留。
