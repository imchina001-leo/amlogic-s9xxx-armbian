# etc/wifibt/ — EA3588S Wi-Fi/BT 启动脚本目录（占位说明，P2）

机型：iflytek EA3588S（RK3588S + Fn-Link 6252B-SRB / RTL8852BS，UART9 蓝牙）

本目录最终放置开机拉起 Wi-Fi/蓝牙的脚本（P4/P5 与实机联调时回填）。
本阶段仅登记既定序列，防止 P3/P4 重新推导。

## BT-A 序列（首选，rtk_hciattach）

前置：DTS 已含 `&gpio0` 上的 `bt-reg-on-hog`（GPIO0_D4 output-high，见 staging DTS 草稿），
内核需 `CONFIG_BT_HCIUART=m` + `CONFIG_BT_RTL=m`（ophub config-6.12 已确认具备，P1 §6.1）。

```sh
# /dev/ttyS9 = uart9@febc0000（uart9m2，GPIO3_D4/D5，流控 GPIO3_D3/D2）
modprobe hci_uart
/usr/bin/rtk_hciattach -n -s 115200 /dev/ttyS9 rtk_h5 &
```

固件：`/lib/firmware/rtlbt/rtl8852bs_fw` + `rtl8852bs_config`（本 different-files 树已预置，md5 已核验）。

## Wi-Fi 序列

```sh
modprobe 8852bs        # 模块来自 P3：armbian/wifi-rtl8852bs OOT 构建（CONFIG_RTL8852BS=m）
# 固件已编译进驱动源码（hal8852b_fw.c 数组），无需额外 /lib/firmware 文件
# 预期出现 wlan0（SDIO fe2c0000 + mmc-pwrseq GPIO0_C7）
```

## BT-B 回退（主线 serdev，P5 决策项）

不使用 rtk_hciattach 与 rtlbt/ 固件；需小补丁使 `hci_h5.c` 识别
`realtek,rtl8852bs-bt` compatible + `enable-gpios`，固件走 `rtl_bt/rtl8852bs_fw.bin`。
详见 P1 报告 §6.2。

## 与 vendor 的差异声明

原厂 BSP 靠 `bluetooth-platdata`/`wlan-platdata` 平台驱动 + `/proc/bluetooth/sleep`
管理电源与 RTS；主线侧一律不用（无该驱动）。电源接管方式：
- BT_REG_ON（GPIO0_D4）：gpio-hog 常高；
- WIFI_REG_ON（GPIO0_C7）：mmc-pwrseq-simple；
- 其余 WAKE GPIO 见 staging DTS 草稿尾注，默认不建节点。
