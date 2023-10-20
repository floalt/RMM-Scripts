<#
    n-able RMM-script for Veeam Backup Check

    << Important: >> Write "monitored" somewhere in Backup Job Description in Veeam Backup

    author: flo.alt@fa-netz.de
    https://github/floalt/
    version: 0.6

#>

[int]$global:errorcount = 0


## define functions


function Get-RecentSessions ($joblist,$sessionlist) {
    # find the most recent (last) session in a list of sessions of the same job
    $recent_sessions = @()
    foreach ($job in $joblist) {
        # find the latest session of every job
        $latest_session = $sessionlist | Where-Object { $_.JobName -eq $job.Name } | Sort-Object CreationTime -Descending | Select-Object -First 1
        # add to the array
        if ($latest_session -ne $null) {
            $recent_sessions += $latest_session
        }
    }
    return $recent_sessions
}


function Get-RecentComputerSessions ($sessionlist) {
    # find tasks for each session
    $temp_sessions = @()
    foreach ($session in $sessionlist) {
        $task = (Get-VBRTaskSession -Session $session)
        if ($task.Name -ne $null) {
            $temp_sessions += $task
        }
    }
    # find unique names in $temp_sessions
    $names = ($temp_sessions | Get-Unique)
    # now build the $recent_sessions
    $recent_sessions = @()
    foreach ($name in $names) {
        # find Status 'Success'
        $result = $temp_sessions | Where { ($_.Name -eq $name.Name) -and ($_.Status -eq "Success") }
        # if there is no 'Success', find 'Failed'
        if (!$result) {
            $result = $temp_sessions | Where { ($_.Name -eq $name.Name) -and ($_.Status -eq "Failed") }
        }
        # add result to $recent_sessions
        $recent_sessions += $result
    }
    return $recent_sessions
}

function Check-JobRunned ($desc,$jobs,$sessions) {
    Write-Host ""
    Write-Host "Number of scheduled $desc Jobs: " $jobs
    Write-Host "Number of executed $desc Jobs: " $sessions
    if ($jobs -eq $sessions) {
        Write-Host "OK: All $desc Jobs were processed"
    } else {
        Write-Host ">> ERROR << The number of scheduled and executed $desc does not match!"
        $global:errorcount++
    }
}


function Check-VMSessionResults ($recent_sessionlist) {
    foreach ($session in $recent_sessionlist) {
        if ($session.Result -eq "Success") {
            Write-Host "OK:" $session.EndTime "|" $session.JobName "completed successfully"
        } else {
            Write-Host ">> ERROR <<" $session.EndTime "|" $session.JobName "failed"
            $global:errorcount++
        }
    }
}


function Check-ComputerSessionResults ($recent_sessionlist) {
    foreach ($session in $recent_sessionlist)  {
        # this is the link between 'JobSessId' and '$all_computer_backup_sessions.Id'
        $findme = ($all_computer_backup_sessions | Where-Object { $_.id -eq $session.JobSessID })
        $endtime = ($findme.CreationTime).ToString("dd.MM.yyyy HH:mm:ss")
        # this is the check:
        if ($session.Status -eq "Success") {
            Write-Host "OK:" $endtime "|" $session.Name "completed successfully" 
        } else {
            Write-Host ">> ERROR <<" $endtime "|" $session.Name "failed"
            $global:errorcount++
        }
    }
}



## Get all info first:


# get all JOBS (active and scheduled)

    # get BACKUP jobs
        $backup_vm_jobs = Get-VBRJob -WarningAction SilentlyContinue | Where-Object { ($_.IsBackup -eq $True) -and ($_.Description -like "*monitored*") }
        $backup_computer_jobs = Get-VBRComputerBackupJob | Where-Object { ($_.Description -like "*monitored*") }

        $names = ($backup_vm_jobs.Name -join ', ') + ', ' + ($backup_computer_jobs.Name -join ', ')
        Write-Host "The following Backup Jobs are scheduled to run: $names"

    # get COPY jobs
        $copy_job = Get-VBRJob -WarningAction SilentlyContinue | Where-Object { ($_.IsBackupCopy -eq $True) }
        if ($copy_job) {
            Write-Host "The following Copy Job is scheduled to run: " $copy_job.Name
        }



# get all SESSIONS of the last 24 hours


    # VM BACKUP Sessions
        $all_vm_backup_sessions = (Get-VBRBackupSession | Where-Object { ($_.CreationTime -ge (Get-Date).AddHours(-24)) -and ($_.JobTypeString -eq "Backup") })
        $recent_vm_backup_sessions = Get-RecentSessions $backup_vm_jobs $all_vm_backup_sessions

    # COPY Sessions
        $all_copy_sessions = (Get-VBRBackupSession | Where-Object { ($_.CreationTime -ge (Get-Date).AddHours(-24)) -and ($_.JobTypeString -eq "Backup Copy") })
        $nameof_copy_sessions = ($all_copy_sessions | Group-Object -Property OrigJobName)
        $recent_copy_sessions = Get-RecentSessions $nameof_copy_sessions $all_copy_sessions

    # Computer Backup Sessions
        $all_computer_backup_sessions = (Get-VBRComputerBackupJobSession) | Where-Object { ($_.CreationTime -gt (Get-Date).AddHours(-24)) }
        $recent_computer_backup_sessions = Get-RecentComputerSessions $all_computer_backup_sessions




## Let's do the checks:

# check if every job did run

    # VM BACKUP jobs:
        $desc = "VM Backup"
        $jobs = $backup_vm_jobs.Count
        $sessions = $recent_vm_backup_sessions.Count
        Check-JobRunned $desc $jobs $sessions

    # COMPUTER BACKUP jobs
        $desc = "Computer Backup"
        $jobs = $backup_computer_jobs.Count
        $sessions = ($recent_computer_backup_sessions | Get-Unique).Count
        Check-JobRunned $desc $jobs $sessions

    # COPY jobs:
        # Get the Backup Job IDs from the Copy Job config
        $linked_ids = ($copy_job.LinkedJobIds)

        # Get the Copy Sessions, where I want to find the Backup Job Name that is linked to the $linked_ids
        $copy_sessions = ($recent_copy_sessions)

        # Look in $copy_sessions for the Job Names
        Write-Host ""
        foreach ($id in $linked_ids.Guid) {
            # this is the link between $linked_ids and $backup_vm_jobs.Name
            $findme = (($backup_vm_jobs | Where-Object { $_.id -eq $id }).Name)
            # this is the check
            if ($copy_sessions | Where-Object { $_.Name -like "*$findme*" }) {
                Write-Host "OK: Backup-Job $findme was processed by Copy-Job"
            } else {
                Write-Host ">> ERROR << Backup-Job $findme was NOT processed by Copy-Job"
                $global:errorcount++
            }
        }


# check result for every element in $recent_sessions
    Write-Host ""
    Write-Host "Result of all Jobs:"

    Check-VMSessionResults $recent_vm_backup_sessions
    Check-VMSessionResults $recent_copy_sessions
    Check-ComputerSessionResults $recent_computer_backup_sessions

# finally:
    if ($global:errorcount -eq 0) { Write-Host "`nYeah, looks fantastic" } else { Write-Host "`nOh what a mess :-(" }
    if ($global:errorcount -eq 0) { exit 0 } else { exit 1001 }
