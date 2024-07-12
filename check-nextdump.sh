#!/bin/bash

# description:
#   This is a script for N-able RMM
#   Checks if the Nextcloud DB Dump went all right
#
# usage:
#   N-able Command Line: Path to config file
#       /usr/local/scripts/nextbackup/config
#
# author: flo.alt@fa-netz.de
# version: 0.1


# read config file
    source $1
    errorcount=0

# this is now:

    now=$(date +"%s")

# check database backup

    # convert days in seconds:
    max_age_in_seconds=$((max_age * 86400))

    # get age of file
    db_age=$(stat -c %Y "$dump_to"/"$db_dumpfile")
    db_age_readable=$(date -d @$db_age +"%Y-%m-%d %H:%M")
        
    # do the test
    if (( (now - db_age) < max_age_in_seconds )); then
        check_db="OK"
    else
        check_db="FAIL"
        ((errorcount++))
    fi



# output

echo "Timestamp last DB-Dump: $db_age_readable"

if [ $check_db == "OK" ]; then
    echo "Database-Backup = OK"
else
    echo "Database-Backup = FAILED"
fi



# monitoring

if [ $errorcount = 0 ]; then
    exit 0
else
    exit 1001
fi