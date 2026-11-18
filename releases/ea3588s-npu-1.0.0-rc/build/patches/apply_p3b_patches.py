#!/usr/bin/env python3
"""
P3-B 隔离副本补丁脚本（仅作用于 work/p3b 的副本，原始仓库零改动）
三个最小补丁，每个锚点必须唯一命中，否则整体失败退出（不做部分应用）。

PATCH-1  架构门禁：允许 x86_64 交叉编译宿主（目标内核仍为 arm64）
PATCH-2  generate_uinitrd 换安全桩：不碰宿主 /boot、/usr/lib/modules、
         /etc/initramfs-tools、/ddbr；只为 boot 包组装 output_path/boot；
         uInitrd 延后到 P4
PATCH-3  关闭 toolchain_check 中约 120 包的全量 apt 安装
"""
import sys, hashlib

SCRIPT = "/mnt/armbian-work/work/p3b/compile-kernel/tools/script/armbian_compile_kernel.sh"

def sha256(p):
    return hashlib.sha256(open(p, "rb").read()).hexdigest()

src = open(SCRIPT, encoding="utf-8").read()

def replace_once(text, old, new, tag):
    n = text.count(old)
    if n != 1:
        print(f"[FAIL] {tag}: anchor found {n} times (expected 1)")
        sys.exit(1)
    print(f"[OK] {tag}: anchor matched once")
    return text.replace(old, new, 1)

# ---------------- PATCH 1 ----------------
old1 = '''# Check script permission, supports running on Armbian system.
[[ "$(id -u)" == "0" ]] || error_msg "Please run this script as root: [ sudo ./${0} ]"
[[ "${arch_info}" == "aarch64" ]] || error_msg "The script only supports running under Armbian system."'''
new1 = '''# Check script permission, supports running on Armbian system.
[[ "$(id -u)" == "0" ]] || error_msg "Please run this script as root: [ sudo ./${0} ]"
# [P3B-PATCH-1] Isolated x86_64 cross-compile copy: also allow x86_64 host.
# Target kernel stays arm64 (SRC_ARCH=arm64 + aarch64 cross toolchain untouched);
# no other environment check is bypassed. See EA3588S_Ophub_P3B_KernelBuild.md.
[[ "${arch_info}" == "aarch64" || "${arch_info}" == "x86_64" ]] || error_msg "The script only supports running under Armbian system."'''

# ---------------- PATCH 2 ----------------
old2 = '''generate_uinitrd() {
    cd ${current_path}
    echo -e "${STEPS} Initializing uInitrd generation environment..."

    # Backup current system files for /boot
    echo -e "${INFO} Backup the files in the [ ${boot_backup_path} ] directory."
    rm -rf ${boot_backup_path} && mkdir -p ${boot_backup_path}
    mv -f /boot/{config-*,initrd.img-*,System.map-*,vmlinuz-*,uInitrd*,*Image} -t ${boot_backup_path} 2>/dev/null'''
new2 = '''generate_uinitrd() {
    # [P3B-PATCH-2] HOST-SAFE STUB (isolated x86_64 build copy only).
    # Original body installs the freshly built kernel into the CURRENT system:
    #   - mv /boot/* to /ddbr/tmp/boot, then writes new /boot files
    #   - mv /usr/lib/modules/$(uname -r) to /ddbr/tmp/modules, then copies modules in
    #   - rewrites /etc/initramfs-tools/initramfs.conf and runs update-initramfs
    # On a build workstation that is destructive if the run aborts mid-way (no restore).
    # This stub only assembles ${output_path}/boot for the boot tarball/deb;
    # uInitrd/initrd.img generation is deferred to P4 (target device or chroot).
    # It does NOT touch host /boot, /usr/lib/modules, /etc/initramfs-tools or /ddbr.
    cd ${current_path}
    echo -e "${STEPS} [P3B-PATCH-2] Host-safe mode: assembling [ ${output_path}/boot ] (uInitrd deferred to P4)..."
    [[ -n "${output_path}" && "${output_path}" == */compile-kernel/output ]] || error_msg "[P3B-PATCH-2] Unexpected output_path [ ${output_path} ], refusing to touch boot staging."
    [[ -f "${kernel_path}/${local_kernel_path}/arch/${SRC_ARCH}/boot/Image" ]] || error_msg "[P3B-PATCH-2] Kernel Image not found."
    rm -rf ${output_path}/boot
    mkdir -p ${output_path}/boot
    cp -f ${kernel_path}/${local_kernel_path}/System.map ${output_path}/boot/System.map-${kernel_outname}
    cp -f ${kernel_path}/${local_kernel_path}/.config ${output_path}/boot/config-${kernel_outname}
    cp -f ${kernel_path}/${local_kernel_path}/arch/${SRC_ARCH}/boot/Image ${output_path}/boot/vmlinuz-${kernel_outname}
    # rockchip/allwinner branch of the original flow (PLATFORM empty on build host):
    cp -f ${output_path}/boot/vmlinuz-${kernel_outname} ${output_path}/boot/Image
    echo -e "${INFO} [P3B-PATCH-2] Boot staging files: $(ls ${output_path}/boot 2>/dev/null | tr '\\n' ' ')"
    return 0
}

generate_uinitrd_original_disabled() {
    cd ${current_path}
    echo -e "${STEPS} Initializing uInitrd generation environment..."

    # Backup current system files for /boot
    echo -e "${INFO} Backup the files in the [ ${boot_backup_path} ] directory."
    rm -rf ${boot_backup_path} && mkdir -p ${boot_backup_path}
    mv -f /boot/{config-*,initrd.img-*,System.map-*,vmlinuz-*,uInitrd*,*Image} -t ${boot_backup_path} 2>/dev/null'''

# ---------------- PATCH 3 ----------------
old3 = '''    # Install dependencies
    sudo apt-get -qq update
    sudo apt-get -qq install -y $(cat compile-kernel/tools/script/armbian-compile-kernel-depends)'''
new3 = '''    # Install dependencies
    # [P3B-PATCH-3] Full dependency installation (~120 packages incl. clang/llvm/
    # debootstrap/nfs-kernel-server) is disabled on this build workstation.
    # The actually missing prerequisites for THIS kernel config (ccache for the
    # script's CC= wrapper, dwarves/pahole for CONFIG_DEBUG_INFO_BTF=y) were
    # installed separately before the run; before/after dpkg state is recorded
    # in the P3-B report. Reference: compile-kernel/tools/script/armbian-compile-kernel-depends'''

src = replace_once(src, old1, new1, "PATCH-1 arch gate")
src = replace_once(src, old2, new2, "PATCH-2 generate_uinitrd stub")
src = replace_once(src, old3, new3, "PATCH-3 apt install off")

open(SCRIPT, "w", encoding="utf-8").write(src)
print("[DONE] patched:", SCRIPT)
print("sha256 patched:", sha256(SCRIPT))
