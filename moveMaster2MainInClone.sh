#!/bin/bash

#######################################################################################################################
#
# Updates a local clone of a repository where the branch was renamed from master to main
#
#######################################################################################################################

git branch -m master main
git fetch origin
git branch -u origin/main main
git remote set-head origin -a

git pull
