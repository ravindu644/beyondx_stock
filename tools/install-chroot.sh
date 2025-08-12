## [Magisk & recovery/TWRP] [nethunter] [This is sourced, not a standalone script]
## Install Kali chroot/rootfs

## Magisk support via do_umount()
do_umount() {
  f_is_mntpoint
  res=$?
  case $res in
    1) f_dir_umount;;
    *) return 0;;
  esac

  if [ -z "$(cat /proc/mounts | grep $PRECHROOT)" ]; then
    print "  - Umount all done"
    isAllunmounted=0
  else
    print "  - There are still mounted points not unmounted yet"
    isAllunmounted=1
  fi

  return $isAllunmounted
}

## Magisk support via do_umount()
f_is_mntpoint() {
  if [ -d "$PRECHROOT" ]; then
    mountpoint -q "$PRECHROOT" && return 0
    return 1
  fi
}

## Magisk support via do_umount()
f_dir_umount() {
  sync

  print "  - Killing all running pids"
  f_kill_pids
  f_restore_setup

  print "  - Removing all fs mounts"
  for i in "dev/pts" "dev/shm" dev proc sys system; do
    f_umount_fs "$i"
  done

  ## Don't force unmount SDcard
  ##   In some devices, it wipes the internal storage
  if mount | grep -q "$PRECHROOT/sdcard"; then
    if umount -l $PRECHROOT/sdcard; then
        if ! rm -rf $PRECHROOT/sdcard; then
        isAllunmounted=1
      fi
    fi
  fi
}

## Magisk support via do_umount()
f_kill_pids() {
  local lsof_full=$(lsof | awk '{print $1}' | grep -c '^lsof')

  if [ "$lsof_full" -eq 0 ]; then
    local pids=$(lsof | grep "$PRECHROOT" | awk '{print $1}' | uniq)
  else
    local pids=$(lsof | grep "$PRECHROOT" | awk '{print $2}' | uniq)
  fi

  if [ -n "$pids" ]; then
    kill -9 $pids 2>/dev/null
    return $?
  fi

  return 0
}

## Magisk support via do_umount()
f_umount_fs() {
  isAllunmounted=0

  if mountpoint -q $PRECHROOT/$1; then
    if umount -f $PRECHROOT/$1; then
      if [ ! "$1" = "dev/pts" -a ! "$1" = "dev/shm" ]; then
        if ! rm -rf $PRECHROOT/$1; then
          isAllunmounted=1
        fi
      fi
    else
      isAllunmounted=1
    fi
  else
    if [ -d $PRECHROOT/$1 ]; then
      if ! rm -rf $PRECHROOT/$1; then
        isAllunmounted=1
      fi
    fi
  fi
}

## Magisk support via do_umount()
f_restore_setup() {
  ## Set shmmax to 128mb to free memory
  sysctl -w kernel.shmmax=134217728 1>&2

  ## Remove all the remaining chroot vnc session pid and log files
  rm -rf $PRECHROOT/tmp/.X11* $PRECHROOT/tmp/.X*-lock $PRECHROOT/root/.vnc/*.pid $PRECHROOT/root/.vnc/*.log >/dev/null 2>&1
}

verify_fs() {
  ## Valid architecture?
  case $FS_ARCH in
    armhf|arm64|i386|amd64);;
    *) return 1;;
  esac

  ## Valid build size?
  case $FS_SIZE in
    full|minimal|nano);;
    *) return 1;;
  esac

  return 0
}

## do_install [optional zip containing kalifs chroot/rootfs]
do_install() {
  print "  - Found Kali chroot to be installed: $KALIFS"

  mkdir -p "$NHSYS"

  ## HACK 1/2: Rename to kali-(arm64,armhf,amd64,i386) as NetHunter app supports searching these directory after first boot
  CHROOT="$NHSYS/kali-$FS_ARCH" # Legacy rootfs directory prior to 2020.1
  ROOTFS="$NHSYS/kalifs"        # New symlink allowing to swap chroots via NetHunter app on the fly
  PRECHROOT=$($BB find /data/local/nhsystem -type d -name "kali-*" | head -n 1)  # Generic previous chroot location

  ## Remove previous chroot
  [ -d "$PRECHROOT" ] && {
    print "  - Previous chroot detected"
    if $BOOTMODE; then
      do_umount # Magisk support
      [ $? == 1 ] && {
        print "  ! Error: Aborting chroot install"
        print "  - Remove the previous chroot and install the new chroot via NetHunter app"
        return 1
      }
    fi

    print "  - Removing previous chroot"
    rm -rf "$PRECHROOT"
    rm -f "$ROOTFS"
  }

  ## Extract new chroot
  print "  - Extracting Kali rootfs (This may take up to 25 minutes)"
  if [ "$1" ]; then
    unzip -p "$1" "$KALIFS" | $BB tar -xJf - -C "$NHSYS" --exclude "kali-$FS_ARCH/dev" || print "  ! Failed to extract"
  else
    $BB tar -xJf "$KALIFS" -C "$NHSYS" --exclude "kali-$FS_ARCH/dev" || print "  ! Failed to extract"
  fi

  [ $? = 0 ] || {
    print "  ! Error: Kali $FS_ARCH $FS_SIZE chroot failed to install!"
    print "  - Maybe you ran out of space on your data partition?"
    return 1
  }

  ## HACK 2/2: Create a link to be used by apps effective 2020.1
  ##           Rename to kali-(arm64,armhf,amd64,i386) based on $FS_ARCH for legacy reasons and create a link to be used by apps effective 2020.1
  [ "$NHSYS/kali-$FS_ARCH" != "$CHROOT" ] && mv "$NHSYS/kali-$FS_ARCH" "$CHROOT"
  ln -sf "$CHROOT" "$ROOTFS"

  mkdir -p -m 0755 "$CHROOT/dev"
  print "  - Kali $FS_ARCH $FS_SIZE chroot installed successfully!"

  ## We should remove the rootfs archive to free up device memory or storage space (if not zip install)
  if [ -z "$1" ]; then
    print "  - Cleaning up old chroot/rootfs ($KALIFS)"
    rm -f "$KALIFS"
  fi
}

#------------------------------------------------------------------------------

## Chroot common path
NHSYS=/data/local/nhsystem

## Check inside zip for kalifs-*-*.tar.xz first
[ -f "$ZIPFILE" ] && {
  KALIFS=$(unzip -lqq "$ZIPFILE" | awk '$4 ~ /^kalifs-/ { print $4; exit }')

  ## If zip contains a chroot/rootfs (kalifs-*-*.tar.xz)
  if [ -n "$KALIFS" ]; then
    FS_SIZE=$(echo "$KALIFS" | awk -F[-.] '{print $2}')
    FS_ARCH=$(echo "$KALIFS" | awk -F[-.] '{print $3}')
    ## Return if we have installed something - winning (Quitting while we're ahead!)
    verify_fs && do_install "$ZIPFILE" && return
  fi
}

## Zip doesn't container chroot/rootfs, so going check other locations (in priority order)   # Recovery/TWRP
for fsdir in "$TMP" "/data/local" "/sdcard" "/external_sd"; do
  ## Check for: kalifs-[size]-[arch].tar.xz
  for KALIFS in "$fsdir"/kalifs-*-*.tar.xz; do
    [ -s "$KALIFS" ] || continue
    FS_SIZE=$(basename "$KALIFS" | awk -F[-.] '{print $2}')
    FS_ARCH=$(basename "$KALIFS" | awk -F[-.] '{print $3}')
    verify_fs && do_install && return
  done

  ## Check for legacy filename: kalifs-[size].tar.xz
  for KALIFS in "$fsdir"/kalifs-*.tar.xz; do
    [ -f "$KALIFS" ] || continue
    FS_ARCH=armhf
    FS_SIZE=$(basename "$KALIFS" | awk -F[-.] '{print $2}')
    verify_fs && do_install && return
  done
done

print "  - No Kali rootfs archive found. Skipping"
