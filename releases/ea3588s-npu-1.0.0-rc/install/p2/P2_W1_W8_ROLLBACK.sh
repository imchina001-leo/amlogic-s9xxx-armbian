#!/bin/bash
# P2_W1_W8_ROLLBACK.sh — P2 驱动自动部署回滚脚本（VM 侧驱动）
# 前提：已执行 P2_W1_W8_DEPLOY.sh（或其部分步骤）；备份目录 /var/backups/p2-w1w8-backup-<TS>/
# 效果：清除 W1/W3/W4/W5/W6 新增文件；恢复 W2 depmod 元数据（文件级恢复，首选）；
#       若备份缺失则用等价路径（删模块后重跑 depmod）。
# 纪律：零模块操作（Live 的 rknpu 不卸载——下次启动 modules-load.d 已移除即不再自动加载）/ 零 reboot
# 用法：bash P2_W1_W8_ROLLBACK.sh <备份目录名>   （如 p2-w1w8-backup-20261118T.....Z）
#       DRYRUN=1 bash P2_W1_W8_ROLLBACK.sh <备份目录名>

set -u
DRYRUN=${DRYRUN:-0}
TS=$(date -u +%Y%m%dT%H%M%SZ)
BKNAME=${1:-}
KVER=6.12.69-ophub
MODDIR=/lib/modules/$KVER
NEWMOD=$MODDIR/updates/drm/rknpu/rknpu.ko
MODSHA=120e0240ff7f091105b415ca05e20175eaf498a5ed4d53c2394ae9b477e25ce3

ASK=/tmp/opencode/askpass.sh; PW=/tmp/opencode/.ea_pw
SSH_OPTS="-o StrictHostKeyChecking=yes -o UserKnownHostsFile=/home/liuxinghua/.ssh/known_hosts -o ConnectTimeout=20"
BOARD=admin@192.168.3.106
LOG=rollback_$TS.log

ssh_root() { printf '%s\n' "$(cat $PW)" | timeout 90 setsid env SSH_ASKPASS=$ASK SSH_ASKPASS_REQUIRE=force DISPLAY=:0 ssh $SSH_OPTS $BOARD "sudo -S -p '' sh -c '$1'" 2>&1 | grep -v "Warning: Permanently"; }
say() { echo "[$(date -u +%FT%TZ)] $*" | tee -a "$LOG"; }
fail() { say "ABORT: $1"; exit 1; }
run() {
  say "EXEC: $2"
  if [ $DRYRUN -eq 1 ]; then say "  (DRYRUN 跳过)  cmd: $1"; return 0; fi
  OUT=$(ssh_root "$1"); RC=$?
  printf '%s\n' "$OUT" | sed 's/^/  | /' | tee -a "$LOG"
  [ $RC -ne 0 ] && { say "  rc=$RC"; return 1; }
  return 0
}
run_ok() { run "$1" "$2" || fail "$2 失败"; }

say "=== P2 W1–W8 回滚开始（DRYRUN=$DRYRUN，备份=$BKNAME）==="

# 现场快照（回滚前只读记录）
run_ok "ls -l $NEWMOD /etc/modules-load.d/rknpu.conf /etc/modprobe.d/rknpu.conf /etc/udev/rules.d/90-rknpu-render.rules /var/lib/rknpu/INSTALLED_MODULE_MANIFEST 2>/dev/null; grep \"^rknpu\" /proc/modules" "回滚前现场快照"

# R-W1/R3/R4/R5/R6：删除新增文件（存在才删）
run_ok "rm -f $NEWMOD /etc/modules-load.d/rknpu.conf /etc/modprobe.d/rknpu.conf /etc/udev/rules.d/90-rknpu-render.rules /var/lib/rknpu/INSTALLED_MODULE_MANIFEST && rmdir /var/lib/rknpu 2>/dev/null; rmdir $MODDIR/updates/drm/rknpu $MODDIR/updates/drm $MODDIR/updates 2>/dev/null; echo REMOVE_OK" "R-W1/3/4/5/6: 删除五处新增（空目录连带清除）"

# R-W2：恢复 depmod 元数据（备份文件级恢复；备份缺失则删模块后重跑 depmod 等价路径）
if [ -n "$BKNAME" ] && ssh_root "[ -d /var/backups/$BKNAME ]" | grep -q .; then
  run_ok "cp -p /var/backups/$BKNAME/modules.dep /var/backups/$BKNAME/modules.dep.bin /var/backups/$BKNAME/modules.alias /var/backups/$BKNAME/modules.alias.bin /var/backups/$BKNAME/modules.symbols /var/backups/$BKNAME/modules.symbols.bin /var/backups/$BKNAME/modules.softdep /var/backups/$BKNAME/modules.weakdep /var/backups/$BKNAME/modules.devname $MODDIR/ && echo RESTORE_OK" "R-W2a: 文件级恢复 depmod 元数据 9 件"
else
  say "备份目录缺失/未指定 → 等价路径：重跑 depmod（模块已删，元数据将不含 rknpu）"
  run_ok "depmod -a $KVER" "R-W2b: depmod -a $KVER（等价恢复）"
fi

# 回滚验证
run_ok "find $MODDIR -name \"rknpu*\" | wc -l; grep -c rknpu $MODDIR/modules.dep" "V1: rknpu 残留计数（期望 0 / 0）"
run_ok "modprobe -n -v rknpu 2>&1 | head -1; echo rc=\$?" "V2: modprobe dry-run（期望 not found）"
run_ok "ls /etc/modules-load.d/rknpu.conf /etc/modprobe.d/rknpu.conf /etc/udev/rules.d/90-rknpu-render.rules /var/lib/rknpu 2>&1 | head -4" "V3: 配置文件残留（期望 No such file）"
run_ok "grep \"^rknpu\" /proc/modules; readlink /sys/bus/platform/drivers/RKNPU/fdab0000.npu; ls /dev/dri/renderD128" "V4: Live 模块/绑定/节点不受影响"

say "=== 回滚完成（DRYRUN=$DRYRUN）==="
say "注：Live 模块保持加载直至下次重启（回滚后启动将不再自动加载）"
