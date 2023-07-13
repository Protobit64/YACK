<#
.DEPENDENCY autorunsc.exe
.PSM_DEPENDENCY DataTransfer.psm1 

.SYNOPSIS
Runs autorunsc.exe and returns the results in csv format.

.NOTES
License: Apache License 2.0
Credits: kansa(github).
#>



$AllEvents = New-Object System.Collections.ArrayList

#C:\Users\conno\AppData\Local\Temp\yack

if (Test-Path "$env:SystemRoot\yack\autorunsc.exe") 
{
    & "$env:SystemRoot\yack\autorunsc.exe" /accepteula -a * -c -h -s -nobanner -t '*' 2> $null | `
        ConvertFrom-Csv | `
        ForEach-Object {[void]$AllEvents.Add($_)}

    YACKPipe-ReturnCSV -PowershellObjects $AllEvents.ToArray() -OutputName "AutoRuns.csv" 
} 
else 
{
    YACKPipe-ReturnError "Couldn't find Autorunsc.exe"
}