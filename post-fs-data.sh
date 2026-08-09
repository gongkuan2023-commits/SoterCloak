#!/system/bin/sh
# ============================================================
# SoterCloak v1.5-LKM
# post-fs-data.sh - 早期启动阶段属性伪造
# ============================================================
# LKM 模式专用（无 SusFS）
# resetprop 必须使用绝对路径
# ro.boottime.vendor.soter 不在此处删除（init 会重新写入）
# 该属性在 service.sh 的后台循环中持续删除
# ============================================================

RP=/data/adb/ksu/bin/resetprop

# ===== Boot 状态伪造 =====
$RP ro.boot.verifiedbootstate green 2>/dev/null
$RP ro.boot.vbmeta.device_state locked 2>/dev/null
$RP ro.boot.flash.locked 1 2>/dev/null

# ===== Soter 属性伪造（让属性显示为不支持）=====
$RP --delete ro.tencent.soter.support 2>/dev/null
$RP --delete ro.tencent.soter.version 2>/dev/null
$RP persist.vendor.soter.enabled false 2>/dev/null
$RP vendor.soter.supported false 2>/dev/null

# ===== AVB 版本号隐藏 =====
$RP --delete ro.boot.vbmeta.avb_version 2>/dev/null
$RP --delete ro.boot.avb_version 2>/dev/null

# ===== OEM 解锁隐藏 =====
$RP ro.oem_unlock_supported 0 2>/dev/null

# ===== oplus 验证结果隐藏 =====
$RP --delete persist.vendor.oplus.verify_result 2>/dev/null

# ===== init.svc 属性隐藏 =====
$RP --delete init.svc.vendor.soter 2>/dev/null
$RP --delete init.svc_debug_pid.vendor.soter 2>/dev/null
