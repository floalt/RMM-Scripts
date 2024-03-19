<#

    nable rmm-script for SNMP Testing

    Synology NAS

    author: flo.alt@fa-netz.de
    https://github/floalt/
    version: 0.5

    command-line:
    -name 'NAS Backup at my Customer' -ipadress 192.168.123.123 -community public

#>



# get variable from command line syntax

    param(
        $name,
        $ipadress,
        $community
    )


# set SNMP Polls

    # desc    = description e.g. Model Name
    # oid     = OID
    # ok      = Value to check, if everything is OK or not. See SNMP Data to put the right value in here
    #           If there is no check necessary, i.e. when just poll the device name, enter "nocheck"
    # compare = eq (equal), gt (greater than), lt (less than), no alert if true

    # Example:
    
    #   Model Name:
    #   ok = "nocheck"
    #   so the model name is just displayed without check if the value is ok. Model Name is always ok ;-)

    #   HDD Smart Info:
    #   ok = "good", compare = "eq"
    #   so there is no alert if the result of the test equals "good"

    #   CPU Temparature:
    #   ok = 60, compare = "lt"
    #   so there is no alert if the result of the test is less than 60 degree

    
    $polls = @(
        @{desc = 'Model Name';oid = '.1.3.6.1.4.1.6574.1.5.1.0';ok = 'nocheck';compare = ''}
        @{desc = 'Serial Number';oid = '.1.3.6.1.4.1.6574.1.5.2.0';ok = 'nocheck';compare = ''}
        @{desc = 'Version';oid = '.1.3.6.1.4.1.6574.1.5.3.0';ok = 'nocheck';compare = ''}
        @{desc = 'System Status';oid = '.1.3.6.1.4.1.6574.1.1.0';ok = '1';compare = 'eq'}
        @{desc = 'System Temperature';oid = '.1.3.6.1.4.1.6574.1.2.0';ok = '61';compare = 'lt'}
        @{desc = 'System Fan Status';oid = '.1.3.6.1.4.1.6574.1.4.1.0';ok = '1';compare = 'eq'}
        @{desc = 'CPU Fan Status';oid = '.1.3.6.1.4.1.6574.1.4.2.0';ok = '1';compare = 'eq'}

        @{desc = 'HDD 1 Model';oid = '.1.3.6.1.4.1.6574.2.1.1.3.0';ok = 'nocheck';compare = ''}
        @{desc = 'HDD 1 Health Status';oid = '.1.3.6.1.4.1.6574.2.1.1.13.0';ok = '1';compare = 'eq'}
        @{desc = 'HDD 1 Temperature';oid = '.1.3.6.1.4.1.6574.2.1.1.6.0';ok = '60';compare = 'lt'}
        @{desc = 'HDD 2 Model';oid = '.1.3.6.1.4.1.6574.2.1.1.3.1';ok = 'nocheck';compare = ''}
        @{desc = 'HDD 2 Health Status';oid = '.1.3.6.1.4.1.6574.2.1.1.13.1';ok = '1';compare = 'eq'}
        @{desc = 'HDD 2 Temperature';oid = '.1.3.6.1.4.1.6574.2.1.1.6.1';ok = '60';compare = 'lt'}

        @{desc = 'RAID Volume Status';oid = '.1.3.6.1.4.1.6574.3.1.1.3.0';ok = '1';compare = 'eq'}
        @{desc = 'RAID StoragePool Status';oid = '.1.3.6.1.4.1.6574.3.1.1.3.1';ok = '1';compare = 'eq'}
        
        # @{desc = '';oid = '';ok = 'nocheck';compare = ''}
    )



## Functions #####

# Poll SNMP info by OID
    
    # loop to retry in case of timeout:
    
    function Poll-SNMP ($oid) {
    
        $maxRetries = 10
        $retryInterval = 1

        for ($i = 1; $i -le $maxRetries; $i++) {
    
            $result = Get-SnmpData -IP $ipadress -Community $community -OID $oid -WarningAction SilentlyContinue

            if ($result) {
                # Write-Host "The result within the for-loop" $result
                return $result
            } else {     # $result is empty in case of timeout
                if ($i -lt $maxRetries) {
                    # Write-Host "Timeout... Try again in $retryInterval second(s)"
                    Start-Sleep -Seconds $retryInterval
                } else {
                    # Write-Host "Max retries reached"
                    $result = "<< timeout >>"
                }
            }
        }
    }



## Start the action #####

    [int]$errorcount = 0

    Write-Host `n "$name" `n


# check if snmp package ist installed / install if not

    $modinst = (Get-Module -ListAvailable *snmp*)
    
    if (!$modinst) {
    Write-Host "INFO: PS-Module SNMP ist not installed. Now installing..."
        Install-Package snmp -Force

        $modinst = (Get-Module -ListAvailable *snmp*)
        if ($modinst) {
            Write-Host "OK: PS-Module installed successfully.`n"
        } else {
            Write-Host "FAIL: PS-Module cannot be installed. Please check locally.`n"
            exit 1001
        }
    }



# poll all the snmp infos

	foreach ($poll in $polls) {
		
        $desc = $poll.desc
		$oid = $poll.oid
        $ok = $poll.ok
        $compare = $poll.compare
		
		$result = (Poll-SNMP -oid $oid)          # poll the smtp info
        # Write-Host "Result in the foreach: "$result
        Write-Host $desc": " $result.Data        # tell me about it
        
        # ok or not ok?

            switch ($compare) {
                eq {
                    if (!($result.DATA -eq $ok)) {
                        $errorcount++
                        Write-Host $desc": ^^ Error ^^`n"
                    }
                    break
                }
                gt {
                    if (!($result.DATA -gt $ok)) {
                        $errorcount++
                        Write-Host $desc": ^^ Error ^^`n"
                    }
                    break
                }
                lt {
                    if (!($result.DATA -lt $ok)) {
                        $errorcount++
                        Write-Host $desc": ^^ Error ^^`n"
                    }
                    break
                }
            }
	}



# finally:

if ($errorcount -eq 0) { Write-Host "`nYeah, looks fantastic" } else { Write-Host "`nOh what a mess :-(" }
if ($errorcount -eq 0) { exit 0 } else { exit 1001 }
