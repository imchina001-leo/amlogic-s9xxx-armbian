# COMPONENT_MANIFEST — 持久化基线组件清单

原始 Release：`EA3588S-Armbian-NPU-1.0.0-rc1`（tag，commit `5085ac68`，prerelease，2026-11-18T08:17:45Z）
本基线提交：`release/ea3588s-npu-stable-1.0.0-rc` 分支新增提交（本提交，不覆盖 rc1）

## 板端部署组件（全部实测在位）

| 组件 | 板端路径 | SHA256 / 身份 |
|---|---|---|
| 内核 | p2 /vmlinuz-6.12.69-ophub | `c6740dfda82e659161747aae411cd1696ab65a0e90839afc0ebf181e8ef3b16f` |
| l1 DTB | p2 /dtb/rk3588s-ea3588s-npu-test-g1.dtb | `a504ce4c205c3f967b6a2f793ca3d2484545c38c706bfadfc63a53bdf2258622` |
| l0 DTB | p2 /dtb/rk3588s-ea3588s.dtb | `87dd71452fb5ca0212d0773844df54e157a24eabb51942986eb9d9f8df3fa595` |
| extlinux.conf ×2 | p2 根 + p2 /extlinux/（双份一致） | `ef34c7f71f91bb41da0410a4d875276235d0c4350116964653a666bef4793b42`（default l1，l0 保留） |
| rknpu.ko | /lib/modules/6.12.69-ophub/updates/drm/rknpu/ | `120e0240ff7f091105b415ca05e20175eaf498a5ed4d53c2394ae9b477e25ce3` |
| modules-load | /etc/modules-load.d/rknpu.conf | 内容 `rknpu` |
| modprobe.d | /etc/modprobe.d/rknpu.conf | 注释占位 |
| udev 规则 | /etc/udev/rules.d/90-rknpu-render.rules | renderD* render:0660 |
| 模块清单 | /var/lib/rknpu/INSTALLED_MODULE_MANIFEST | 见 NPU_DRIVER_DEPLOYMENT.md |
| modelctl | /usr/local/sbin/rknpu-modelctl | `e494cf0715781addeb6c4c274e710c5d06cd6017aec6c7523d6552c65b2a946b` |
| 探针 ×2 | /opt/rknn-probe/g6_{vision,llm}_probe | `bf324113…832cf56` / `6ebdb7cb…6fc12ce` |
| systemd 单元 ×3 | /etc/systemd/system/ea3588s-*.service | `8a2023cb…` / `54f5ceea…` / `a886a3b1…` |
| verify 启用 | /etc/systemd/system/multi-user.target.wants/ → verify.service 符号链接 | static 启用 |
| M1V 模型 | /home/admin/Downloads/qwen3-vl-2b_vision_rk3588.rknn | `3d707ef5dbf0e420ac48e57b5bf0ed6c0fd1d5d048c29d81e1b5a8d051ab7ea8`（**不入库**） |
| M1L 模型 | /home/admin/Downloads/qwen3-vl-2b-instruct_w8a8_rk3588.rkllm | `d5474340221fc495c70e1ec2c7dafc4ebf88292ce466db7e771e3a20b99cf21f`（**不入库**） |
| RKNN runtime | /opt/rknn-runtime/librknnrt.so | `d31fc19c85b85f6091b2bd0f6af9d962d5264a4e410bfb536402ec92bac738e8`（**不入库**） |
| RKLLM runtime | /opt/rknn-runtime/librkllmrt.so | `bbcf28a8666b9fbf7361d6aad892b957920f6ea92400c074899b48f4c5b2c96f`（**不入库**） |

## 仓库内组件（本目录）

9 份基线文档 + SHA256SUMS（模型权重、运行时、密码/密钥均不入库）。

## 备份锚点（板端）

- `/var/backups/ea3588s-persistent-npu/20261118T0900Z/`（部署前全量：extlinux+内核+DTB+Live 模块+depmod 元数据 9 件+状态记录）
- `/var/backups/p2-w1w8-backup-20261118T084221Z/`（depmod 元数据 9 件 + 哈希表）
- p2 内 `.bak-persistent-*` 两份（就地回滚）
