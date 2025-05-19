#!/bin/bash
#
# POC to verify it's possible to remove a disk from a RAID5 and not to force a RAID rebuild with a Raspberry
#
# Setup: Three devices with 3 partitions. md0 and md1 use partitions 1 and 2 as a RAID1. Partition3 is used in a RAID5.
#
# Steps:
# 1) Create the RAIDs
# 2) Create files in the RAIDs
# 3) Deactivate the RAID5
# ... remove disk /dev/sda ... and insert it again
# 4) Add the removed disk again to all RAIDs
# ... The two RAID1s are rebuilt because they were active when the disk was removed. The RAID5 is active immediately without any rebuild
#
# POC created by framp@linux-tips-and-tricks.de

case $1 in

createRaid|1)

	echo "*** Removing mdadm config"
	rm /etc/mdadm/mdadm.conf

	echo
	echo "*** Umounting RAIDs"

	umount /dev/md0
	umount /dev/md1
	umount /dev/md2

	echo
	echo "*** Wipe RAID partition"

	umount /dev/md0; sudo wipefs --all --force /dev/md0 
	umount /dev/md1; sudo wipefs --all --force /dev/md1 
	umount /dev/md2; sudo wipefs --all --force /dev/md2

	echo
	echo "*** Stopping RAIDs"

	mdadm --stop /dev/md0
	mdadm --stop /dev/md1
	mdadm --stop /dev/md2

	echo
	echo "*** Wipe partitions"

	umount /dev/sda?; sudo wipefs --all --force /dev/sda?; sudo wipefs --all --force /dev/sda
	umount /dev/sdb?; sudo wipefs --all --force /dev/sdb?; sudo wipefs --all --force /dev/sdb
	umount /dev/sdc?; sudo wipefs --all --force /dev/sdc?; sudo wipefs --all --force /dev/sdc

	echo
	echo "*** Zero superblock"
	mdadm --zero-superblock /dev/sda1 /dev/sdb1 /dev/sdc1 /dev/sda2 /dev/sdb2 /dev/sdc2 /dev/sda3 /dev/sdb3 /dev/sdc3

	echo
	echo "*** Allocate partitions"

	sgdisk -n 0:0:+1GiB -t 0:8300 -c 0:dsm /dev/sda
	sgdisk -n 0:0:+1GiB -t 0:8300 -c 0:swap /dev/sda
	sgdisk -n 0:0:+1GiB -t 0:8300 -c 0:sp /dev/sda
	sgdisk -n 0:0:+1GiB -t 0:8300 -c 0:dsm /dev/sdb
	sgdisk -n 0:0:+1GiB -t 0:8300 -c 0:swap /dev/sdb
	sgdisk -n 0:0:+1GiB -t 0:8300 -c 0:sp /dev/sdb
	sgdisk -n 0:0:+1GiB -t 0:8300 -c 0:dsm /dev/sdc
	sgdisk -n 0:0:+1GiB -t 0:8300 -c 0:swap /dev/sdc
	sgdisk -n 0:0:+1GiB -t 0:8300 -c 0:sp /dev/sdc

	echo
	echo "*** Creating RAIDs"

	yes | mdadm --create --verbose /dev/md0 --level=1 --raid-devices=3 /dev/sd[a-c]1
	yes | mdadm --create --verbose /dev/md1 --level=1 --raid-devices=3 /dev/sd[a-c]2
	yes | mdadm --create --verbose /dev/md2 --level=5 --raid-devices=3 /dev/sd[a-c]3

	echo
	echo "*** Formating RAID"

	yes | mkfs.ext4 -m 0 -E lazy_itable_init=0,lazy_journal_init=0 /dev/md0
	yes | mkfs.ext4 -m 0 -E lazy_itable_init=0,lazy_journal_init=0 /dev/md1
	yes | mkfs.ext4 -m 0 -E lazy_itable_init=0,lazy_journal_init=0 /dev/md2

	cat /proc/mdstat
	exit
	;;

createFiles|2)

	echo
	echo "*** Persisting mdadm config"
	mdadm --detail --scan --verbose | sudo tee -a /etc/mdadm/mdadm.conf

	echo
	echo "*** Creating mount points"
	mkdir /mnt/md0
	mkdir /mnt/md1
	mkdir /mnt/md2

	echo
	echo "*** Mounting RAIDs"

	mount /dev/md0 /mnt/md0
	mount /dev/md1 /mnt/md1
	mount /dev/md2 /mnt/md2

	echo
	echo "*** Creating files"

	echo "DSM" > /mnt/md0/DSM
	echo "SWAP" > /mnt/md1/SWAP
	echo "SP" > /mnt/md2/SP
	ls /mnt/md*
	exit
	;;

deactivateSP|3)

	echo
	echo "*** Deactivate /dev/md2"
	umount /dev/md2
	mdadm --stop /dev/md2
	cat /proc/mdstat
	exit
	;;

readdDevice|4)
	
	echo 
	echo "*** Readd missing device"
	mdadm --manage /dev/md0 -a /dev/sda1
	mdadm --manage /dev/md1 -a /dev/sda2
	mdadm --manage /dev/md2 -a /dev/sda3
	mdadm --assemble /dev/md2
	mdadm --readwrite /dev/md2
	ls /mnt/md*
	cat /proc/mdstat
	exit
	;;

*) echo "Available commands"
	echo "createRaid|1"
	echo "createFiles|2"
	echo "deactivateSP|3"
	echo "readdDevice|4"
	exit
	;;
esac

