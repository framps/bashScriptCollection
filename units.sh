#!/bin/bash

#######################################################################################################################
#
# Converts a number in gibibits. Example: 1024 -> 1K, 1073741825 -> 1T
#
#######################################################################################################################
#
#    Copyright (C) 2016,2023 framp at linux-tips-and-tricks dot de
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

function convertToMetric() { # number

    local DIM=(" " K M G T P)
    local r=$1

    while (($r >= 1024)); do
        ((r = $r / 1024))
        ((m = m + 1))
        if (($m >= ${#DIM[@]})); then
            echo "??? Number $1 too big"
            exit 127
        fi
    done
    echo $r${DIM[$m]}

}

if (("$#" == 1)); then
    echo $(convertToMetric $1)
else
    for n in 10 1024 1024*1024+1 1024*1024*1024+1 1024*1024*1024*1024+1 1024*1024*1024*1024*1024+1 1024*1024*1024*1024*1024*1024+1; do
        echo "Number: $(($n)) - metric: $(convertToMetric $(($n)))"
    done
fi
