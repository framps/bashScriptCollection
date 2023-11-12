#!/bin/bash

#######################################################################################################################
#
# 	 Script to check whether current external IP address matches the IP address registered in a dyndns service
#	 and update the dyndns IP address if there is a mismatch
#	 Useful to start per cron early in the morning when the daily IP renewal happend in Germany
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

MYNAME=$(basename $0)
MYNAME=${MYNAME%.sh}
MYCONFIG="/usr/local/etc/$MYNAME.conf"
LOG="/var/log/${MYNAME}.log"

if [[ ! -f $MYCONFIG ]]; then
	echo "Config file $MYCONFIG not found. Using hard coded values"
else
	EXTERNAL_NAME="myName.ddns.org"		# external DYNDNS name
	USERNAME="user@ddns.org"		# DYNDNS username 
	PWD="myVerySecurePassword"		# DYNDNS password
	DDNS_URL="ddns.org/update"		# DNYDNS URL to update the registered IP
fi

source $MYCONFIG

STATE_NOW="$(date +%Y%m%d)"
STATE_FILE="/tmp/${MYNAME}.sts"
NOW=$(date)
UPDATE_RETRY=3
UPDATE_INTERVAL=60 # seconds

touch $STATE_FILE
lastRun=$(< $STATE_FILE)

if [[ -z $lastRun ]] || (( "$lastRun" < "$STATE_NOW" )); then

        myExternalIP="$(dig +short myip.opendns.com @resolver1.opendns.com)"
        externalNameIP="$(getent hosts $EXTERNAL_NAME | cut -f 1 -d " ")"

        success=0
        if [[ "$myExternalIP" != "$externalNameIP" ]]; then
                for (( i=0; i<=$UPDATE_RETRY; i++)); do
                        echo "$NOW: Update request $i from $externalNameIP to $myExternalIP" >> $LOG 
                        curl -s "$DDNS_URL?hostname=$EXTERNAL_NAME&myip=$myExternalIP&user=$USERNAME&pass=$PWD"
                        if (( $? )); then
                                echo "$NOW: Update request $i failed" >> $LOG
                                if (( $i != $UPDATE_RETRY )); then
                                        sleep ${UPDATE_INTERVAL}s
                                        NOW=$(date)
                                else
                                        break
                                fi
                        else
                                success=1
                                break
                        fi
                done
                if (( $success )); then
                        echo "$NOW: IP OK $externalNameIP - $myExternalIP" >> $LOG 
                        echo "$STATE_NOW" > $STATE_FILE
                else
                        echo "$NOW: IP update failed from $externalNameIP to $myExternalIP" >> $LOG 
                fi
        else
                echo "$NOW: IP OK $externalNameIP - $myExternalIP" >> $LOG 
                echo "$STATE_NOW" > $STATE_FILE
        fi      
else
        : echo "$NOW: Skipped" >> $LOG 
fi        
