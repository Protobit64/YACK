
<#
.DEPENDENCY AppCompatCacheParser.exe
.PSM_DEPENDENCY DataTransfer.psm1 

.SYNOPSIS
AKA ShimCache
Tracks the executables file name, file size, last modified time, and in Windows XP the last update time  - SANS

.NOTES
Credit: Eric Zimmerman. Connor Martin for YACK
License: MIT License
https://github.com/EricZimmerman/AppCompatCacheParser
#>


$BinPath = "$env:SystemRoot\yack\AppCompatCacheParser.exe"

#check if binary exists
if (Test-Path $BinPath) 
{
    $OutputFolder = "$env:SystemRoot\yack\AppCompact\"
    $temp = (& $BinPath "--csv" "$OutputFolder" "-t")

    #Read in results
    $CSVAppCompactCache = Get-ChildItem $OutputFolder

    if ($CSVAppCompactCache)
    {
        # I could just copy back the csv but it's small enough that it doesn't really matter
        $PSAppCompactCache = Import-Csv $CSVAppCompactCache[0].FullName
        YACKPipe-ReturnCSV -PowershellObjects $PSAppCompactCache -OutputName "AppCompactCache.csv"

        #Cleanup
        #Remove the copied item from temp
        Remove-Item -Path $CSVAppCompactCache[0].FullName
    }
    else 
    {
        YACKPipe-ReturnError -ErrorMessage "No results from AppCompatCacheParser were produced."    
    }
}
else 
{
    YACKPipe-ReturnError -ErrorMessage "Couldn't find $BinPath"
}

