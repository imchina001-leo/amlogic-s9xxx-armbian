/* SPDX-License-Identifier: GPL-2.0 */
/*
 * Mainline compatibility shim for the out-of-tree RKNPU driver (0.9.8).
 *
 * The vendor driver pulls in Rockchip BSP-only headers
 * (rockchip_opp_select.h / rockchip_system_monitor.h / rockchip_ipa.h)
 * that do not exist in a mainline kernel.  The minimal-viable mainline
 * port is built without DVFS / system-monitor support, so we only need
 * enough type and stub definitions to satisfy the always-compiled
 * translation units.
 *
 * When/if those features are ported, replace the relevant pieces with
 * mainline equivalents (dev_pm_opp, devfreq cooling, dma-buf heaps).
 *
 * Derived from the QNAP rknpu-mainline port (rknpu_compat.h), adapted
 * for the official BSP develop-6.12 rknpu 0.9.8 baseline.
 */
#ifndef __RKNPU_COMPAT_H_
#define __RKNPU_COMPAT_H_

#include <linux/of.h>
#include <linux/errno.h>
#include <linux/types.h>

/*
 * Embedded by value in struct rknpu_device, but only ever touched by the
 * (not compiled) devfreq translation unit.  Keep an opaque placeholder so
 * the struct definition compiles.
 */
struct rockchip_opp_info {
	int unused;
};

/* Referenced only through pointers in struct rknpu_device. */
struct monitor_dev_info;

/*
 * Vendor helper that reads the fused-off NPU core mask from an nvmem cell
 * on partial-good dies.  A full RK3588S exposes all cores reachable in DT;
 * if the DT does not declare the "cores" nvmem cell the caller falls back
 * to its default mask, so reporting -ENOENT is correct here.
 */
static inline int rockchip_nvmem_cell_read_u8(struct device_node *np,
					      const char *cell_id, u8 *val)
{
	return -ENOENT;
}

#endif /* __RKNPU_COMPAT_H_ */
