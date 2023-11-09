#!/bin/bash
#
#######################################################################################################################
#
# 	 Create a local backup of a Webhosting website and restore the backup to a restore test website 
#
#	Steps:
#	1) Create mysqldump of database
#	2) Restore mysqldump in regression database
#	3) Download website files
#	4) Upload website files into regression directory
#
#	Prerequisites:
#	1) Website directory and mysqlDB
#	2) Restortest Website directoy and restore mysqlDB
#
#	Number of backups is configurable
#
#	Just use this code as a template for your website
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

CONFIGURATION_FILE="configuration.php"

# defaults
VERBOSE=""

CLONE=0						# create a local website and db backup and restore website and db"
MAXBACKUPS=3
REMOTE_WAS_MOUNTED=0		# don't umount remote website if it's already mounted
TIMING=""

function isMounted() { # dir
	grep -qs "$1" /proc/mounts
	return
}

function writeToConsole() {
	echo "===> $@"
}

# calculate time difference, return array with days, hours, minutes and seconds
function duration() { # startTime endTime
	factors=(86400 3600 60 1)
	local diff=$(( $2 - $1 ))
	local d i q
	i=0
	for f in "${factors[@]}"; do
		q=$(( diff / f ))
		diff=$(( diff - q * f ))
		d[i]=$(printf "%02d" $q)
		((i++))
	done
	echo "${d[@]}"
}

# return current time
function timerStart() {
	local START_TIME=$(date +%s)
	echo "$START_TIME"
}

# calculate time difference with passed time and return readable time difference as hh:mm:ss
function timerEnd() { # starttime
	local END_TIME=$(date +%s)
	local BACKUP_TIME=($(duration $1 $END_TIME))
	echo "${BACKUP_TIME[1]}:${BACKUP_TIME[2]}:${BACKUP_TIME[3]}"
}

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
      echo "Usage: $(basename $0) [-b <backups>] [-c] [-v]"
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

if (( $UID != 0 )); then
	writeToConsole "Call script as root or with sudo"
	exit 1
fi

if [[ -e ./$MYNAME.conf ]]; then
	source ./$MYNAME.conf						# use config file for following config variables
else 											# hard code config variables
	# Backup directory
	BACKUP_DIR="~"
	# Local backupdirname of website files, don't use _ in dirname
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
	# restore URL
	BACKUP_URL="https://restore.test.de"
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
DIRNAME="${DIRNAME}_"			# add backup sequence number separator

LASTNO=$(find $BACKUP_DIR -name "$DIRNAME*" -type d | sort -t _ -k 2 -n | tail -n 1 | sed "s@.*$BACKUP_DIR/$DIRNAME@@")

# create next backup dir
if [[ -n $LASTNO ]]; then
	NO=$((LASTNO+1))
	LINKNO=$((NO-1))
	if [[ -d $BACKUP_DIR/$DIRNAME$LINKNO ]]; then
		LINKDEST="--link-dest=$BACKUP_DIR/$DIRNAME$LINKNO"
		writeToConsole "Using $BACKUP_DIR/$DIRNAME$LINKNO for hardlinks"
	fi
else
	NO=$INITIAL_NO
fi

function cleanup() {
	if (( ! REMOTE_WAS_MOUNTED )); then
		if mount | grep -q "^$REMOTE_MP"; then
			writeToConsole "umount $REMOTE_MP"
			umount $REMOTE_MP
		fi
	fi
	if (( failure )); then
		writeToConsole "Deleting incomplete backup dir $BACKUP_DIR/$DIRNAME$NO"
		rm -rf $BACKUP_DIR/$DIRNAME$NO
	else
		writeToConsole "Deleting old backups and keep $MAXBACKUPS backups"
		find $BACKUP_DIR -name "$DIRNAME*" -type d | sort -t _ -k 2 -n | head -n -$MAXBACKUPS | xargs -I {} rm -rf "{}"
	fi
}

# create new backup dir
if [[ ! -d $BACKUP_DIR/$DIRNAME$NO ]]; then
	writeToConsole "Creating $BACKUP_DIR/$DIRNAME$NO"
	mkdir $BACKUP_DIR/$DIRNAME$NO
	(( $? )) && ( echo "Error creating directory $BACKUP_DIR/$DIRNAME$NO"; exit )
fi
trap "cleanup" SIGINT SIGTERM EXIT

START_TIME=$(timerStart)

RUN_TIME=$(timerStart)
writeToConsole "Dumping DB $DB_BACKUPSOURCE_DBNAME to $BACKUP_DIR/$DIRNAME$NO"
mysqldump -p $DB_BACKUPSOURCE_DBNAME -u $DB_BACKUPSOURCE_USERID -p$DB_BACKUPSOURCE_PASSWORD -h $DB_BACKUPSOURCE_SERVER --default-character-set=utf8mb4 > $BACKUP_DIR/$DIRNAME$NO/$DB_BACKUPSOURCE_DBNAME.sql
(( failure=failure || $? )) && ( writeToConsole "DB dump of $DB_BACKUPSOURCE_DBNAME failed"; exit )
RUN_TIME="$(timerEnd $RUN_TIME)"
writeToConsole "DB Dumptime: $RUN_TIME"

RUN_TIME=$(timerStart)
writeToConsole "Restoring DB $DB_RESTORESOURCE_DBNAME from $BACKUP_DIR/$DIRNAME$NO"
mysql -p $DB_RESTORESOURCE_DBNAME -u $DB_RESTORESOURCE_USERID -p$DB_RESTORESOURCE_PASSWORD -h $DB_RESTORESOURCE_SERVER < $BACKUP_DIR/$DIRNAME$NO/$DB_BACKUPSOURCE_DBNAME.sql
(( failure=failure || $? )) && ( writeToConsole "Restor of DB dump to $DB_RESTORESOURCE_DBNAME failed"; exit )
RUN_TIME="$(timerEnd $RUN_TIME)"
writeToConsole "DB importtime: $RUN_TIME"

if (( $CLONE )); then

	if ! isMounted $REMOTE_MP; then
		mount $REMOTE_MP
	else
		REMOTE_WAS_MOUNTED=1
	fi
	(( $? )) && ( writeToConsole "Error mounting REMOTE_MP"; exit )

	RUN_TIME=$(timerStart)
	writeToConsole "rsync remote website from $REMOTE_MP/$FS_BACKUP to $BACKUP_DIR/$DIRNAME$NO"
	rsync -a $VERBOSE --delete --exclude cache/* $LINKDEST $REMOTE_MP/$FS_BACKUP/ $BACKUP_DIR/$DIRNAME$NO/
	(( failure=failure || $? )) && exit 1
	RUN_TIME="$(timerEnd $RUN_TIME)"
	writeToConsole "Website download time: $RUN_TIME"

	if [[ ! -d $REMOTE_MP/$FS_RESTORE ]]; then
		mkdir $REMOTE_MP/$FS_RESTORE
		(( $? )) && ( writeToConsole "Error creating directory $REMOTE_MP/$FS_RESTORE"; exit )
	fi

	RUN_TIME=$(timerStart)
	writeToConsole "rsync local website from $BACKUP_DIR/$DIRNAME$NO to $FS_RESTORE"
	rsync -a $VERBOSE --delete --exclude $DB_BACKUPSOURCE_DBNAME.sql $BACKUP_DIR/$DIRNAME$NO/ $REMOTE_MP/$FS_RESTORE
	(( failure=failure || $? )) && exit 1
	RUN_TIME="$(timerEnd $RUN_TIME)"
	writeToConsole "Website upload time: $RUN_TIME"

	RUN_TIME=$(timerStart)
	writeToConsole "Updating $CONFIGURATION_FILE"
	sed -i "s/public \$host =.*;/public \$host = '$DB_RESTORESOURCE_SERVER';/" $REMOTE_MP/$FS_RESTORE/$CONFIGURATION_FILE
	(( failure=failure || $? )) && ( writeToConsole "Error updating host"; exit 1 )
	sed -i "s/public \$user =.*;/public \$user = $DB_RESTORESOURCE_USERID;/" $REMOTE_MP/$FS_RESTORE/$CONFIGURATION_FILE
	(( failure=failure || $? )) && ( writeToConsole "Error updating user"; exit 1 )
	sed -i "s/public \$password =.*;/public \$password = $DB_RESTORESOURCE_PASSWORD;/" $REMOTE_MP/$FS_RESTORE/$CONFIGURATION_FILE
	(( failure=failure || $? )) && ( writeToConsole "Error updating password"; exit 1 )
	sed -i "s/public \$db =.*;/public \$db = $DB_RESTORESOURCE_DBNAME;/" $REMOTE_MP/$FS_RESTORE/$CONFIGURATION_FILE
	(( failure=failure || $? )) && ( writeToConsole "Error updating db"; exit 1 )
	sed -i "s@public \$live_site =.*;@public \$live_site = '$BACKUP_URL';@" $REMOTE_MP/$FS_RESTORE/$CONFIGURATION_FILE
	(( failure=failure || $? )) && ( writeToConsole "Error updating live_site"; exit 1 )
	RUN_TIME="$(timerEnd $RUN_TIME)"
	writeToConsole "Website config update time: $RUN_TIME"

	writeToConsole "Backup created, db import tested and website cloned"
else
	writeToConsole "Backup created and db import tested"
fi

BACKUP_TIME="$(timerEnd $START_TIME)"
writeToConsole "BackupRestoreTestTime: $BACKUP_TIME"
