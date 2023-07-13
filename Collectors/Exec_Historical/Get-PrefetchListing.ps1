
<#
.DEPENDENCY 
.PSM_DEPENDENCY DataTransfer.psm1 

.SYNOPSIS
Prints a listing of prefetch files.

Prefetch files contain the name of the executable, a Unicode list of DLLs used 
by that executable, a count of how many times the executable has been run, and a 
timestamp indicating the last time the program was run. (https://www.forensicswiki.org/wiki/Prefetch)

Win XP+


.NOTES
License: Apache License 2.0
Credits: kansa(github).
#>


$PrefetchListing = Get-ChildItem -Path "C:\Windows\Prefetch" | Where-Object { ! $_.PSIsContainer } |  Sort-Object LastWriteTime | 
        Select-Object FullName, Name, Mode, Length, CreationTimeUtc, LastAccessTimeUtc, LastWriteTimeUtc

YACKPipe-ReturnCSV -PowershellObjects $PrefetchListing -OutputName "PrefetchListing.csv"