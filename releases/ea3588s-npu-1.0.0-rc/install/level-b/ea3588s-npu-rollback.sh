#!/bin/bash
# ea3588s-npu-rollback.sh — EA3588S NPU 系统更新包回滚脚本（Level B，目标机本地运行）
# 前提：曾运行 ea3588s-npu-update.sh，其备份目录 /var/backups/ea3588s-npu-update-<TS>/ 存在
# 效果：
#   1. p2 分区从备份镜像整分区恢复（dd + 读回校验）
#   2. 移除更新新增的 rootfs 侧文件（模块/配置/清单/modelctl/单元/探针）
#   3. depmod 元数据 9 件从备份恢复（文件级）
# 纪律：零模块操作（已加载的 rknpu 不卸载——重启后 modules-load.d 已移除即不再自动加载）
#       零 reboot（用户自行决定何时重启）
# 用法：sudo bash ea3588s-npu-rollback.sh /var/backups/ea3588s-npu-update-<TS>
#       DRYRUN=1 sudo bash ea3588s-npu-rollback.sh <备份目录>   # 演练
set -u
DRYRUN=${DRYRUN:-0}
TESTMODE=${TESTMODE:-0}
ROOT=${ROOT:-}
TS=$(date -u +%Y%m%dT%H%M%SZ)
KVER=6.12.69-ophub
P2DEV=${TEST_P2DEV:-/dev/mmcblk0p2}
P2DEV_SZ=134217728
MODDIR="$ROOT/lib/modules/$KVER"
NEWMOD="$MODDIR/updates/drm/rknpu/rknpu.ko"
LOG="rollback_$TS.log"

say()  { echo "[$(date -u +%FT%TZ)] $*" | tee -a "$LOG"; }
fail() { say "ABORT: $1"; exit 1; }
sha()  { sha256sum "$1" 2>/dev/null | cut -d' ' -f1; }

[ "$(id -u)" = "0" ] || { echo "必须以 root 运行"; exit 1; }
cd "$(dirname "$0")" || exit 1

BK=${1:-}
if [ -z "$BK" ]; then
  # 未指定则取最新备份目录
  BK=$(ls -1d "$ROOT"/var/backups/ea3588s-npu-update-* 2>/dev/null | sort | tail -1)
  [ -n "$BK" ] || fail "未找到备份目录（指定：bash $0 /var/backups/ea3588s-npu-update-<TS>）"
fi
say "=== 回滚开始（DRYRUN=$DRYRUN 备份目录=$BK）==="

# ---------- 备份目录完整性 ----------
[ -d "$BK" ] || fail "备份目录不存在：$BK"
[ -f "$BK/p2-backup.img" ] || fail "备份缺 p2-backup.img"
SHA_BK=$(grep " p2-backup.img$" "$BK/BACKUP_SHA256SUMS" | cut -d' ' -f1)
say "R0 备份 p2 镜像记录哈希=$SHA_BK"
[ "$(sha "$BK/p2-backup.img")" = "$SHA_BK" ] || fail "备份镜像自身哈希不符（备份损坏，停止）"

# ---------- R1：p2 整分区恢复 ----------
if [ "$DRYRUN" = "1" ]; then
  say "R1 (DRYRUN) dd $BK/p2-backup.img → $P2DEV + 读回校验"
else
  if grep -q " $P2DEV " /proc/mounts 2>/dev/null; then
    umount "$P2DEV" 2>>"$LOG" || fail "p2 挂载中无法卸载"
  fi
  dd if="$BK/p2-backup.img" of="$P2DEV" bs=4M conv=fsync status=none >>"$LOG" 2>&1 || fail "R1 p2 恢复 dd 失败"
  sync
  RD=$(head -c $P2DEV_SZ "$P2DEV" 2>/dev/null | sha256sum | cut -d' ' -f1)
  [ "$RD" = "$SHA_BK" ] || fail "R1 p2 读回哈希不符（勿重启！重试或用完整恢复镜像）"
  say "R1 p2 已恢复并校验 ✓"
fi

# ---------- R2：移除新增文件 ----------
for f in "$NEWMOD" \
         "$ROOT/etc/modules-load.d/rknpu.conf" \
         "$ROOT/etc/modprobe.d/rknpu.conf" \
         "$ROOT/etc/udev/rules.d/90-rknpu-render.rules" \
         "$ROOT/var/lib/rknpu/INSTALLED_MODULE_MANIFEST" \
         "$ROOT/usr/local/sbin/rknpu-modelctl" \
         "$ROOT/etc/systemd/system/ea3588s-npu-verify.service" \
         "$ROOT/etc/systemd/system/ea3588s-model-vision.service" \
         "$ROOT/etc/systemd/system/ea3588s-model-llm.service" \
         "$ROOT/opt/rknn-probe/g6_vision_probe" \
         "$ROOT/opt/rknn-probe/g6_llm_probe"; do
  if [ -e "$f" ]; then
    if [ "$DRYRUN" = "1" ]; then say "R2 (DRYRUN) rm $f"; else rm -f "$f" && say "R2 已移除 ${f#$ROOT}"; fi
  fi
done
[ "$DRYRUN" = "0" ] && rmdir "$ROOT/var/lib/rknpu" "$ROOT/opt/rknn-probe" 2>/dev/null

# ---------- R3：depmod 元数据恢复（备份存在则文件级恢复） ----------
if [ -f "$BK/modules.dep" ]; then
  if [ "$DRYRUN" = "1" ]; then
    say "R3 (DRYRUN) 恢复 depmod 元数据 9 件 → $MODDIR"
  else
    cp -p "$BK"/modules.dep "$BK"/modules.dep.bin "$BK"/modules.alias "$BK"/modules.alias.bin \
          "$BK"/modules.symbols "$BK"/modules.symbols.bin "$BK"/modules.softdep \
          "$BK"/modules.weakdep "$BK"/modules.devname "$MODDIR/" 2>>"$LOG" \
      || fail "R3 元数据恢复失败"
    say "R3 depmod 元数据 9 件已恢复（modules.dep=$(sha "$MODDIR/modules.dep" | cut -c1-8)…）"
  fi
else
  if [ "$DRYRUN" = "1" ]; then say "R3 (DRYRUN) 无备份元数据 → rm 模块后 depmod -a $KVER"
  else
    depmod -a "$KVER" || fail "R3 depmod 失败"
    say "R3 已重跑 depmod（模块已移除）"
  fi
fi

say "=== 回滚完成（DRYRUN=$DRYRUN）==="
say "系统未重启；已加载的 rknpu（若有）保持运行，重启后不再自动加载。"
exit 0
