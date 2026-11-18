# NPU_DRIVER_DEPLOYMENT — 驱动持久化部署（板端实测态）

## 部署位（W1-W8，全部就位并经重启验证自动加载）

| 件 | 路径 | 内容/哈希 |
|---|---|---|
| 模块 | `/lib/modules/6.12.69-ophub/updates/drm/rknpu/rknpu.ko` | `120e0240…e25ce3`（2,469,512B，0644 root:root） |
| 自动加载 | `/etc/modules-load.d/rknpu.conf` | `rknpu`（6B） |
| 模块选项 | `/etc/modprobe.d/rknpu.conf` | 注释占位（E2 冻结 .cmd 宏构建，无需选项） |
| udev | `/etc/udev/rules.d/90-rknpu-render.rules` | `SUBSYSTEM=="drm", KERNEL=="renderD*", GROUP="render", MODE="0660"` |
| 身份清单 | `/var/lib/rknpu/INSTALLED_MODULE_MANIFEST` | 模块/内核/DTB/extlinux/cma 全链身份 |

## 自动加载链（W7 已实测）

systemd-modules-load.service 读 modules-load.d/rknpu.conf → modprobe rknpu（depmod 元数据已含 `updates/drm/rknpu/rknpu.ko:` 条目）→ 驱动注册 → DTB(l1) npu@fdab0000（enabled）→ 平台设备绑定 → renderD128（udev 规则属 render:0660）。

两次重启实测：模块均自动 Live（无需手动 insmod），l1 下设备/节点/IRQ 全部就位；l0 下模块同样自动加载（无设备可绑，静默，无副作用）。

## 驱动来源与构建身份

- 源树：`p1-npu/auth03-patch@e4629a6`，构建宏 CONFIG_ROCKCHIP_RKNPU_DRM_GEM=1 + DEBUG_FS=1（无 DMA_HEAP/FENCE/SRAM）
- srcversion `3D2A681794D91035B698E9D` / vermagic `6.12.69-ophub SMP mod_unload aarch64`
- 与 Live（G6 验证版）为**同一文件**（哈希一致），仅从 /var/tmp 落位到标准模块路径

## 部署纪律遵守记录

零 rmmod / 零 insmod / 零 reboot（部署期间）/ 零 udev trigger / 部署时 Live E2 保持运行直至受控重启。

## 回滚

`POST-G6-STABLE-DEPLOYMENT/02_P2_DRIVER_AUTOLOAD/P2_W1_W8_ROLLBACK.sh`（DRYRUN 已演练）：
删五处新增（模块/两配置/udev/MANIFEST）+ 还原 9 件 depmod 元数据（板端备份 `/var/backups/p2-w1w8-backup-20261118T084221Z/`）→ 回滚后启动不再自动加载，系统回到 G6 前态。
