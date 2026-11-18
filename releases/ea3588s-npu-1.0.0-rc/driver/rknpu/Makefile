# SPDX-License-Identifier: GPL-2.0
obj-$(CONFIG_ROCKCHIP_RKNPU) += rknpu.o

ccflags-y += -I$(srctree)/$(src)/include
ccflags-y += -I$(src)/include

# Out-of-tree build: the kernel's autoconf.h does not carry the vendor
# CONFIG_ROCKCHIP_RKNPU_* symbols, so #ifdef usage inside the C sources needs
# them defined explicitly (mirrors the QNAP rknpu-mainline Makefile).
ccflags-y += -DCONFIG_ROCKCHIP_RKNPU_DRM_GEM=1
ccflags-y += -DCONFIG_ROCKCHIP_RKNPU_DEBUG_FS=1
ccflags-y += -Werror

rknpu-y += rknpu_drv.o
rknpu-y += rknpu_reset.o
rknpu-y += rknpu_job.o
rknpu-y += rknpu_debugger.o
rknpu-y += rknpu_iommu.o
# Mainline port: devfreq support depends on vendor rockchip_opp_select /
# rockchip_system_monitor APIs absent from mainline kernels.  Leave DVFS off;
# NPU frequency is set statically (DT assigned-clock-rates or the npu_rate
# module param), matching the QNAP rknpu-mainline minimal-viable config.
# rknpu-$(CONFIG_PM_DEVFREQ) += rknpu_devfreq.o
rknpu-$(CONFIG_ROCKCHIP_RKNPU_SRAM) += rknpu_mm.o
rknpu-$(CONFIG_ROCKCHIP_RKNPU_FENCE) += rknpu_fence.o
rknpu-$(CONFIG_ROCKCHIP_RKNPU_DRM_GEM) += rknpu_gem.o
rknpu-$(CONFIG_ROCKCHIP_RKNPU_DMA_HEAP) += rknpu_mem.o
