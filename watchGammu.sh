#!/bin/bash
#######################################################################################################################
#
# 	Sample code for a SMS relay server with gammu
#   Script listens for SMS received and forwards them to another phone number
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
TARGET_PHONE="+4917147114711"
MYSELF=${0##*/}
MYNAME=${MYSELF%.*}

if [[ $1 == "start" ]]; then
        $MYSELF >> /var/log/$MYNAME.log &

elif [[ $1 == "stop" ]]; then
        killall $MYSELF

else
        inotifywait -m $GAMMU_INPUT_DIR -e create | while read path action file; do
          echo "The file '$file' appeared in directory '$path' via '$action'"
          msg="$(<$path/$file)"
          if [[ ${msg^^} == "STOP" ]]; then
                echo "SMS relay server will be stopped soon" | gammu-smsd-inject TEXT $TARGET_PHONE
                sleep 1m
                systemctl stop gammu-smsd
                exit 0
          fi
          src_phone_number="$(cut -d _ -f 4 <<< "$file")"
          echo "$src_phone_number $msg" | gammu-smsd-inject TEXT $TARGET_PHONE
      done
fi

