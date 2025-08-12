## [Magisk & recovery/TWRP] [boot-patcher & nethunter] [This is sourced, not a standalone script]
## Install NetHunter's BusyBox
##
## REF: ./nethunter/META-INF/com/google/android/update-recovery:get_bb() & $MAGISKBB
##      ./nethunter/post-fs-data.sh
##      ./nethunter/tools/install-chroot.sh

ls $TMP/tools/busybox_nh-* 1>/dev/null 2>&1 || {
  print "  ! No NetHunter BusyBox found - skipping"
  return 1
}

if $BOOTIMAGE; then
  ## util_functions.sh to get grep_prop() working
  ##   boot-patcher doesn't (yet?) support Magisk, but Magisk's file should be there due to nethunter pre-extracting/setting up
  source /data/adb/magisk/util_functions.sh || print "  ! Issue with util_functions.sh"

  [ -z $TMPDIR ] && TMPDIR=/dev/tmp

  MODID=$(grep_prop id $TMPDIR/module.prop)

  ## Define modules target dirs
  if [ -e /data/adb/modules ]; then
    MNT=/data/adb/modules_update
    MAGISK=/$MODID/system
  fi

  TARGET=$MNT$MAGISK
  if [ -d /system/xbin ]; then
    XBIN=$TARGET/xbin
  else
    XBIN=$TARGET/bin
  fi
else
  [ -z $XBIN ] && XBIN=/system/xbin
fi
[ -d $XBIN ] || mkdir -p $XBIN

print "  - Installing NetHunter BusyBox"
cd "$TMP/tools/"
for bb in busybox_nh-*; do
  print "  - Installing $bb"
  rm -f $XBIN/$bb
  cp -f $bb $XBIN/$bb
  chmod 0755 $XBIN/$bb
done
cd - >/dev/null

if ! [ $BOOTMODE ]; then
  rm -f $XBIN/busybox_nh
  cd $XBIN/
  busybox_nh=$( (ls -v busybox_nh-* || ls busybox_nh-*) | tail -n 1 ) # Alt: BB_latest=$( (ls -v busybox_nh-* 2>/dev/null || ls busybox_nh-*) | tail -n 1)
  [ -z "$busybox_nh" ] && print "  ! Failed to find busybox_nh in $XBIN" && return 1
  #BB=$XBIN/$busybox_nh # Use NetHunter BusyBox from ./arch/<arch>/tools/ # Alt: export BB=$TMP/$busybox_nh
  print "  - Setting $busybox_nh as default"
  ln -sf $XBIN/$busybox_nh busybox_nh # Alt: $XBIN/$busybox_nh ln -sf $busybox_nh busybox_nh
  $XBIN/busybox_nh --install -s $XBIN

  ## Create symlink for applets
  print "  - Creating symlinks for BusyBox applets"
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
    print "  - $XBIN/busybox not found! Symlinking"
    ln -s $XBIN/busybox_nh $XBIN/busybox # Alt: $XBIN/$busybox_nh ln -sf busybox_nh busybox
  }

  cd - >/dev/null
fi

## Magisk, not recovery/TWRP
set_perm_recursive >/dev/null 2>&1 && {
  set_perm_recursive "$XBIN" 0 0 0755 0755
}

print "  - BusyBox successfully installed"
