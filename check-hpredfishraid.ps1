<#
description:

    Checks RAID Health via ILO Redfish API

usage:
    
    Edit local host-file for ILO-Hostname
    Make self-signed certificate for ILO, because Powershell 5.x cannot handle -SkipCertificateCheck yet
    
    Set the expectes number of hdds in $hddnumber

    N-able Command Line:

        -ilohostname ILOXXXXXXXX -user Administrator -pass xxxxxxxxxx -hddnumber 2

author: flo.alt@fa-netz.de

#>


# Get variables from command line syntax
param(
    [string]$ilohostname,
    [string]$user,
    [string]$pass,
    [int]$hddnumber
)

[int]$errorcount = 0

# Redfish API Base URL
$baseUrl = "https://$ilohostname/redfish/v1"

# Function to query Redfish API with authentication
function Invoke-RedfishQuery {
    param(
        [string]$url
    )
    try {
        $authHeader = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${user}:${pass}"))
        return Invoke-RestMethod -Uri $url -Method Get -Headers @{ Authorization = "Basic $authHeader" }
    } catch {
        Write-Host "Error querying Redfish API: $_"
        $global:errorcount++  # Zugriff auf global:errorcount
        return $null
    }
}

# Function to check RAID Health
function Get-RAIDHealth {
    Write-Host "Checking RAID Health..."
    $storageUrl = "$baseUrl/Systems/1/Storage/DA000002"
    $response = Invoke-RedfishQuery -url $storageUrl

    if ($response) {
        $health = $response.Status.Health
        if ($health -eq "OK") {
            Write-Host "RAID is very healthy."
        } else {
            Write-Host "RAID is not feeling well: $health"
            $global:errorcount++  # Zugriff auf global:errorcount
        }
    }
}

# Function to check HDD states
function Get-HDDState {
    Write-Host "Checking HDD States..."
    $storageUrl = "$baseUrl/Systems/1/Storage/DA000002"
    $response = Invoke-RedfishQuery -url $storageUrl

    if ($response -and $response.Drives) {
        $foundDrives = $response.Drives.Count  # Zählt die gefundenen Festplatten
        if ($foundDrives -ne $hddnumber) {
            Write-Host "Warning: Expected $hddnumber drives, but found $foundDrives."
            $global:errorcount++  # Zugriff auf global:errorcount
        }

        foreach ($drive in $response.Drives) {
            $relativeDriveUrl = $drive.'@odata.id'.Replace("/redfish/v1", "")
            $driveUrl = "$baseUrl$relativeDriveUrl"
            $driveResponse = Invoke-RedfishQuery -url $driveUrl

            if ($driveResponse) {
                $model = $driveResponse.Model
                $health = $driveResponse.Status.Health
                if ($model -and $health) {
                    Write-Host "Model: $model, Health: $health"
                } else {
                    Write-Host "Could not retrieve model or health status for drive: $driveUrl"
                    $global:errorcount++  # Zugriff auf global:errorcount
                }
            }
        }
    } else {
        Write-Host "No drives found in the storage subsystem."
        $global:errorcount++  # Zugriff auf global:errorcount
    }
}

# Main Execution
Get-RAIDHealth
Get-HDDState

# Final Status
if ($global:errorcount -eq 0) {  # Zugriff auf global:errorcount
    Write-Host "`nYeah, looks fantastic!"
    exit 0
} else {
    Write-Host "`nOh, what a mess :-("
    exit 1001
}
