#!/bin/bash

ext4=(
	"format(\"ext4\", \"EMMC\", \"/dev/block/platform/msm_sdcc.1/by-name/system\", \"0\", \"/system\");"
	"mount(\"ext4\", \"EMMC\", \"/dev/block/platform/msm_sdcc.1/by-name/system\", \"/system\");"
	)
f2fs=(
	"run_program(\"/sbin/mkfs.f2fs\", \"/dev/block/platform/msm_sdcc.1/by-name/system\");"
	"run_program(\"/sbin/busybox\", \"mount\", \"/system\");"
	)

echo "doing checks..."
[[ ! -f "tools/signapk.jar" ]] && echo "signapk not found" && exit 1
[[ ! -f "tools/7za" ]] && echo "7za not found" && exit 1
[[ ! -f "tools/md5sum" ]] && echo "md5sum not found" && exit 1
[[ ! -f "$1" ]] && echo "no such file $1" && exit 1

P7ZIP="./tools/7za"
SIGNAPK="java -jar ./tools/signapk.jar ./tools/testkey.x509.pem ./tools/testkey.pk8"
MD5SUM="./tools/md5sum"

WORKINGDIR="$(mktemp -d)"
FILEIN="$1"
FILENAME="$(basename $FILEIN)"
EXTENSION="${FILENAME##*.}"
FILENAME="${FILENAME%.*}"
BASEDIR="$(dirname $FILEIN)"
FILESIGNED="$FILENAME-f2fsall-signed.$EXTENSION"

echo "removing old files which may interfere..."
[[ -f "$FILESIGNED" ]] && rm "$FILESIGNED"
[[ -f "$FILESIGNED.md5" ]] && rm "$FILESIGNED.md5"

echo "unzipping..."
sh -c "$P7ZIP x -y -o$WORKINGDIR $FILEIN META-INF/com/google/android/updater-script > /dev/null"

echo "changing commands..."
sed -i -e "s#${ext4[0]}#${f2fs[0]}#" "$WORKINGDIR/META-INF/com/google/android/updater-script"
sed -i -e "s#${ext4[1]}#${f2fs[1]}#" "$WORKINGDIR/META-INF/com/google/android/updater-script"

echo "updating..."
sh -c "cp $FILEIN $WORKINGDIR/$FILESIGNED"
sh -c "$P7ZIP u -r -m0 $WORKINGDIR/$FILESIGNED $WORKINGDIR/META-INF > /dev/null"

echo "signing..."
sh -c "$SIGNAPK $WORKINGDIR/$FILESIGNED $BASEDIR/$FILESIGNED"

echo "final touches..."
sh -c "$MD5SUM $BASEDIR/$FILESIGNED > $BASEDIR/$FILESIGNED.md5"

echo "cleaning up the mess..."
rm -rf "$WORKINGDIR"

echo "all done! your files are in: $BASEDIR"
