#!/bin/bash

#######################################################################################################################
#
# 	Sample code for a SMS relay server with gammu
#   Script reads SMS received by gammu daemon and forwards them to another phone number or sends it to an eMail or does some other stuff with the SMS
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
SOURCE_PHONE="+4947114712"
TARGET_PHONE="+4947134714"
MYSELF=${0##*/}
MYNAME=${MYSELF%.*}
EMAIL_TARGET="user@dummy.com"
EMAIL_ADMIN="admin@dummy.com"
SERVER_NAME="SMSRelay"
LOG="/var/log/$MYNAME.log"
NOTIFY_TARGET=1
NOTIFY_ADMIN=2
NOTIFY_BOTH=$(($NOTIFY_TARGET | $NOTIFY_ADMIN))

function send() { # rcv subject message
    #echo "$3" | gammu-smsd-inject TEXT $TARGET_PHONE
    if (($1 & $NOTIFY_TARGET)); then
        echo "--- relay sms to target $EMAIL_TARGET"
        echo "$3" | mail -s "$SERVER_NAME: $2" $EMAIL_TARGET
    fi

    if (($1 & $NOTIFY_ADMIN)); then
        echo "--- relay sms to admin $EMAIL_ADMIN"
        echo "$3" | mail -s "$SERVER_NAME: $2" $EMAIL_ADMIN
    fi
}

function handleSMS() { # number msg

    local number="$1"
    local msg="$2"

    case "$msg" in
        *\*echo*)
            echoMessage="$(cut -f 2- -d ' ' <<< "$msg")"
            echo "--- echo"
            send $NOTIFY_ADMIN "*echo command received" "$echoMessage"
            ;;
        *\*status*)
            echo "--- status"
            send $NOTIFY_ADMIN "*status command received"
            ;;
        *\*help*)
            echo "--- help"
            send $NOTIFY_ADMIN "*help command received" "*echo MESSAGE, *status, *restart, *cancel"
            ;;
        *\*restart*)
            echo "--- restart"
            send $NOTIFY_ADMIN "*restart command received" "SMS relay server will be restarted soon"
            sleep 1m
            systemctl restart gammu-smsd
            ;;
        *\*cancel*)
            echo "--- cancel"
            send $NOTIFY_ADMIN "*cancel command received" "SMS relay server will be stopped soon"
            sleep 1m
            systemctl stop gammu-smsd
            exit 0
            ;;
        *)
            echo "--- default"
            send $NOTIFY_BOTH "SMS received from $number" "$msg"
            ;;
    esac
}

for i in $SMS_MESSAGES; do
    echo "Processing $i: $1"
    number="SMS_${i}_NUMBER"
    echo "SMS_NUMBER: ${!number}"
    text="SMS_${i}_TEXT"
    echo "SMS_TEXT: ${!text}"
    echo "$(date +"%Y%m%d-%H%M%S") SMS '$1' received"
    handleSMS "${!number}" "${!text}"
done
