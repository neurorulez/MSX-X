#!/bin/bash
IMGSIZE=$1

if [ -z "$IMGSIZE" ]; then
  echo "Missing image size (in MB)."
  echo "Ex.:"
  echo "$0 256"
  exit 2
fi

IMGFILE=SD_SM-X.img

[ -z "$( which sfdisk )" ] && echo "sfdisk not found!" && exit 1
[ -z "$( which mkfs.msdos )" ] && echo "mkfs.msdos not found!" && exit 1
[ -z "$( which mcopy )" ] && echo "mcopy not found!" && exit 1
[ -z "$( which mattrib )" ] && echo "truncate not found!" && exit 1

echo "MSX-X Image creator"
echo "==================="
echo

SIZEB=$(( $IMGSIZE * 1024 * 1024 ))

echo
echo "# Creating image file"
echo

truncate --size=$SIZEB $IMGFILE

echo
echo "# Creating partition"
echo

NSECTORS=$( expr $SIZEB / 512 - 1 )
echo 1 $NSECTORS 6 | sfdisk -q --force $IMGFILE
sync
sleep 1

echo
echo "## Formatting image"
echo

CYLINDERS=$( expr $NSECTORS / 16065 )
mformat -i $IMGFILE@@512 -v FAT16MSX -t $CYLINDERS -h 255 -n 63 -H 1 -m 248 ::
sleep 1

echo "### Copying BIOS file"
echo
mcopy -i $IMGFILE@@512 sdbios/OCM-BIOS.DAT ::
mattrib -i $IMGFILE@@512 +h ::OCM-BIOS.DAT

echo "#### Copying system files"
echo
mcopy -i $IMGFILE@@512 os/MSXDOS2.SYS ::
mcopy -i $IMGFILE@@512 os/NEXTOR.SYS ::
mcopy -i $IMGFILE@@512 os/COMMAND2.COM ::

mattrib -i $IMGFILE@@512 +s ::MSXDOS2.SYS
mattrib -i $IMGFILE@@512 +s ::NEXTOR.SYS
mattrib -i $IMGFILE@@512 +s ::COMMAND2.COM

mcopy -i $IMGFILE@@512 system/* ::

if [ "$( find ./core/ -name "*.np1" )" ]; then
  echo "##### Copying Core files"
  echo
  mcopy -i $IMGFILE@@512 core/*.np1 ::
  mattrib -i $IMGFILE@@512 +h ::*.np1
fi

sync

echo "Done"
