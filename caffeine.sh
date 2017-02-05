#!/bin/bash

# Small script which deactivates screensaver if any configured programs are up and running
# Environment: Mint 18.1 running Mate
#
# Kudos for Z-App from www.linuxmintusers.de who figured out how to enable and disable the screensaver in mate
#
# Just start in your .bashrc this script in the background and update the screensaver timeout
# 
# framp - 2017/01/24

set -e -o pipefail -o errtrace

PROGRAMS_TO_WATCH=( "kaffeine" "foo" "bar" )

DEBUG=0
SCREENSAVER_TIMEOUT=$(gsettings get org.mate.session idle-delay)
(( $DEBUG )) && echo "Timeout: $SCREENSAVER_TIMEOUT"
WATCHER_TIMEOUT=$(( SCREENSAVER_TIMEOUT / 2 ))

function screensaver_off() {	
	if (( $screensaver_status )); then
		(( $DEBUG )) && echo "Turning screensaver off"
		screensaver_status=0
		gsettings set org.mate.screensaver idle-activation-enabled false
	fi
}

function screensaver_on() {
	if (( ! $screensaver_status )) ; then
		(( $DEBUG )) && echo "Turning screensaver on"
		screensaver_status=1
		gsettings set org.mate.screensaver idle-activation-enabled true
	fi
}

screensaver_status=0
screensaver_off

while :; do
	hit=0
	(( $DEBUG )) && echo "Checking"
	for program in "${PROGRAMS_TO_WATCH[@]}"; do
		if ps -C "$program" >/dev/null; then
			hit=1
			(( $DEBUG )) && echo "$program is active"
			break
		fi
	done
	if (( $hit )); then
		screensaver_off
	else 
		screensaver_on
	fi
	sleep ${WATCHER_TIMEOUT}m
done
