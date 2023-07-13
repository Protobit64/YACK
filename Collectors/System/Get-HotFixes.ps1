
<#
.DEPENDENCY
.PSM_DEPENDENCY DataTransfer.psm1 

.SYNOPSIS
Retreives all installed windows hotfixes.

.NOTES
License: 
Credits: Connor Martin.
#>



$HotFixes = Get-WmiObject -Class win32_quickfixengineering | Select-Object PSComputername, InstalledOn, HotFixID, InstalledBy, Description


YACKPipe-ReturnCSV -PowershellObjects $HotFixes -OutputName "HotFixes.csv"
