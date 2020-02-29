#!/bin/bash

#######################################################################################################################
#
# 	  Listen for SMS and forward them via eMail, can also be used to receive SMS for phone number A and forward the SMS to telephone number B
#
# 	  Required tools: gammu-smsd, eMail client
#
#	  Setup:
#    1) Install and configure gammu-smsd to use an existing USB phone stick, e.g. ZTE ML190
#	  2 Add following line in /etc/gammu-smsdrc
# 	    runonreceive = /usr/local/sbin/relaySMS.sh
# 	  3) Copy script into /usr/local/sbin and make it executable
#
#######################################################################################################################
#
#    Copyright (C) 2020 framp at linux-tips-and-tricks dot de
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
SOURCE_PHONE="+49471147114711"	# source phone number listened for SMS
TARGET_PHONE="+49471247124712"	# target phone number if SMS should be forwarded to another SMS phone number
MYSELF=${0##*/}
MYNAME=${MYSELF%.*}
EMAIL_TARGET="smsrelay@dummy.com"	# eMail which receives the forwarded SMS
EMAIL_ADMIN="admin@dummy.com"			# admin eMail which receives server status change eMails
SERVER_NAME="SMSRelay"
LOG="/var/log/$MYNAME.log"
NOTIFY_TARGET=1
NOTIFY_ADMIN=2
NOTIFY_BOTH=$(( $NOTIFY_TARGET | $NOTIFY_ADMIN ))

# send SMS to eMails or other SMS phone number

function send() { # rcv subject message
	#echo "$3" | gammu-smsd-inject TEXT $TARGET_PHONE
	if (( $1 & $NOTIFY_TARGET )); then
		echo "--- notify target"	
	      	echo "$3" | mail -s "$SERVER_NAME: $2" $EMAIL_TARGET 
	fi

	if (( $1 & $NOTIFY_ADMIN )); then
		echo "--- notify admin"	
	      	echo "$3" | mail -s "$SERVER_NAME: $2" $EMAIL_ADMIN
	fi
}

# parse SMS and initiate different actions

function handleSMS() { # number msg

	local number="$1"
	local msg="$2"

	case "$msg" in
		\*echo*)					# command *echo: just echo the received text to admin email
			echoMessage="$(cut -f 2- -d ' ' <<< "$msg")"
		       	echo "--- echo"	
			send $NOTIFY_ADMIN "*echo command received" "$echoMessage"
			;;	
		\*status*)				# command *status: just send alive email to admin email
		       	echo "--- status"	
			send $NOTIFY_ADMIN "*status command received"
			;;
		\*|\*help*)				# command *help: just send help text to admin eMail
		       	echo "--- help"	
			send $NOTIFY_ADMIN "*help command received" "*echo MESSAGE, *status, *cancel"
			;;	
		\*cancel*)				# command *cancel: cancel gammu-smsd. Just in case there is some unrecoverable loop
		       	echo "--- cancel"	
		 	send $NOTIFY_ADMIN "*cancel command received" "SMS relay server will be stopped soon" 
			sleep 1m
			systemctl stop gammu-smsd
			exit 0
			;;
	 	*) 						# forward received SMS
		       	echo "--- *"	
	  		send $NOTIFY_BOTH "SMS received from $number" "$msg" 
			;;
	esac
 }

# read all received messages and process them

for i in $SMS_MESSAGES; do
	echo "Processing $i: $1"
        number="SMS_${i}_NUMBER"	
	echo "SMS_NUMBER: ${!number}"
        text="SMS_${i}_TEXT"	
	echo "SMS_TEXT: ${!text}"
	echo "$(date +"%Y%m%d-%H%M%S") SMS '$1' received"
	handleSMS "${!number}" "${!text}" 
done

