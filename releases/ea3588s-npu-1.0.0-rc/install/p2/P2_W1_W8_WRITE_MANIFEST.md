# P2 W1–W8 驱动自动部署写入清单（P2_W1_W8_WRITE_MANIFEST）

| 项 | 内容 |
|---|---|
| 阶段 | POST-G6 / B（P2 W1–W8） |
| 日期 | 2026-11-18 |
| 目标 | 解决"重启后需手动 insmod E2"：开机经 systemd-modules-load 自动加载 rknpu，NPU probe → renderD128 就绪 |
| 原始设计依据 | `EA3588S-NPU-STABLE-DEPLOYMENT/02_NPU_DRIVER_STABLE_DEPLOYMENT/NPU_DRIVER_DEPLOYMENT_PLAN.md` §5/§6/§12（W1–W8 原义不改） |
| 状态分级 | W1–W6 + W8 = **BOARD_WRITE_REQUIRES_APPROVAL**（本清单即审批对象）；W7 = 运行态操作，不随本包自动执行 |
| 本任务授权边界 | VM 侧设计/脚本/静态审查/VM 隔离测试已完成；**板端持久化写入待用户批准后执行** |

---

## 0. 设计复核结论（B1/B2）

| 项目 | 原始设计（02 目录） | 当前状态（2026-11-18 板端只读审计） | 实施方式 | 风险 | 验收 |
|---|---|---|---|---|---|
| W1 模块安装路径 | `/lib/modules/6.12.69-ophub/updates/drm/rknpu/rknpu.ko` | `updates/` 不存在（纯新增）；/lib/modules 全树 **零 rknpu**（无两代并存） | install -m 0644（板内源 `/var/tmp/auth04-rknpu/rknpu.ko`，安装前哈希复核） | 低（纯新增文件） | 目标位哈希 = `120e0240…` |
| W2 modules.dep | `depmod -a 6.12.69-ophub` | 现 modules.dep 207,526B（`d1d3179e…`），kmod 30 | 备份 9 个元数据文件 → depmod → 核验新增条目 | 中（**修改既有元数据**，非纯新增） | `updates/drm/rknpu/rknpu.ko:` 条目存在且唯一 |
| W3 modules-load.d | `/etc/modules-load.d/rknpu.conf` 内容 `rknpu` | 目录存在，先例 `8852bs.conf`（同机制已在板验证——WiFi 模块自动加载） | 新增单行文件 | 低 | 内容逐字匹配 |
| W4 modprobe.d | `/etc/modprobe.d/rknpu.conf` 空占位 | 目录存在（8189fs/dkms/r8723bs 共存） | 新增注释占位文件 | 低 | modprobe -c 解析无错 |
| W5 udev 规则 | `/etc/udev/rules.d/90-rknpu-render.rules` | 目录存在 4 条规则；**render 组已存在（render:x:105）**；当前 renderD128 已 root:render 0660（规则=现状固化，非变更） | 新增规则文件（不 trigger，下次生效） | 低（形式化现有权限） | 规则在位；现节点不变 |
| W6 安装清单 | `/var/lib/rknpu/INSTALLED_MODULE_MANIFEST` | `/var/lib/rknpu` 不存在（纯新增） | 新增身份记录（0644 root） | 低 | 内容与冻结值一致 |
| W7 modprobe 在线加载 | 运行态操作 | **模块当前已 Live（手动 insmod）**；在线 modprobe = 幂等 no-op | **不随部署脚本执行**；真实自动加载验证 = 下次授权重启（systemd-modules-load → modprobe） | —（重启需单独授权） | 下次 l1 启动后 rknpu Live 且无需人工 |
| W8 验证 | 只读 | — | 部署脚本末尾自动执行（全部只读命令） | 零 | §3 验收矩阵全过 |

## 1. 自动加载链路（B2，与 BOOT_INTEGRATION_PLAN §3 一致）

```text
开机（extlinux l1，用户已选/默认回 l0）
  → 内核 6.12.69-ophub + l1 DTB（npu@fdab0000 status=okay）
  → systemd-modules-load.service（sysinit 阶段，static 启用，已核验）
  → 读 /etc/modules-load.d/rknpu.conf → modprobe rknpu
  → kmod 从 modules.dep 解析 → insmod /lib/modules/.../updates/drm/rknpu/rknpu.ko
  → probe fdab0000.npu（of_match rockchip,rk3588-rknpu）
  → renderD128 出现（udev 规则固化为 root:render 0660）
  → NPU 服务就绪（模型服务属阶段 F，不在本包）
```

**安全性质（继承并板端复核）**：
- l0 启动 + 本配置：模块加载但 npu@fdab0000 status=disabled → probe 干净失败（-ENODEV，of_match 机制保证），**不影响 l0 桌面/网络**（BOOT_INTEGRATION §3 论证 + 8852bs 先例）；
- 不重复加载：modprobe 幂等（/sys/module/rknpu 存在即跳过）；
- 身份不匹配不强载：modules-load.d 只写 `rknpu` 名，解析由 modules.dep（部署时哈希冻结）决定；安装前双重哈希门（源文件 + 落位后）防旧模块 `F05850B8…` 误装；
- 加载失败不无限重试：systemd-modules-load 每靴仅一次，失败仅记日志（不 Restart）；
- 不自动卸载：无任何 rmmod 路径；
- l0/l1 共享同一内核镜像（`c6740dfd…`）与同一 rootfs → W1–W6 对两启动项同时生效，差异仅在 DTB probe 结果（设计内）。

## 2. 逐项写入清单（审批对象，共 6 写 + 1 元数据刷新）

### W1：模块安装

| 项 | 值 |
|---|---|
| 目标文件 | `/lib/modules/6.12.69-ophub/updates/drm/rknpu/rknpu.ko`（**新建**） |
| 当前内容 | 不存在（父目录 updates/ 亦不存在，连带新建） |
| 计划内容 | 与 `/var/tmp/auth04-rknpu/rknpu.ko` 逐字节相同 |
| 文件权限 | 0644 root:root（目录 0755 root:root） |
| SHA256 | `120e0240ff7f091105b415ca05e20175eaf498a5ed4d53c2394ae9b477e25ce3`（srcversion `3D2A681794D91035B698E9D`；vermagic `6.12.69-ophub SMP mod_unload aarch64`） |
| 修改命令 | `install -D -m 0644 -o root -g root /var/tmp/auth04-rknpu/rknpu.ko /lib/modules/6.12.69-ophub/updates/drm/rknpu/rknpu.ko` |
| 修改前备份 | 纯新增，无需备份（回滚=删除） |
| 修改后验证 | 落位 sha256 = 上值；modinfo -F srcversion = 上值 |
| 回滚命令 | `rm /lib/modules/6.12.69-ophub/updates/drm/rknpu/rknpu.ko && rmdir …/updates/drm/rknpu …/updates/drm …/updates（逐层仅当空）` |
| l0/l1 影响 | 文件级相同；运行级差异由 DTB probe 决定（l0 -ENODEV 干净失败） |
| 是否需要重启 | 否（文件就位即有效于下次 modprobe 解析） |

### W2：depmod 元数据刷新（唯一修改既有文件的步骤）

| 项 | 值 |
|---|---|
| 目标文件 | `/lib/modules/6.12.69-ophub/modules.{dep,dep.bin,alias,alias.bin,symbols,symbols.bin,softdep,weakdep,devname}`（**既有文件被重生成**） |
| 当前内容 | modules.dep 207,526 B（`d1d3179e…`）等 9 件 |
| 计划内容 | 同上 + 每文件含 1 条 rknpu 相关新条目（modules.dep 新增 `updates/drm/rknpu/rknpu.ko:`；modules.alias 由模块 alias 生成——rknpu 驱动无 modalias（platform 驱动 of_match），**预期 alias 零新增**，实际以运行结果为准） |
| 文件权限 | 保持 depmod 默认（0644 root:root） |
| SHA256 | 部署后记录全部 9 件新哈希（执行时生成，写入备份目录 MANIFEST） |
| 修改命令 | `depmod -a 6.12.69-ophub` |
| 修改前备份 | `mkdir -p /var/backups/p2-w1w8-<ts>/ && cp -p modules.{9件} → 备份目录`（板端 /var/backups 为 Armbian 既有目录） |
| 修改后验证 | `grep -c "^updates/drm/rknpu/rknpu.ko:" modules.dep == 1`；`modprobe -n -v rknpu` 解析到新路径 |
| 回滚命令 | `cp -p 备份目录/modules.{9件} → /lib/modules/6.12.69-ophub/`（或等价：删除 W1 模块后重跑 depmod——双路径均可） |
| l0/l1 影响 | 相同（共享内核目录） |
| 是否需要重启 | 否 |

### W3：modules-load.d 自动加载声明

| 项 | 值 |
|---|---|
| 目标文件 | `/etc/modules-load.d/rknpu.conf`（**新建**） |
| 当前内容 | 不存在（目录内仅 8852bs.conf + modules.conf 符号链接） |
| 计划内容 | 单行：`rknpu`（+ 换行，共 7 字节） |
| 文件权限 | 0644 root:root |
| SHA256 | 部署后记录（内容确定性 → 哈希可预计算，执行时核验） |
| 修改命令 | `printf 'rknpu\n' > /tmp/rknpu.conf.g6 && install -m 0644 -o root -g root /tmp/rknpu.conf.g6 /etc/modules-load.d/rknpu.conf` |
| 修改前备份 | 纯新增，无需 |
| 修改后验证 | `cat` 内容逐字 = `rknpu`；`systemd-analyze cat-config modules-load.d`（如可用） |
| 回滚命令 | `rm /etc/modules-load.d/rknpu.conf`（**下次启动即不再自动加载**；当前 Live 模块不受影响） |
| l0/l1 影响 | 相同声明；l0 下加载后 probe -ENODEV（安全性质 §1） |
| 是否需要重启 | 是（下次启动生效——即自动加载验证点） |

### W4：modprobe.d 占位

| 项 | 值 |
|---|---|
| 目标文件 | `/etc/modprobe.d/rknpu.conf`（**新建**） |
| 当前内容 | 不存在 |
| 计划内容 | 两行注释：`# rknpu module options placeholder` + `# (E2 built with frozen .cmd macros; no options required)` |
| 文件权限 | 0644 root:root |
| 修改命令 | `install -m 0644 …（同 W3 模式，源在 /tmp 生成）` |
| 修改前备份 | 纯新增，无需 |
| 修改后验证 | 文件在位；`modprobe -c >/dev/null` 退出 0（语法有效） |
| 回滚命令 | `rm /etc/modprobe.d/rknpu.conf` |
| l0/l1 影响 | 无（无有效配置行） |
| 是否需要重启 | 否 |

### W5：udev 设备权限固化

| 项 | 值 |
|---|---|
| 目标文件 | `/etc/udev/rules.d/90-rknpu-render.rules`（**新建**） |
| 当前内容 | 不存在（目录内 4 条既有规则不冲突） |
| 计划内容 | 单行：`SUBSYSTEM=="drm", KERNEL=="renderD*", GROUP="render", MODE="0660"` |
| 文件权限 | 0644 root:root |
| 修改命令 | `install -m 0644 …（同 W3 模式）` |
| 修改前备份 | 纯新增，无需 |
| 修改后验证 | 文件在位（+ `udevadm verify` 如可用）；**不执行 udevadm trigger**（现节点已 root:render 0660，无变更需求） |
| 回滚命令 | `rm /etc/udev/rules.d/90-rknpu-render.rules`（下次设备枚举回 udev 默认） |
| l0/l1 影响 | 相同（权限固化，非变更；现值=目标值） |
| 是否需要重启 | 规则自下次设备枚举生效（当前节点不动） |

### W6：安装身份清单（MANIFEST）

| 项 | 值 |
|---|---|
| 目标文件 | `/var/lib/rknpu/INSTALLED_MODULE_MANIFEST`（**新建**，目录连带新建 `/var/lib/rknpu/` 0755 root:root） |
| 当前内容 | 不存在 |
| 计划内容 | 模块 SHA256/srcversion/vermagic + 源树 HEAD `e4629a6` + 构建配置冻结声明（NPU_DRIVER_DEPLOYMENT_PLAN §1 五条）+ 内核 Image SHA `c6740dfd…`（p2 vmlinuz-6.12.69-ophub，G2 冻结）+ DTB l1 SHA `a504ce4c…` + extlinux 现态 `35170c8d…` + cmdline `cma=2048M` + 部署时间戳 |
| 文件权限 | 0644 root:root |
| 修改命令 | `install -m 0644 …（VM 侧生成全文 → scp → 板端落位）` |
| 修改前备份 | 纯新增，无需 |
| 修改后验证 | 内容逐行比对（哈希核验） |
| 回滚命令 | `rm /var/lib/rknpu/INSTALLED_MODULE_MANIFEST && rmdir /var/lib/rknpu` |
| l0/l1 影响 | 无（纯记录） |
| 是否需要重启 | 否 |

### W7：在线 modprobe（**不随本包执行**）

模块当前已 Live（G6 后手动 insmod 态）。在线 `modprobe rknpu` 为幂等 no-op（kmod 检查 /sys/module）——**无执行必要**。真实自动加载验证 = 下次授权重启：systemd-modules-load → modprobe → rknpu Live（无人工）。该重启属独立授权点（建议与 P8 24h 结束后的下一动作合并决策）。

### W8：只读验收（部署脚本内嵌）

| 验收项 | 判据 |
|---|---|
| 模块落位 | sha256 = `120e0240…`；srcversion = `3D2A68…`；vermagic 逐字 |
| modules.dep | rknpu 条目恰 1 条，路径 `updates/drm/rknpu/rknpu.ko` |
| modprobe 解析 | `modprobe -n -v rknpu` 输出 insmod 新路径（**-n dry-run，零加载**） |
| modules-load.d | `rknpu` 单行 |
| modprobe.d | 文件在位且 `modprobe -c` 解析通过 |
| udev | 规则文件在位 |
| MANIFEST | 内容含全部冻结身份值 |
| 现场保护 | 全程零模块操作（无 insmod/rmmod/modprobe 实际加载）、零 reboot、零 extlinux/DTB 触碰；rknpu 保持 Live 不受影响 |

## 3. 状态分级汇总

| 步骤 | 分级 |
|---|---|
| 设计/脚本/静态审查/VM 隔离测试（本目录交付物） | **VM_ONLY_READY**（已完成） |
| 板端现状审计（§0 表：目录/先例/哈希） | **BOARD_READONLY_VERIFIED**（已完成，见 raw/） |
| W1–W6 + W8 执行 | **BOARD_WRITE_REQUIRES_APPROVAL**（本清单即申请） |
| W7 + 自动加载实测 | 重启级操作，独立授权点（建议 P8 24h 结束后合并决策） |

## 4. 交付物索引

| 文件 | 用途 |
|---|---|
| `P2_W1_W8_WRITE_MANIFEST.md` | 本清单（审批对象） |
| `P2_W1_W8_DEPLOY.sh` | 部署脚本（W1–W6+W8；先备份→哈希门→逐项验证；DRYRUN=1 演练模式） |
| `P2_W1_W8_ROLLBACK.sh` | 回滚脚本（删除新增件 + 恢复 depmod 元数据双路径；不动 Live 模块） |
| `raw/` | 板端只读审计证据（modules_dir/rknpu_search/modules_load_conf/udev_groups/depmod_state/precedent） |

## 5. 风险与残余

- **W2 是唯一非纯新增步骤**（depmod 重生成 9 件元数据）→ 双备份（文件级备份 + "删模块重跑 depmod"等价路径）；
- 板上另存在 `6.18.3-current-rockchip64` 模块目录（救援内核）——**本部署零触碰**（depmod -a 限定 `6.12.69-ophub` 参数）；
- modules-load.d 失败模式：若模块文件损坏未来被移除，modprobe 失败仅日志一行，系统正常启动（8852bs 先例同型）；
- 自动加载后 NPU 电源域保持 genpd 按需上电（G3/G6 结论：空闲 power off 不变）；
- 本包不含：l1 设默认（BOOT_INTEGRATION 选项 B——P9 独立决策）、模型服务（阶段 F）、任何 extlinux/p2 修改。
