#!/bin/bash

#######################################################################################################################
#
#    Check whether the local external IP matches the IP registered in an externel DDNS
#
#    Usually the home router updates the external DDNS IP when a new IP is provided by the internet provider.
#    Unfortunately sometimes this update fails for some reasons (timing, unavailability of DDNS, ...)
#    This script checks if the external IP is registered in the DDNS and updates the IP if required.
#    This script should be called via cron either regularly or when the internet provider has piblished a new external IP
#	  A state file will make shure the IP update only happens once a day.
#
#    Visit https://github.com/framps/bashScriptCollection for latest code and other details
#
#######################################################################################################################
#
#    Copyright (C) 2023 framp at linux-tips-and-tricks dot de
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

# DDNS definitions
DDNS_URL="https://my.ddns.de"							# DDNS host
EXTERNAL_NAME="myExternalName.mydomain.de"		# DNS name used by DDNS
# required to update the IP in DDNS
USERNAME="mynam@ddns.de"
PWD="secret"

LOG="/var/log/${MYNAME}.log"
STATE_NOW="$(date +%Y%m%d)"
STATE_FILE="/tmp/${MYNAME}.sts"
NOW=$(date)

UPDATE_RETRY=3
UPDATE_INTERVAL=60 # seconds

touch $STATE_FILE
lastRun=$(<$STATE_FILE)

if [[ -z $lastRun ]] || (( "$lastRun" < "$STATE_NOW" )); then

	myExternalIP="$(dig +short myip.opendns.com @resolver1.opendns.com)"
	externalNameIP="$(getent hosts $EXTERNAL_NAME | cut -f 1 -d " ")"

	success=0
	if [[ "$myExternalID" != "$externalNameIP" ]]; then
		for (( i=0; i<=$UPDATE_RETRY; i++)); do
			echo "$NOW: Update request $i from $externalNameIP to $myExternalIP" >> $LOG
			curl "$DDNS_URL/nic/update?hostname=$EXTERNAL_NAME&myip=$myExternalIP&user=$USERNAME&pass=$PWD"
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

