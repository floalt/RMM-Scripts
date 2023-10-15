<#

    nable rmm-script for SNMP Testing

    BUFFALO NAS

    author: flo.alt@fa-netz.de
    https://github/floalt/
    version: 0.6

    command-line:
    -name "NAS-Backup-at-my-Customer" -ipadress 192.168.123.123 -community public -hddnumber 4

#>


# get variable from command line syntax

    param(
        $name,
        $ipadress,
        $community,
        $hddnumber
    )

[int]$errorcount = 0


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


    # Basic SNMP polls including 1 HDD:
    
    $polls = @(
    
        
        @{desc = 'Model Name';oid = '1.3.6.1.4.1.5227.27.1.10.1.0';ok = 'nocheck';compare = ''}
        @{desc = 'Serial Number';oid = '1.3.6.1.4.1.5227.27.1.10.2.0';ok = 'nocheck';compare = ''}
        @{desc = 'Firmware Version Major';oid = '1.3.6.1.4.1.5227.27.1.10.3.0';ok = 'nocheck';compare = ''}
        @{desc = 'Firmware Version Minor';oid = '1.3.6.1.4.1.5227.27.1.10.4.0';ok = 'nocheck';compare = ''}

        @{desc = 'RAID Status';oid = '1.3.6.1.4.1.5227.27.1.3.1.2.1';ok = '4';compare = 'eq'}
        @{desc = 'HDD 1 Model';oid = '1.3.6.1.4.1.5227.27.1.2.1.30.1';ok = 'nocheck';compare = ''}
        @{desc = 'HDD 1 SMART Status';oid = '1.3.6.1.4.1.5227.27.1.2.1.5.1';ok = '1';compare = 'eq'}
        
        # @{desc = '';oid = '';ok = 'nocheck';compare = ''}

        )

    
    # Add more HDDs:

        $poll_2hdds = @(
            @{desc = 'HDD 2 Model';oid = '1.3.6.1.4.1.5227.27.1.2.1.30.2';ok = 'nocheck';compare = ''}
            @{desc = 'HDD 2 SMART Status';oid = '1.3.6.1.4.1.5227.27.1.2.1.5.2';ok = '1';compare = 'eq'}
        )

        $poll_3hdds = @(
            @{desc = 'HDD 3 Model';oid = '1.3.6.1.4.1.5227.27.1.2.1.30.3';ok = 'nocheck';compare = ''}
            @{desc = 'HDD 3 SMART Status';oid = '1.3.6.1.4.1.5227.27.1.2.1.5.3';ok = '1';compare = 'eq'}
        )

        $poll_4hdds = @(
            @{desc = 'HDD 4 Model';oid = '1.3.6.1.4.1.5227.27.1.2.1.30.4';ok = 'nocheck';compare = ''}
            @{desc = 'HDD 4 SMART Status';oid = '1.3.6.1.4.1.5227.27.1.2.1.5.4';ok = '1';compare = 'eq'}
        )

        $poll_5hdds = @(
            @{desc = 'HDD 5 Model';oid = '1.3.6.1.4.1.5227.27.1.2.1.30.5';ok = 'nocheck';compare = ''}
            @{desc = 'HDD 5 SMART Status';oid = '1.3.6.1.4.1.5227.27.1.2.1.5.5';ok = '1';compare = 'eq'}
        )

    # Lets biuld the final array
    
        switch -Wildcard($hddnumber) {
            1 { break } # Nothing to do. Array already contains 1 hdd
            2 { $polls += $poll_2hdds; break }
            3 { $polls += ($poll_2hdds + $poll_3hdds); break }
            4 { $polls += ($poll_2hdds + $poll_3hdds + $poll_4hdds); break }
            5 { $polls += ($poll_2hdds + $poll_3hdds + $poll_4hdds + $poll_5hdds); break }
            * { 
                $errorcount++
                Write-Host "`n >> ERROR: HDD Number $hddnumber ist out of scope. Use [1 - 5] <<`n"
                break}
            }



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

    Write-Host `n$name`n


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
