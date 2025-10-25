#!/bin/bash

#
# Sample code which implements a bash commandline parser
#
# Option format of flag:
# -x and -x- will mark a flag as false (0)
# -x+ will mark a flag as true (1)
#
# Option format of parameter:
# -x or --some_long_option_name_for_x
#
# (C) 2018 framp at linux-stips-and-tricks dot de
#

# 0 -> disable, 1 -> enable, -1 -> neither
function isEnableDisableParm() { # parm
    case "$1" in
        -*-) echo 0 ;;
        -*+ | -*) echo 1 ;;
        *) echo -1 ;;
    esac
}

PARAMS=""

while (("$#")); do
    case "$1" in
        -f | --flag-with-argument)
            FARG=$2
            shift 2
            echo "Got flag -f: $FARG"
            ;;
        -g | --gflag-with-argument)
            GARG=$2
            shift 2
            echo "Got flag -g: $GARG"
            ;;
        -e | -e[+-])
            f="$1"
            shift 1
            EARG=$(isEnableDisableParm "$f")
            if (($EARG < 0)); then
                echo "Invalid flag $f"
            else
                echo "Got flag -e: $EARG"
            fi
            ;;
        --) # end argument parsing
            shift
            break
            ;;
        -* | --* | +* | ++*) # unsupported flags
            echo "Error: Unsupported flag $1" >&2
            exit 1
            ;;
        *) # preserve positional arguments
            [[ -z $PARAMS ]] && PARAMS="$1" || PARAMS="$PARAMS $1"
            shift
            ;;
    esac
done

# set positional arguments in argument list $@
set -- $PARAMS

i=1
while (("$#")); do
    echo "Positional parm $((i++)): $1"
    shift
done
