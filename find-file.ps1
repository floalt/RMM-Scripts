<#
    nable rmm-script for find files
 
    author: flo.alt@fa-netz.de
    https://github/floalt/
    version: 0.5
 
    command-line:
    -filenames "file1.txt", "file2.txt" -searchpath "C:\search\path"
#>

param (
    [string[]]$filenames,
    [string]$searchpath
)

# Clear the variable $found
$found = $null

# Search for files in the specified path
foreach ($filename in $filenames) {
    $filepath = Join-Path -Path $searchpath -ChildPath $filename
    if (Test-Path $filepath -PathType Leaf) {
        Write-Host "File found: $filename"
        $found = 1
    }
}

# If no file is found, set $found to 0
if (-not $found) {
    Write-Host "None of the files were found."
}

if ($found -eq 0) { exit 0 } else { exit 1001 }