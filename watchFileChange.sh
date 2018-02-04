#!/bin/bash
#
# Sample code which listens for a file contents change
# and depending on the new contents triggers an action
#
# (C) 2018 framp at linux-stips-and-tricks dot de
#

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
