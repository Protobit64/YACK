
<#
.DEPENDENCY
.PSM_DEPENDENCY DataTransfer.psm1 

.SYNOPSIS
Collects system enviromental variable.

.NOTES
License: 
Credits: Connor Martin.
#>

$EnvVaraible = Get-WmiObject -Class win32_environment | Select-Object PSComputername, UserName, Name, VariableValue, SystemVariable

YACKPipe-ReturnCSV -PowershellObjects $EnvVaraible -OutputName "ENVVar.csv"