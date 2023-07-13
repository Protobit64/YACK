<#
.DEPENDENCY 
.PSM_DEPENDENCY DataTransfer.psm1 

.SYNOPSIS
Gets a list of mapped network drivers.

.NOTES
License: 
Credits: POSH-R2. Connor Martin
#>


$Drives = Get-WmiObject -Class win32_mappedlogicaldisk | select PSComputername, Name, ProviderName 

YACKPipe-ReturnCSV -PowershellObjects $Drives -OutputName "MappedDrives.csv" 
