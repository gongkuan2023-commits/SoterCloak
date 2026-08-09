#!/system/bin/sh
# SoterCloak v1.5-LKM — LKM 模式专用（无 SusFS）
# 兼容 SukiSU Ultra / KernelSU Next LKM 模式
RP=/data/adb/ksu/bin/resetprop
while [ "$(getprop sys.boot_completed)" != "1" ]; do sleep 2; done
sleep 10
cat /proc/cmdline 2>/dev/null | sed -e 's/verifiedbootstate=orange/verifiedbootstate=green/' -e 's/oplusboot.secure_type=3/oplusboot.secure_type=1/' > /data/local/tmp/fake_cmdline.txt
mount --bind /data/local/tmp/fake_cmdline.txt /proc/cmdline 2>/dev/null
pm disable com.tencent.soter.soterserver 2>/dev/null
am force-stop com.tencent.soter.soterserver 2>/dev/null
$RP --delete ro.tencent.soter.support 2>/dev/null
$RP --delete ro.tencent.soter.version 2>/dev/null
$RP persist.vendor.soter.enabled false 2>/dev/null
$RP vendor.soter.supported false 2>/dev/null
$RP --delete ro.boot.vbmeta.avb_version 2>/dev/null
$RP ro.boot.verifiedbootstate green 2>/dev/null
$RP ro.boot.flash.locked 1 2>/dev/null
$RP ro.boot.vbmeta.device_state locked 2>/dev/null
(
    while true; do
        stop vendor.soter 2>/dev/null
        $RP --delete init.svc.vendor.soter 2>/dev/null
        $RP --delete init.svc_debug_pid.vendor.soter 2>/dev/null
        $RP --delete ro.boottime.vendor.soter 2>/dev/null
        mount --bind /data/local/tmp/fake_cmdline.txt /proc/cmdline 2>/dev/null
        sleep 30
    done
) &
