<#
.DEPENDENCY
.PSM_DEPENDENCY DataTransfer.psm1 

.SYNOPSIS
Collects installed software from the system by using the
uninstall registry key.

.NOTES
License: 
Credits: Connor Martin.
#>



$CollectorResult = "" | Select-Object Error, ErrorMessage, OutputType, OutputName, OutputFolder, Content

#win32_product causes a package validation check and can cause reconfiguration. It's not passive
#$CollectorResult.Content = Get-WmiObject -Class win32_product 

#So use uninstall registry key
$RegPath = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
$RegPath2 = 'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'

if ((Test-Path $RegPath) -or (Test-Path $RegPath2))
{
    
    $AllInstalled = @()
    if(Test-Path $RegPath)
    {
        $AllInstalled += Get-ItemProperty $RegPath | `
            Select-Object @{l="ComputerName";e={$env:COMPUTERNAME}}, DisplayName, DisplayVersion, Publisher, InstallDate, InstallLocation
    }

    if(Test-Path $RegPath2)
    {
        $AllInstalled += Get-ItemProperty $RegPath2 | `
            Select-Object @{l="ComputerName";e={$env:COMPUTERNAME}}, DisplayName, DisplayVersion, Publisher, InstallDate, InstallLocation
    }

    #Remove Empty Entries
    $AllInstalled = $AllInstalled| Where-Object {$_.DisplayName} 

    #Remove Duplicate Entries and sort A-Z
    $AllInstalled = $AllInstalled | Select-Object * -Unique | Sort-Object DisplayName

    YACKPipe-ReturnCSV -PowershellObjects $AllInstalled -OutputName "InstalledSoftware.csv"
}
else 
{
    YACKPipe-ReturnError "Could not find either uninstall registry key"
}