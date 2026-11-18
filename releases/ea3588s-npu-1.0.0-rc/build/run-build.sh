#!/bin/bash
# P3-B build runner — executes the ISOLATED patched copy only.
# cwd is forced to work/p3b so the script's ${PWD}-rooted paths stay inside the sandbox.
cd /mnt/armbian-work/work/p3b || exit 9
set -o pipefail
SCRIPT=$(readlink -f compile-kernel/tools/script/armbian_compile_kernel.sh)
echo "RUNNER: invoking isolated copy: ${SCRIPT}"
echo "RUNNER: sha256=$(sha256sum "${SCRIPT}" | cut -d' ' -f1)"
echo "BUILD_START=$(date '+%F %T')"
bash "${SCRIPT}" -r unifreq -k 6.12.69 -a false -f rk3588 2>&1 | tee logs/p3b-build2.log
rc=${PIPESTATUS[0]}
echo "$rc" > logs/build2-exit-code.txt
echo "BUILD_END=$(date '+%F %T') BUILD_SCRIPT_EXIT=$rc"
exit "$rc"
