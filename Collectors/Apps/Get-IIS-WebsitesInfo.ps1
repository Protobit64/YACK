<#
.DEPENDENCY 
.PSM_DEPENDENCY DataTransfer.psm1 

.SYNOPSIS
Gets general information about the websites that are hosted on a server

.OUTPUTS


.NOTES
License: 
Credits: Connor Martin.
#>



#modify execution policy for this session
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope Process -Confirm:$false


#Import web aministration ps modules
$ImportWorked = $true
try {
    Import-Module WebAdministration -ErrorAction Stop
    $ImportWorked = $true
}
catch {
    $ImportWorked = $false
}


if ($ImportWorked)
{
    $WebInfo = Get-Website 

    #Convert Bindings to a string
    Foreach ($Site in $WebInfo) 
    { 
        Foreach ($Bind in $Site.bindings.collection) 
        {
            if ($null -ne $Bind) # PS2.0 check
            {
                $Site | Add-Member -MemberType NoteProperty -Name "BindingsString" -Value "$($Bind.Protocol)$($Bind.BindingInformation)$($Site.name) `n"
            }
        }
    }

    $WebInfo = $WebInfo | Select-Object Id, Name, State, ServerAutoStart, EnabledProtocols, BindingsString, PhysicalPath, @{l="LogPath";e={$_.LogFile.directory}}

    YACKPipe-ReturnCSV -PowershellObjects $WebInfo -OutputName "WebsitesInfo.csv"
}
else 
{
    YACKPipe-ReturnError "Couldn't import web administration ps module"
}