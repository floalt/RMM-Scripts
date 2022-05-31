<#
description:
    This is a script for N-able RMM
    Checks if the SQL-DUMP was made last night

author: flo.alt@fa-netz.de
version: 0.1


usage:

    -Folder "path/to/folder/where/dumps/are/in"
    -Age 24        (Age in hours, default 24)
    -MinSize 500   (size in MB)

    N-able Command Line:

        -Folder C:\SQLDumps -Age 12 -MinSize 500


#>


param(
    $Folder,
    $Age,
    $MinSize
)



# convert $MinSize from MB to byte
    
    [int]$size_byte = [int]$MinSize * 1048576


# timestamp for Age
    
    # set default value
        if (!($Age)) {$Age = 24}
    
    # calculate
        [int]$Age = "-" + $Age
        $CurrentDate = Get-Date
        $check_date = $CurrentDate.AddHours($Age)


# do the test

$check = ""
$check = Get-ChildItem -Path $folder | where { ($_.Length -gt $size_byte) -and ($_.LastWriteTime -gt $check_date) }


# print all available dumps

    Get-ChildItem -Path $folder | where { $_.Extension -eq ".BAK" }| ft Name,Length,LastWriteTime

# if ($check) { $code = 0 } else { $code = 1001 }
if ($check) { exit 0 } else { exit 1001 }
