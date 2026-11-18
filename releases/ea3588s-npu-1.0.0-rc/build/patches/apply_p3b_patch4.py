#!/usr/bin/env python3
"""
P3-B PATCH-4 (build #2): re-assert CONFIG_RTL8852BS=m after the stock config copy.

Root cause (build #1 evidence, logs/p3b-build.log):
  - The mandated -f/--configFlavor flag sets config_download=true (init_var L177-180).
  - get_kernel_config then clones ophub/kernel's stock config bundle and does
    `rm -rf ${config_path}/*` + `cp -f ... config-*` — overwriting the P3-A
    modified config-6.12 (5f41b9a2..., which carried CONFIG_RTL8852BS=m).
  - compile_env copies the stock config to .config; Kconfig treats RTL8852BS as a
    NEW symbol -> defaults to n. Build #1 final .config line 3484:
    "# CONFIG_RTL8852BS is not set"; auto.conf: absent; 8852bs mentions in the
    24,948-line build log: ZERO -> the driver never compiled.
Fix: idempotently re-append CONFIG_RTL8852BS=m to .config right after the
template copy (before Kconfig syncconfig). Sandbox copy only; no other change.
Deps WLAN=y, MMC=y, CFG80211=m allow tristate m, so syncconfig keeps it.
"""
import sys, hashlib

SCRIPT = "/mnt/armbian-work/work/p3b/compile-kernel/tools/script/armbian_compile_kernel.sh"

old = '''    cp -f ${config_path}/config-${kernel_verpatch} .config
    # Clear kernel signature
    sed -i "s|CONFIG_LOCALVERSION=.*|CONFIG_LOCALVERSION=\\"\\"|" .config
'''
new = '''    cp -f ${config_path}/config-${kernel_verpatch} .config
    # [P3B-PATCH-4] Re-assert the P3-A target driver symbol. The mandated
    # -f/--configFlavor flag forces config_download=true, and the downloaded
    # stock config overwrites tools/config/config-6.12, silently dropping the
    # CONFIG_RTL8852BS=m line appended in P3-A. Build #1 evidence: final
    # .config had "# CONFIG_RTL8852BS is not set" and the driver never
    # compiled. Re-append before Kconfig syncconfig (idempotent; deps
    # WLAN=y MMC=y CFG80211=m allow tristate m). Sandbox copy only.
    grep -q "^CONFIG_RTL8852BS=m" .config || echo "CONFIG_RTL8852BS=m" >> .config
    # Clear kernel signature
    sed -i "s|CONFIG_LOCALVERSION=.*|CONFIG_LOCALVERSION=\\"\\"|" .config
'''

src = open(SCRIPT, encoding="utf-8").read()
n = src.count(old)
if n != 1:
    print(f"[FAIL] PATCH-4 anchor found {n} times (expected 1)"); sys.exit(1)
open(SCRIPT, "w", encoding="utf-8").write(src.replace(old, new, 1))
print("[OK] PATCH-4 applied (anchor matched once)")
print("sha256 patched:", hashlib.sha256(open(SCRIPT, "rb").read()).hexdigest())
