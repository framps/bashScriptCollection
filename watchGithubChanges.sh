#!/bin/bash

#######################################################################################################################
#
#    Check for any updates in github for repository forks, subscribers and stars and send a eMail about the changes
#
#######################################################################################################################
#
#    Copyright (c) 2026 framp at linux-tips-and-tricks dot de
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

set -euo pipefail

readonly SCRIPT_FILENAME=$(basename "$0")
readonly SCRIPT_NAME=${SCRIPT_FILENAME%.*}
readonly STATE_FILENAME="${SCRIPT_NAME}.cnt"
readonly EMAIL="dummy@dummy.com"
readonly GITHUB_USER="user"
readonly REPOSITORIES="repo1 repo2 repo3"
declare -A PROPERTIES
readonly PROPERTIES=([stars]=stargazers_count [forks]=forks_count [subscribers]=subscribers_count)

MYSELF="$(basename "$0")"
VERSION="0.1"
GITREPO="https://github.com/framps/bashScriptCollection"

tty -s
INTERACTIVE=$((!$?))

if (( INTERACTIVE )); then
	echo "$MYSELF $VERSION ($GITREPO)"
fi	

trap 'rm -f "${STATE_FILENAME}.tmp"' EXIT

if ! hash "jq" 2>/dev/null; then
	echo "Missing jq. Install jq first"
	exit 42
fi	

function check() { #repository

	local repo="$1"

	if [[ ! -e "$STATE_FILENAME" ]]; then		# countfile does not exist
		echo -n "$repo" > "$STATE_FILENAME"
		for ((i=1;i<="${#PROPERTIES[@]}";i++)); do
			echo -n " 0" >> "$STATE_FILENAME"
		done
		echo "" >> "$STATE_FILENAME"
	elif ! grep -q "^$repo " "$STATE_FILENAME"; then	# repo does not exist in count file
		echo -n "$repo" >> "$STATE_FILENAME"
		for ((i=1;i<="${#PROPERTIES[@]}";i++)); do
			echo -n " 0" >> "$STATE_FILENAME"
		done
		echo "" >> "$STATE_FILENAME"
	fi

	httpResponse=$(curl -u framps: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zz -s -q -w "\n%{http_code}" "https://api.github.com/repos/$GITHUB_USER/$repo" -H 'Accept: application/vnd.github.preview')
	rc=$?

	if (( rc != 0 )); then
		echo "??? curl failed with RC $rc"
		exit 42
	fi

	httpCode=$(tail -n 1 <<< "$httpResponse")
	if (( httpCode != 200 )); then
		echo ??? "Curl request failed with HTTP: $httpCode"
		exit 42
	else

		apiResult="$(sed '$d' <<< "$httpResponse")"

		index=2
		new=""
		for property in "${!PROPERTIES[@]}"; do
		
			attribute="${PROPERTIES[$property]}"
		
			actual="$(jq ".$attribute" <<< "$apiResult")"

			old="$(grep "$repo" "$STATE_FILENAME" | cut -f $index -d ' ')"
			(( index++ ))
		
			new="$new$actual "
			
			if (( old != actual )); then
				if (( old > actual )); then
					: sig="-"
				else
					sig="+"
				fi
				(( diff = actual - old ))
				if ! declare -p "$property" &>/dev/null; then
					declare -g -A "$property"
				fi
				declare -n arr="$property"
				arr["$repo"]="$property: $sig$diff to $actual"	
			fi
				
		done
		echo "$repo $new" >> "${STATE_FILENAME}.tmp"		
	fi

}

for repository in $REPOSITORIES; do
	check "$repository"
done

mv "${STATE_FILENAME}.tmp" "$STATE_FILENAME"

for repository in $REPOSITORIES; do
	m=""
	for property in "${!PROPERTIES[@]}"; do
		declare -n arr="$property"   # arr now references the array named by $property

		for r in "${!arr[@]}"; do
			if [[ $r == "$repository" ]]; then
				s="${arr[$r]}"
				m="$m $s"
			fi
		done	
	done
	if [[ -n $m ]]; then # send eMail only if there are any updates
		if (( INTERACTIVE )); then
			echo "$repository: $m"
		else
			echo "$repository: $m" | mail -s "$repository $m" $EMAIL
		fi
	fi
done
