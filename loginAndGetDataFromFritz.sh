#!/bin/bash

#########################################################
#
# bash prototype which logs on to a Fritz AVM 7390 and 
# extracts the number of sent and received bytes of 
# today, yesterday, last week and last month
#
# June 2013 - framp at linux-tips-and-tricks dot de 
#
#########################################################

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
challenge_bf=$(echo -n $challenge_bf | iconv -f ISO8859-1 -t UTF-16LE | md5sum -b)
challenge_bf=$(echo $challenge_bf | sed "s/ .*$//")
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

