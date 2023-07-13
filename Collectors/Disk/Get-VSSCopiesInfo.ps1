<#
.DEPENDENCY 
.PSM_DEPENDENCY DataTransfer.psm1 

.SYNOPSIS
Returns properties from Volume shadow copies.

.NOTES
License: Apache License 2.0 
Credits: Connor Martin.
#>


$ShadowCopies = Get-WmiObject -Class Win32_ShadowCopy
$ShadowCopies = $ShadowCopies | Select-Object PSComputerName, InstallDate,DeviceObject, Name, ID, VolumeName, `
                ClientAccessible, Differential, HardwareAssisted, Plex, `
                Persistent, ExposedLocally, ExposedRemotely

YACKPipe-ReturnCSV -PowershellObjects $ShadowCopies -OutputName "VSSCopiesInfo.csv"
