## $ adb push *nethunter*.zip /sdcard/Download/nh.zip; adb shell 'su -c magisk --install-module /sdcard/Download/nh.zip'

TMPDIR=/dev/tmp
mkdir -p $TMPDIR
cd $TMPDIR/

## If your using CLI, more of a chance you want to be more verbose!
DEBUG=1

echo "* Unpacking nethunter script"
unzip -o "$ZIPFILE" META-INF/com/google/android/update-binary -d $TMPDIR || print "! Failed to extract"

echo "* Running nethunter script"
[ -f $TMPDIR/META-INF/com/google/android/update-binary ] && source $TMPDIR/META-INF/com/google/android/update-binary 2>&1   # Don't spawn a new session (aka using sh), do in current session (able to pass variables/functions)
