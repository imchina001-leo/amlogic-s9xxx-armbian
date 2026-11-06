# rtlbt/ — RTL8852BS 蓝牙固件（P2 已落盘，md5 已核验）

机型：iflytek EA3588S（RK3588S，Fn-Link 6252B-SRB = RTL8852BS）
消费者：`rtk_hciattach`（BT-A 路线，radxa/rkwifibt 用户态工具），
其固件路径**硬编码**为 `/lib/firmware/rtlbt/`（rtb_fwc.c L39-40，P1 已确认），
芯片表匹配名 `rtk_h5`（rtb_fwc.c L204-207）。

## 文件与校验（下载于 2026-10-27）

| 文件 | 字节 | md5 | sha256 |
|------|------|-----|--------|
| `rtl8852bs_fw` | 94556 | `ae966a75a07dc57bb73ee76ee917870a` | `af469c0df2af4d6a8721f442fef356a76ec4b72a605d53faffc1fa0cad595de5` |
| `rtl8852bs_config` | 33 | `07cc2e1115a52e7f43624f1a7167be9d` | `efa8915db59c5bc30aaa23e1f264656bbf425fcaf091db0954c27752a1d8f7a0` |

来源：`https://github.com/armbian/firmware` master 分支 `rtlbt/` 目录
（raw.githubusercontent.com 直接抓取，HTTP 200，md5 与 P1 报告 §5 预录值一致【外部资料已确认】）。

## 回退方案

仓库 B（原厂，只读）自带旧版固件：
`/mnt/armbian-work/source/ea_3588s/` 内 `rtl8852bs_fw`（49852 字节，md5 `df3fa697…`，P1 §5）。
仅在 armbian/firmware 版本配对异常时替换实验，**当前不使用**。

## 部署链路

`rebuild` L890-894 将 `different-files/ea3588s/rootfs/` 整目录 `cp -af` 进 rootfs，
故本目录最终落在镜像内 `/usr/lib/firmware/rtlbt/`（Armbian 中 `/lib` → `/usr/lib` 合并）。

## 交付边界

- BT-B（主线 serdev）回退路线不用本目录，改用 `rtl_bt/rtl8852bs_fw.bin`
  （62532 字节，内核 `btusb/btintel` 类加载路径，P1 §6.2）——本阶段不预置。
- `rtl8852bs_config` 为 33 字节板级配置（含 USB VID/PID 修正段），必须与 fw 同目录同名配对。
