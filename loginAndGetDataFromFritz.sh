#!/bin/bash
#
#######################################################################################################################
#
#    bash prototype which logs on to a Fritz AVM 7590 and executes som command against dect200
#	 1) retrieves temperature
#	 2) retrieves energy used
#	 3) Turn switch on or off or queries the switch state
#
#    Visit https://github.com/framps/bashScriptCollection for latest code and other details
#
#######################################################################################################################
#
#    Copyright (C) 2013-2025 framp at linux-tips-and-tricks dot de
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

SERVER="http://192.168.172.1"
USER="dect200"
PASSWORD="dect200"
AIN="471147114711"

if (( $# < 1 )) || [[ ! $1 =~ ^(temp|energy|on|off|state)$ ]]; then
	(( $# < 1 )) && c="Missing" || c="Expected"
	echo "$c command temp, energy, on or off or state"
	exit 42
fi		

cmd="$1"

function executeRequest() {
	echo "$(curl -s -k ${SERVER}'/webservices/homeautoswitch.lua?ain='${AIN}'&sid='${sidRsp}'&switchcmd='${1})"
}	

challengeRsp=$(curl --header "Accept: application/xml" \
	--header "Content-Type: text/plain"		\
	"$SERVER/login_sid.lua" 2>/dev/null)

challenge=$(echo $challengeRsp | sed "s/^.*<Challenge>//" | sed "s/<\/Challenge>.*$//")

if [[ -z $challenge ]]; then
	echo "No challenge received"
	exit 0
fi

md5=$(echo -n "$challenge-$PASSWORD" | iconv -t UTF-16LE | md5sum - | cut -c 1-32)
response="${challenge}-${md5}"

sidRsp=$(curl -i -s -k -d "response=${response}&username=${USER}" "$SERVER/login_sid.lua" | sed -n 's/.*<SID>\([[:xdigit:]]\+\)<\/SID>.*/\1/p')

regex="^0+$"
if [[ $sidRsp =~ $regex || -z "$sidRsp" ]]; then
	echo "Invalid userid or password"
	exit 0
fi

case $cmd in

	temp) tempNum="$(executeRequest "gettemperature")"
		tempDegree=$(echo $tempNum | sed 's/\B[0-9]\{1\}\>/\.&/')
		echo "DECT200 measures ${tempDegree}°C"
		;;
	on|off) state="$(executeRequest "setswitch$cmd")"
		stateWord=$([ "$state" == 0 ] && echo "off" || echo "on")
		echo "DECT200 switched $stateWord"
		;;
	state) state="$(executeRequest "getswitchstate")"
		stateWord=$([ "$state" == 0 ] && echo "off" || echo "on")
		echo "DECT200 switch is $stateWord"
		;;
	energy) energyNum="$(executeRequest "getswitchenergy")"
		echo "DECT200 measures $energyNum Wh"
		;;
	*) echo "Internal error"
		exit 42
esac	

