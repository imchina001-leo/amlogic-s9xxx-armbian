# COMPONENT_MANIFEST — EA3588S-Armbian-NPU-1.0.0-rc1 全组件清单

分三域：①Git 入仓资产（本目录，见 `SHA256SUMS`）②Release 制品（GitHub Release 附档）③许可隔离件（不入任何发布）。

## 1. Git 入仓资产（本目录 releases/ea3588s-npu-1.0.0-rc/）

| 组件 | 路径 | 身份要点 | 许可 |
|---|---|---|---|
| NPU 驱动源码 | `driver/rknpu/`（25 文件） | 构建产物 = E2 `rknpu.ko` `120e0240…e25ce3`；srcversion `3D2A681794D91035B698E9D` | GPL-2.0（内核驱动） |
| 板级 DTS | `dts/rk3588s-ea3588s.dts` | 编译 → l0 DTB `87dd7145…` | GPL-2.0（dts） |
| NPU DTS 生成链 | `dts/npu/{make_npu_dts.py, board-npu.dts}` | 生成 → l1 DTB `a504ce4c…` | 自建 |
| 内核配置冻结件 | `compile-kernel/tools/config/config-6.12`（主仓 a81b5fd6 已入库） | 内核 `c6740dfd…f3b16f` 的配置源 | GPL-2.0 |
| 构建脚本/补丁 | `build/{run-build.sh, patches/*}` | P3-B 冻结构建链 | 自建（补丁对 GPL 内核） |
| P2 部署/回滚 | `install/p2/*` | W1-W8 写入集 + 文件级回滚 | 自建 |
| Level B 脚本 | `install/level-b/*` | 更新/回滚（门禁+备份+DRYRUN） | 自建 |
| 配置模板 | `install/p2/config-templates/*` | modules-load/modprobe/udev 三件（与镜像内字节一致） | 自建 |
| 模型服务层 | `install/model-service/*` | modelctl `e494cf07…` + 3 单元 + 设计文档 | 自建 |
| 探针 | 随 Level B payload / Release | `g6_vision_probe` `bf324113…` / `g6_llm_probe` `6ebdb7cb…` | 自建 |
| 审查/报告文档 | `docs/*` | AUTH-03 终审、P9 β1 构建、内核冻结说明、P8 状态 | 报告文档 |

## 2. Release 制品（GitHub Release 附档，不入 Git）

### Level A 完整恢复镜像（rockdev 六件套）

| 文件 | 大小 | SHA256 |
|---|---|---|
| `MiniLoaderAll.bin` | 448,960B | `ac4fec136c0e2e8898f54b9f6a5f08ae4c0fb9fae480140b485bc4b3e4e73249` |
| `uboot.img` | 2,090,496B | `5e693c832747389542a8cbaad7f4c6410518db238df0c098e01d77d9bf1271fe` |
| `parameter.txt` | 343B | `766afa34d2c9f075…`（完整值见 Release 级 SHA256SUMS） |
| `package-file` | 151B | `a46c752a8f4e2ab3…` |
| `boot.img` | 128MiB | `0187b5158affe5a20b6d6859ee9c595ecda33e030aef912f88ec8bbc2cad2bf8` |
| `rootfs.img.xz` | 884MiB | `52b5ffe05f01ac93e223914c6ac1625377f3b56f07761fe706238611c6eda91a`（解压 4.26G → `713151820a739146ce84203fd785e77340df7650479eeb6b69e048e9b6356e7f`，xz 往返已验） |
| `idblock-board-raw.bin` | 450,560B | `1e452e96f96fd5bf6b2b58a05f82130052cf6c5596c8b406e9a49f25d51622a7`（板端原始 dump，dd 级兜底件） |

### Level B 系统更新包（tar）

| 文件 | 身份要点 |
|---|---|
| `p2-boot-ea3588s-npu-1.0.0-rc1.img` | = Level A `boot.img`（`0187b515…`） |
| `payload/rknpu.ko` | `120e0240…e25ce3` |
| `payload/*`（13 件） | 配置四件套/modelctl/3 单元/双探针/清单 |
| `ea3588s-npu-update.sh` / `ea3588s-npu-rollback.sh` | 见 `install/level-b/`（同源） |

### 关键身份（跨制品锚点）

| 锚点 | 值 |
|---|---|
| 内核 vmlinuz | `c6740dfda82e659161747aae411cd1696ab65a0e90839afc0ebf181e8ef3b16f` |
| 模块树 modules.dep（板端验证态） | `d1d3179e…`（恢复镜像注入后+depmod → `a84187c7…`，差异=rknpu 条目） |
| extlinux | `35170c8d…`（default=l0；l1 cma=2048M） |
| p2 UUID | `7a3f0000-0000-446a-8000-702f00006273` |
| 主板 GPT | `BE480000-0000-4D2D-8000-3F8A000039C5` |

## 3. 许可隔离件（不入 Git、不入 Release）

| 件 | 身份 | 处置 |
|---|---|---|
| M1V 模型 `qwen3-vl-2b_vision_rk3588.rknn`（850,488,413B） | `3d707ef5…` | 本地资产包 + MODEL_DOWNLOAD_MANIFEST 登记（用户自备来源） |
| M1L 模型 `qwen3-vl-2b-instruct_w8a8_rk3588.rkllm` | `d5474340…` | 同上 |
| runtime `librknnrt-2.3.2` / `librkllmrt-1.2.3` | `d31fc19c…` / `bbcf28a8…` | 厂商二进制：本地 runtime 包 + 部署指引（INSTALL §7） |

> 以上三类的再分发许可均未确认。**任何情况下不得提交入仓或上传公开 Release。**

## 4. 凭据纪律

发布制品与 Git 资产均经检视：NetworkManager 连接模板为空、无 SSH 私钥/密码/token 类内容。rootfs 基底用户家目录为发行版默认（admin/linaro/teamhd），不含个人数据。
