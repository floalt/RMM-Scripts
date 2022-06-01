<#
description

    Checks the bitlocker state of local hard disk
    Can be (should be!) integrated in n-able RMM

author: flo.alt@fa-netz.de

#>
$logfile = "C:\Windows\Temp\bitlocker-enable.log"
$encryptvolume = (Get-BitLockerVolume | Where-Object {$_.VolumeType -eq "OperatingSystem"})

switch ($encryptvolume.VolumeStatus) {
    FullyEncrypted {
        write-host "OK: Local Disk is Fully encrpyted"; exit 0
    }
    EncryptionInProgress {
        $percentage = ($encryptvolume.EncryptionPercentage)
        write-host "INFO: Encryption is in progress: $percentage%"
        exit 1001
    }
    FullyDecrypted {
        if (test-path $logfile) {
            write-host "INFO: Encryption is enabled, but waiting for reboot to start encrypting"
        }
        else {
            write-host "WARNING: Local Disk is NOT encrpyted"
        }
        exit 1001
    }
    Default {
        Write-Host "WARNING: Something strange has happened. Please check locally."
        exit 1001
    }
}
