# SoterCloak

> KernelSU 模块 | 解决春秋检测器 (Eros 3.8) TEE 环境不可信 + avb=2.0 + Property Modified 等检测异常

## 适用设备

| 设备品牌 | SoterService 路径 | 兼容性 |
|---|---|---|
| OnePlus / OPPO / realme | `/system_ext/app/SoterService` | ✅ 直接使用 |
| 小米 / Redmi | `/system_ext/app/SoterService` 或 `/vendor/app/SoterService` | ⚠️ 需调整路径 |
| 三星 / Google / 其他无 SOTER 设备 | 无 SoterService | ❌ 不需要此模块 |

> **已测试设备**：OnePlus Ace 6T（PLR110/PLQ110, OP6113L1）
>
> 其他设备需自行确认 SoterService 路径，并调整 `sus_path.txt` 和 `post-fs-data.sh` 中的路径。
>
> **SusFS 内核**：GKI 设备（Android 12+ 高通/联发科）可使用 [WildKernels/GKI_KernelSU_SUSFS](https://github.com/WildKernels/GKI_KernelSU_SUSFS) 通用内核；非 GKI 设备需自行编译 SusFS 内核。

## 依赖

| 组件 | 要求 |
|---|---|
| KernelSU Next | ≥ 3.3.0（[KernelSU Next](https://github.com/rifsxd/KernelSU-Next)） |
| SusFS 内核 | ≥ v2.2.0（需刷入集成了 SusFS 的内核） |
| Zygisk Next | 推荐（用于隐藏 Zygisk） |
| HMA-OSS | 推荐（隐藏 SoterService 包） |

> **SusFS 内核下载**：[WildKernels/GKI_KernelSU_SUSFS](https://github.com/WildKernels/GKI_KernelSU_SUSFS)
>
> SusFS 必须通过刷入集成 SusFS 的内核来实现，不能仅靠模块。OnePlus Ace 6T 可使用 `6.6.118-android15-2026-01-AnyKernel3.zip` 内核，通过 KernelSU 管理器或 TWRP 刷入。

## 检测项状态

| 检测项 | 状态 | 解决方式 |
|---|---|---|
| ✅ TEE 环境不可信 | 已解决 | SoterService 冻结 + vendor.soter 停止 + 属性隐藏 + vendor soter 文件隐藏 |
| ✅ avb=2.0 | 已解决 | resetprop 删除 avb_version |
| ✅ Found ksu/免解设备 | 已解决 | SusFS 隐藏 `/system/bin/su` |
| ✅ 挂载间隙 | 已解决 | SusFS 隐藏 KSU LOOP + DEX2OAT |
| ✅ Bootloader 解锁 | 已解决 | cmdline 伪装 |
| ✅ 启动状态异常 | 已解决 | cmdline 伪装 |
| ✅ 发现异常模块 | 已解决 | HMA-OSS + SusFS 挂载隐藏 |
| ✅ Property Modified | 已解决 | 重启后 init 自动修复空洞 |
| ⚠️ Found ksu（侧信道） | 部分解决 | SusFS 隐藏文件/进程，但 GKI 模式内核侧信道无法隐藏 |

> **注**：Found ksu 的侧信道检测需要切换到 LKM 模式才能完全解决，当前 GKI 模式下无法通过软件隐藏。

## 工作原理

### SoterService 交叉验证逻辑

春秋检测器通过 4 种组合判定 TEE 状态：

| 组合 | 属性状态 | SoterService 程序 | 判定 |
|---|---|---|---|
| 1 | 正常 | 存在 | 正常支持 SOTER |
| **2** | **异常** | **不存在** | **原生不支持（降级）** ← 目标 |
| 3 | 正常 | 不存在 | TEE 环境不可信 |
| 4 | 异常 | 存在 | TEE 环境不可信 |

本模块通过**伪造第 2 种情况**（属性异常 + 服务不存在 → 原生不支持 → 跳过 TEE 验证）来绕过检测。

### 关键属性隐藏

| 属性 | 处理方式 |
|---|---|
| `ro.tencent.soter.support` | 删除 |
| `ro.tencent.soter.version` | 删除 |
| `persist.vendor.soter.enabled` | 设为 false |
| `vendor.soter.supported` | 设为 false |
| `init.svc.vendor.soter` | 删除（需 stop vendor.soter） |
| `init.svc_debug_pid.vendor.soter` | 删除 |
| `ro.boottime.vendor.soter` | 删除（**关键！**） |
| `ro.boot.vbmeta.avb_version` | 删除 |
| `ro.boot.verifiedbootstate` | 设为 green |
| `ro.boot.vbmeta.device_state` | 设为 locked |
| `ro.boot.flash.locked` | 设为 1 |

### `ro.boottime.vendor.soter` — 最终根因

这个属性记录了 vendor.soter 服务的启动时间戳。即使删了 `init.svc.vendor.soter`，只要 `ro.boottime.vendor.soter` 还在，检测器就知道系统跑过 soter → TEE 不可信。

此属性由 init 在启动时写入，`resetprop --delete` 删除后 init 会重新写入。因此必须在 `service.sh` 的后台循环中持续删除。

## 安装

### 方法一：KSU Next 自动安装（推荐）

1. 下载 `SoterCloak_v1.4.zip`
2. 打开 KernelSU Next 管理器 → 模块 → 从存储安装
3. 选择 `SoterCloak_v1.4.zip`
4. 重启设备

### 方法二：手动安装（源文件）

> ⚠️ `SoterCloak_v1.4_source.zip` 为源文件，不能直接刷入。

1. 下载并解压 `SoterCloak_v1.4_source.zip`
2. 将模块文件复制到 `/data/adb/modules/soter_cloak/`：
   ```bash
   su
   mkdir -p /data/adb/modules/soter_cloak
   cp module.prop post-fs-data.sh service.sh /data/adb/modules/soter_cloak/
   ```
3. 设置脚本执行权限：
   ```bash
   chmod +x /data/adb/modules/soter_cloak/post-fs-data.sh
   chmod +x /data/adb/modules/soter_cloak/service.sh
   ```
4. 重启设备

## 额外配置（必须）

### 1. SusFS 路径隐藏

编辑 `/data/adb/susfs4ksu/sus_path.txt`：

```
/system_ext/app/SoterService
/system/bin/su
/vendor/bin/hw/vendor.qti.hardware.soter-service
/vendor/bin/vendor.qti.hardware.soter-provision
/vendor/etc/init/vendor.qti.hardware.soter-service.rc
/vendor/etc/vintf/manifest/vendor.qti.hardware.soter-service.xml
/vendor/firmware_mnt/image/soter64.b00
/vendor/firmware_mnt/image/soter64.b01
/vendor/firmware_mnt/image/soter64.b02
```

> **关键**：vendor 分区的 soter 文件必须隐藏，否则检测器查到这些文件 → TEE 不可信

### 2. SusFS WebUI 开关

| 开关 | 状态 |
|---|---|
| 伪装 CMDLINE | ✅ 开启 |
| 隐藏 KSU LOOP | ✅ 开启 |
| 强制隐藏 DEX2OAT 挂载 | ✅ 开启 |

### 3. HMA-OSS 配置

隐藏目标应用：
- `com.chunqiunativecheck`（春秋检测器）
- `com.tencent.mm`（微信，可选）

隐藏内容：
- `com.tencent.soter.soterserver`

### 4. 禁用冲突模块

| 模块 | 兼容性 | 说明 |
|---|---|---|
| RKF:Daemon & Ctrl_AVB & Backend | ❌ 冲突 | 导致 avb=2.0，必须禁用 |
| TEESimulator-RS | ⚠️ 需禁用 | 被检测到痕迹（需要写 key 时再启用） |
| SoterFix / 其他 Soter 模块 | ❌ 冲突 | 与本模块重复操作，必须删除 |

### 5. 兼容模块

| 模块 | 兼容性 | 说明 |
|---|---|---|
| SusFS-FOR-KERNELSU | ✅ 必须配合 | 路径隐藏 + 挂载隐藏 |
| HMA-OSS | ✅ 必须配合 | 隐藏 SoterService 包 |
| Zygisk Next | ✅ 兼容 | 无冲突 |
| LSPosed | ✅ 兼容 | 无冲突 |
| Play Integrity Fork | ✅ 兼容 | 无冲突 |
| Tricky Store | ✅ 兼容 | 无冲突 |
| 主题类模块 | ✅ 兼容 | 无冲突 |

## 注意事项

1. **重启后等待 15 秒再开检测器** — service.sh 需要时间执行 `stop vendor.soter`
2. **微信指纹支付不可用** — SoterService 被冻结后，微信支付无法使用 SOTER 指纹
3. **stop vendor.soter 不能在开机早期执行** — 会导致卡第一屏
4. **resetprop/ksu_susfs 必须用绝对路径** — `/data/adb/ksu/bin/`

## 已知问题

| 问题 | 状态 | 说明 |
|---|---|---|
| Found ksu（侧信道） | ⚠️ 无法完全解决 | GKI 模式下内核侧信道检测，需要 LKM 模式 |
| Property Modified | ✅ 重启后自动修复 | resetprop 修改会留下空洞，init 重启后覆盖 |
| 微信指纹支付 | ❌ 不可用 | SoterService 被冻结，微信支付无法使用 SOTER |

## 关键教训

1. `resetprop --delete` 会在属性区留下空洞，检测器查到空洞就报 Property Modified
2. `init.svc.vendor.soter` 由 init 维护，只删属性没用，必须 `stop vendor.soter`
3. `ro.boottime.vendor.soter` 是最终根因，必须持续删除
4. `stop vendor.soter` 在 boot_completed+5s 执行会卡第一屏，延迟到 +10s 安全
5. `ro.` 属性是只读的，但 resetprop 可以修改（init 会重新写入）
6. **vendor 分区的 soter 文件必须隐藏**（`/vendor/bin/hw/vendor.qti.hardware.soter-service` 等）
7. `shamiko_Plus.sh` 会制造更多属性空洞，不建议使用
8. `stop vendor.soter` 在开机早期执行会导致卡第一屏
9. `resetprop/ksu_susfs` 不在 PATH 中，必须用绝对路径 `/data/adb/ksu/bin/`

## 文件结构

```
soter_cloak/
├── module.prop          # 模块信息
├── post-fs-data.sh      # 早期启动：属性伪造
└── service.sh           # 开机后：cmdline伪装 + 冻结SoterService + stop vendor.soter + 循环清理
```

## 作者

- **龔寬**
- 型号：PLQ110
- 日期：2026-08-02

## 致谢

- [KernelSU Next](https://github.com/rifsxd/KernelSU-Next)
- [SusFS](https://gitlab.com/simonpunk/susfs4ksu)
- [HMA-OSS](https://github.com/frknkrc44/HMA-OSS)
- [Chunqiu-Detector-Problem-solution](https://github.com/mingzun09/Chunqiu-Detector-Problem-solution)
- [Tencent SOTER](https://github.com/Tencent/soter)
