# RECOVERY_GUIDE — 持久化基线恢复指南

适用：本持久化基线（persistent-baseline）部署后的回退/修复。全流程无需重刷 eMMC。

## 恢复入口总览（保底能力）

| 层级 | 入口 | 操作 |
|---|---|---|
| L1 启动项 | extlinux l0 菜单项 | 开机 30s 内人工选 l0（原厂 DTB、无 NPU、系统照常） |
| L2 启动配置 | p2 双份 extlinux.conf | 还原 .bak 备份（见 BOOT_CONFIGURATION.md） |
| L3 驱动持久化 | P2 回滚脚本 | 删五新增 + 还原 depmod 元数据（见下） |
| L4 服务 | 4 件文件 + 1 符号链接 | 删 modelctl/探针/3 单元 + 去 wants 链接 |
| L5 全盘 | Release rc1 制品 | 完整恢复镜像（rockdev 六件套 + idblock，见 RECOVERY_EA3588S.md）——最后手段 |

## 场景速查

### 场景 A：l1 启动异常 / 想回 l0
1. 开机菜单（30s 窗口）选 `l0` ——立即生效，无需任何写入。
2. 永久回 l0 默认：挂 p2 → `cp <p2>/extlinux.conf.bak-persistent-20261118T0900Z <p2>/extlinux.conf`（**根目录与 extlinux/ 两份都要还原**）。

### 场景 B：NPU 驱动异常回滚（文件级）
```bash
# 板端执行；备份在 /var/backups/p2-w1w8-backup-20261118T084221Z/
rm -f /lib/modules/6.12.69-ophub/updates/drm/rknpu/rknpu.ko \
      /etc/modules-load.d/rknpu.conf /etc/modprobe.d/rknpu.conf \
      /etc/udev/rules.d/90-rknpu-render.rules /var/lib/rknpu/INSTALLED_MODULE_MANIFEST
cp -p /var/backups/p2-w1w8-backup-20261118T084221Z/modules.* /lib/modules/6.12.69-ophub/
depmod -a 6.12.69-ophub
```
回滚后重启即回到"无自动加载"状态（系统其余不受影响）。

### 场景 C：模型服务回滚
```bash
rm -f /etc/systemd/system/multi-user.target.wants/ea3588s-npu-verify.service
rm -f /etc/systemd/system/ea3588s-{npu-verify,model-vision,model-llm}.service \
      /usr/local/sbin/rknpu-modelctl /opt/rknn-probe/g6_vision_probe /opt/rknn-probe/g6_llm_probe
systemctl daemon-reload
```
（模型文件与 runtime 不属于服务，保留不影响系统。）

### 场景 D：系统级损坏
按仓库 `releases/ea3588s-npu-1.0.0-rc/RECOVERY_EA3588S.md`（Level A 完整恢复镜像流程；idboard 兜底件 dd 引导区）。

## 验证基线（恢复后自检）

```bash
cat /proc/cmdline | grep -o "cma=2048M"      # l1 生效
grep "^rknpu" /proc/modules                   # 驱动自动加载
ls /dev/dri/renderD128                        # 设备就绪
systemctl is-active ea3588s-npu-verify.service
rknpu-modelctl verify
```

## 重要注意

- p2 的 extlinux.conf 有**两份**（根目录份为 U-Boot 实际读取），任何修改必须双份同步
- 备份锚点：/var/backups/ea3588s-persistent-npu/20261118T0900Z/（部署前全量）与 /var/backups/p2-w1w8-backup-20261118T084221Z/（depmod 元数据）
- 禁止事项沿用：不 saveenv/fw_setenv、不擦 eMMC、不改分区表、模型/凭据不进仓库
