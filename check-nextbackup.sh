#!/bin/bash

# description:
#   This is a script for N-able RMM
#   Checks if the Nextcloud Backup went all right
#
# usage:
#   N-able Command Line: Path to config file
#       /usr/local/scripts/nextbackup/check-nextbackup.config
#
# author: flo.alt@fa-netz.de
# version: 0.1


# read config file
source $1

errorcount=0

# this is now:

    now=$(date +"%s")

# check database backup

    db_age=$(stat -c %Y $db_backup)
    if (( (now - db_age) < (max_age * 3600) )); then
        check_db="OK"
    else
        check_db="FAIL"
        ((errorcount++))
    fi

# check config backup

    conf_age=$(stat -c %Y $conf_backup)
    if (( (now - conf_age) < (max_age * 3600) )); then
        check_conf="OK"
    else
        check_conf="FAIL"
        ((errorcount++))
    fi

# check data backup

    data_age=$(stat -c %Y $data_backup)
    if (( (now - data_age) < (max_age * 3600) )); then
        check_data="OK"
    else
        check_data="FAIL"
        ((errorcount++))
    fi

# output

if [ $check_db == "OK" ]; then
    echo "Database-Backup = OK"
else
    echo "Database-Backup = FAILED"
fi

if [ $check_conf == "OK" ]; then
    echo "Configuration-Backup = OK"
else
    echo "Configuration-Backup = FAILED"
fi

if [ $check_data == "OK" ]; then
    echo "Data-Backup = OK"
else
    echo "Data-Backup = FAILED"
fi


# monitoring

if [ $errorcount = 0 ]; then
    exit 0
else
    exit 1001
fi