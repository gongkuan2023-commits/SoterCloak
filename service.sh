#!/system/bin/sh
# ============================================================
# SoterCloak v1.6
# service.sh - 开机完成后执行
# ============================================================
# 更新内容 (v1.6):
#   - 合并 v1.5 + 用户定制版
#   - mount --bind /proc/cmdline 兜底（Wild 内核 SusFS spoof 不生效时）
#   - SusFS add_sus_path 循环（每 30s 重新绑定路径隐藏）
#   - 循环间隔 3s -> 30s（mount --bind 更稳定，无需高频）
# ============================================================
RP=/data/adb/ksu/bin/resetprop
SU=/data/adb/ksu/bin/ksu_susfs
while [ "$(getprop sys.boot_completed)" != "1" ]; do sleep 2; done
sleep 10
# 伪造 cmdline：orange->green, secure_type=3->1
cat /proc/cmdline 2>/dev/null | sed -e 's/verifiedbootstate=orange/verifiedbootstate=green/' -e 's/oplusboot.secure_type=3/oplusboot.secure_type=1/' > /data/local/tmp/fake_cmdline.txt
# SusFS spoof（改 /proc/bootconfig）
$SU set_cmdline_or_bootconfig /data/local/tmp/fake_cmdline.txt 2>/dev/null
# mount --bind 覆盖 /proc/cmdline（SusFS spoof cmdline 在 Wild 内核上不生效，用 bind 兜底）
mount --bind /data/local/tmp/fake_cmdline.txt /proc/cmdline 2>/dev/null
# 冻结 SoterService
pm disable com.tencent.soter.soterserver 2>/dev/null
am force-stop com.tencent.soter.soterserver 2>/dev/null
# SusFS 路径隐藏
SUS_PATHS="/system_ext/app/SoterService /vendor/bin/hw/vendor.qti.hardware.soter-service /vendor/bin/vendor.qti.hardware.soter-provision /vendor/etc/init/vendor.qti.hardware.soter-service.rc /vendor/etc/vintf/manifest/vendor.qti.hardware.soter-service.xml /vendor/firmware_mnt/image/soter64.b00 /vendor/firmware_mnt/image/soter64.b01 /vendor/firmware_mnt/image/soter64.b02"
for p in $SUS_PATHS; do
    $SU add_sus_path "$p" 2>/dev/null
done
(
    while true; do
        stop vendor.soter 2>/dev/null
        $RP --delete init.svc.vendor.soter 2>/dev/null
        $RP --delete init.svc_debug_pid.vendor.soter 2>/dev/null
        $RP --delete ro.boottime.vendor.soter 2>/dev/null
        # 确保 mount --bind 持续生效（被 umount 后重新 bind）
        mount --bind /data/local/tmp/fake_cmdline.txt /proc/cmdline 2>/dev/null
        for p in $SUS_PATHS; do
            $SU add_sus_path "$p" 2>/dev/null
        done
        sleep 30
    done
) &
