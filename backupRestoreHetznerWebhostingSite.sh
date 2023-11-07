#/bin/bash
#
#######################################################################################################################
#
# 	 Create a local backup of a Webhosting website from a Hetzner and
#	 restore the backup to a restore test website on a Webhosting website from Hetzner
#
#	===> NOTE: Script is still under construction
#
#	Steps:
#	1) Create mysqldump of database
#	2) restore mysqldump in regression database
#	3) Download website files
#	4) Upload website files into regression directory
#
#	Number of backups is configurable
#
#######################################################################################################################
#
#    Copyright (c) 2023 framp at linux-tips-and-tricks dot de
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#######################################################################################################################

MYSELF="$(basename "$(test -L "$0" && readlink "$0" || echo "$0")")"
MYNAME=${MYSELF%.*}

# defaults
VERBOSE=""

CLONE=0						# create a local website and db backup and restore website and db"
MAXBACKUPS=3				
REMOTE_WAS_MOUNTED=0		# dont umount remote website if it's already mounted
TIMING=""

while getopts ':bchtv' opt; do
  case "$opt" in

	 b)
      BACKUPS="$OPTARG"
      if (( $BACKUPS < 1 || $BACKUPS >= 10 )); then
			echo "Invalid number of backups specified: $BACKUPS"
			exit 1
      fi
      ;;

    c)
		CLONE=1
      ;;

	t)
		TIMING="time"
		;;

    v)
      VERBOSE="-v"
      ;;

    ?|h)
      echo "Usage: $(basename $0) [-c] [-v]"
      exit 1
      ;;

	:)
      echo "Option requires an argument."
      exit 1
      ;;

    ?)
      echo "Invalid command option."
      exit 1
      ;;
  esac
done
shift "$(($OPTIND -1 ))"

if [[ -e ./$MYNAME.conf ]]; then
	source ./$MYNAME.conf
else
	# Local backupdirname of website files
	DIRNAME="myBackups"
	# Mountpoint of Website
	REMOTE_MP="/remote/hetzner"
	# Path to website in mountpoint
	FS_BACKUP="myWebsite"
	# Path to restore website in mountpoint
	FS_RESTORE="myWebsiteRestore"
	# DBname userid password server
	DB_BACKUPSOURCE=(dbname uid pwd srv)
	DB_RESTORESOURCE=(dbname uid pwd srv)
	# maximum of backups to keep
	MAXBACKUPS="3"
fi

DB_BACKUPSOURCE_NAMES=(DB_BACKUPSOURCE_DBNAME DB_BACKUPSOURCE_USERID DB_BACKUPSOURCE_PASSWORD DB_BACKUPSOURCE_SERVER)
DB_RESTORESOURCE_NAMES=(DB_RESTORESOURCE_DBNAME DB_RESTORESOURCE_USERID DB_RESTORESOURCE_PASSWORD DB_RESTORESOURCE_SERVER)

# initialize DB config vars
for ((i=0; i<${#DB_BACKUPSOURCE_NAMES[@]}; i++)); do
	eval ${DB_BACKUPSOURCE_NAMES[$i]}=${DB_BACKUPSOURCE[$i]}
done

for ((i=0; i<${#DB_RESTORESOURCE_NAMES[@]}; i++)); do
	eval ${DB_RESTORESOURCE_NAMES[$i]}=${DB_RESTORESOURCE[$i]}
done

failure=0
INITIAL_NO=0

LASTNO=$(find . -name "$DIRNAME*" -type d | sort | tail -n 1 | sed "s/.*$DIRNAME//")

# create next backup dir
if [[ -n $LASTNO ]]; then
	NO=$((LASTNO+1))
	LINKNO=$((NO-1))
	LINKDEST="--link-dest=../$DIRNAME$LINKNO"
else
	NO=$INITIAL_NO
fi

function isMounted() { # dir
	grep -qs "$1" /proc/mounts
	return
}

function writeToConsole() {
	echo "===> $@"
}

function cleanup() {
	if (( ! REMOTE_WAS_MOUNTED )); then
		if mount | grep -q "^$REMOTE_MP"; then
			writeToConsole "umount $REMOTE_MP"
			sudo umount $REMOTE_MP
		fi
	fi
	if (( failure )); then
		writeToConsole "Deleting incomplete backup dir $DIRNAME$NO"
		sudo rm -rf $DIRNAME$NO
	else
		sudo find . -name "$DIRNAME*" -type d | sort | head -n -$MAXBACKUPS | xargs -I {} sudo rm -rf "{}"
	fi
}

# create new backup dir
if [[ ! -d $DIRNAME$NO ]]; then
	writeToConsole "Creating $DIRNAME$NO"
	mkdir $DIRNAME$NO
	(( $? )) && ( echo "Error creating directory $DIRNAME$NO"; exit )
fi
trap "cleanup" SIGINT SIGTERM EXIT

writeToConsole "Dumping DB $DB_BACKUPSOURCE_DBNAME"
$TIMING mysqldump -p $DB_BACKUPSOURCE_DBNAME -u $DB_BACKUPSOURCE_USERID -p$DB_BACKUPSOURCE_PASSWORD -h $DB_BACKUPSOURCE_SERVER --default-character-set=utf8mb4 > $DIRNAME$NO/$DB_BACKUPSOURCE_DBNAME.sql
(( failure=failure || $? )) && exit 1

writeToConsole "Restoring DB $DB_RESTORESOURCE_DBNAME"
$TIMING mysql -p $DB_RESTORESOURCE_DBNAME -u $DB_RESTORESOURCE_USERID -p$DB_RESTORESOURCE_PASSWORD -h $DB_RESTORESOURCE_SERVER < $DIRNAME$NO/$DB_BACKUPSOURCE_DBNAME.sql
(( failure=failure || $? )) && exit 1

if (( $CLONE )); then

	if ! isMounted $REMOTE_MP; then
		sudo mount $REMOTE_MP
	else
		REMOTE_WAS_MOUNTED=1
	fi
	(( $? )) && ( writeToConsole "Error mounting REMOTE_MP"; exit )

	writeToConsole "rsync remote website from $REMOTE_MP/$FS_BACKUP to $DIRNAME$NO"
	$TIMING sudo rsync -a $VERBOSE --delete --exclude cache/* $LINKDEST $REMOTE_MP/$FS_BACKUP/ $DIRNAME$NO/
	(( failure=failure || $? )) && exit 1

	if [[ ! -d $REMOTE_MP/$FS_RESTORE ]]; then
		mkdir $REMOTE_MP/$FS_RESTORE
		(( $? )) && ( writeToConsole "Error creating directory $REMOTE_MP/$FS_RESTORE"; exit )
	fi

	writeToConsole "rsync local website from $DIRNAME$NO to $FS_RESTORE"
	$TIMING sudo rsync -a $VERBOSE --delete --exclude $DB_BACKUPSOURCE_DBNAME.sql $DIRNAME$NO/ $REMOTE_MP/$FS_RESTORE
	(( failure=failure || ( $? && ($? != 23)) )) && exit 1

	writeToConsole "Backup created, db import tested and website cloned"
else
	writeToConsole "Backup created and db import tested"
fi
