#!/bin/bash

METADATA_FILE="ramdisk_metadata.txt"

if [ ! -f "$METADATA_FILE" ]; then
    echo "Metadata file not found: $METADATA_FILE"
    exit 1
fi

echo "Restoring ownership and permissions from $METADATA_FILE..."

while read uid gid perms path; do
    if [ -e "$path" ]; then
        echo "$path → chown $uid:$gid && chmod $perms"
        chown "$uid:$gid" "$path"
        chmod "$perms" "$path"
    else
        echo "Skipping missing file: $path"
    fi
done < "$METADATA_FILE"

chcon -R u:object_r:vendor_configs_file:s0 ramdisk/overlay.d/vendor && echo "Restore complete!"
