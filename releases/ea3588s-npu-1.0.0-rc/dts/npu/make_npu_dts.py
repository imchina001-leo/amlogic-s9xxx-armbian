#!/usr/bin/env python3
"""P1 DTB adaptation experiment (VM-only, board untouched).

Takes the decompiled board DTS (from the p12 boot staging copy of the live
EA3588S DTB), removes the three mainline rknn-core nodes and inserts a
vendor-form rknpu node using the board DTB's own phandle/index value space
(NOT the BSP rk3588-cru.h numbering, which differs).

Port strategy C (temporary validation): no iommus property (no iommu-v2
driver in mainline), no operating-points-v2 (no devfreq), status okay,
SCMI NPU clock left at the vendor default 200 MHz (frequency bumped at
runtime via the rknpu module's npu_rate parameter).
"""
import re
import sys

SRC = "board.dts"
DST = "board-npu.dts"

text = open(SRC).read()

# --- remove the three mainline rknn-core nodes (brace-aware) ---
def remove_node(text, header):
    lines = text.split("\n")
    out, i, skipping, depth = [], 0, False, 0
    while i < len(lines):
        line = lines[i]
        if not skipping and line.strip().startswith(header):
            skipping = True
            depth = line.count("{") - line.count("}")
            i += 1
            continue
        if skipping:
            depth += line.count("{") - line.count("}")
            if depth <= 0:
                skipping = False
            i += 1
            continue
        out.append(line)
        i += 1
    return "\n".join(out)

before = len(text)
text = remove_node(text, "npu@fdab0000 {")
text = remove_node(text, "npu@fdac0000 {")
text = remove_node(text, "npu@fdad0000 {")
after = len(text)
print(f"removed 3 mainline rknn-core nodes ({before - after} bytes)")

vendor_node = """
	rknpu: npu@fdab0000 {
		compatible = "rockchip,rk3588-rknpu";
		reg = <0x00 0xfdab0000 0x00 0x10000 0x00 0xfdac0000 0x00 0x10000 0x00 0xfdad0000 0x00 0x10000>;
		interrupts = <0x00 0x6e 0x04 0x00 0x00 0x6f 0x04 0x00 0x00 0x70 0x04 0x00>;
		interrupt-names = "npu0_irq", "npu1_irq", "npu2_irq";
		clocks = <0x0a 0x06 0x1e 0x11f 0x1e 0x114 0x1e 0x116 0x1e 0x120 0x1e 0x115 0x1e 0x117 0x1e 0x123>;
		clock-names = "clk_npu", "aclk0", "aclk1", "aclk2", "hclk0", "hclk1", "hclk2", "pclk";
		assigned-clocks = <0x0a 0x06>;
		assigned-clock-rates = <0xbebc200>;
		resets = <0x1e 0x110 0x1e 0xfa 0x1e 0xfe 0x1e 0x112 0x1e 0xfc 0x1e 0x100>;
		reset-names = "srst_a0", "srst_a1", "srst_a2", "srst_h0", "srst_h1", "srst_h2";
		power-domains = <0x1f 0x09 0x1f 0x0a 0x1f 0x0b>;
		power-domain-names = "npu0", "npu1", "npu2";
		status = "okay";
	};
"""

# insert where the first mainline node used to be (right before iommu@fdab9000)
marker = "\tiommu@fdab9000 {"
if marker not in text:
    sys.exit("marker iommu@fdab9000 not found")
text = text.replace(marker, vendor_node + "\n" + marker, 1)

open(DST, "w").write(text)
print(f"wrote {DST} (+vendor rknpu node, {len(text) - after} bytes)")
