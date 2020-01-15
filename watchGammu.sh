#!/bin/bash
#######################################################################################################################
#
# 	Sample code for a SMS relay server with gammu
#   Script listens for SMS received and forwards them to another phone number or sends it to an eMail or does some other stuff with the SMS
#
#	This script is referred by https://www.linux-tips-and-tricks.de/en/raspberry/559-use-zte-ml190-usb-pen-drive-to-create-a-sms-relay-server
#	which explains in detail how to create a SMS relay server
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

GAMMU_INPUT_DIR="/var/spool/gammu/inbox" # directory gammu stores the received SMS
SOURCE_PHONE="+4917147124712"	# phone number of SMS receiver
TARGET_PHONE="+4917147114711"	# phone number of SMS relay target
EMAIL="smsrelay@mydomain.de"	# email the SMS should be relayed to

MYSELF=${0##*/}
MYNAME=${MYSELF%.*}

if [[ $1 == "start" ]]; then	# start sms relay
        $MYSELF >> /var/log/$MYNAME.log &

elif [[ $1 == "stop" ]]; then	# stop sms relay
        killall $MYSELF

else	# process sms
        inotifywait -m $GAMMU_INPUT_DIR -e create | while read path action file; do
          echo "The file '$file' appeared in directory '$path' via '$action'"
          msg="$(<$path/$file)"
          if [[ ${msg^^} == "STOP" ]]; then
                echo "SMS relay server will be stopped soon" | gammu-smsd-inject TEXT $TARGET_PHONE
                sleep 1m
                systemctl stop gammu-smsd
                exit 0
          fi
          src_phone_number="$(cut -d _ -f 4 <<< "$file")"	# source phone number of SMS

          echo "$src_phone_number $msg" | gammu-smsd-inject TEXT $TARGET_PHONE	# relay received SMS
          cat $path/$file | mail -s "$SOURCE_PHONE: SMS received from $src_phone_number" $EMAIL # send SMS to an eMail
      done
fi

