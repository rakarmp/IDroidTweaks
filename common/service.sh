#!/system/bin/sh

MODDIR=${0%/*}

# Menerapkan tweaks setelah boot
wait_until_boot_complete() {
  while [[ "$(getprop sys.boot_completed)" != "1" ]]; do
    sleep 3
  done
}

wait_until_boot_complete

script_dir="$MODDIR/script"

# Memastikan init sudah selesai
sleep 10

# Menerapkan tweaks dibawab liat😴
sh $script_dir/optimization.sh

# Exit Alhamdullilah Stay Halal Brother
exit 0