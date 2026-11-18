# BOOT_CONFIGURATION — 启动项配置（板端实测）

## 启动链

MiniLoaderAll（idblock）→ U-Boot（p1，`uboot-dev-01/08/2026`）→ `sysboot` 读取 **p2（ext2）根目录 `/extlinux.conf`** → 超时后启动 default 项 → l1

## extlinux.conf 关键事实（重要经验）

1. **p2 上存在两份 extlinux.conf 且 U-Boot 读取根目录份**：
   - `/extlinux.conf`（p2 根，**U-Boot 实际读取**）
   - `/extlinux/extlinux.conf`（目录份，历史遗留）
   - **两份必须保持一致**（当前均为 `ef34c7f7…`）；只改一份会导致启动项不生效（本基线部署中实际踩过并修复：分歧实验证明 U-Boot 读根份）
2. U-Boot（v2017 pxe 解析器，`cmd/pxe.c:1342-1353`）**无条件生效顶层 `default` 指令**；default 缺失/名字不匹配时按文件顺序启动第一个 label

## 当前配置（双份一致）

```
default l1              ← 自动启动项
menu title EA3588S U-Boot menu
prompt 1                ← 保留交互能力
timeout 300             ← 30s 人工选择窗口
label l0                ← 恢复入口（原厂 DTB，NPU disabled，CMA 256M）
  linux vmlinuz-6.12.69-ophub
  fdt /dtb/rk3588s-ea3588s.dtb
  append root=/dev/mmcblk0p3 …（无 cma 参数）
label l1                ← NPU 生产项
  linux vmlinuz-6.12.69-ophub
  fdt /dtb/rk3588s-ea3588s-npu-test-g1.dtb
  append root=/dev/mmcblk0p3 … cma=2048M
```

修改记录：`default l0` → `default l1`（双份，sed 单行最小改动）。l0 入口、timeout、prompt、append 参数零改动。

## 人工恢复路径（l0）

1. 开机 30s 菜单窗口内（串口/键盘）选择 `l0` ——立即生效，无需写入；
2. 或挂载 p2 后还原备份（**根目录份与 extlinux/ 目录份两份都要还原**，缺一不生效）：
   ```bash
   mount /dev/mmcblk0p2 /mnt/p2
   cp /mnt/p2/extlinux.conf.bak-persistent-20261118T0900Z /mnt/p2/extlinux.conf
   cp /mnt/p2/extlinux/extlinux.conf.bak-persistent-20261118T0845Z /mnt/p2/extlinux/extlinux.conf
   umount /mnt/p2
   ```

## 回滚锚点（三层）

- p2 内就地备份：`extlinux.conf.bak-persistent-20261118T0845Z` / `-20261118T0900Z`（SHA `35170c8d…` = 原始件，双份各一）
- 板端 `/var/backups/ea3588s-persistent-npu/20261118T0900Z/extlinux/extlinux.conf`
- 历史构建件：POST-G6 工作区 `build/p2-boot-ea3588s-npu-1.0.0-rc1.img`（β1 镜像，default l0 版；属构建产物备份，不在 git 树内）

## 未做 / 禁止项

未改 U-Boot 环境变量、未 saveenv/fw_setenv、未动分区表、未删 l0。
