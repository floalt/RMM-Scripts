#!/bin/bash

# This script monitors the health status of ZFS pools on a server.
# - If all pools are healthy, the script takes no further action.
# - If any issues are detected, an email notification is sent with a log file attached.
# - Log files are stored in /var/log/zfscheck, and old logs are rotated to retain a maximum of 30 files.
#
# Requirements:
# - ZFS must be installed and functional.
# - The `mail` command must be available for sending email notifications.

# Configuration
mailto="itflows@it-flows.de"  # Target email address for notifications
logdir="/var/log/zfscheck"  # Directory for log files
logretention=30  # Maximum number of log files to retain
hostname=$(hostname)  # Hostname of the server for the email subject

# Ensure the log directory exists, if it does not already exist
[ ! -d "$logdir" ] && mkdir -p "$logdir"

# Current date for the log file
logfile="$logdir/zfscheck_$(date +%Y-%m-%d_%H-%M-%S).log"

# Function: Clean up old logs
cleanup_logs() {
    find "$logdir" -type f -name "zfscheck_*.log" | sort -r | tail -n +$((logretention + 1)) | xargs -r rm -f
}

# Function: Check ZFS status
check_zfs() {
    echo "$(date) - Starting ZFS health check" > "$logfile"

    # Check ZFS pool status
    zpool list &> /dev/null
    if [ $? -ne 0 ]; then
        echo "ZFS is not available on this system or zpool command failed." >> "$logfile"
        return 2
    fi

    errorcount=0

    # Check all pools
    zpool status | while read -r line; do
        echo "$line" >> "$logfile"

        if [[ "$line" =~ "DEGRADED" || "$line" =~ "FAULTED" || "$line" =~ "UNAVAIL" || "$line" =~ "OFFLINE" || "$line" =~ "REMOVED" || "$line" =~ "UNHEALTHY" ]]; then
            errorcount=1
        fi
    done

    return $errorcount
}

# Main logic
check_zfs
status=$?

if [ $status -ne 0 ]; then
    # Problem detected, send email
    subject="[ALERT] ZFS issue detected on $hostname"
    echo "ZFS health check detected problems on server $hostname. Please review the attached log file." | \
        mail -s "$subject" -a "$logfile" "$mailto"
fi

# Clean up logs
cleanup_logs

exit 0

