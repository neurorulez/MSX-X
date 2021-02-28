#!/bin/bash
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit 1
fi

DEVICE=$1

if [ -z "$DEVICE" ]; then
  echo "Missing device name."
  echo "Ex.:"
  echo "$0 /dev/sdX"
  exit 2
fi

[ -z "$( which sfdisk )" ] && echo "sfdisk not found!" && exit 1
[ -z "$( which mkfs.msdos )" ] && echo "mkfs.msdos not found!" && exit 1
[ -z "$( which mcopy )" ] && echo "mcopy not found!" && exit 1
[ -z "$( which mattrib )" ] && echo "truncate not found!" && exit 1

echo "MSX-X SD Card creator"
echo "====================="
echo

sfdisk -l $DEVICE | grep "Disk"
[ ${?} -ne 0 ] && echo "Device not ready." && exit 9

echo
echo "#########################"
echo "######## WARNING ########"
echo "#########################"
echo
echo "This operation WILL DESTROY ALL DATA on '$DEVICE'"
echo
df -h | grep "$DEVICE"
echo
while true; do
    read -p "Do you wish to continue? [Yes/No] " yn
    case $yn in
        [Yy]* ) break;;
        [Nn]* ) echo "No changes made."; exit 0;;
        * ) echo "Please answer yes or no.";;
    esac
done

#MAXPARTSIZE=1990196736
MAXPARTSIZE=4293918720

umount $DEVICE?
sleep 1

DEVICESIZE=$( sfdisk -l $DEVICE | grep "Disk $DEVICE" | cut -d' ' -f5 )

SIZEB=$DEVICESIZE
[ "$DEVICESIZE" -gt "$MAXPARTSIZE" ] && SIZEB=$MAXPARTSIZE

echo
echo "# Creating partition"
echo

NSECTORS=$( expr $SIZEB / 512 - 1 )
echo 1 $NSECTORS 6 | sfdisk -q --force $DEVICE
sync
sleep 1

echo
echo "## Formatting device"
echo

# CYLINDERS=$( expr $NSECTORS / 16065 )
# mformat -i $DEVICE@@512 -v FAT16MSX -t $CYLINDERS -h 255 -n 63 -H 1 -m 248 ::
mkfs.msdos -F16 -R1 -a -nFAT16MSX "$DEVICE"1
sync
sleep 1

echo "### Copying BIOS file"
echo
mcopy -i $DEVICE@@512 sdbios/OCM-BIOS.DAT ::
mattrib -i $DEVICE@@512 +h ::OCM-BIOS.DAT

echo "#### Copying system files"
echo
mcopy -i $DEVICE@@512 os/MSXDOS2.SYS ::
mcopy -i $DEVICE@@512 os/NEXTOR.SYS ::
mcopy -i $DEVICE@@512 os/COMMAND2.COM ::

mattrib -i $DEVICE@@512 +s ::MSXDOS2.SYS
mattrib -i $DEVICE@@512 +s ::NEXTOR.SYS
mattrib -i $DEVICE@@512 +s ::COMMAND2.COM

mcopy -i $DEVICE@@512 system/* ::

if [ "$( find ./core/ -name "*.np1" )" ]; then
  echo "##### Copying Core files"
  echo
  mcopy -i $DEVICE@@512 core/*.np1 ::
  mattrib -i $DEVICE@@512 +h ::*.np1
fi

sync

echo "Done"
