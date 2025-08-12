## [Magisk & recovery/TWRP] [nethunter] [This is sourced, not a standalone script]
## Set the wallpaper based on device screen resolution

[ -d "$TMP/wallpaper" ] || return 1

## Define wallpaper variables
wp=/data/system/users/0/wallpaper
wpinfo=${wp}_info.xml
non_res_wallpaper=$TMP/wallpaper/non-resolution.png
magick_a64=$TMP/tools/imagemagick/arm64/magick
magick_a32=$TMP/tools/imagemagick/armhf/magick
magick_a864=$TMP/tools/imagemagick/amd64/magick
magick_a86=$TMP/tools/imagemagick/i386/magick

## Check if non-resolution.png exists
[ ! -f "$non_res_wallpaper" ] && {
  print "  ! non-resolution.png not found! Skipping"
  return 1
}

## Try to grab resolution using wm size (Method #1)
res=$(wm size | grep "Physical size:" | cut -d' ' -f3 2>/dev/null)

## Check if we grabbed resolution from wm or not
[ -z "$res" ] && {
  echo "  Method #1: Couldn't get resolution using wm size. Trying next method..." >&2

  ## Try to grab the wallpaper height and width from /sys / sysfs (Method #2)
  res="$(cat /sys/class/drm/*/modes | head -n 1)"
}

## Check if we grabbed resolution from /sys / sysfs or not
[ -z "$res" ] && [ -f $TMP/tools/screenres ] && {
  echo "  Method #2: Couldn't get resolution from /sys. Trying old method..." >&2

  ## Try the old method for old devices (Method #3)
  res=$($TMP/tools/screenres)

  ([ -z "$res" ] || [[ "$res" == *"failed"* ]]) && unset res
}

## Give up if resolution is still not found
[ -z "$res" ] && {
  print "  ! Can't get screen resolution of device! Skipping"
  return 1
}

## Try to grab DPI using wm density (Method #1)
dpi=$(wm density | grep "Physical density:" | cut -d' ' -f3 2>/dev/null)

## Check if we grabbed DPI from wm or not
[ -z "$dpi" ] && {
  echo "  Couldn't get DPI using wm density. Falling back to default DPI of 240" >&2
  dpi=240 # Default DPI
}

#------------------------------------------------------------------------------

print "  - Found screen resolution: $res"
res_w=$(echo "$res" | cut -f1 -dx)
res_h=$(echo "$res" | cut -f2 -dx)

# Determine device architecture
arch=$(uname -m)
if [ "$arch" == "aarch64" ]; then
  print "  - Detected architecture: ARM64"
  magick_binary="$magick_a64"
  export MAGICK_HOME=$TMP/tools/imagemagick
  export LD_LIBRARY_PATH="$MAGICK_HOME/arm64"
elif [ "$arch" == "armv7l" ] || [ "$arch" == "arm" ]; then
  print "  - Detected architecture: ARM32"
  magick_binary="$magick_a32"
  export MAGICK_HOME=$TMP/tools/imagemagick
  export LD_LIBRARY_PATH="$MAGICK_HOME/armhf"
elif [ "$arch" == "x86_64" ]; then
  print "  - Detected architecture: x86_64"
  magick_binary="$magick_a864"
  export MAGICK_HOME=$TMP/tools/imagemagick
  export LD_LIBRARY_PATH="$MAGICK_HOME/amd64"
elif [ "$arch" == "i686" ] || [ "$arch" == "i386" ]; then
  print "  - Detected architecture: x86"
  magick_binary="$magick_a86"
  export MAGICK_HOME=$TMP/tools/imagemagick
  export LD_LIBRARY_PATH="$MAGICK_HOME/i386"
else
  print "  ! Unsupported architecture: $arch. Skipping"
  return 1
fi

## Ensure ImageMagick binary exists before execution
[ ! -f "$magick_binary" ] && {
  print "  ! ImageMagick binary not found for architecture $arch. Skipping"
  return 1
}

## Extract image dimensions using convert
image_info=$($magick_binary "$non_res_wallpaper" -print "%wx%h\n" /dev/null 2>/dev/null)
image_w=$(echo "$image_info" | cut -d'x' -f1)
image_h=$(echo "$image_info" | cut -d'x' -f2)

## Compare extracted dimensions with the target resolution
if [ "$image_w" == "$res_w" ] && [ "$image_h" == "$res_h" ]; then
  print "  - Image already matches target resolution. Skipping resize."
  resized_wallpaper="$non_res_wallpaper"
else
  ## Create resolution-specific wallpaper from non-resolution.png
  resized_wallpaper=$TMP/wallpaper/$res.png
  print "  - Resizing non-resolution.png to $res..."
  $magick_binary "$non_res_wallpaper" -resize "${res_w}x${res_h}^" -gravity center -extent "${res_w}x${res_h}" -units pixelsperinch -density "$dpi" "$resized_wallpaper" >/dev/null 2>&1

  # Check if the resizing failed
  if [ ! -f "$resized_wallpaper" ]; then
    print "  ! Failed to resize wallpaper. Skipping"
    return 1
  fi
fi

## Set the wallpaper directly
cat "$resized_wallpaper" > "$wp"

cat <<EOF > "$wpinfo"
<?xml version='1.0' encoding='utf-8' standalone='yes' ?>
<wp width="$res_w" height="$res_h" name="nethunter.png" />
EOF

chown system:system "$wp" "$wpinfo"
chmod 0600 "$wp" "$wpinfo"
chcon "u:object_r:wallpaper_file:s0" "$wp"
chcon "u:object_r:system_data_file:s0" "$wpinfo"

print "  - NetHunter wallpaper applied successfully"
