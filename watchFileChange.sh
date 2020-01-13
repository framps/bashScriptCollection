#!/bin/bash

#######################################################################################################################
#
# 	Sample code which listens for a file contents change
# 	and depending on the new contents triggers an action
##
#######################################################################################################################
#
#    Copyright (C) 2017 framp at linux-tips-and-tricks dot de
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

if ! type inotifywait &>/dev/null ; then
    echo "Missing inotifywait dependency. Install package inotify-tools (sudo apt-get install inotify-tools)"
    exit 42
fi

LOGFILE="fileToWatch.txt"

# setup change listener on file

coproc INOTIFY {
        inotifywait -q -m -e close_write --format %e "$LOGFILE" &
        trap "kill $!" 1 2 3 6 15
        wait
}

# listen for event from coproc pipe and trigger action

while read event; do
        value=$(<$LOGFILE)
        case $value in
                0) echo "Off received"
                        # shutdown
                        ;;
                1) echo "On received"
                        # reboot
                        ;;
                *) echo "Unknown -$value- detected"
                        ;;
        esac
done <&${INOTIFY[0]}
