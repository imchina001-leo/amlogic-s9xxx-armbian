#!/bin/bash
# ea3588s-npu-update.sh — EA3588S NPU 系统更新包安装脚本（Level B，目标机本地运行）
# 包身份：EA3588S-Armbian-NPU-1.0.0-rc1（Personal Recovery Candidate）
#
# 适用系统（必须全部满足，脚本逐项门禁）：
#   - 设备：EA3588S（/etc/armbian-release BOARD_NAME=EA_3588S）
#   - 系统：Armbian 26.02.0-trunk bookworm（P13 稳定基线 / v0.1.0 / 完整恢复镜像 1.0.0-rc1）
#   - 内核：6.12.69-ophub（运行中内核与模块 vermagic 严格一致）
#   - DTB 兼容：设备树 model 含 EA3588S 或 compatible 含 rk3588s
#
# 更新内容：
#   1. rootfs 侧（纯新增，不动无关配置）：
#      - /lib/modules/6.12.69-ophub/updates/drm/rknpu/rknpu.ko（E2 驱动）
#      - /etc/modules-load.d/rknpu.conf + /etc/modprobe.d/rknpu.conf
#      - /etc/udev/rules.d/90-rknpu-render.rules
#      - /var/lib/rknpu/INSTALLED_MODULE_MANIFEST
#      - /usr/local/sbin/rknpu-modelctl + 3 个 systemd 单元 + /opt/rknn-probe 双探针
#      - depmod -a 6.12.69-ophub（先备份 9 件元数据）
#   2. boot 侧：dd 新 p2 镜像（含 l0 原基线 + l1 NPU(cma=2048M) 双入口 extlinux）
#      - 默认启动项保持 l0（不自动切换）；l1 由用户在 U-Boot 菜单手动选择
#
# 纪律（任务书六-B 硬性要求）：
#   - 不自动重启（脚本绝不调用 reboot）
#   - 不自动切换默认启动项（新 extlinux default=l0 与 P13 基线一致）
#   - 安装失败可恢复（备份 + 配套 ea3588s-npu-rollback.sh）
#   - 不覆盖不相关设备配置（仅写 NPU 专属路径 + p2）
#
# 用法（在板端解包目录内以 root 运行）：
#   sudo bash ea3588s-npu-update.sh              # 实际执行
#   DRYRUN=1 sudo bash ea3588s-npu-update.sh     # 演练（门禁照跑，写入全跳过）
#   TESTMODE=1 ROOT=/mnt/fixture TEST_P2DEV=/path/loop-file bash ea3588s-npu-update.sh
#     # TESTMODE 仅用于 VM 夹具验证：强制 p2 目标为普通文件（物理上不可能触碰真实 eMMC）
#
set -u

DRYRUN=${DRYRUN:-0}
TESTMODE=${TESTMODE:-0}
ROOT=${ROOT:-}                # TESTMODE：夹具根（真实运行留空）
TS=$(date -u +%Y%m%dT%H%M%SZ)
KVER=6.12.69-ophub
PKGVER=EA3588S-Armbian-NPU-1.0.0-rc1

# ---- 身份常量（与 SHA256SUMS 一致；改动即失效） ----
SHA_P2IMG=0187b5158affe5a20b6d6859ee9c595ecda33e030aef912f88ec8bbc2cad2bf8
SHA_MOD=120e0240ff7f091105b415ca05e20175eaf498a5ed4d53c2394ae9b477e25ce3
SHA_MODELCTL=e494cf0715781addeb6c4c274e710c5d06cd6017aec6c7523d6552c65b2a946b
SHA_VPROBE=bf3241138739f481ff699a909d37a096be1dc043a6451747c8b0f80fa832cf56
SHA_LPROBE=6ebdb7cb2d56bf9a045f431c28681a160fd587f07b6db184210883b186fc12ce
MOD_VERMAGIC="6.12.69-ophub SMP mod_unload aarch64"
MOD_SRCVERSION=3D2A681794D91035B698E9D
SHA_KERNEL_IMG=c6740dfda82e659161747aae411cd1696ab65a0e90839afc0ebf181e8ef3b16f

P2IMG=p2-boot-ea3588s-npu-1.0.0-rc1.img
P2DEV=${TEST_P2DEV:-/dev/mmcblk0p2}
P2DEV_SZ=134217728            # 128 MiB
MODDIR="$ROOT/lib/modules/$KVER"
NEWMOD="$MODDIR/updates/drm/rknpu/rknpu.ko"
BKTOP="$ROOT/var/backups/ea3588s-npu-update-$TS"
LOG="update_$TS.log"

say()  { echo "[$(date -u +%FT%TZ)] $*" | tee -a "$LOG"; }
fail() { say "ABORT: $1"; say "现场保持——已写内容可用 ea3588s-npu-rollback.sh $BKTOP 恢复；未重启。"; exit 1; }
sha()  { sha256sum "$1" 2>/dev/null | cut -d' ' -f1; }

[ "$(id -u)" = "0" ] || { echo "必须以 root 运行（sudo bash $0）"; exit 1; }
cd "$(dirname "$0")" || exit 1     # 包目录（payload/ 相对本目录）

say "=== EA3588S NPU 更新包 v$PKGVER 开始（DRYRUN=$DRYRUN TESTMODE=$TESTMODE TS=$TS）==="

# ---------- G0：包完整性 ----------
for f in "$P2IMG" payload/rknpu.ko payload/modules-load.d-rknpu.conf payload/modprobe.d-rknpu.conf \
         payload/udev-90-rknpu-render.rules payload/INSTALLED_MODULE_MANIFEST payload/rknpu-modelctl \
         payload/ea3588s-npu-verify.service payload/ea3588s-model-vision.service payload/ea3588s-model-llm.service \
         payload/g6_vision_probe payload/g6_llm_probe; do
  [ -f "$f" ] || { echo "ABORT: 包缺件 $f（先校验 SHA256SUMS）"; exit 1; }
done
say "G0 包完整性：13 件全在位"
[ "$(sha $P2IMG)" = "$SHA_P2IMG" ]  || fail "G0 p2 镜像哈希不符（先 sha256sum -c SHA256SUMS）"
[ "$(sha payload/rknpu.ko)" = "$SHA_MOD" ] || fail "G0 模块哈希不符"
say "G0 关键哈希：p2=$SHA_P2IMG mod=$SHA_MOD 一致"

# ---------- G1：目标机身份门 ----------
if [ "$TESTMODE" = "1" ]; then
  say "G1 TESTMODE：跳过实机 uname/armbian-release 门（仅 VM 夹具验证用）"
  # TESTMODE 安全约束：p2 目标必须是普通文件（物理不可能写真实 eMMC）
  [ -f "$P2DEV" ] && [ ! -b "$P2DEV" ] || fail "TESTMODE 要求 TEST_P2DEV 为普通文件（保护真实 eMMC）"
  [ -n "$ROOT" ] || fail "TESTMODE 要求 ROOT=<夹具根>"
else
  ARMBIAN_BOARD=$(grep -E '^BOARD_NAME=' "$ROOT/etc/armbian-release" 2>/dev/null | cut -d= -f2)
  say "G1 BOARD_NAME='$ARMBIAN_BOARD'（期望 EA_3588S）"
  [ "$ARMBIAN_BOARD" = "EA_3588S" ] || fail "G1 非 EA3588S 设备，拒绝安装"
  KREL=$(uname -r)
  say "G1 内核 '$KREL'（期望 $KVER）"
  [ "$KREL" = "$KVER" ] || fail "G1 运行内核不是 $KVER（本包严格限定内核版本）"
  DTC=$(cat "$ROOT/proc/device-tree/compatible" 2>/dev/null | tr '\0' '\n' | tr -d '\n')
  DTM=$(cat "$ROOT/proc/device-tree/model" 2>/dev/null | tr -d '\n')
  say "G1 DTB model='$DTM' compatible='$DTC'"
  echo "$DTM$DTC" | grep -qiE "ea.?3588|rk3588" || fail "G1 设备树不含 EA3588S/rk3588 兼容标识"
  [ -b "$P2DEV" ] || fail "G1 $P2DEV 不是块设备"
  CURSZ=$(blockdev --getsize64 "$P2DEV" 2>/dev/null || echo 0)
  say "G1 p2 容量 $CURSZ（期望 $P2DEV_SZ）"
  [ "$CURSZ" = "$P2DEV_SZ" ] || fail "G1 p2 容量非 128MiB"
fi

# ---------- G2：模块与运行内核 vermagic 严格匹配 ----------
VERM=$(modinfo -F vermagic payload/rknpu.ko 2>/dev/null)
SRCV=$(modinfo -F srcversion payload/rknpu.ko 2>/dev/null)
say "G2 模块 vermagic='$VERM' srcversion='$SRCV'"
[ "$VERM" = "$MOD_VERMAGIC" ] || fail "G2 模块 vermagic 与包身份不符"
[ "$SRCV" = "$MOD_SRCVERSION" ] || fail "G2 模块 srcversion 与包身份不符"
if [ "$TESTMODE" != "1" ]; then
  RUNV=$(modinfo -F vermagic "$(find /lib/modules/$(uname -r) -name '*.ko*' | head -1)" 2>/dev/null)
  say "G2 板上既有模块 vermagic 抽检='$RUNV'"
  [ "$RUNV" = "$MOD_VERMAGIC" ] || fail "G2 板上模块 vermagic 与新模块不一致（内核树不匹配）"
fi

# ---------- G3：空间与挂载状态 ----------
AVAIL=$(df -Pk "$ROOT/" 2>/dev/null | tail -1 | awk '{print $4}')
say "G3 rootfs 可用空间 ${AVAIL}KB（要求 ≥ 262144KB）"
[ "${AVAIL:-0}" -ge 262144 ] || fail "G3 空间不足（备份 p2 需 ~131072KB）"
if grep -q " $P2DEV " /proc/mounts 2>/dev/null; then
  say "G3 $P2DEV 当前已挂载——尝试卸载"
  umount "$P2DEV" 2>>"$LOG" || fail "G3 p2 挂载中且无法卸载（排查后重试）"
fi
[ -e "$MODDIR" ] || fail "G3 $MODDIR 不存在（内核模块树缺失）"

# ---------- 状态预检：已装/未装（幂等友好） ----------
precheck() {  # <路径> <期望哈希>
  if [ -e "$1" ]; then
    H=$(sha "$1")
    if [ "$H" = "$2" ]; then echo "PRESENT_SAME"; else echo "PRESENT_DIFF"; fi
  else
    echo "ABSENT"
  fi
}
ST_MOD=$(precheck "$NEWMOD" "$SHA_MOD")
ST_ML=$(precheck "$ROOT/etc/modules-load.d/rknpu.conf" "$(sha payload/modules-load.d-rknpu.conf)")
say "状态：模块=$ST_MOD modules-load=$ST_ML（PRESENT_SAME=幂等重装）"

say "=== 门禁全部通过，开始安装 ==="

# ---------- B1：备份 ----------
if [ "$DRYRUN" = "1" ]; then
  say "B1 (DRYRUN) 备份将写入 $BKTOP：p2 现镜像(dd) + depmod 元数据 9 件 + 既有被替换件"
else
  mkdir -p "$BKTOP" || fail "B1 建备份目录失败"
  say "B1 备份当前 p2 → $BKTOP/p2-backup.img（128MiB，只读源）"
  dd if="$P2DEV" of="$BKTOP/p2-backup.img" bs=4M status=none >>"$LOG" 2>&1 || fail "B1 p2 备份 dd 失败"
  echo "$(sha "$BKTOP/p2-backup.img")  p2-backup.img" > "$BKTOP/BACKUP_SHA256SUMS"
  say "B1 p2 备份哈希 $(sha "$BKTOP/p2-backup.img")"
  if [ -e "$MODDIR/modules.dep" ]; then
    cp -p "$MODDIR"/modules.dep "$MODDIR"/modules.dep.bin "$MODDIR"/modules.alias "$MODDIR"/modules.alias.bin \
          "$MODDIR"/modules.symbols "$MODDIR"/modules.symbols.bin "$MODDIR"/modules.softdep \
          "$MODDIR"/modules.weakdep "$MODDIR"/modules.devname "$BKTOP/" 2>>"$LOG" \
      || fail "B1 depmod 元数据备份失败"
    say "B1 depmod 元数据 9 件已备份"
  fi
  for f in "$ROOT/etc/modules-load.d/rknpu.conf" "$ROOT/etc/modprobe.d/rknpu.conf" \
           "$ROOT/etc/udev/rules.d/90-rknpu-render.rules" "$ROOT/var/lib/rknpu/INSTALLED_MODULE_MANIFEST" \
           "$ROOT/usr/local/sbin/rknpu-modelctl"; do
    [ -e "$f" ] && cp -pd "$f" "$BKTOP/" 2>>"$LOG" && say "B1 既有件备份 $(basename "$f")"
  done
  sha256sum "$BKTOP"/* >> "$BKTOP/BACKUP_SHA256SUMS" 2>/dev/null
  echo "update_pkg=$PKGVER" > "$BKTOP/UPDATE_IDENTITY"
  echo "update_utc=$TS" >> "$BKTOP/UPDATE_IDENTITY"
fi

# ---------- W1：安装 E2 驱动模块 ----------
if [ "$DRYRUN" = "1" ]; then
  say "W1 (DRYRUN) install rknpu.ko → $MODDIR/updates/drm/rknpu/"
else
  install -D -m 0644 -o root -g root payload/rknpu.ko "$NEWMOD" || fail "W1 模块落位失败"
  [ "$(sha "$NEWMOD")" = "$SHA_MOD" ] || fail "W1 落位哈希不符"
  say "W1 rknpu.ko 落位 ✓ $SHA_MOD"
fi

# ---------- W2：depmod ----------
if [ "$DRYRUN" = "1" ]; then
  say "W2 (DRYRUN) depmod -b "$ROOT" $KVER"
else
  if [ -n "$ROOT" ]; then depmod -b "$ROOT" "$KVER" || fail "W2 depmod 失败"; else depmod -a "$KVER" || fail "W2 depmod 失败"; fi
  grep -q "^updates/drm/rknpu/rknpu.ko:" "$MODDIR/modules.dep" || fail "W2 modules.dep 无 rknpu 条目"
  say "W2 depmod ✓（modules.dep 含 rknpu 条目）"
fi

# ---------- W3-W6：配置四件套 ----------
if [ "$DRYRUN" = "1" ]; then
  say "W3-W6 (DRYRUN) modules-load/modprobe/udev/MANIFEST"
else
  install -D -m 0644 -o root -g root payload/modules-load.d-rknpu.conf "$ROOT/etc/modules-load.d/rknpu.conf" || fail "W3 失败"
  install -D -m 0644 -o root -g root payload/modprobe.d-rknpu.conf     "$ROOT/etc/modprobe.d/rknpu.conf"     || fail "W4 失败"
  install -D -m 0644 -o root -g root payload/udev-90-rknpu-render.rules "$ROOT/etc/udev/rules.d/90-rknpu-render.rules" || fail "W5 失败"
  install -D -m 0644 -o root -g root payload/INSTALLED_MODULE_MANIFEST  "$ROOT/var/lib/rknpu/INSTALLED_MODULE_MANIFEST" || fail "W6 失败"
  printf 'deployed_utc=%s\ndeployed_by=ea3588s-npu-update.sh (%s)\n' "$TS" "$PKGVER" >> "$ROOT/var/lib/rknpu/INSTALLED_MODULE_MANIFEST"
  say "W3-W6 配置四件套落位 ✓（udev 规则不主动 trigger）"
fi

# ---------- W7：模型服务层（不含 runtime/模型——许可隔离，另行部署） ----------
if [ "$DRYRUN" = "1" ]; then
  say "W7 (DRYRUN) modelctl + 3 systemd 单元 + 双探针"
else
  install -D -m 0755 -o root -g root payload/rknpu-modelctl "$ROOT/usr/local/sbin/rknpu-modelctl" || fail "W7 modelctl 失败"
  [ "$(sha "$ROOT/usr/local/sbin/rknpu-modelctl")" = "$SHA_MODELCTL" ] || fail "W7 modelctl 哈希不符"
  for u in ea3588s-npu-verify ea3588s-model-vision ea3588s-model-llm; do
    install -D -m 0644 -o root -g root "payload/$u.service" "$ROOT/etc/systemd/system/$u.service" || fail "W7 单元 $u 失败"
  done
  install -D -m 0755 -o root -g root payload/g6_vision_probe "$ROOT/opt/rknn-probe/g6_vision_probe" || fail "W7 探针失败"
  install -D -m 0755 -o root -g root payload/g6_llm_probe   "$ROOT/opt/rknn-probe/g6_llm_probe"   || fail "W7 探针失败"
  [ "$(sha "$ROOT/opt/rknn-probe/g6_vision_probe")" = "$SHA_VPROBE" ] || fail "W7 vision 探针哈希不符"
  [ "$(sha "$ROOT/opt/rknn-probe/g6_llm_probe")" = "$SHA_LPROBE" ]   || fail "W7 llm 探针哈希不符"
  # 单元不 enable 不 start（按需服务；激活留待用户批准）
  say "W7 模型服务层落位 ✓（未 enable/start——按需服务）"
fi

# ---------- W8：boot 分区写入（无重启，默认项保持 l0） ----------
if [ "$DRYRUN" = "1" ]; then
  say "W8 (DRYRUN) dd $P2IMG → $P2DEV（128MiB）+ 读回校验；extlinux default=l0 保持"
else
  say "W8 写入新 p2（默认启动项仍为 l0；l1=NPU+cma=2048M 需 U-Boot 菜单手动选择）"
  dd if="$P2IMG" of="$P2DEV" bs=4M conv=fsync status=none >>"$LOG" 2>&1 || fail "W8 p2 写入失败"
  sync
  RD2=$(head -c 134217728 "$P2DEV" 2>/dev/null | sha256sum | cut -d' ' -f1)
  [ "$RD2" = "$SHA_P2IMG" ] || { say "W8 读回校验全量=$RD2"; fail "W8 p2 读回哈希不符（勿重启！用 rollback 恢复）"; }
  say "W8 p2 读回校验 ✓（全量 128MiB = $SHA_P2IMG）"
fi

# ---------- V：安装后核验（只读，零加载） ----------
if [ "$DRYRUN" = "0" ]; then
  say "=== 安装后核验（只读） ==="
  if [ -n "$ROOT" ]; then MP="modprobe -d $ROOT"; else MP="modprobe"; fi
  $MP -n -v rknpu >>"$LOG" 2>&1 && say "V1 modprobe -n 解析 OK（零加载）" || say "V1 modprobe -n 异常（见日志；不阻断——内核未重启）"
  ls -l "$NEWMOD" "$ROOT/etc/modules-load.d/rknpu.conf" >>"$LOG" 2>&1 && say "V2 文件在位"
  grep -q "^rknpu" "$ROOT/etc/modules-load.d/rknpu.conf" && say "V3 自动加载配置内容 ✓"
fi

say "=== 更新完成（DRYRUN=$DRYRUN）==="
say "备份目录：$BKTOP（回滚：sudo bash ea3588s-npu-rollback.sh $BKTOP）"
say "本脚本未重启系统；默认启动项保持 l0（P13 基线）。"
say "激活 NPU 路径（用户手动）：重启 → U-Boot 菜单选 l1（cma=2048M）→ 驱动经 modules-load.d 自动加载。"
say "模型层（runtime+模型，许可隔离未随包）：部署方法见 INSTALLATION_GUIDE 第 7 节。"
exit 0
