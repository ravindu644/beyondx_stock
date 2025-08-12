## [Magisk] [nethunter] [This is standalone script, not sourced]
##
## REF: ./nethunter/META-INF/com/google/android/update-recovery:get_bb() & $MAGISKBB
##      ./nethunter/post-fs-data.sh
##      ./nethunter/tools/install-chroot.sh

MODDIR="${0%/*}"
TARGET=$MODDIR/system
BIN=$TARGET/bin

if [ -d /system/xbin ]; then
  XBIN=$TARGET/xbin
else
  XBIN=$TARGET/bin
fi

rm -f $XBIN/busybox_nh
cd $XBIN/
busybox_nh=$( (ls -v busybox_nh-* || ls busybox_nh-*) | tail -n 1 ) # Alt: BB_latest=$( (ls -v busybox_nh-* 2>/dev/null || ls busybox_nh-*) | tail -n 1)
[ -z "$busybox_nh" ] && print "! Failed to find busybox_nh in $XBIN" && return 1
#BB=$XBIN/$busybox_nh # Use NetHunter BusyBox from ./arch/<arch>/tools/ # Alt: export BB=$TMP/$busybox_nh
ln -sf $XBIN/$busybox_nh busybox_nh # Alt: $XBIN/$busybox_nh ln -sf $busybox_nh busybox_nh

## Create symlink for applets
sysbin="$(ls /system/bin)"
existbin="$(ls $BIN 2>/dev/null || true)"
for applet in $($XBIN/busybox_nh --list); do
  case $XBIN in
    */bin)
      if [ "$(echo "$sysbin" | $XBIN/busybox_nh grep "^$applet$")" ]; then
        if [ "$(echo "$existbin" | $XBIN/busybox_nh grep "^$applet$")" ]; then
          $XBIN/busybox_nh ln -sf busybox_nh $applet
        fi
      else
        $XBIN/busybox_nh ln -sf busybox_nh $applet
      fi
      ;;
    *) $XBIN/busybox_nh ln -sf busybox_nh $applet
      ;;
    esac
done

[ -e $XBIN/busybox ] || {
  ln -s $XBIN/busybox_nh $XBIN/busybox # Alt: $XBIN/$busybox_nh ln -sf busybox_nh busybox
}

chmod 755 *
chcon u:object_r:system_file:s0 *
