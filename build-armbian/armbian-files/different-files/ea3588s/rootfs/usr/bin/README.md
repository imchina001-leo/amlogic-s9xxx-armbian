# usr/bin/ — rtk_hciattach 占位（P2b 待构建，本阶段不放二进制）

机型：iflytek EA3588S（RK3588S）

## 目标

`rtk_hciattach`（源：github.com/radxa/rkwifibt，`util/rtk_hciattach/`，静态链接）
构建后将放入本目录，镜像内路径 `/usr/bin/rtk_hciattach`。

## 状态（P2）

- 【尚待验证】P2b 编译验证段未获用户明确授权，**未执行**；本目录刻意无二进制。
- 容器内交叉工具链现场检查结果见 P2 报告 §工具链（只读 `command -v` 探测，未安装任何包）。
- 构建要求（P1 §6.3）：`gcc`（宿主或 `aarch64-linux-gnu-` 交叉前缀均可，需静态链接
  `-static` 以免 rootfs 缺运行库）；源码取 rkwifibt master，勿用仓库 B 预编译件
  （其依赖 BSP 蓝牙驱动的 `/proc/bluetooth/sleep` 接口，主线内核无此节点）。

## 消费方式（构建后生效）

见本 different-files 树 `rootfs/etc/wifibt/README.md` 的 BT-A 启动序列；
届时由 `/etc/wifibt/` 下的启动脚本调用：
`rtk_hciattach -n -s 115200 /dev/ttyS9 rtk_h5 &`
