#!/bin/bash

#######################################################################################################################
#
#    bash prototype which logs on to a Fritz AVM 7590 and
#    extracts the number of sent and received bytes of
#    today, yesterday, last week and last month
#
#    Visit https://github.com/framps/bashScriptCollection for latest code and other details
#
#######################################################################################################################
#
#    Copyright (C) 2013-2021 framp at linux-tips-and-tricks dot de
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

SERVER="192.168.171.1"
USER=""
PASSWORD="password"

challengeRsp=$(curl --header "Accept: application/xml" \
	--header "Content-Type: text/plain"		\
	"http://$SERVER/login_sid.lua" 2>/dev/null)

challenge=$(echo $challengeRsp | sed "s/^.*<Challenge>//" | sed "s/<\/Challenge>.*$//")

if [[ -z $challenge ]]; then
	echo "No challenge found"
	exit 0
fi

challenge_bf="$challenge-$PASSWORD"
challenge_bf=$(echo -n $challenge_bf | iconv -t UTF-16LE | md5sum - | cut -c 1-32)
response_bf="$challenge-$challenge_bf"

url="http://$SERVER/login_sid.lua"
if [[ -n "$USER" ]]; then
	url="$url+?username=$USER&response=$response_bf"
	sidRsp=$(curl --header "Accept: text/html,application/xhtml+xml,application/xml" \
		--header "Content-Type: application/x-www-form-urlencoded"		\
		$url 2>/dev/null)
else
	sidRsp=$(curl --header "Accept: text/html,application/xhtml+xml,application/xml" \
		--header "Content-Type: application/x-www-form-urlencoded"		\
		-d "response=$response_bf" \
		$url 2>/dev/null)
fi


sid=$(echo $sidRsp | sed "s/^.*<SID>//" | sed "s/<\/SID>.*$//")

regex="^0+$"
if [[ $sid =~ $regex ]]; then
	echo "Invalid password"
	exit 0
fi

IFS=' '
stats="$(curl --header "Accept: application/xml" \
	--header "Content-Type: text/plain"		\
	"http://$SERVER/internet/inetstat_counter.lua?sid=$sid" 2>/dev/null)"

# <td datalabel="Online-Zeit (hh:mm)" class="time">134:47</td><td datalabel="Datenvolumen gesamt(MB)" class="vol">15634</td><td datalabel="Datenvolumen gesendet(MB)" class="vol">2726</td><td datalabel="Datenvolumen empfangen(MB)" class="vol">12907</td><td datalabel="Verbindungen" class="conn">6</td></tr><tr><td datalabel="" class="first_col">Aktueller Monat</td> 
stats=$(echo $stats | grep -E "datalabel.+Online-Zeit")

IFS=$'\n'
regex='"time">(.+)</td>.+"vol">(.+)</td>.+"vol">(.+)</td>.+"vol">(.+)</td>.+"conn">(.+)</td>.+"first_col">(.+)</td>'
printf "%-20s %-10s %-10s %-10s %-10s %-5s\n" "When" "Online" "Total" "Sent" "Received" "Connections"

for line in $stats; do
	if [[ $line =~ $regex ]]; then
		online="${BASH_REMATCH[1]}"
		total="${BASH_REMATCH[2]}"
		sent="${BASH_REMATCH[3]}"
		received="${BASH_REMATCH[4]}"
		connections="${BASH_REMATCH[5]}"
		when="${BASH_REMATCH[6]}"
		printf "%-20s %-10s %-10s %-10s %-10s %-5s\n" $when $online $total $sent $received $connections
	fi
done

