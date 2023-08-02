#!/system/bin/sh

# Memeriksa izin root jika device lu ndak root mengembalikan output No root permissions. Exiting.
if [[ "$(id -u)" -ne 0 ]]
then
	echo "No root permissions. Exiting."
	exit 1
fi

# Ukuran bilangan bulat tidak bertanda maksimum dalam C
UINT_MAX="4294967295"

# Menganbil total size memory
memTotal=$(free -m | awk '/^Mem:/{print $2}')

# Durasi dalam nanodetik dari satu periode penjadwalan
SCHED_PERIOD=$((4*1000*1000))

# Banyak tugas yang harus dimiliki secara maksimal dalam satu periode penjadwalan
SCHED_TASKS="8"

# Fungsi dasar
# Menulis nilai dengan aman ke file
write() {
	# jika file tidak ada
	if [[ ! -f "$1" ]]
	then
		echo "Failed $1 does not exist"
		return 1
	fi
	
	local current=$(cat "$1")

	# jika nilai sudah ditetapkan
	if [[ "$current" == "$2" ]]
	then
		echo "Success $1: $current --> $2"
		return 0
	fi

	# menulis value baru
	echo "$2" > "$1"

	# jika penulisan gagal
	if [[ $? -ne 0 ]]
	then
		err "Failed to write $2 to $1"
		return 1
	fi

	echo "Success $1: $current --> $2"
}

set_cpufreq_min() {
    write /sys/module/msm_performance/parameters/cpu_min_freq "$1"
    local key
    local val
    for kv in $1; do
        key=${kv%:*}
        val=${kv#*:}
        write /sys/devices/system/cpu/cpu$key/cpufreq/scaling_min_freq "$val"
    done
}

set_cpufreq_max() {
    write /sys/module/msm_performance/parameters/cpu_max_freq "$1"
    local key
    local val
    for kv in $1; do
        key=${kv%:*}
        val=${kv#*:}
        write /sys/devices/system/cpu/cpu$key/cpufreq/scaling_max_freq "$val"
    done
}

# fungsi cgroup
# panduan : $1 - task_name | $2 - "cpuset" atau "stune" | $3 - cgroup_name
change_task_cgroup() {
    local ps_ret
    ps_ret="$(ps -Ao pid,args)"
    for temp_pid in $(echo "$ps_ret" | grep "$1" | awk '{print $1}'); do
        for temp_tid in $(ls "/proc/$temp_pid/task/"); do
            write "/dev/$2/$3/tasks" "$temp_tid"
        done
    done
}

# panduan : $1 - task_name | $2 - nice (relatif ke 120)
change_task_nice() {
    local ps_ret
    ps_ret="$(ps -Ao pid,args)"
    for temp_pid in $(echo "$ps_ret" | grep "$1" | awk '{print $1}'); do
        for temp_tid in $(ls "/proc/$temp_pid/task/"); do
            renice -n "$2" -p "$temp_tid"
        done
    done
}

# Script inti🔥
# Set up untuk Gpu
# mencari direktori settingan gpu 
if [ -d "/sys/class/kgsl/kgsl-3d0" ]; then
	gpu="/sys/class/kgsl/kgsl-3d0"
elif [ -d "/sys/devices/platform/kgsl-3d0.0/kgsl/kgsl-3d0" ]; then
	gpu="/sys/devices/platform/kgsl-3d0.0/kgsl/kgsl-3d0"
elif [ -d "/sys/devices/soc/*.qcom,kgsl-3d0/kgsl/kgsl-3d0" ]; then
	gpu="/sys/devices/soc/*.qcom,kgsl-3d0/kgsl/kgsl-3d0"
elif [ -d "/sys/devices/soc.0/*.qcom,kgsl-3d0/kgsl/kgsl-3d0" ]; then
	gpu="/sys/devices/soc.0/*.qcom,kgsl-3d0/kgsl/kgsl-3d0"
elif [ -d "/sys/devices/platform/*.gpu/devfreq/*.gpu" ]; then
	gpu="/sys/devices/platform/*.gpu/devfreq/*.gpu"
elif [ -d "/sys/devices/platform/gpusysfs" ]; then
	gpu="/sys/devices/platform/gpusysfs"
elif [ -d "/sys/devices/*.mali" ]; then
	gpu="/sys/devices/*.mali"
elif [ -d "/sys/devices/*.gpu" ]; then
	gpu="/sys/devices/*.gpu"
elif [ -d "/sys/devices/platform/mali.0" ]; then
	gpu="/sys/devices/platform/mali.0"
elif [ -d "/sys/devices/platform/mali-*.0" ]; then
	gpu="/sys/devices/platform/mali-*.0"
elif [ -d "/sys/module/mali/parameters" ]; then
	gpu="/sys/module/mali/parameters"
elif [ -d "/sys/class/misc/mali0" ]; then
	gpu="/sys/class/misc/mali0"
elif [ -d "/sys/kernel/gpu" ]; then
	gpu="/sys/kernel/gpu"
fi

# GPU setting
write $gpu/max_pwrlevel "0"
write $gpu/adrenoboost "0"
write $gpu/adreno_idler_active "N"
write $gpu/throttling "0"
write $gpu/perfcounter "0"
write $gpu/bus_split "0"
write $gpu/thermal_pwrlevel "0"
write $gpu/force_clk_on "0"
write $gpu/force_bus_on "0"
write $gpu/force_rail_on "0"
write $gpu/force_no_nap "1"
write $gpu/idle_timer "80"
write $gpu/pmqos_active_latency "1000"

write /proc/gpufreq/gpufreq_limited_thermal_ignore "1"

# Dvds dan gpu algorithm (gpu algoritma)
if [ -e "/proc/mali/dvfs_enable" ]; then
    write /proc/mali/dvfs_enable "1"
fi

if [ -e "/sys/module/pvrsrvkm/parameters/gpu_dvfs_enable" ]; then
    write /sys/module/pvrsrvkm/parameters/gpu_dvfs_enable "1"
fi

if [ -e "/sys/module/simple_gpu_algorithm/parameters/simple_gpu_activate" ]; then
    write /sys/module/simple_gpu_algorithm/parameters/simple_gpu_activate "1"
fi

# GPU dan Graphic system properties
resetprop debug.enabletr "true"
resetprop debug.egl.buffcount "4"
resetprop ro.surface_flinger.max_frame_buffer_acquired_buffers "4"
resetprop debug.egl.hw "0"
resetprop debug.sf.hw "0"
resetprop debug.gralloc.gfx_ubwc_disable "0"
resetprop debug.mdpcomp.logs "0"
resetprop debug.sf.recomputecrop "0"
resetprop debug.sf.enable_hwc_vds "1"
resetprop debug.sf.enable_gl_backpressure "1"
resetprop debug.sf.latch_unsignaled "1"
resetprop vendor.gralloc.disable_ubwc "0"
resetprop hwui.use_gpu_pixel_buffers "true"
resetprop sys.hwc.gpu_perf_mode "1"
# dikomen dulu
#persist.sys.ui.hw=true
resetprop ro.zygote.disable_gl_preload "false"

# Disable input boost untuk unify Qualcomm
write /sys/devices/system/cpu/cpu_boost/* "0"
write /sys/devices/system/cpu/cpu_boost/parameters/* "0"
write /sys/module/cpu_boost/parameters/* "0"
write /sys/module/msm_performance/parameters/* "0"
write /sys/kernel/msm_performance/parameters/* "0"
write /proc/sys/walt/input_boost/* "0"
write /sys/kernel/cpu_input_boost/* "0"
write /sys/module/cpu_input_boost/parameters/* "0"
write /sys/module/dsboost/parameters/* "0"
write /sys/module/devfreq_boost/parameters/* "0"

# Set up untuk Hwui
if [ "$memTotal" -lt 3072 ]; then
	resetprop ro.hwui.texture_cache_size $((memTotal*10/100/2))
	resetprop ro.hwui.layer_cache_size $((memTotal*5/100/2))
	resetprop ro.hwui.path_cache_size $((memTotal*2/100/2))
	resetprop ro.hwui.r_buffer_cache_size $((memTotal/100/2))
	resetprop ro.hwui.drop_shadow_cache_size $((memTotal/100/2))
	resetprop ro.hwui.texture_cache_flushrate "0.3"
else 
	resetprop ro.hwui.texture_cache_size $((memTotal*10/100))
	resetprop ro.hwui.layer_cache_size $((memTotal*5/100))
	resetprop ro.hwui.path_cache_size $((memTotal*2/100))
	resetprop ro.hwui.r_buffer_cache_size $((memTotal/100))
	resetprop ro.hwui.drop_shadow_cache_size $((memTotal/100))
	resetprop ro.hwui.texture_cache_flushrate "0.3"
fi

# Ram+🔥
if [ "$memTotal" -le "512" ]; then
    settings put global ram_expand_size "512"
elif [ "$memTotal" -le "1024" ]; then
    settings put global ram_expand_size "1024"
elif [ "$memTotal" -le "2048" ]; then
    settings put global ram_expand_size "2048"
elif [ "$memTotal" -le "3072" ]; then
    settings put global ram_expand_size "3072"
elif [ "$memTotal" -le "4096" ]; then
    settings put global ram_expand_size "4096"
elif [ "$memTotal" -le "6144" ]; then
    settings put global ram_expand_size "6144"
else
	settings put global ram_expand_size "8192"
fi

# Set up untuk max background aplikasi
if [ "$memTotal" -le "512" ]; then
    backgroundAppLimit="16"
elif [ "$memTotal" -le "1024" ]; then
	backgroundAppLimit="24"
elif [ "$memTotal" -le "2048" ]; then
	backgroundAppLimit="28"
elif [ "$memTotal" -le "3072" ]; then
	backgroundAppLimit="30"
elif [ "$memTotal" -le "4096" ]; then
	backgroundAppLimit="36"
else
	backgroundAppLimit="42"
fi

# Memory properties
resetprop ro.vendor.qti.sys.fw.bservice_enable "true"
resetprop ro.sys.fw.bg_apps_limit "$backgroundAppLimit"
resetprop ro.vendor.qti.sys.fw.bg_apps_limit "$backgroundAppLimit"

# Disable JIT
resetprop dalvik.vm.dexopt-flags "v=n,o=n,m=n,u=n"
resetprop debug.usejit "false"
resetprop dalvik.vm.usejit "false"
resetprop dalvik.vm.usejitprofiles "false"

# JIT - limit JIT ke minimal verifikasi, tidak ada penggunaan profil.
resetprop dalvik.vm.image-dex2oat-filter "verify-at-runtime"
resetprop pm.dexopt.first-boot "verify-at-runtime"
resetprop pm.dexopt.boot "verify-at-runtime"
resetprop pm.dexopt.install "interpret-only"
resetprop pm.dexopt.ab-ota "quicken"
resetprop pm.dexopt.core-app "quicken"
resetprop pm.dexopt.bg-dexopt "quicken"
resetprop pm.dexopt.shared-apk "quicken"
resetprop pm.dexopt.nsys-library "quicken"
resetprop pm.dexopt.forced-dexopt "quicken"

# JIT - mengurangi verifikasi dengan dex checksum sebelum dijalankan, dan mengurangi log
resetprop dalvik.vm.check-dex-sum "false"
resetprop dalvik.vm.checkjni "false"
resetprop dalvik.vm.verify-bytecode "false"
resetprop debug.atrace.tags.enableflags "0"
resetprop ro.config.dmverity "false"
resetprop ro.config.htc.nocheckin "1"
resetprop ro.config.nocheckin "1"
resetprop ro.dalvik.vm.native.bridge "0"
resetprop ro.kernel.android.checkjni "0"
resetprop ro.kernel.checkjni "0"
resetprop dalvik.vm.dex2oat-minidebuginfo "false"
resetprop dalvik.vm.minidebuginfo "false"

# Hypertheading & Multithread
resetprop persist.sys.dalvik.hyperthreading "true"
resetprop persist.sys.dalvik.multithread "true"

upgrade_miui() {
# Periksa apakah kita menjalankan Memeui (MIUI)🔥
    [[ "$(getprop ro.miui.ui.version.name)" ]] && miui=true

    nr_cores=$(cat /sys/devices/system/cpu/possible | awk -F "-" '{print $2}')
    nr_cores=$(nr_cores + 1)

    [[ "$nr_cores" -eq "0" ]] && nr_cores=1

    [[ "$miui" == "true" ]] && [[ "$nr_cores" == "8" ]] && {
    resetprop persist.sys.miui.sf_cores "4-7"
    resetprop persist.sys.miui_animator_sched.bigcores "4-7"
    }

    [[ "$miui" == "true" ]] && [[ "$nr_cores" == "6" ]] && {
    resetprop persist.sys.miui.sf_cores "0-5"
    resetprop persist.sys.miui_animator_sched.bigcores "2-5"
    }

    [[ "$miui" == "true" ]] && [[ "$nr_cores" == "4" ]] && {
    resetprop persist.sys.miui.sf_cores "0-3"
    resetprop persist.sys.miui_animator_sched.bigcores "0-3"
    }
    
    # Cpu sets
    write /dev/cpuset/foreground/cpus "0-2,4-7"
    write /dev/cpuset/foreground/boost/cpus "4-7"
}

for net in /proc/sys/net; do
    write $net/ipv4/tcp_fastopen "3"
    write $net/ipv4/tcp_ecn "1"
    write $net/ipv4/tcp_syncookies "0"
done

# Menentukan ukuran buffer TCP untuk berbagai jaringan
resetprop net.tcp.buffersize.default "6144,87380,1048576,6144,87380,524288"
resetprop net.tcp.buffersize.wifi "524288,1048576,2097152,524288,1048576,2097152"
resetprop net.tcp.buffersize.umts "6144,87380,1048576,6144,87380,524288"
resetprop net.tcp.buffersize.gprs "6144,87380,1048576,6144,87380,524288"
resetprop net.tcp.buffersize.edge "6144,87380,524288,6144,16384,262144"
resetprop net.tcp.buffersize.hspa "6144,87380,524288,6144,16384,262144"
resetprop net.tcp.buffersize.lte "524288,1048576,2097152,524288,1048576,2097152"
resetprop net.tcp.buffersize.hsdpa "6144,87380,1048576,6144,87380,1048576"
resetprop net.tcp.buffersize.evdo_b "6144,87380,1048576,6144,87380,1048576"

# Set up untuk kernel sched
for sched_kernel in /proc/sys/kernel; do
    write $sched_kernel/sched_boost "0"
    write $sched_kernel/timer_migration "0"
    write $sched_kernel/sched_tunable_scaling "0"
    write $sched_kernel/sched_child_runs_first "0"
    write $sched_kernel/sched_autogroup_enabled "0"
    write $sched_kernel/sched_upmigrate "95 85"
    write $sched_kernel/sched_downmigrate "95 60"
    write $sched_kernel/sched_nr_migrate "32"
    write $sched_kernel/sched_min_task_util_for_boost "15"
    write $sched_kernel/sched_min_task_util_for_colocation "1000"
    write $sched_kernel/perf_cpu_time_max_percent "15"
    write $sched_kernel/sched_rr_timeslice_ns "100"
    write $sched_kernel/sched_rt_period_us "1000000"
    write $sched_kernel/sched_rt_runtime_us "950000"
    write $sched_kernel/sched_migration_cost_ns "5000000"
    write $sched_kernel/sched_latency_ns $SCHED_PERIOD
    write $sched_kernel/sched_min_granularity_ns $((SCHED_PERIOD/SCHED_TASKS))
    write $sched_kernel/sched_wakeup_granularity_ns $((SCHED_PERIOD/2))
done

# Set max freq untuk semua cpu
set_cpufreq_min "0:0 1:0 2:0 3:0 4:0 5:0 6:0 7:0"
set_cpufreq_max "0:9999000 1:9999000 2:9999000 3:9999000 4:9999000 5:9999000 6:9999000 7:9999000"

# Loop setiap cpu didalam system
for cpu in /sys/devices/system/cpu/cpu*/cpufreq; do
	# Mengambil Governor yang tersedia di CPU
	avail_govs="$(cat "$cpu/scaling_available_governors")"
	# Menerapkan dan mencoba mengatur governor di urutan ini
	for governor in schedutil interactive; do
		# Setelah governor yang cocok ketemu
		# atur dan hentikan untuk cpu itu sendiri
		if [[ "$avail_govs" == "$governor" ]]; then
			write $cpu/scaling_governor "$governor"
			break
		fi
	done
done

# Menerapkan governor khusus schedutil
find /sys/devices/system/cpu/ -name schedutil -type d | while IFS= read -r governor; do
	# Pertimbangkan untuk mengubah frekuensi satu kali per periode scheduling
	write $governor/up_rate_limit_us $((SCHED_PERIOD/1000))
	write $governor/down_rate_limit_us $((4*SCHED_PERIOD/1000))
	write $governor/rate_limit_us $((SCHED_PERIOD/1000))

	# Lanjut ke frekuensi kecepatan persentase
	write $governor/hispeed_freq "$UINT_MAX"
done

# menerapkan governor khusus interactive
find /sys/devices/system/cpu/ -name interactive -type d | while IFS= read -r governor; do
	# Pertimbangkan untuk mengubah frekuensi satu kali per periode scheduling
	write $governor/timer_rate $((SCHED_PERIOD/1000))
	write $governor/min_sample_time $((SCHED_PERIOD/1000))

	# Lanjut ke frekuensi kecepatan persentase
	write $governor/hispeed_freq "$UINT_MAX"
done

# Set up untuk Cpusets
write /dev/cpuset/cpus "0-7"
write /dev/cpuset/background/cpus "0-1"
write /dev/cpuset/system-background/cpus "0-3"
write /dev/cpuset/foreground/cpus "0-2,4-6"
write /dev/cpuset/foreground/boost/cpus "4-6"
write /dev/cpuset/top-app/cpus "0-7"
write /dev/cpuset/restricted/cpus "0-3"
write /dev/cpuset/camera-daemon/cpus "0-7"

# Entropy
write /proc/sys/kernel/random/read_wakeup_threshold "128"
write /proc/sys/kernel/random/write_wakeup_threshold "1024"

# Efisiensi CPU
write /sys/module/workqueue/parameters/power_efficient "Y"

# Disable multi core power saving
mcps="/sys/devices/system/cpu/sched_mc_power_savings"
if [ -e $mcps ]; then
  write $mcps "0"
fi

# Disable V-Sync
resetprop debug.cpurend.vsync "false"
resetprop hwui.disable_vsync "true"

# FileSystem | optimized & enhancements
write /proc/sys/fs/dir-notify-enable "0"
write /proc/sys/fs/lease-break-time "20"
write /proc/sys/kernel/hung_task_timeout_secs "0"

# LMP
for lmp in /sys/module/lpm_levels/parameters; do
    write $lmp/lpm_ipi_prediction "0"
    write $lmp/lpm_prediction "0"
    write $lmp/sleep_disabled "0"
done

# Gaming Touch
if [ -f "/sys/devices/virtual/touch/touch_dev/bump_sample_rate" ]; then
    write /sys/devices/virtual/touch/touch_dev/bump_sample_rate "1"
fi

# Unity fix
write /proc/sys/kernel/sched_lib_name "com.miHoYo., com.activision., UnityMain, libunity.so, libfb.so"
write /proc/sys/kernel/sched_lib_mask_force "255"

# Kernel Panic Off
write /proc/sys/kernel/panic "0"
write /proc/sys/kernel/panic_on_oops "0"
write /proc/sys/kernel/panic_on_warn "0"
write /proc/sys/kernel/panic_on_rcu_stall "0"
write /sys/module/kernel/parameters/panic "0"
write /sys/module/kernel/parameters/panic_on_warn "0"
write /sys/module/kernel/parameters/pause_on_oops "0"
write /sys/module/kernel/panic_on_rcu_stall "0"

# Virtual memory
for virtual_memory in /proc/sys/vm; do
    write $virtual_memory/page-cluster "0"
    write $virtual_memory/stat_interval "20"
    write $virtual_memory/oom_kill_allocating_task "0"
    write $virtual_memory/dirty_expire_centisecs "300"
    write $virtual_memory/dirty_writeback_centisecs "700"
done

# Watermark Boost
if [[ "$(cat /proc/version)" == "4.19" ]]; then
    echo "Found 4.19 kernel, disabling watermark boost because doesn't work"
    write /proc/sys/vm/watermark_boost_factor "0"
elif [ -e /proc/sys/vm/watermark_boost_factor ]; then
    echo "Found Watermark Boost support, tweaking it"
    write /proc/sys/vm/watermark_boost_factor "15000"
else
    echo "Your kernel doesn't support watermark boost"
fi

# Set up untuk I/O Scheduler
for scheduler in /sys/block/*/queue; do
    write $scheduler/scheduler "cfq"
    write $scheduler/iostats "0"
    write $scheduler/add_random "0"
    write $scheduler/nomerges "2"
    write $scheduler/rq_affinity "1"
    write $scheduler/rotational "0"
    write $scheduler/read_ahead_kb "128"
    write $scheduler/nr_requests "64"
done

# Loop
for loop in /sys/block/loop*/queue; do
    write $loop/scheduler "none"
done

# Zram
for zram in /sys/block/zram0/queue; do
    write /sys/block/zram0/queue/scheduler "deadline"
    write /sys/block/zram0/queue/read_ahead_kb "512"
done

# Set up untuk ioshed, disable idle
for iosched in /sys/block/*/iosched; do
    write $iosched/slice_idle "0"
    write $iosched/slice_idle_us "0"
    write $iosched/group_idle "0"
    write $iosched/group_idle_us "0"
    write $iosched/low_latency "0"
done

# Set up untuk ngeloop, disable idle
for loopiosched in /sys/block/*/iosched; do
    write $loopiosched/slice_idle "0"
    write $loopiosched/slice_idle_us "0"
done

# Set up for Stune Boost
write /dev/stune/schedtune.boost "0"
write /dev/stune/schedtune.sched_boost_no_override "0"
write /dev/stune/schedtune.prefer_idle "0"
write /dev/stune/schedtune.colocate "0"
write /dev/stune/cgroup.clone_children "0"

for stune in /dev/stune/*; do
    write $stune/schedtune.boost "0"
    write $stune/schedtune.sched_boost_no_override "0"
    write $stune/schedtune.prefer_idle "0"
    write $stune/schedtune.colocate "0"
    write $stune/cgroup.clone_children "0"
done

# Turunkan Schedtune di latar belakang karena bakalan menghabiskan banyak daya.
write /dev/stune/background/schedtune.prefer_idle "1"

# Foreground
write /dev/stune/foreground/schedtune.boost "1"
write /dev/stune/foreground/schedtune.sched_boost_no_override "1"

# Top app
write /dev/stune/top-app/schedtune.boost "1"
write /dev/stune/top-app/schedtune.sched_boost_no_override "1"

# Off Ramdumps
if [ -d "/sys/module/subsystem_restart/parameters" ]; then
    write /sys/module/subsystem_restart/parameters/enable_ramdumps "0"
    write /sys/module/subsystem_restart/parameters/enable_mini_ramdumps "0"
fi

# Disable logs & debuggers
for exception_trace in $(find /proc/sys/ -name exception-trace); do
    write $exception_trace "0"
done

for sched_schedstats in $(find /proc/sys/ -name sched_schedstats); do
    write $sched_schedstats "0"
done

for printk in $(find /proc/sys/ -name printk); do
    write $printk "0 0 0 0"
done

for printk_devkmsg in $(find /proc/sys/ -name printk_devkmsg); do
    write $printk_devkmsg "off"
done

for compat_log in $(find /proc/sys/ -name compat-log); do
    write $compat_log "0"
done

for tracing_on in $(find /proc/sys/ -name tracing_on); do
    write $tracing_on "0"
done

for log_level in $(find /sys/ -name log_level*); do
    write $log_level "0"
done

for debug_mask in $(find /sys/ -name debug_mask); do
    write $debug_mask "0"
done

for debug_level in $(find /sys/ -name debug_level); do
    write $debug_level "0"
done

for log_ue in $(find /sys/ -name *log_ue*); do
    write $log_ue "0"
done

for log_ce in $(find /sys/ -name *log_ce*); do
    write $log_ce "0"
done

for edac_mc_log in $(find /sys/ -name edac_mc_log*); do
    write $edac_mc_log "0"
done

for enable_event_log in $(find /sys/ -name enable_event_log); do
    write $enable_event_log "0"
done

for log_ecn_error in $(find /sys/ -name log_ecn_error); do
    write $log_ecn_error "0"
done

for sec_log in $(find /sys/ -name sec_log*); do
    write $sec_log "0"
done

for snapshot_crashdumper in $(find /sys/ -name snapshot_crashdumper); do
    write $snapshot_crashdumper "0"
done

# Disable Fsync
write /sys/module/sync/parameters/fsync_enabled "N"

# Disable CRC check
for use_spi_crc in $(find /sys/module -name use_spi_crc); do
    write $use_spi_crc "0"
done

# Exynos hotplug
write /sys/power/cpuhotplug/enabled "0"
write /sys/devices/system/cpu/cpuhotplug/enabled "0"

# Turn off msm_thermal
write /sys/module/msm_thermal/core_control/enabled "0"
write /sys/module/msm_thermal/parameters/enabled "N"
    
# Disable Hotplug
for hotplug in /sys/devices/system/cpu/cpu[0,4,7]/core_ctl; do
    write $hotplug/enable "0"
done


# clear uclamp
for uclamp in /dev/cpuctl/*; do
    write $uclamp/cpu.uclamp.min "0"
    write $uclamp/cpu.uclamp.latency_sensitive "0"
done


# Restart mi_thermald
disable_userspace_thermal() {
    # Respawn
    killall mi_thermald
    # Set max freq untuk cpu_limits
    for all_cores in 0 1 2 3 4 5 6 7; do
        local maxfreq="$(cat /sys/devices/system/cpu/cpu$all_cores/cpufreq/cpuinfo_max_freq)"
        [ "$maxfreq" -gt "0" ] && write /sys/devices/virtual/thermal/thermal_message/cpu_limits "cpu$all_cores $maxfreq"
    done
}

restart_userspace_thermal() {
    # Respawn
    killall mi_thermald
}

# Stop services
su -c stop logd
su -c stop tcpdump
su -c stop cnss_diag
su -c stop statsd
su -c stop traced
su -c stop miuibooster
su -c stop vendor.perfservice

# Better rendering speed
change_task_cgroup "surfaceflinger" "top-app" "cpuset"
change_task_cgroup "surfaceflinger" "foreground" "stune"
change_task_cgroup "android.hardware.graphics.composer" "top-app" "cpuset"
change_task_cgroup "android.hardware.graphics.composer" "foreground" "stune"
change_task_nice "android.hardware.graphics.composer" "-15"
change_task_nice "android.hardware.graphics.composer" "-15"

# Apply settings untuk Memeui (MIUI)
upgrade_miui

# Restart userspace thermal
disable_userspace_thermal
restart_userspace_thermal

# Exit Alhamdullilah stay halal brother
exit 0