# RECOVERY_EA3588S — EA3588S 系统崩溃恢复指南（Level A 完整恢复镜像）

版本 `EA3588S-Armbian-NPU-1.0.0-rc1`。适用：**系统无法启动 / rootfs 损坏 / 分区结构损坏 / eMMC 软件级全损**。
系统尚能启动时请用 Level B（`INSTALL_EA3588S.md`），不要动用本指南。

## 1. 恢复能力边界（如实）

恢复后系统状态 = **P13 稳定功能基线 + NPU 驱动层就绪**：

- ✅ 可启动（l0 默认 + l1 NPU 双入口）、XFCE 桌面、lightdm、网络（首次上电走 Armbian 首启配置）、USB、HDMI、Wi-Fi/蓝牙（8852bs）、救援内核模块树（6.18.3）保留
- ✅ NPU：E2 驱动在 `/lib/modules`、自动加载配置、udev render 节点、modelctl/服务单元/探针
- ❌ 不含：模型权重与 runtime（许可隔离，恢复后按 INSTALL_EA3588S.md §7 自行部署）、用户个人数据（/home 下用户文件、用户自装软件）、网络凭据

## 2. 制品与校验

GitHub Release 下载 Level A 制品集：

| 文件 | 身份（SHA256） |
|---|---|
| `MiniLoaderAll.bin` | `ac4fec136c0e2e8898f54b9f6a5f08ae4c0fb9fae480140b485bc4b3e4e73249` |
| `uboot.img` | `5e693c832747389542a8cbaad7f4c6410518db238df0c098e01d77d9bf1271fe` |
| `parameter.txt` | `766afa34d2c9f075…`（分区表） |
| `package-file` | `a46c752a8f4e2ab3…` |
| `boot.img` | `0187b5158affe5a20b6d6859ee9c595ecda33e030aef912f88ec8bbc2cad2bf8` |
| `rootfs.img.xz` | `52b5ffe05f01ac93e223914c6ac1625377f3b56f07761fe706238611c6eda91a` |
| `SHA256SUMS`（Release 级） | 汇总以上全部 |

```bash
sha256sum -c SHA256SUMS          # 第一步：全部 OK 才继续
xz -dk rootfs.img.xz             # 解出 rootfs.img（约 4.26G，解后校验 71315182…）
sha256sum rootfs.img             # 713151820a739146ce84203fd785e77340df7650479eeb6b69e048e9b6356e7f
```

## 3. 刷写前检查

1. **目标识别**：RKDevTool 识别到 `MASKROM` 或 `LOADER` 设备（EA3588S/RK3588S）。
2. **介质确认**：恢复写入的是目标板 eMMC——确认不是别的设备。
3. **分区表确认**：`parameter.txt` 定义 p1 uboot 4M@0x4000 / p2 boot 128M@0x6000 / p3 rootfs@0x4C800（grow）——与原厂布局一致。
4. **供电与线缆**：整个刷写过程不掉电。

## 4. 刷写路径 A（RKDevTool，Windows/官方 GUI）

按 rockdev 包结构逐项写入：

1. 首步烧 `MiniLoaderAll.bin`（Loader 按钮，写入 idblock/sector 64 起）。
2. 按 `parameter.txt` 下载分区表（RKDevTool"下载分区表地址" 0x4000）。
3. 依次下载：`uboot.img`@0x4000、`boot.img`@0x6000、`rootfs.img`@0x4C800。
   （等价做法：直接用 package-file 清单让工具按 `package-file` 顺序执行。）
4. 完成后重启。

> 注：`boot.img` 与 Level B 的 p2 镜像为同一文件（128MiB，ext2 UUID `7a3f0000-…`，与 parameter.txt `uuid:boot` 匹配）。

## 5. 刷写路径 B（Linux rkdeveloptool / dd，供进阶用户）

```bash
# MaskROM 下（RKDevTool/rkdeveloptool 路径）
rkdeveloptool wl 64 MiniLoaderAll.bin        # idblock @ LBA64
rkdeveloptool wl 0x4000 uboot.img
rkdeveloptool wl 0x6000 boot.img
rkdeveloptool wl 0x4C800 rootfs.img
rkdeveloptool rd                              # 重启
```

或对已能进系统/挂载 eMMC 的场景按分区 dd（`/dev/mmcblk0p1`←uboot.img、`p2`←boot.img、`p3`←rootfs.img；先 dd idblock）。dd 后 `sync` 并读回校验哈希。

## 6. 刷写后验证

1. 串口/HDMI 看到 U-Boot 菜单 → 选 **l1** 验证 NPU 路径（或默认 l0 验证基线）。
2. 登录后：

```bash
uname -r                                   # 6.12.69-ophub
ls /dev/mmcblk0p1 /dev/mmcblk0p2 /dev/mmcblk0p3
mount | grep mmcblk0p2                     # p2 ext2 kdevboot
cat /var/lib/rknpu/INSTALLED_MODULE_MANIFEST
rknpu-modelctl verify                      # 驱动就绪（模型层提示缺失属预期）
dmesg | grep -i rknpu                      # l1 下应见驱动初始化
```

3. P13 功能逐项回归：桌面登录、网络连接、`lsusb`、HDMI 显示、Wi-Fi 扫描。
4. 模型层（可选）：`INSTALL_EA3588S.md` §7。

## 7. 恢复失败处置

| 症状 | 处置 |
|---|---|
| RKDevTool 识别不到 MaskROM | 短接/按键进 MaskROM；查线缆供电 |
| 刷后无 U-Boot 串口输出 | 重刷 MiniLoaderAll + uboot（检查两文件哈希）；仍失败→idblock 备份件 `idblock-board-raw.bin`（板端原始 dump）按 dd 路径回写 |
| U-Boot 起但内核不起 | 校验 boot.img 哈希；串口看是否找错分区（parameter.txt 与实际 GPT 不符时重刷分区表） |
| 内核起但 rootfs panic | 校验 rootfs.img 哈希（xz 解压错误最常见）；重刷 p3 |
| 系统起但无网络 | 恢复镜像不含凭据——走 Armbian 首启网络配置 |
| p2 内文件想单独换 | 用 Level B 只更 p2，无需整盘重刷 |

## 8. 历史版本归档与回滚路线

| 层级 | 回滚手段 |
|---|---|
| 单配置/驱动文件 | `install/p2/P2_W1_W8_ROLLBACK.sh`（文件级） |
| p2 boot 分区 | Level B 回滚脚本（备份镜像 dd 回写）；或 `p2-boot-ea3588s-v0.1.0.img`（`e90b3a90…`，无 NPU 基线）回刷 |
| 整系统 | 本指南 Level A（1.0.0-rc1）或原厂发行镜像 |
| idblock | `idblock-board-raw.bin`（`1e452e96…`，450,560B，板端原始 dump，dd 回写 sector 64） |

## 9. 未经实机验证声明

Level A 制品已通过：结构审计、六组件哈希闭环、rootfs 只读挂载全量核验（NPU 层/服务层/P13 基线在位）、e2fsck、xz 完整性与往返哈希、boot.img 内容与 β1（板端验证态同源）逐字节一致。
**尚未在真实 eMMC 上执行整盘刷写验证**（在用主板保护约定）。首次实机恢复建议先在备用介质/维护窗口演练。
