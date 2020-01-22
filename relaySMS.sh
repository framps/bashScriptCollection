#!/bin/bash
#######################################################################################################################
#
# 	Sample code for a SMS relay server with gammu
#   Script listens for SMS received and forwards them to another phone number or sends it to an eMail or does some other stuff with the SMS
#
#	This script is referred by https://www.linux-tips-and-tricks.de/en/raspberry/559-use-zte-ml190-usb-pen-drive-to-create-a-sms-relay-server
#	which explains in detail how to create and manage the SMS relay server
#
#######################################################################################################################
#
#    Copyright (c) 2020 framp at linux-tips-and-tricks dot de
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

GAMMU_INPUT_DIR="/var/spool/gammu/inbox"
SOURCE_PHONE="+4917147114711"
TARGET_PHONE="+4917147124712"
MYSELF=${0##*/}
MYNAME=${MYSELF%.*}
EMAIL_TARGET="smsrelay@dummy.com"
EMAIL_ADMIN="admin@dummy.com"
SERVER_NAME="SMSRelay"
LOG="/var/log/$MYNAME.log"
NOTIFY_TARGET=1
NOTIFY_ADMIN=2
NOTIFY_BOTH=$(( $NOTIFY_TARGET | $NOTIFY_ADMIN ))

function send() { # rcv subject message
	#echo "$3" | gammu-smsd-inject TEXT $TARGET_PHONE
	(( $1 & $NOTIFY_TARGET )) && echo "$3" | mail -s "$2" $EMAIL_TARGET
	(( $1 & $NOTIFY_ADMIN )) && echo "$3" | mail -s "$2" $EMAIL_ADMIN
}

function handleSMS() { # file msg

	local file="$1"
	local msg="$2"

	case "$msg" in
		\*echo)	echoMessage="$(cut -f 2- -d ' ' <<< "$msg")"
			send $NOTIFY_ADMIN "$SERVER_NAME: *echo" "$echoMessage"
			;;
		\*|\*status)
			send $NOTIFY_ADMIN "$SERVER_NAME: *status"
			;;
		\*help)
			send $NOTIFY_ADMIN "$SERVER_NAME: *help" "*echo, *status, *cancel"
			;;
		\*cancel)
		 	send $NOTIFY_ADMIN "$SERVER_NAME: *cancel" "SMS relay server will be stopped soon"
			sleep 1m
			systemctl stop gammu-smsd
			exit 0
			;;
	 	*)
			src_phone_number="$(cut -d _ -f 4 <<< "$file")"
	  		send $NOTIFY_BOTH "SMS received from $src_phone_number" "$msg"
			;;
	esac
 }

case $1 in

	start)	n=$(pgrep -c $MYSELF)
		if (( $n != 1 )); then
			echo "$MYSELF already active"
			exit 0
		fi
		send $NOTIFY_ADMIN "$SERVER_NAME: *start" "Starting $SERVER_NAME for $SOURCE_PHONE"
		$MYSELF execute >> $LOG &
		;;
	stop)	n=$(pgrep -c $MYSELF)
		if (( $n  == 1 )); then
			echo "$MYSELF already inactive"
			exit 0
		fi
		send $NOTIFY_ADMIN "$SERVER_NAME: *stop" "Stopping $SERVER_NAME for $SOURCE_PHONE"
		killall $MYSELF
		;;

	execute) send $NOTIFY_ADMIN "$SERVER_NAME: Listening for $SOURCE_PHONE..."
		inotifywait -m $GAMMU_INPUT_DIR -e create | while read path action file; do
			echo "$(date +"%Y%m%d-%H%M%S") The file '$file' appeared in directory '$path' via '$action'"
 	  		msg=$(<$path/$file)
 	  		echo "SMS contents: $msg"
	  		handleSMS "$file" "$msg"
      		done
      		;;
	*)	echo "Unknown $MYNAME command"
		exit 0
		;;
esac
