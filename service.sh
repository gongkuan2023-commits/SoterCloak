#!/system/bin/sh
# ============================================================
# SoterCloak v1.4
# service.sh - 开机完成后执行
# ============================================================
# 执行顺序：
#   1. 等待 sys.boot_completed = 1
#   2. 延迟 10 秒（避免卡第一屏）
#   3. cmdline 伪装
#   4. 冻结 SoterService APK
#   5. 后台循环：stop vendor.soter + 删除 init.svc 属性 + 删除 boottime 属性
# ============================================================
# 注意：stop vendor.soter 在开机早期执行会导致卡第一屏
#       必须延迟到 boot_completed 后执行
# ============================================================

RP=/data/adb/ksu/bin/resetprop
SU=/data/adb/ksu/bin/ksu_susfs

# 等待开机完成
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 2
done
sleep 10

# ===== cmdline 伪装 =====
cat /proc/cmdline 2>/dev/null | sed \
    -e 's/verifiedbootstate=orange/verifiedbootstate=green/' \
    -e 's/oplusboot.secure_type=3/oplusboot.secure_type=1/' \
    > /data/local/tmp/fake_cmdline.txt
$SU set_cmdline_or_bootconfig /data/local/tmp/fake_cmdline.txt 2>/dev/null

# ===== 冻结 SoterService APK =====
pm disable com.tencent.soter.soterserver 2>/dev/null
am force-stop com.tencent.soter.soterserver 2>/dev/null

# ===== 后台循环清理 =====
# init 会重新写入 init.svc.vendor.soter 和 ro.boottime.vendor.soter
# 必须持续删除才能保持隐藏
(
    while true; do
        stop vendor.soter 2>/dev/null
        $RP --delete init.svc.vendor.soter 2>/dev/null
        $RP --delete init.svc_debug_pid.vendor.soter 2>/dev/null
        $RP --delete ro.boottime.vendor.soter 2>/dev/null
        # reboot/abnormal 属性清理
        $RP --delete persist.sys.boot.reason.history 2>/dev/null
        $RP --delete persist.sys.oplus.abnormalreboot_type 2>/dev/null
        $RP --delete persist.sys.oplus.total_abnormalreboot_count 2>/dev/null
        $RP --delete persist.sys.oplus.total_abnormalreboot_count_neras 2>/dev/null
        $RP --delete persist.sys.system.abnormalboot 2>/dev/null
        $RP --delete sys.oplus.abnormal_reboot_record 2>/dev/null
        $RP --delete sys.oplus.abnormalreboot_type 2>/dev/null
        $RP --delete sys.oplus.reboot 2>/dev/null
        $RP --delete persist.sys.reboot.time.count 2>/dev/null
        $RP --delete ro.boot.bootreason 2>/dev/null
        $RP --delete ro.boot.mode 2>/dev/null
        $RP --delete ro.bootmode 2>/dev/null
        $RP --delete sys.boot.reason.last 2>/dev/null
        $RP --delete vendor.oplus.boot.bootreason 2>/dev/null
        $RP --delete vendor.oplus.boot.reason.last 2>/dev/null
        sleep 5
    done
) &
