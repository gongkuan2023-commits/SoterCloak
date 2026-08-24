# SoterCloak

> KernelSU / SukiSU 模块 | 解决春秋检测器 TEE 环境不可信 + Bootloader 解锁 + MT 管理器 等检测异常

## v1.7.1 更新（紧急修复）

- ⚠️ **移除 MT 文件夹的 `mount --bind`**：v1.7 对 `/sdcard/MT2`、`/sdcard/Android/data/bin.mt.plus` 等做 bind 遮挡，会导致（1）文件夹内容看似消失、（2）后台循环每 30s re-bind 拖慢模拟存储层、安装 APP 变慢。已彻底移除。
- ✅ **MT 管理器检测改为 HMA-OSS**：请在 HMA-OSS 中隐藏包名 `bin.mt.plus` 及对应路径，不要再用模块 bind 用户文件夹。
- ✅ 保留 `pm hide bin.mt.plus`（仅藏包、可逆、不影响安装速度）。

## v1.7 更新

- ✅ **版本 1.7**（versionCode 9），相比 GitHub 已有 v1.6 增加：
- ✅ **SusFS 自动适配**：自动检测 `ksu_susfs` 是否存在，无 SusFS（如 SukiSU Ultra GKI）时跳过 SusFS 调用，不再产生无效报错
- ✅ **cmdline 伪装兜底**：`mount --bind` 覆盖 `/proc/cmdline`，将 `verifiedbootstate=orange` 改为 `green`（SusFS 改 bootconfig 在 Wild 内核失效时的可靠替代）
- ✅ **增强 Soter 隐藏**：`pm hide` SoterService + 后台守护循环持续清理
- ✅ **模块页面「执行」按钮**：新增 `action.sh`，KernelSU/SukiSU 管理器模块卡片点按钮即可立即重跑全部修复，**免重启**
- ✅ **无 WebUI**：执行按钮走原生 `action.sh`，不依赖任何网页界面

## 适用设备

| 设备品牌 | SoterService 路径 | 兼容性 |
|---|---|---|
| OnePlus / OPPO / realme | `/system_ext/app/SoterService` | ✅ 直接使用 |
| 小米 / Redmi | `/system_ext/app/SoterService` 或 `/vendor/app/SoterService` | ⚠️ 需调整路径 |
| 三星 / Google / 其他无 SOTER 设备 | 无 SoterService | ❌ 不需要此模块 |

> **已测试设备**：OnePlus Ace 6（PLQ110），内核 `6.6.118-android15-8-gccd9bb9aa1796`（Wild, 4k 页），SukiSU Ultra GKI 模式
>
> 其他设备需自行确认 SoterService 路径，并调整 `service.sh` / `action.sh` 中的路径。

## 依赖

| 组件 | 要求 |
|---|---|
| KernelSU / SukiSU Ultra | 任意较新版本（管理器版本号与驱动不一致可忽略） |
| SusFS 内核 | 可选。有则自动启用路径隐藏；无（如 SukiSU Ultra GKI）则走 `mount --bind` 兜底，功能不受影响 |
| HMA-OSS | 推荐（隐藏 SoterService 包 / MT Manager 包，配合本模块效果更佳） |

> **关于 SusFS**：本模块不强制依赖 SusFS。SukiSU Ultra GKI 模式（Wild 6.6.118）默认无 `ksu_susfs` 二进制，模块会自动跳过 SusFS 调用，核心的 cmdline green / Soter 停止 / 属性隐藏 / MT 规避全部走 `resetprop` + `mount --bind` 实现，照常生效。

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

### 方法一：管理器自动安装（推荐）

1. 下载 `SoterCloak_v1.7.zip`
2. 打开 KernelSU / SukiSU 管理器 → 模块 → 从存储安装
3. 选择 `SoterCloak_v1.7.zip`
4. 重启设备
5. （可选）模块卡片右下角出现「执行」按钮，点一下可立即重跑全部修复，无需重启

### 方法二：手动安装（源文件）

> ⚠️ `SoterCloak_v1.7_source.zip` 为源文件，不能直接刷入。

1. 将模块文件复制到 `/data/adb/modules/soter_persist_fix/`：
   ```bash
   su
   mkdir -p /data/adb/modules/soter_persist_fix
   cp module.prop post-fs-data.sh service.sh action.sh /data/adb/modules/soter_persist_fix/
   ```
2. 设置脚本执行权限：
   ```bash
   chmod +x /data/adb/modules/soter_persist_fix/post-fs-data.sh
   chmod +x /data/adb/modules/soter_persist_fix/service.sh
   chmod +x /data/adb/modules/soter_persist_fix/action.sh
   ```
3. 重启设备

## 额外配置（可选，本模块不依赖 WebUI）

### 1. SusFS 路径隐藏（仅当内核集成 SusFS 时）

> 本模块**不强制依赖 SusFS**，也**不使用 WebUI**。SukiSU Ultra GKI（Wild 6.6.118）默认无 `ksu_susfs`，模块会自动跳过 SusFS 调用，核心功能（cmdline green / Soter 停止 / 属性隐藏 / MT 规避）全部通过 `resetprop` + `mount --bind` 实现，照常生效。
>
> 若你的内核集成了 SusFS，可编辑 `/data/adb/susfs4ksu/sus_path.txt` 加入以下路径（需自行用对应 SusFS 工具启用，本模块不处理）：

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

> **关键**：vendor 分区的 soter 文件必须隐藏，否则检测器查到这些文件 → TEE 不可信。无 SusFS 时，本模块通过 `pm hide` + `stop vendor.soter` 达到等效效果。

### 2. HMA-OSS 配置

隐藏目标应用：
- `com.chunqiunativecheck`（春秋检测器）
- `com.tencent.mm`（微信，可选）

隐藏内容：
- `com.tencent.soter.soterserver`

### 3. 禁用冲突模块

| 模块 | 兼容性 | 说明 |
|---|---|---|
| RKF:Daemon & Ctrl_AVB & Backend | ❌ 冲突 | 导致 avb=2.0，必须禁用 |
| TEESimulator-RS | ⚠️ 需禁用 | 被检测到痕迹（需要写 key 时再启用） |
| SoterFix / 其他 Soter 模块 | ❌ 冲突 | 与本模块重复操作，必须删除 |

### 4. 兼容模块

| 模块 | 兼容性 | 说明 |
|---|---|---|
| HMA-OSS | ✅ 推荐 | 隐藏 SoterService / MT 包，配合本模块效果更佳 |
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
10. 本模块**无 WebUI**，执行按钮走 KernelSU 原生 `action.sh`，点一下即重跑全部修复，免重启

## 文件结构

```
soter_persist_fix/
├── module.prop          # 模块信息（id=soter_persist_fix, version=1.6）
├── post-fs-data.sh      # 早期启动：属性伪造
├── service.sh           # 开机后：cmdline伪装 + 冻结/隐藏SoterService + stop vendor.soter + MT规避 + 循环清理
└── action.sh            # 模块页面「执行」按钮：立即重跑全部修复（免重启）
```

## 作者

- **龔寬**
- 日期：2026-08-24

## 致谢

- [KernelSU Next](https://github.com/rifsxd/KernelSU-Next)
- [SusFS](https://gitlab.com/simonpunk/susfs4ksu)
- [HMA-OSS](https://github.com/frknkrc44/HMA-OSS)
- [Chunqiu-Detector-Problem-solution](https://github.com/mingzun09/Chunqiu-Detector-Problem-solution)
- [Tencent SOTER](https://github.com/Tencent/soter)
