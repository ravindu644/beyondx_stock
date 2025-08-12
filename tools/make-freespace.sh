## [Recovery/TWRP] [nethunter] [This is sourced, not a standalone script]
## Move safe apps from system to data partition to free up space for installation

## Free space we require on /system (in Megabytes)
SpaceRequired=20

MoveableApps="
QuickOffice
CloudPrint2
YouTube
PlusOne
PlayGames
Drive
Music2
Maps
Magazines
Newsstand
Currents
Photos
Books
Street
Hangouts
KoreanIME
GoogleHindiIME
GooglePinyinIME
iWnnIME
Keep
FaceLock
Wallet
HoloSpiralWallpaper
BasicDreams
PhaseBeam
LiveWallpapersPicker
"

IFS="
"
SYSTEM_APP=$SYSTEM/app
DATA_APP=/data/app
AndroidV=$(grep 'ro.build.version.release=' ${SYSTEM}/build.prop | cut -d'=' -f2) # Alt: ro.build.version.release_or_codename

## TWRP's df from /sbin doesn't has -m flag so we use BusyBox instead and use df from it
FreeSpace=$($BB df -m $SYSTEM | tail -n 1 | tr -s ' ' | cut -d' ' -f4)

if [ -z $FreeSpace ]; then
  print "  ! Warning: Could not get free space status. Skipping"
elif [ "$FreeSpace" -gt "$SpaceRequired" ]; then
  ## We have enough space! Return/exit
  print "  - $SYSTEM free space: $FreeSpace MB"
else
  print "  - You don't have enough free space on ${SYSTEM}: $FreeSpace MB"
  print "  - Trying to free up some space"

  if [ "$AndroidV" -gt "7" ]; then
    print "  - Android Version: Android $AndroidV"
    print "  - Starting from Android 8 'Oreo', we can't move apps from /system to /data"
    print "  ! Aborting installation"
    return 1
  else
    for app in $MoveableApps; do
      if [ "$FreeSpace" -gt "$SpaceRequired" ]; then
        break
      fi

      if [ -d "$SYSTEM_APP/$app/" ]; then
        if [ -d "$DATA_APP/$app/" ] || [ -f "$DATA_APP/$app.apk" ]; then
          print "  -- Removing $SYSTEM_APP/$app/ (extra)"
          rm -rf "$SYSTEM_APP/$app/"
        else
          print "  -- Moving $app/ to $DATA_APP"
          mv "$SYSTEM_APP/$app/" "$DATA_APP/"
        fi
      fi

      if [ -f "$SYSTEM_APP/$app.apk" ]; then
        if [ -d "$DATA_APP/$app/" ] || [ -f "$DATA_APP/$app.apk" ]; then
          print "  -- Removing $SYSTEM_APP/$app.apk (extra)"
          rm -f "$SYSTEM_APP/$app.apk"
        else
          print "  -- Moving $app.apk to $DATA_APP"
          mv "$SYSTEM_APP/$app.apk" "$DATA_APP/"
        fi
      fi
    done

    print "  - Free space (after): $FreeSpace MB"

    if [ ! "$FreeSpace" -gt "$SpaceRequired" ]; then
      print "  ! Unable to free up $SpaceRequired MB of space on '$SYSTEM'!"
      return 1
    fi
  fi
fi

print "  - Freespace done"
