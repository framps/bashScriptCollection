#!/bin/bash

#######################################################################################################################
#
# Display text in any possible fonts
#
#######################################################################################################################
#
#    Copyright (C) 2016 framp at linux-tips-and-tricks dot de
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

if [[ -z $1 ]]; then
    echo "Missing parameter text"
    exit
fi

for font in /usr/share/figlet/*.*lf; do
    f=$(basename $font)
    echo "### $f ###"
    figlet -f $f -k -c -w 130 $1
done
