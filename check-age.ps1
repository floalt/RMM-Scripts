<#
description:

    Checks if $file exists
    and if is older than $days

usage:

    -file 'path/to/file'
                   (don't use: "  use instead: ' )
    -days X        (max age in days)
    
    N-able Command Line:

        -file 'C:\This is the Folder\and this ist the file.txt' -days 7

author: flo.alt@fa-netz.de

#>

param (
    $file,
    $days
)

if (!(Test-Path $file)) {
    Write-Host "File does not exist"
    exit 1001
}

if (Test-Path $file -OlderThan (Get-Date).AddDays(-$days)) {
    Write-Host File is older than $days days
    Write-Host Last Write Time: $(Get-ChildItem $file).LastWriteTime
    exit 1001
} else {
    Write-Host Last Write Time: $(Get-ChildItem $file).LastWriteTime
    exit 0
}