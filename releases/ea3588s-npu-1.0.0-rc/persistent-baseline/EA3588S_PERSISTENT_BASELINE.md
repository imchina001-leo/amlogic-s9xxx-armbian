# EA3588S_PERSISTENT_BASELINE — 持久化 NPU 基线（板端实测态）

> 状态：**已部署并经两次受控重启验收（终态全 PASS）** · 2026-11-18
> 上游：本仓库 Release `EA3588S-Armbian-NPU-1.0.0-rc1`（tag @ `5085ac68`，prerelease）
> 本提交：在 `release/ea3588s-npu-stable-1.0.0-rc` 分支新增（不覆盖既有 Release/标签）

## 基线一句话

EA3588S 通电后：自动进入 l1（cma=2048M）→ rknpu 驱动 systemd 自动加载 → NPU 设备就绪（renderD128）→ 就绪服务自检通过 → M1V/M1L 模型**按需**加载（互斥 + 哈希门 + CMA 预算门）——**无需任何人工 insmod / 手动选启动项**。

## 关键身份总表

| 组件 | 值 |
|---|---|
| 内核 | 6.12.69-ophub（vmlinuz SHA256 `c6740dfda82e659161747aae411cd1696ab65a0e90839afc0ebf181e8ef3b16f`） |
| NPU 驱动 | rknpu.ko `120e0240ff7f091105b415ca05e20175eaf498a5ed4d53c2394ae9b477e25ce3`，srcversion `3D2A681794D91035B698E9D`，vermagic `6.12.69-ophub SMP mod_unload aarch64` |
| l1 DTB | `rk3588s-ea3588s-npu-test-g1.dtb` `a504ce4c205c3f967b6a2f793ca3d2484545c38c706bfadfc63a53bdf2258622` |
| l0 DTB | `rk3588s-ea3588s.dtb` `87dd71452fb5ca0212d0773844df54e157a24eabb51942986eb9d9f8df3fa595` |
| CMA | 2048M（l1 启动参数；实测 CmaTotal 2,097,152kB） |
| extlinux（双份一致） | `ef34c7f71f91bb41da0410a4d875276235d0c4350116964653a666bef4793b42`，`default l1`，l0 入口保留 |
| M1V 模型 | `/home/admin/Downloads/qwen3-vl-2b_vision_rk3588.rknn` 850,488,413B `3d707ef5dbf0e420ac48e57b5bf0ed6c0fd1d5d048c29d81e1b5a8d051ab7ea8` |
| M1L 模型 | `/home/admin/Downloads/qwen3-vl-2b-instruct_w8a8_rk3588.rkllm` 2,375,022,956B `d5474340221fc495c70e1ec2c7dafc4ebf88292ce466db7e771e3a20b99cf21f` |
| RKNN 运行时 | librknnrt.so `d31fc19c85b85f6091b2bd0f6af9d962d5264a4e410bfb536402ec92bac738e8`（API 2.3.2） |
| RKLLM 运行时 | librkllmrt.so `bbcf28a8666b9fbf7361d6aad892b957920f6ea92400c074899b48f4c5b2c96f`（1.2.3） |
| modelctl | `/usr/local/sbin/rknpu-modelctl` `e494cf0715781addeb6c4c274e710c5d06cd6017aec6c7523d6552c65b2a946b` |
| 探针 | /opt/rknn-probe/ g6_vision_probe `bf324113…832cf56` / g6_llm_probe `6ebdb7cb…6fc12ce` |

## 验收结论（2026-11-18T12:0xZ，第二次受控重启后）

- 启动：无人工干预自动进 l1 ✅（cmdline 含 cma=2048M）
- 驱动：自动加载 ✅ 设备绑定 fdab0000.npu ✅ renderD128 ✅ IRQ 81/82/83 ✅ idle power off ✅
- 服务：ea3588s-npu-verify Finished（MODELCTL_VERIFY_OK）✅ 零 failed 单元 ✅ 开机不载大模型 ✅
- 模型：M1V checksum `0x6ae6dc22ba88b5e7`（与 G6 逐字一致）✅；M1L 16 token 输出正常 ✅；CMA 即用即释 ✅
- 硬件回归：eth0/wlan0、XFCE/lightdm、HDMI、USB、蓝牙全 ✅
- 详见同目录 TEST_MATRIX.md

## 遗留（非阻断）

- P8 24h 稳定性测试因授权部署中断（tick 30/288，2 cycle PASS，`INTERRUPTED_BY_AUTHORIZED_DEPLOYMENT`），可在本基线上重新安排
- 模型以 root 运行（VM 测试设计原样，见 MODEL_SERVICE.md 低权限说明）
- Release rc1 制品的实机全量刷写验证仍未执行（rc1 为恢复用制品，非本基线运行必需）
