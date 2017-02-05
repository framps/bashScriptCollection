#!/bin/bash

# Converts a number in gibibits. Example: 1024 -> 1K, 1073741825 -> 1T
#
# (C) 2016 framp at linux-stips-and-tricks dot de
#

function convertToMetric() { # number

	local DIM=(" " K M G T)
	local r=$1

	while [[ $r -ge 1024 ]]; do
		let r=$r/1024
		let m=m+1
		if [[ $m -ge ${#DIM[@]} ]]; then
			echo "??? Number $(( $1 )) too big"
			exit 127
		fi
	done
	echo $r${DIM[$m]}
	
}

if [ "$#" -eq 1 ]; then
	echo $(convertToMetric $1)
else
	for n in 10 1024 1024*1024+1 1024*1024*1024+1 1024*1024*1024*1024+1; do
		echo "Number: $n - $(( $n )) - metric: $(convertToMetric $n)"
	done
fi



