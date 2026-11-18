#!/bin/bash
# P2_W1_W8_DEPLOY.sh — P2 驱动自动部署执行脚本（VM 侧驱动，板端 W1–W6 + W8 只读验收）
# 依据：02_P2_DRIVER_AUTOLOAD/P2_W1_W8_WRITE_MANIFEST.md（审批对象）
# 纪律：零模块操作（无 insmod/rmmod/modprobe 实加载）/ 零 reboot / 零 extlinux/DTB 触碰
# 用法：bash P2_W1_W8_DEPLOY.sh          （实际执行，须已获用户批准）
#       DRYRUN=1 bash P2_W1_W8_DEPLOY.sh （演练：前置只读门照跑，写入与验证全跳过）

set -u
DRYRUN=${DRYRUN:-0}
TS=$(date -u +%Y%m%dT%H%M%SZ)
BK="p2-w1w8-backup-$TS"                       # 板端备份目录名
KVER=6.12.69-ophub
MODDIR=/lib/modules/$KVER
NEWMOD=$MODDIR/updates/drm/rknpu/rknpu.ko
SRCMOD=/var/tmp/auth04-rknpu/rknpu.ko
MODSHA=120e0240ff7f091105b415ca05e20175eaf498a5ed4d53c2394ae9b477e25ce3
MODSRCV=3D2A681794D91035B698E9D
MODVERMAGIC="6.12.69-ophub SMP mod_unload aarch64"

ASK=/tmp/opencode/askpass.sh; PW=/tmp/opencode/.ea_pw
SSH_OPTS="-o StrictHostKeyChecking=yes -o UserKnownHostsFile=/home/liuxinghua/.ssh/known_hosts -o ConnectTimeout=20"
BOARD=admin@192.168.3.106
LOG=deploy_$TS.log

ssh_root() { printf '%s\n' "$(cat $PW)" | timeout 90 setsid env SSH_ASKPASS=$ASK SSH_ASKPASS_REQUIRE=force DISPLAY=:0 ssh $SSH_OPTS $BOARD "sudo -S -p '' sh -c '$1'" 2>&1 | grep -v "Warning: Permanently"; }
say() { echo "[$(date -u +%FT%TZ)] $*" | tee -a "$LOG"; }
fail() { say "ABORT: $1"; say "现场保持（回滚脚本可恢复 depmod 元数据；纯新增件可手动 rm）"; exit 1; }

run() {  # run "<board cmd>" "<描述>"
  say "EXEC: $2"
  if [ $DRYRUN -eq 1 ]; then say "  (DRYRUN 跳过)  cmd: $1"; return 0; fi
  OUT=$(ssh_root "$1"); RC=$?
  printf '%s\n' "$OUT" | sed 's/^/  | /' | tee -a "$LOG"
  [ $RC -ne 0 ] && { say "  rc=$RC"; return 1; }
  return 0
}
run_ok() { run "$1" "$2" || fail "$2 失败"; }
vfy() {  # vfy "<board cmd>" "<期望值>" "<描述>"
  if [ $DRYRUN -eq 1 ]; then say "VDRY: $3（期望 '$2'）"; return 0; fi
  local got; got=$(ssh_root "$1" | tr -d '\r\n')
  say "V: $3 → '$got'"
  [ "$got" = "$2" ] || fail "$3 不符（got='$got' expect='$2'）"
}
gate() {  # 前置只读门（DRYRUN 也执行）
  local got; got=$(ssh_root "$1" | tr -d '\r\n')
  say "GATE: $3 → '$got'（期望 '$2'）"
  [ "$got" = "$2" ] || fail "前置门 $3 不符"
}

say "=== P2 W1–W8 部署开始（DRYRUN=$DRYRUN，TS=$TS）==="

# ---------- 前置只读门（全部执行，含 DRYRUN） ----------
gate "sha256sum $SRCMOD 2>/dev/null | cut -d\" \" -f1" "$MODSHA" "源模块哈希"
gate "[ -e $NEWMOD ] && echo EXISTS || echo ABSENT" "ABSENT" "目标模块不存在（纯新增）"
gate "[ -e /etc/modules-load.d/rknpu.conf ] && echo EXISTS || echo ABSENT" "ABSENT" "modules-load.d/rknpu.conf 不存在"
gate "[ -e /etc/modprobe.d/rknpu.conf ] && echo EXISTS || echo ABSENT" "ABSENT" "modprobe.d/rknpu.conf 不存在"
gate "[ -e /etc/udev/rules.d/90-rknpu-render.rules ] && echo EXISTS || echo ABSENT" "ABSENT" "udev 规则不存在"
gate "[ -e /var/lib/rknpu/INSTALLED_MODULE_MANIFEST ] && echo EXISTS || echo ABSENT" "ABSENT" "MANIFEST 不存在"

# ---------- W2 前置：备份 depmod 元数据（9 件） ----------
run_ok "mkdir -p /var/backups/$BK && cp -p $MODDIR/modules.dep $MODDIR/modules.dep.bin $MODDIR/modules.alias $MODDIR/modules.alias.bin $MODDIR/modules.symbols $MODDIR/modules.symbols.bin $MODDIR/modules.softdep $MODDIR/modules.weakdep $MODDIR/modules.devname /var/backups/$BK/ && sha256sum /var/backups/$BK/* > /var/backups/$BK/BACKUP_SHA256SUMS && echo BACKUP_OK" "W2 前置：备份 depmod 元数据 9 件 → /var/backups/$BK/"

# ---------- W1：模块安装 ----------
run_ok "install -D -m 0644 -o root -g root $SRCMOD $NEWMOD" "W1: install rknpu.ko → updates/drm/rknpu/"
vfy "sha256sum $NEWMOD | cut -d\" \" -f1" "$MODSHA" "W1 落位哈希"
vfy "modinfo -F srcversion $NEWMOD" "$MODSRCV" "W1 srcversion"
vfy "modinfo -F vermagic $NEWMOD" "$MODVERMAGIC" "W1 vermagic"

# ---------- W2：depmod ----------
run_ok "depmod -a $KVER" "W2: depmod -a $KVER"
vfy "grep -c \"^updates/drm/rknpu/rknpu.ko:\" $MODDIR/modules.dep" "1" "W2 modules.dep rknpu 条目数"

# ---------- W3：modules-load.d ----------
run_ok "printf 'rknpu\n' > /tmp/p2w3.conf && install -m 0644 -o root -g root /tmp/p2w3.conf /etc/modules-load.d/rknpu.conf && rm -f /tmp/p2w3.conf" "W3: 写 /etc/modules-load.d/rknpu.conf"
vfy "cat /etc/modules-load.d/rknpu.conf" "rknpu" "W3 内容"

# ---------- W4：modprobe.d 占位 ----------
run_ok "printf '# rknpu module options placeholder\n# (E2 built with frozen .cmd macros; no options required)\n' > /tmp/p2w4.conf && install -m 0644 -o root -g root /tmp/p2w4.conf /etc/modprobe.d/rknpu.conf && rm -f /tmp/p2w4.conf" "W4: 写 /etc/modprobe.d/rknpu.conf（注释占位）"
run_ok "modprobe -c > /dev/null && echo MODPROBE_CONFIG_OK" "W4 verify: modprobe -c 解析"

# ---------- W5：udev 规则 ----------
run_ok "printf 'SUBSYSTEM==\"drm\", KERNEL==\"renderD*\", GROUP=\"render\", MODE=\"0660\"\n' > /tmp/p2w5.rules && install -m 0644 -o root -g root /tmp/p2w5.rules /etc/udev/rules.d/90-rknpu-render.rules && rm -f /tmp/p2w5.rules" "W5: 写 udev 规则（不 trigger）"
vfy "grep -c 'KERNEL==' /etc/udev/rules.d/90-rknpu-render.rules" "1" "W5 规则行数"

# ---------- W6：安装身份清单 ----------
MANIFEST_CONTENT="# INSTALLED_MODULE_MANIFEST — P2 W1-W8 deployment
module_sha256=$MODSHA
module_srcversion=$MODSRCV
module_vermagic=$MODVERMAGIC
source_tree=p1-npu/auth03-patch@e4629a6
build_config=CONFIG_ROCKCHIP_RKNPU_DRM_GEM=1,CONFIG_ROCKCHIP_RKNPU_DEBUG_FS=1;no DMA_HEAP/FENCE/SRAM
kernel_image_sha256=c6740dfda82e659161747aae411cd1696ab65a0e90839afc0ebf181e8ef3b16f
kernel_version=$KVER
dtb_l1_sha256=a504ce4c
extlinux_conf_sha256=35170c8d
cmdline_cma=cma=2048M
deployed_utc=$TS
deployed_by=P2_W1_W8_DEPLOY.sh (POST-G6-STABLE-DEPLOYMENT)
"
if [ $DRYRUN -eq 1 ]; then
  say "W6: (DRYRUN) MANIFEST 内容预览："
  printf '%s\n' "$MANIFEST_CONTENT" | sed 's/^/  | /' | tee -a "$LOG"
else
  printf '%s' "$MANIFEST_CONTENT" > /tmp/p2w6_manifest.local
  timeout 60 setsid env SSH_ASKPASS=$ASK SSH_ASKPASS_REQUIRE=force DISPLAY=:0 scp -o StrictHostKeyChecking=yes -o UserKnownHostsFile=$HOME/.ssh/known_hosts /tmp/p2w6_manifest.local $BOARD:/tmp/p2w6_manifest.up 2>&1 | grep -v "Warning: Permanently" | tee -a "$LOG"
  rm -f /tmp/p2w6_manifest.local
  run_ok "install -D -m 0644 -o root -g root /tmp/p2w6_manifest.up /var/lib/rknpu/INSTALLED_MODULE_MANIFEST && rm -f /tmp/p2w6_manifest.up" "W6: 落位 INSTALLED_MODULE_MANIFEST"
  vfy "grep -c \"module_sha256=$MODSHA\" /var/lib/rknpu/INSTALLED_MODULE_MANIFEST" "1" "W6 MANIFEST 身份行"
fi

# ---------- W8：只读验收矩阵 ----------
say "=== W8 只读验收 ==="
run_ok "modprobe -n -v rknpu 2>&1 | head -2" "W8-1: modprobe dry-run 解析（-n 零加载）"
run_ok "grep \"^updates/drm/rknpu/rknpu.ko:\" $MODDIR/modules.dep" "W8-2: modules.dep 条目"
run_ok "ls -l $NEWMOD /etc/modules-load.d/rknpu.conf /etc/modprobe.d/rknpu.conf /etc/udev/rules.d/90-rknpu-render.rules /var/lib/rknpu/INSTALLED_MODULE_MANIFEST" "W8-3: 五文件在位"
run_ok "grep \"^rknpu\" /proc/modules && readlink /sys/bus/platform/drivers/RKNPU/fdab0000.npu && ls /dev/dri/renderD128" "W8-4: Live 模块不受影响（保持绑定与节点）"
run_ok "sha256sum /var/backups/$BK/* | tail -9" "W8-5: 备份哈希存档"

say "=== P2 W1–W8 部署完成（DRYRUN=$DRYRUN）==="
say "备份目录：/var/backups/$BK"
say "后续：自动加载验证 = 下次授权重启（W7 独立授权点）"
