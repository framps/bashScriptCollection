#!/bin/bash

#######################################################################################################################
#
#    Helperscript for ism7mqtt (https://github.com/zivillian/ism7mqtt) which helps to find ptids which match a given
#	 search string
#
#    Visit https://github.com/framps/bashScriptCollection for latest code and other details
#
#######################################################################################################################
#
#    Copyright (C) 2024 framp at linux-tips-and-tricks dot de
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

readonly MYSELF="$(basename "$(test -L "$0" && readlink "$0" || echo "$0")")"
readonly MYNAME=${MYSELF%.*}

readonly VERSION="v0.1"
readonly GITREPO="https://github.com/framps/bashScriptCollection"	

function usage() {
   cat <<- EOF
$MYSELF $VERSION ($GITREPO)

Search for ism7mqtt ptids which are in parameter.json.
The search is executed case insensitive and with no exact match.

Example: Search argument "wasser" will find
 "Warmwassertemperatur", "Durchfluss Warmwasser",
 "Auslauftemperatur Warmwasser", "Obere Brennerleistung Warmwasser" ...

Usage: $0 "search string" [parameter_json_filename]

Default for parameter_json_filename is parameter.json
EOF
}

if (( $# < 1 )); then
   usage
   exit 1
fi

readonly name="$1"
readonly parameterJSON="${2:-parameter_full.json}"
readonly parameterXML="ParameterTemplates.xml"
readonly deviceXML="DeviceTemplates.xml"

echo "$MYSELF $VERSION ($GITREPO)"

l=0

readonly usedFiles=( $parameterJSON $parameterXML $deviceXML )

for file in "${usedFiles[@]}"; do
	if [[ ! -e $file ]]; then
		echo "$file not found"
		exit 1
	fi
done

if ! which xmllint &>/dev/null; then
	echo "Please install xmllint first (package libxml2-utils)"
	exit 1
fi	

while read -r line; do

    if [[ $line != "--" ]]; then

        #echo "@@@ $l: $line"
        case $l in
            0) if [[ "$line" =~ PTID=\"([^\"]+) ]]; then
                    ptid="${BASH_REMATCH[1]}"
                else
                    echo "error1"
                    exit 1
                fi
                 ;;

            1) if [[ "$line" =~ \<Name\>([^\<]+)\<\/Name\> ]]; then
                   ptid_name="${BASH_REMATCH[1]}"
                else
                    echo "error2"
                    exit 1
                fi
               ;;
            *) echo "error3"
               ;;
        esac
    fi

    set +e
    l=$(( (l+1)%3 ))
    set -e

    if (( $l == 2 )); then
        set +e
        ptidJSON="$(grep -o " $ptid" $parameterJSON)"
        # dtid="$(jq -e ".Devices[] | select(.Parameter[] == ${ptid}).DeviceTemplateId" $parameterJSON)" # ... inefficient for huge parameter.json :-(
        found=$(( ! $? ))        
        set -e
        if (( $found )); then
			device=$(xmllint --xpath "string(/DeviceTemplateConfig/DeviceTemplates/DeviceTemplate/ParameterReferenceList/ParameterReference[@PTID=${ptid}]/../../@Name)" $deviceXML)
            echo ">>> \"$ptid_name\": $device - $ptid"
        else
            : echo "    \"$ptid_name\": $ptid"
        fi
     fi
done < <(grep -i -B 1 "<Name>.*${name}.*</Name>" $parameterXML)

