#!/bin/bash
#
#######################################################################################################################
#
# 	 Execue some API requests against seafile server using uid & token authorization
#
#	 Can be used to to test seafile API throtteling by using invalid credentials and executing the script in an endless loop.
#	 Just set invalid credentials and execute
#
#    while :; do ./seafileAPIRequests.sh; done
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

	if [[ -z "$SF_USER" ]]; then
		echo 'Missing export SF_USER="email, e.g foo@bar.com"'
		exit 42
	fi

	if [[ -z "$SF_PASSWORD" ]]; then
		echo 'Missing export SF_PASSWORD="password, e.g V3ry53cur3P455w0rd"'
		exit 42
	fi

	if [[ -z "$SF_URL" ]]; then
		echo 'Missing export SF_URL="seafileurl, e.g myseafile.foo.com"'
		exit 42
	fi

	if ! which jq; then
		echo "Missing jq"
		exit 42
	fi

}
function expect() { # http status codes
	for s in "$@"; do
		(( HTTP_STATUS == s )) && return
	done
	echo "Unexpected http status $HTTP_STATUS received"
	exit 42
}

function executeRequest() { # API endpoint, creds

	echo "Executing ${SF_URL}$1"
	if [[ $2 == 1 ]]; then
		HTTP_RESPONSE="$(curl -d "username=$SF_USER&password=$SF_PASSWORD" --silent --write-out "HTTPSTATUS:%{http_code}" https://${SF_URL}$1)"
	elif [[ $2 != 0 ]]; then
		HTTP_RESPONSE="$(curl -H "Authorization: Token $2" --silent --write-out "HTTPSTATUS:%{http_code}" https://${SF_URL}$1)"
	else
		HTTP_RESPONSE="$(curl --silent --write-out "HTTPSTATUS:%{http_code}" https://${SF_URL}$1)"
	fi
	HTTP_BODY=$(echo "$HTTP_RESPONSE" | sed -e 's/HTTPSTATUS\:.*//g')
	HTTP_STATUS=$(echo $HTTP_RESPONSE | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
	echo "Status $HTTP_STATUS"
}

checkPrerequ

echo "Using seafile $SF_URL"
echo "Using user $SF_USER"

executeRequest "/api2/server-info/" 0
expect 200
jq '.' <<< $HTTP_BODY
VERSION=$(jq -r '.version' <<< $HTTP_BODY)
echo "Seafile server version: $VERSION"

executeRequest "/api2/ping/" 0
expect 200
echo "$HTTP_BODY"

executeRequest "/api2/auth-token/" 1
expect 200
TOKEN=$(jq -r '.token' <<< "$HTTP_BODY")
echo "Got access token $TOKEN"

executeRequest "/api2/auth/ping/" "$TOKEN"
expect 200

executeRequest "/api2/account/info/" "$TOKEN"
expect 200
jq '.' <<< "$HTTP_BODY"

