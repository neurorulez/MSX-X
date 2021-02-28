MSX-X SD CREATE v1.1
====================

This tool allows you to easily create your SD-Card.

WARNING: USE THIS TOOL AT YOUR OWN RISK AND PROCEED WITH EXTREME CAUTION!
-------------------------------------------------------------------------

Before starting, you can add your Core inside the directory `./core` to be copied
during the process.

Also, the core can be copied to SD-Card after the process finalize.

## Windows

Any target size lower or higher than 4GB are automatically managed by DiskPart of Windows.
No other external tool is needed to go!

Tested with Microsoft Windows 10.0.15063 64-bit.

1. Insert the SD-Card into the card reader.
2. Run the "sdcreate.cmd" script as Administrator.
3. Enter the target drive letter and a label name.
4. Press a key to finalize the process.

All done!

## Linux

1. Insert the SD-Card into the card reader.
2. Identify your SD-Card device. Ex: `lsblk | grep /media`
3. Run the "sdcreate.sh" script with "sudo".

Ex: `sudo ./sdcreate.sh /dev/sdX`

Where "/dev/sdX" is your SD Card without partition number (Ex.: /dev/sdb)

4. Press a key to finalize the process.

All done!
