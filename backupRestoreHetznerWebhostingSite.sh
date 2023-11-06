#/bin/bash
#
#######################################################################################################################
#
# 	 Create a local backup of a Webhosting website from a Hetzner and
#	 restore the backup to a restore test website on a Webhosting website from Hetzner
#
#	===> NOTE: Script is still under construction
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

VERBOSE=""
CLONE=0						# create a local website and db backup and restore website and db"
BASKUPS=3

while getopts ':bchv' opt; do
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

function cleanup() {
	if mount | grep -q "^$REMOTE_MP"; then
		echo "umount $REMOTE_MP"
		sudo umount $REMOTE_MP
	fi
	if (( failure )); then
		echo "Deleting incomplete backup dir $DIRNAME$NO"
		sudo rm -rf $DIRNAME$NO
	else
		find . -name "$DIRNAME*" -type d | sort | head -n -MAXBACKUPS | xargs -I {} rm -rf "{}"
	fi
}

# create new backup dir
if [[ ! -d $DIRNAME$NO ]]; then
	mkdir $DIRNAME$NO
	(( $? )) && ( echo "Error creating directory $DIRNAME$NO"; exit )
fi
trap "cleanup" SIGINT SIGTERM EXIT

echo "Dumping DB"
time mysqldump -p $DB_BACKUPSOURCE_DBNAME -u $DB_BACKUPSOURCE_USERID -p$DB_BACKUPSOURCE_PASSWORD -h $DB_BACKUPSOURCE_SERVER --default-character-set=utf8mb4 > $DIRNAME$NO/$DB_BACKUPSOURCE_DBNAME_backup.sql
(( failure=failure || $? )) && exit 1

if (( $CLONE )); then

	sudo mount $REMOTE_MP
	(( $? )) && ( echo "Error mounting REMOTE_MP"; exit )

	echo "rsync remote website from $REMOTE_MP/$FS_BACKUP to $DIRNAME$NO"
	time sudo rsync -a $VERBOSE --delete --exclude cache/* $LINKDEST $REMOTE_MP/$FS_BACKUP $DIRNAME$NO
	(( failure=failure || $? )) && exit 1

	echo "Restoring DB"
	time mysql -p $DB_RESTORESOURCE_DBNAME -u $DB_RESTORESOURCE_USERID -p$DB_RESTORESOURCE_PASSWORD -h $DB_RESTORESOURCE_SERVER < $DIRNAME$NO/$DB_BACKUPSOURCE_DBNAME_backup.sql
	(( failure=failure || $? )) && exit 1

	if [[ ! -d $REMOTE_MP/$FS_RESTORE ]]; then
		mkdir $REMOTE_MP/$FS_RESTORE
		(( $? )) && ( echo "Error creating directory $REMOTE_MP/$FS_RESTORE"; exit )
	fi

	echo "rsync local website from $DIRNAME$NO to $FS_RESTORE"
	time sudo rsync -a $VERBOSE --delete $DIRNAME$NO/ $REMOTE_MP/$FS_RESTORE
	(( failure=failure || $? )) && exit 1

	echo "Backup created, db import tested and website cloned"
else
	echo "Backup created and db import tested"
fi
