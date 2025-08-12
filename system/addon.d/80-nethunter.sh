#!/sbin/sh
#
# ADDOND_VERSION=2
#
# /system/addon.d/80-nethunter.sh
# During a system upgrade, this script backs up NetHunterStore client and privext,
# /system is formatted and reinstalled, then the files are restored.
#

. /tmp/backuptool.functions

list_files() {
cat <<EOF
app/NetHunterStore.apk
app/NetHunterStore/NetHunterStore.apk
app/NetHunter/NetHunter.apk
app/NetHunter-Terminal/NetHunterTerminal.apk
etc/permissions/permissions_com.offsec.nethunter.store.privileged.xml
priv-app/NetHunterStorePrivilegedExtension.apk
priv-app/NetHunterStorePrivilegedExtension/NetHunterStorePrivilegedExtension.apk
EOF
}

case "$1" in
  backup)
    list_files | while read FILE DUMMY; do
      backup_file $S/"$FILE"
    done
  ;;
  restore)
    list_files | while read FILE REPLACEMENT; do
      R=""
      [ -n "$REPLACEMENT" ] && R="$S/$REPLACEMENT"
      [ -f "$C/$S/$FILE" ] && restore_file $S/"$FILE" "$R"
    done
  ;;
  pre-backup)
    # Stub
  ;;
  post-backup)
    # Stub
  ;;
  pre-restore)
    # Stub
  ;;
  post-restore)
    # Stub
  ;;
esac

