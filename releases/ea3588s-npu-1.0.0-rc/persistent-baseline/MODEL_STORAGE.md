# MODEL_STORAGE — 模型权重持久化（板端实测态）

## 存储位置（沿用，不搬动）

`/home/admin/Downloads/`（eMMC p3 rootfs，重启持久；G6 验证路径，避免 3.2GB 无谓搬移）

| 模型 | 文件 | 大小 | SHA256 |
|---|---|---|---|
| M1V（视觉） | qwen3-vl-2b_vision_rk3588.rknn | 850,488,413B | `3d707ef5dbf0e420ac48e57b5bf0ed6c0fd1d5d048c29d81e1b5a8d051ab7ea8` |
| M1L（LLM） | qwen3-vl-2b-instruct_w8a8_rk3588.rkllm | 2,375,022,956B | `d5474340221fc495c70e1ec2c7dafc4ebf88292ce466db7e771e3a20b99cf21f` |

两哈希 = G6 验证基线（未更换模型版本）。重启后复验一致。

## 完整性保护

modelctl 推理前强制双模型哈希门（硬编码期望值，不依赖文件权限）；探针二进制亦过哈希门。

## 权限

admin:admin 0644（最小化：其他用户不可写；哈希门为完整性权威）。

## 运行时依赖（在位，版本未动）

- /opt/rknn-runtime/librknnrt.so（RKNN API 2.3.2，drv 0.9.8）
- /opt/rknn-runtime/librkllmrt.so（RKLLM 1.2.3）

## 纪律

- **模型权重不进 Git 仓库**（本仓库仅存哈希与路径）
- 不从未知来源下载替代模型；不更换 G6 已验证版本
- 许可：Qwen 系列（Apache-2.0 权重）转换件，个人设备部署用途
