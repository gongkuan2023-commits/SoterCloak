#!/system/bin/sh
# ============================================================
# SoterCloak v1.6 — 模块页面「执行」按钮
# KernelSU / SukiSU 管理器点击模块卡片按钮时以 "action" 为参数执行本脚本
# 作用：无需重启，立即重跑全部修复（cmdline green / 停 Soter / 隐藏 MT）
# ============================================================
RP=/data/adb/ksu/bin/resetprop
SU=/data/adb/ksu/bin/ksu_susfs
HAS_SUSFS=0
[ -x "$SU" ] && HAS_SUSFS=1

SUS_PATHS="/system_ext/app/SoterService /vendor/bin/hw/vendor.qti.hardware.soter-service /vendor/bin/vendor.qti.hardware.soter-provision /vendor/etc/init/vendor.qti.hardware.soter-service.rc /vendor/etc/vintf/manifest/vendor.qti.hardware.soter-service.xml /vendor/firmware_mnt/image/soter64.b00 /vendor/firmware_mnt/image/soter64.b01 /vendor/firmware_mnt/image/soter64.b02"
MT_PATHS="/sdcard/MT2 /storage/emulated/0/MT2 /sdcard/Android/data/bin.mt.plus"

# 1. cmdline orange -> green
cat /proc/cmdline 2>/dev/null | sed -e 's/verifiedbootstate=orange/verifiedbootstate=green/' -e 's/oplusboot.secure_type=3/oplusboot.secure_type=1/' > /data/local/tmp/fake_cmdline.txt
[ "$HAS_SUSFS" = "1" ] && $SU set_cmdline_or_bootconfig /data/local/tmp/fake_cmdline.txt 2>/dev/null
mount --bind /data/local/tmp/fake_cmdline.txt /proc/cmdline 2>/dev/null

# 2. SoterService 冻结 + 隐藏
pm disable com.tencent.soter.soterserver 2>/dev/null
pm hide com.tencent.soter.soterserver 2>/dev/null
am force-stop com.tencent.soter.soterserver 2>/dev/null

# 3. 停止 vendor.soter
stop vendor.soter 2>/dev/null
$RP --delete init.svc.vendor.soter 2>/dev/null
$RP --delete ro.boottime.vendor.soter 2>/dev/null

# 4. SusFS 路径隐藏（仅在有 SusFS 时）
[ "$HAS_SUSFS" = "1" ] && for p in $SUS_PATHS; do $SU add_sus_path "$p" 2>/dev/null; done

# 5. MT 管理器规避
pm hide bin.mt.plus 2>/dev/null
mkdir -p /data/local/tmp/mt_decoy
for mp in $MT_PATHS; do
    [ -d "$mp" ] && mount --bind /data/local/tmp/mt_decoy "$mp" 2>/dev/null
done

echo "SoterCloak v1.6：已立即重跑全部修复 ✅"
