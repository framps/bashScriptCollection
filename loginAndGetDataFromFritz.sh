#!/bin/bash

#######################################################################################################################
#
#    Python prototype which logs on to a Fritz AVM 7390 and
#    extracts the number of sent and received bytes of
#    today, yesterday, last week and last month
#
#    Visit https://github.com/framps/bashScriptCollection for latest code and other details
#
#######################################################################################################################
#
#    Copyright (C) 2013-2017 framp at linux-tips-and-tricks dot de
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

SERVER="192.168.0.1"
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

sidRsp=$(curl --header "Accept: text/html,application/xhtml+xml,application/xml" \
	--header "Content-Type: application/x-www-form-urlencoded"		\
	-d "response=$response_bf" \
	$url 2>/dev/null)

sid=$(echo $sidRsp | sed "s/^.*<SID>//" | sed "s/<\/SID>.*$//")

regex="^0+$"
if [[ $sid =~ $regex ]]; then
	echo "Invalid password"
	exit 0
fi

IFS=' '
stats=$(curl --header "Accept: application/xml" \
	--header "Content-Type: text/plain"		\
	"http://$SERVER/internet/inetstat_counter.lua?sid=$sid" 2>/dev/null)

stats=$(echo $stats | grep "inetstat:" | sed "s/inetstat:status\///" | sed 's/[["\]//g' | sed 's/\]//' | sed 's/ = / /' | sed 's/,//' | sed 's/\// /' | sed 's/^ //')

IFS=$'\n'
regex="([a-zA-Z]+) ([a-zA-Z]+) ([0-9]+)"
for line in $stats; do
	if [[ $line =~ $regex ]]; then
		date=${BASH_REMATCH[1]}
		type=${BASH_REMATCH[2]}
		value=${BASH_REMATCH[3]}
		echo "$date $type $value"
	fi
done

