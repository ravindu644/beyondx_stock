#!/system/bin/sh
## [Magisk] [nethunter] [This is standalone script, not sourced]
## Flash without custom recoveries
##
## CREDITS to HuskyDG
##   REF: https://github.com/Magisk-Modules-Alt-Repo/magic-flash/blob/1b1092d88e1172a86f1470744320718dc6117754/system/bin/magic-flash

#set -x

abort() {
  echo "! $1"
  exit 1
}

prepare_sh() {
  ## Make sure sh exists
  cat "$(command -v busybox)" > "${1}/system/bin/sh"
  chmod 0777 "${1}/system/bin/sh"
  cat /system/build.prop > "${1}/system/build.prop"
}

make_chroot() {
  command -v busybox &>/dev/null || abort "BusyBox not found"
  [ ! -e "$(command -v busybox)" ] && abort "BusyBox missing"

  ## Create suitable environment to flash
  export NEWROOT="/dev/rootfs_$$"

  rm -rf $NEWROOT
  rm -rf /data/adb/sideload
  mkdir $NEWROOT
  mkdir /data/adb/sideload
  chmod 0777 /data/adb/sideload
  chcon u:object_r:system_file:s0 /data/adb/sideload
  mount -t tmpfs tmpfs $NEWROOT || abort "Failed to prepare chroot environment"

  mountpoint -q /vendor && vendor=vendor || ln -sf /system/vendor $NEWROOT/vendor
  mountpoint -q /system_ext && system_ext=system_ext || ln -sf /system/system_ext $NEWROOT/system_ext
  mountpoint -q /product && product=product || ln -sf /system/product $NEWROOT/product

  [ -e $NEWROOT/bin ] || ln -s /system/bin $NEWROOT/bin
  [ -e $NEWROOT/lib ] || ln -s /system/lib $NEWROOT/lib
  [ -e $NEWROOT/lib64 ] || ln -s /system/lib64 $NEWROOT/lib64

  for dir in apex cache data sbin $vendor $system_ext $product sys proc dev sideload sdcard sysblock etc mnt; do
    mkdir -p $NEWROOT/$dir
  done

  mount -t tmpfs tmpfs $NEWROOT/sysblock

  if [ "$NOSYSTEM" == 1 ]; then
    echo "NOSYSTEM: Ignored mount system partition!"
  fi

  ## Access to magisk bin
  MAGISKTMP="$(magisk --path)"
  if [ ! -z "$MAGISKTMP" ]; then
    touch "$NEWROOT/sbin"/{magisk,magiskpolicy}
    mount --bind "$MAGISKTMP/magisk" "$NEWROOT/sbin/magisk"
    mount --bind "$MAGISKTMP/magiskpolicy" "$NEWROOT/sbin/magiskpolicy"
    ln -s "./magisk" "$NEWROOT/sbin/su"
    ln -s "./magisk" "$NEWROOT/sbin/resetprop"
    ln -s "./magisk" "$NEWROOT/sbin/magiskhide"
    ln -s "./magiskpolicy" "$NEWROOT/sbin/supolicy"
  fi

  sysroot_major_minor="$(mountpoint -d /)"
  sysroot_major="${sysroot_major_minor%:*}"
  sysroot_minor="${sysroot_major_minor: ${#sysroot_major}+1}"
  if [ "$sysroot_major" != "0" ]; then
    echo "Device is system-as-root"
    mknod -m 666 "$NEWROOT/sysblock/system_root" b "$sysroot_major" "$sysroot_minor"
    echo "/sysblock/system_root /system_root ext4 ro 0 0" >> "$NEWROOT/etc/fstab"
    mkdir -p "$NEWROOT/system_root/system/bin"
    ln -sf "system_root/system" "$NEWROOT/system"
    prepare_sh "$NEWROOT"
    if [ "$NOSYSTEM" != 1 ]; then
      mount -o ro "$NEWROOT/sysblock/system_root" "$NEWROOT/system_root"
    fi
  else
    system_major_minor="$(mountpoint -d /system)"
    system_major="${system_major_minor%:*}"
    system_minor="${system_major_minor: ${#system_major}+1}"
    mkdir -p "$NEWROOT/system/bin"
    prepare_sh "$NEWROOT"
    mknod -m 666 "$NEWROOT/sysblock/system" b "$system_major" "$system_minor"
    echo "/sysblock/system /system ext4 ro 0 0" >> "$NEWROOT/etc/fstab"
    if [ "$NOSYSTEM" != 1 ]; then
      mount -o ro "$NEWROOT/sysblock/system" "$NEWROOT/system"
    fi
  fi
  mkdir -p "$NEWROOT/mnt/vendor/persist"
  ln -fs mnt/vendor/persist "$NEWROOT/persist"

  for ext_part in /cache /mnt/vendor/persist /metadata; do
    dev_mount="$(mount -t ext4 | grep " $ext_part " | tail -1 | awk '{ print $1 }')"
    if [ ! -z "$dev_mount" ]; then
      mount -t ext4 "$dev_mount" "$NEWROOT/$ext_part"
      echo "$dev_mount $ext_part ext4 rw 0 0" >> "$NEWROOT/etc/fstab"
    fi
  done

  echo "proc /proc proc default 0 0
sysfs /sys sysfs default 0 0
/system/apex /apex ext4 bind 0 0" >> "$NEWROOT/etc/fstab"

  for systemfs in /vendor /product /system_ext; do
    if mountpoint -q $systemfs; then
      if [ "$NOSYSTEM" != 1 ]; then
        mount --bind $systemfs $NEWROOT/$systemfs
      fi
      system_major_minor="$(mountpoint -d $systemfs)"
      system_major="${system_major_minor%:*}"
      system_minor="${system_major_minor: ${#system_major}+1}"
      mknod -m 666 "$NEWROOT/sysblock/$systemfs" b "$system_major" "$system_minor"
      echo "/sysblock$systemfs $systemfs ext4 ro 0 0" >> "$NEWROOT/etc/fstab"
    fi
  done

  mount --bind /system/apex "$NEWROOT/apex"
  mount --bind /dev "$NEWROOT/dev"
  mount --bind /data "$NEWROOT/data"
  mount --bind /data/adb/sideload "$NEWROOT/sideload"
  mount --bind /sdcard "$NEWROOT/sdcard"
  mount -t sysfs sysfs "$NEWROOT/sys"
  mount -t proc proc "$NEWROOT/proc"

  ## SELinux stuff
  if [ "$SELINUX" == 1 ]; then
    mount -t selinuxfs selinuxfs "$NEWROOT/sys/fs/selinux"
  else
    mount -t tmpfs selinuxfs "$NEWROOT/sys/fs/selinux"
    echo -n "0" > "$NEWROOT/sys/fs/selinux/enforce"
    echo -n > "$NEWROOT/sys/fs/selinux/policy"
  fi

  if [ "${MAGISKTMP%/*}" == "/dev" ]; then
    mount -t tmpfs tmpfs "$NEWROOT/$MAGISKTMP"
    ln -fs "/proc/$$/root/$MAGISKTMP/.magisk" "$NEWROOT/$MAGISKTMP/.magisk"
  fi
  ln -fs "/proc/$$/root/$MAGISKTMP/.magisk" "$NEWROOT/sbin/.magisk"

  if [ "$NOSYSTEM" != 1 ]; then
    if [ "$SYSTEM_MODE" == "ro" ]; then
      echo "SYSTEM_MODE: read-only"
      for systemfs in /system_root /system /vendor /product /system_ext; do
        mountpoint -q $NEWROOT/$systemfs && { mount -o ro,remount $NEWROOT/$systemfs || echo "! Can't remount $systemfs as read-only"; }
      done
      echo "Mounted all system partitions as read-only"
    elif [ "$SYSTEM_MODE" == "rw" ]; then
      echo "SYSTEM_MODE: read-write"
      for systemfs in /system_root /system /vendor /product /system_ext; do
        mountpoint -q $NEWROOT/$systemfs && { mount -o rw,remount $NEWROOT/$systemfs || echo "! Can't remount $systemfs as read-write"; }
      done
    fi
  fi

  cp "$(command -v busybox)" $NEWROOT/sbin/busybox

  ## Install BusyBox into path
  $NEWROOT/sbin/busybox --install $NEWROOT/sbin

  export TMPDIR=/tmp
  mkdir $NEWROOT/tmp
  mount -t tmpfs tmpfs $NEWROOT/tmp
}

vmshell() {
  make_chroot
  exec 2>&1
  unshare -m $NEWROOT/sbin/busybox chroot $NEWROOT /sbin/sh
  umount -l $NEWROOT
  rm -rf $NEWROOT
}

flash() {
  make_chroot
  for zip in "$@"; do
    ( flash_process "$zip"; )
  done

  ## Clean environment
  umount -l $NEWROOT
  rm -rf $NEWROOT
  rm -rf /data/adb/sideload
}

flash_process() {
  ZIP="$1"
  [ "$DEBUG" == 1 ] && { set -x; exec 2>&1; } && echo "DEBUG: is on"
  [ "$ZIP" == "flash" ] && unset ZIP
  test -z "$ZIP" && abort "Please provide a zip"

  ZIP_NAME="$(basename "$ZIP")"
  rm -rf "$NEWROOT/sideload/$ZIP_NAME"
  cp "$ZIP" "$NEWROOT/sideload/$ZIP_NAME"
  ZIP="$NEWROOT/sideload/$ZIP_NAME"
  ZIP_CHROOT="/sideload/$ZIP_NAME"

  unzip -o "$ZIP" "META-INF/com/google/android/update-binary" -d "$NEWROOT/sbin" || print "! Failed to extract"
  mv "$NEWROOT/sbin/META-INF/com/google/android/update-binary" "$NEWROOT/sbin/update-binary"

  echo "Flashing \"$ZIP_NAME\""
  chmod +x "$NEWROOT/sbin/update-binary"

  unshare -m $NEWROOT/sbin/busybox chroot $NEWROOT "/sbin/update-binary" 3 1 "$ZIP_CHROOT"
  ret=$?

  echo "Flashing exists with code $ret"
  exit $ret    # We are using sh, not source
}

TMP=$( cd $(dirname $0)/../; pwd )
if [ ! -f ${TMP}/tools/busybox ]; then
  echo "Creating: ${TMP}/tools/busybox"
  ln -sf $( ls -1 ${TMP}/tools/busybox* | head -n 1 ) ${TMP}/tools/busybox   # See: ./update-recovery:get_bb()
fi
export PATH=/sbin:/data/adb/modules/magic-flash/busybox:/system/bin:/system/xbin:${TMP}/tools/   # Alt: $XBIN
#exec 2>/dev/null   # Not sure of the value this brings?

#export DEBUG=1
VALUE="$1"

case $(basename "$0") in
  vmshell)
    if [ "$VALUE" == "vmshell" ]; then
      exec "$@";
    else
      test "$(id -u)" == 0 || abort "Root user only"
      unshare -m sh "$0" vmshell "$@";
    fi
    ;;
  *)
    if [ "$VALUE" == "flash" ]; then
      exec "$@";
    elif [ -n "$1" ]; then
      test "$(id -u)" == 0 || abort "Root user only"
      unshare -m sh "$0" flash "$@"
    else
      echo "Flash any recovery zip without using Custom Recovery"
      echo "Flashing will be processed in isolated chroot environment"
      echo "Multiple flashing at same time are allowed"
      echo "Make sure the current environment is clean"
      echo "usage: $(basename "$0") ZIP"
      echo "       $(basename "$0") ZIP1 ZIP2..."
      echo "Environment variable flag:"
      echo "   NOSYSTEM=1 - Ignore mount system partition in chroot"
      echo "   SYSTEM_MODE=ro - Remount all system partitions as read-only"
      echo "   SYSTEM_MODE=rw - Remount all system partitions as read-write"
      echo "   DEBUG=1 - Show all error dialogs"
    fi
    ;;
esac
