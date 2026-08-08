#!/system/bin/sh
# ============================================================
# SoterCloak v1.5
# post-fs-data.sh - 早期启动阶段属性伪造
# ============================================================
# 更新内容 (v1.5):
#   - 适配 Android 16 (SDK 36) / PLQ110 16.0.5.700
#   - 增加 androidboot.* 前缀属性处理 (Android 16 新格式)
#   - 增加 oplusboot.* 属性清理
#   - 增加 ro.boot.vbmeta.avb_algorithm 删除
# ============================================================
# 注意：resetprop 必须使用绝对路径（不在 PATH 中）
# 注意：ro.boottime.vendor.soter 不在此处删除（init 会重新写入）
#       该属性在 service.sh 的后台循环中持续删除
# ============================================================

RP=/data/adb/ksu/bin/resetprop

# ===== Boot 状态伪造 =====
$RP ro.boot.verifiedbootstate green 2>/dev/null
$RP ro.boot.vbmeta.device_state locked 2>/dev/null
$RP ro.boot.flash.locked 1 2>/dev/null
# Android 16 androidboot.* 前缀 (部分固件使用新格式)
$RP ro.boot.androidboot.verifiedbootstate green 2>/dev/null
$RP ro.boot.androidboot.vbmeta.device_state locked 2>/dev/null
$RP ro.boot.androidboot.flash.locked 1 2>/dev/null

# ===== Soter 属性伪造（让属性显示为不支持）=====
$RP --delete ro.tencent.soter.support 2>/dev/null
$RP --delete ro.tencent.soter.version 2>/dev/null
$RP persist.vendor.soter.enabled false 2>/dev/null
$RP vendor.soter.supported false 2>/dev/null

# ===== AVB 版本号隐藏 =====
$RP --delete ro.boot.vbmeta.avb_version 2>/dev/null
$RP --delete ro.boot.avb_version 2>/dev/null
$RP --delete ro.boot.vbmeta.avb_algorithm 2>/dev/null

# ===== OEM 解锁隐藏 =====
$RP ro.oem_unlock_supported 0 2>/dev/null
$RP --delete ro.boot.oem_unlocked 2>/dev/null

# ===== oplus 验证结果隐藏 =====
$RP --delete persist.vendor.oplus.verify_result 2>/dev/null
$RP --delete ro.boot.oplus.secure_type 2>/dev/null

# ===== init.svc 属性隐藏 =====
$RP --delete init.svc.vendor.soter 2>/dev/null
$RP --delete init.svc_debug_pid.vendor.soter 2>/dev/null
