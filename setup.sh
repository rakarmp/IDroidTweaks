#!/sbin/sh

SKIPMOUNT=false
PROPFILE=true
POSTFSDATA=false
LATESTARTSERVICE=true

info_print() {
  awk '{print}' "$MODPATH"/idroidtweaks-banner
}
 
 
ui_print "----------------------------------"
ui_print "   █ █▀▄ █▀█ █▀█ █ █▀▄ ▀█▀ █░█░█ █▀▀ ▄▀█ █▄▀ █▀"
ui_print "   █ █▄▀ █▀▄ █▄█ █ █▄▀ ░█░ ▀▄▀▄▀ ██▄ █▀█ █░█ ▄█"
ui_print "----------------------------------"

mf=$(getprop ro.boot.hardware)
soc=$(getprop ro.board.platform)
if [[ $soc == " " ]]; then
soc=$(getprop ro.product.board)
fi
api=$(getprop ro.build.version.sdk)
aarch=$(getprop ro.product.cpu.abi | awk -F- '{print $1}')
androidRelease=$(getprop ro.build.version.release)
dm=$(getprop ro.product.model)
socet=$(getprop ro.soc.model)
device=$(getprop ro.product.vendor.device)
magisk=$(magisk -c)
percentage=$(cat /sys/class/power_supply/battery/capacity)
memTotal=$(free -m | awk '/^Mem:/{print $2}')
rom=$(getprop ro.build.display.id)
romversion=$(getprop ro.vendor.build.version.incremental)
version="1.0"

ui_print ""
ui_print "----------------------------------"
ui_print "   █ INFORMATION DEVICE"
ui_print "----------------------------------"
ui_print "   --> Kernel: `uname -a`"
sleep 0.2
ui_print "   --> Rom: $rom ($romversion)"
sleep 0.2
ui_print "   --> Android Version: $androidRelease"
sleep 0.2
ui_print "   --> Api: $api"
sleep 0.2
ui_print "   --> SOC: $mf, $soc, $socet"
sleep 0.2
ui_print "   --> CPU AArch: $aarch"
sleep 0.2
ui_print "   --> Device: $dm ($device)"
sleep 0.2
ui_print "   --> Battery charge level: $percentage%"
sleep 0.2
ui_print "   --> Device total RAM: $memTotal MB"
sleep 0.2
ui_print "   --> Magisk: $magisk"
sleep 0.2
ui_print " "
ui_print "   --> Version tweaks: $version"
ui_print "----------------------------------"
ui_print ""

sleep 1.25

# INIT 

init_main() {
  $BOOTMODE || abort "[!] IDroidTweaks cannot be installed in recovery, flash to magisk."

  ui_print "----------------------------------"
  ui_print ""
  ui_print "   █ EXTRACT MODULE..."
  ui_print ""
  ui_print "----------------------------------"
  
  unzip -o "$ZIPFILE" 'system/*' -d $MODPATH >&2
  
  ui_print ""
  sleep 1.25

  ui_print "----------------------------------"
  ui_print "   █ DONE"
  ui_print "----------------------------------"
  
  ui_print ""
  sleep 1
  
  SCRIPT_PARENT_PATH="$MODPATH/script"
  SCRIPT_NAME="optimization.sh"
  SCRIPT_PATH="$SCRIPT_PARENT_PATH/$SCRIPT_NAME"

  sleep 1

  ui_print "----------------------------------"
  ui_print "   █ RUNNING FSTRIM"
  ui_print "----------------------------------"
  
  fstrim -v /data
  fstrim -v /system
  fstrim -v /cache

  ui_print "----------------------------------"
  ui_print "   █ DONE"
  ui_print "----------------------------------"

  ui_print ""
  sleep 1.25

  ui_print "----------------------------------"
  ui_print "   █ ATTENTION "
  ui_print "----------------------------------"
  ui_print ""
  ui_print "   ❗ Reboot is required"
  sleep 0.2
  ui_print ""
  ui_print "   ❗ Report issues to @Zyarexx Chat on Telegram"
  ui_print ""
  sleep 1.5

  ui_print "----------------------------------"
  ui_print "   █ REBOOT TO FINISH"
  ui_print "----------------------------------"
}

# Set permissions

set_permissions() {
  set_perm_recursive $MODPATH 0 0 0755 0644
  set_perm_recursive $SCRIPT_PATH root root 0777 0755
  set_perm_recursive $MODPATH/script 0 0 0755 0755
  set_perm_recursive $MODPATH/bin 0 0 0755 0755
  set_perm_recursive $MODPATH/system 0 0 0755 0755
  set_perm_recursive $MODPATH/system/bin 0 0 0755 0755
  set_perm_recursive $MODPATH/system/vendor 0 0 0755 0755
  set_perm_recursive $MODPATH/system/vendor/etc 0 0 0755 0755
}
