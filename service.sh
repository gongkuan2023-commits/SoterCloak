#!/system/bin/sh
# ============================================================
# SoterCloak v1.7.1  —  OnePlus Ace 6 (PLQ110)
# SukiSU Ultra GKI 适配：无 ksu_susfs 时自动跳过 SusFS 调用
# 设备内核：6.6.118-android15-8-gccd9bb9aa1796 (Wild, 4k)
# 注意：MT 管理器检测请改用 HMA-OSS 隐藏包名/路径，
#       模块内不再对 /sdcard 任何目录做 mount --bind（会拖慢安装、遮挡文件）
# ============================================================
RP=/data/adb/ksu/bin/resetprop
SU=/data/adb/ksu/bin/ksu_susfs
HAS_SUSFS=0
[ -x "$SU" ] && HAS_SUSFS=1

# Soter 相关路径（SusFS 隐藏 / 备用）
SUS_PATHS="/system_ext/app/SoterService /vendor/bin/hw/vendor.qti.hardware.soter-service /vendor/bin/vendor.qti.hardware.soter-provision /vendor/etc/init/vendor.qti.hardware.soter-service.rc /vendor/etc/vintf/manifest/vendor.qti.hardware.soter-service.xml /vendor/firmware_mnt/image/soter64.b00 /vendor/firmware_mnt/image/soter64.b01 /vendor/firmware_mnt/image/soter64.b02"

apply_susfs() {
    [ "$HAS_SUSFS" != "1" ] && return 0
    for p in $SUS_PATHS; do
        $SU add_sus_path "$p" 2>/dev/null
    done
}

# ---------- 核心修复（action.sh 复用同一套逻辑）----------
apply_fixes() {
    # 1. cmdline orange -> green（SusFS 改 bootconfig 在 Wild 内核失效，用 mount --bind 兜底）
    cat /proc/cmdline 2>/dev/null | sed -e 's/verifiedbootstate=orange/verifiedbootstate=green/' -e 's/oplusboot.secure_type=3/oplusboot.secure_type=1/' > /data/local/tmp/fake_cmdline.txt
    [ "$HAS_SUSFS" = "1" ] && $SU set_cmdline_or_bootconfig /data/local/tmp/fake_cmdline.txt 2>/dev/null
    mount --bind /data/local/tmp/fake_cmdline.txt /proc/cmdline 2>/dev/null

    # 2. 冻结 SoterService（pm hide 仅藏包、可逆、不影响安装速度）
    pm disable com.tencent.soter.soterserver 2>/dev/null
    pm hide com.tencent.soter.soterserver 2>/dev/null
    am force-stop com.tencent.soter.soterserver 2>/dev/null

    # 3. 停止 vendor.soter
    stop vendor.soter 2>/dev/null

    # 4. SusFS 路径隐藏（仅在有 SusFS 时）
    apply_susfs
}

# ---------- 启动阶段 ----------
while [ "$(getprop sys.boot_completed)" != "1" ]; do sleep 2; done
sleep 10
apply_fixes

# ---------- 后台守护（持续生效，防被重置）----------
(
    while true; do
        stop vendor.soter 2>/dev/null
        $RP --delete init.svc.vendor.soter 2>/dev/null
        $RP --delete init.svc_debug_pid.vendor.soter 2>/dev/null
        $RP --delete ro.boottime.vendor.soter 2>/dev/null
        mount --bind /data/local/tmp/fake_cmdline.txt /proc/cmdline 2>/dev/null
        apply_susfs
        sleep 30
    done
) &
