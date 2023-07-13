
<#
.DEPENDENCY
.PSM_DEPENDENCY DataTransfer.psm1 

.SYNOPSIS
Retreives general info about the system.

.NOTES
License: 
Credits: Connor Martin. POSH-R2
#>


$Info = Get-WmiObject -Class win32_computersystem  | `
    Select-Object PSComputername, Domain, Workgroup, Model, Manufacturer, EnableDaylightSavingsTime, CurrentTimeZone, `
    DNSHostName, PartOfDomain, @{l="Roles";e={"$($_.Roles)"}}, SystemType, NumberOfLogicalProcessors, TotalPhysicalMemory, Username, SystemSKUNumber


YACKPipe-ReturnCSV -PowershellObjects $Info -OutputName "GeneralInfo.csv"

