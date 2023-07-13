<#
.DEPENDENCY 
.PSM_DEPENDENCY DataTransfer.psm1 

.SYNOPSIS
Check if you have the ability to run the modules.

.NOTES
License: 
Credits: Connor Martin.
#>



function Test-AdminPriv 
{
    <#
    .SYNOPSIS
    Checks if you are running with admin privs
    #>

    ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

}

function Test-Powershell 
{
    <#
    .SYNOPSIS
    Checks if powershell is up to date
    #>

    ($PSVersionTable.PSVersion.Major -ge 2)
}


$ReturnString = ""

$PrivTest = $(Test-AdminPriv)
$ReturnString += "Admin:" + $PrivTest + "`r`n"

$PSTest = $(Test-Powershell)
$ReturnString += "Powershell Support:" + $PSTest + "`r`n"


YACKPipe-ReturnArray -ArrayResult $ReturnString -OutputName "privs.txt" -YACKOutputFolder "misc"