#!/bin/bash
# findPi:
#       Find all active Raspi's on the LAN
#
#	2017/01/24 - framp 

fping -a -r1 -g 192.168.0.0/24  &> /dev/null
arp -n | fgrep " b8:27:eb"
