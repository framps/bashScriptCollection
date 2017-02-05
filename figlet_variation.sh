#!/bin/bash

# Display text in any possible fonts
#
# (C) 2016 framp at linux-stips-and-tricks dot de
# 

if [[ -z $1 ]]; then
	echo "Missing parameter text"
	exit 
fi

for font in /usr/share/figlet/*.*lf; do
   f=$(basename $font)
   echo "### $f ###"
   figlet -f $f -k -c -w 130 $1
done 
