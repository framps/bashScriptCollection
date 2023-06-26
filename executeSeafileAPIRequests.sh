#!/bin/bash
#
#######################################################################################################################
#
# 	 Execue some API requests against seafile server using uid & token authorization
#
#	 Can be used to test seafile API throtteling by using invalid credentials and executing the script in an endless loop.
#	 Just set invalid credentials and execute
#
#    while :; do ./executeSeafileAPIRequests.sh; done
#
#	 Using valid credentials will display the API results with jq
#
#######################################################################################################################
#
#    Copyright (C) 2018 framp at linux-tips-and-tricks dot de
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

function checkPrerequ() {

	local miss=1
	if [[ -z "$SF_USER" ]]; then
		echo '??? Missing export SF_USER="email", e.g foo@bar.com'
		miss=0
	fi

	if [[ -z "$SF_PASSWORD" ]]; then
		echo '??? Missing export SF_PASSWORD="password", e.g V3ry53cur3P455w0rd'
		miss=0
	fi

	if [[ -z "$SF_URL" ]]; then
		echo '??? Missing export SF_URL="seafileurl", e.g myseafile.foo.com'
		miss=0
	fi

	if ! which jq &>/dev/null; then
		echo "??? Missing jq"
		miss=0
	fi
	
	return $miss

}
function expect() { # expected valid http status codes
	for s in "$@"; do
		(( HTTP_STATUS == s )) && return
	done
	echo "??? Unexpected http status $HTTP_STATUS received"
	exit 42
}

function executeRequest() { # API endpoint, creds

	echo -n "Executing ${SF_URL}$1 : "
	case $2 in
		u) AUTH=( -d "username=$SF_USER&password=$SF_PASSWORD" )
			echo "PASSWORD AUTH";;										# user auth
		n) 	echo "NO AUTH";;										#no auth
		*) AUTH=( -H "Authorization: Token $2" )						# token auth
			echo "TOKEN AUTH";;
	esac

	HTTP_RESPONSE="$(curl "${AUTH[@]}" --silent --write-out "HTTPSTATUS:%{http_code}" https://${SF_URL}$1)"
	HTTP_BODY=$(sed -e 's/HTTPSTATUS\:.*//g' <<< "$HTTP_RESPONSE")
	HTTP_STATUS=$(tr -d '\n'  <<< "$HTTP_RESPONSE" | sed -e 's/.*HTTPSTATUS://')
	echo "--- Status $HTTP_STATUS"
}

checkPrerequ

if (( ! $? )); then
	exit 42
fi	

echo "Using seafile $SF_URL"
echo "Using user $SF_USER"

executeRequest "/api2/server-info/" n
expect 200
jq '.' <<< $HTTP_BODY
VERSION=$(jq -r '.version' <<< $HTTP_BODY)
echo "Seafile server version: $VERSION"

executeRequest "/api2/ping/" n
expect 200
echo "$HTTP_BODY"

executeRequest "/api2/auth-token/" u
expect 200
TOKEN=$(jq -r '.token' <<< "$HTTP_BODY")
echo "Got access token $TOKEN"

executeRequest "/api2/auth/ping/" "$TOKEN"
expect 200

executeRequest "/api2/account/info/" "$TOKEN"
expect 200
jq '.' <<< "$HTTP_BODY"
executeRequest "/api2/accounts/" "$TOKEN"
expect 200
jq '.' <<< "$HTTP_BODY"

