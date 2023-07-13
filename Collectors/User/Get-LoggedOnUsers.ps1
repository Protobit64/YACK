<#
.DEPENDENCY
.PSM_DEPENDENCY DataTransfer.psm1 

.SYNOPSIS
Retreives all current logons including local service accounts.

.NOTES
License: 
Credits: mjolinor. Connor Martin.
#>

function Get-WMILoggedOnUsers
{
    <#
    .SYNOPSIS
    Retreives all current logons using wmi classes.

    .NOTES
    License: 
    Credits: mjolinor. Connor Martin.
    #>

    #mjolinor 3/17/10  
    $RegexA = '.+Domain="(.+)",Name="(.+)"$'
    $RegexD = '.+LogonId="(\d+)"$'

    $LogonType = @{
    "0"="Local System"
    "2"="Interactive" #(Local logon)
    "3"="Network" # (Remote logon)
    "4"="Batch" # (Scheduled task)
    "5"="Service" # (Service account logon)
    "7"="Unlock" #(Screen saver)
    "8"="NetworkCleartext" # (Cleartext network logon)
    "9"="NewCredentials" #(RunAs using alternate credentials)
    "10"="RemoteInteractive" #(RDP\TS\RemoteAssistance)
    "11"="CachedInteractive" #(Local w\cached credentials)
    }

    $LogonSessions = @(gwmi win32_logonsession)
    $LogonUsers = @(gwmi win32_loggedonuser)

    $SessionUser = @{}

    $LogonUsers |% {
        $_.antecedent -match $RegexA > $nul
        $Username = $matches[1] + "\" + $matches[2]
        $_.dependent -match $RegexD > $nul
        $Session = $matches[1]
        $SessionUser[$Session] += $Username
    }


    #Begin - Connor Martin

    $SessionProcesses = Get-WmiObject Win32_SessionProcess
    $UsersToRemove = New-Object System.Collections.ArrayList

    #Filter out sessions that dont have anything running under them. IE they are dead
    foreach ($User in $SessionUser.GetEnumerator())
    {
        if ($null -ne $User) # PS2.0 check
        {
            $MatchFound = $false
            foreach ($SesProc in $SessionProcesses)
            {
                if ($null -ne $SesProc) # PS2.0 check
                {
                    if ($SesProc.Antecedent -like "*`"$($User.Name)`"*" )
                    {
                        $MatchFound = $true
                        break;
                    }
                }
            }

            if ($MatchFound -eq $false)
            {
                #null out the username since it no longer is active
                $null = $UsersToRemove.Add($User.Name)
            }
        }
    }

    #Remove marked users
    foreach ($User in $UsersToRemove)
    {
        if ($null -ne $User)
        {
            $SessionUser.Remove($User)
        }
    }
    #ENd Connor Martin




    foreach ($LogSes in $LogonSessions)
    {
        if (($null -ne $LogSes) -and ($null -ne $SessionUser[$LogSes.logonid]))
        {
            $StartTime = [management.managementdatetimeconverter]::todatetime($LogSes.starttime)

            $LoggedOnUser = New-Object -TypeName psobject
            $LoggedOnUser | Add-Member -MemberType NoteProperty -Name "Session" -Value $LogSes.logonid
            $LoggedOnUser | Add-Member -MemberType NoteProperty -Name "User" -Value $SessionUser[$LogSes.logonid]
            $LoggedOnUser | Add-Member -MemberType NoteProperty -Name "Type" -Value $LogonType[$LogSes.logontype.tostring()]
            $LoggedOnUser | Add-Member -MemberType NoteProperty -Name "Auth" -Value $LogSes.authenticationpackage
            $LoggedOnUser | Add-Member -MemberType NoteProperty -Name "StartTime" -Value $StartTime

            $LoggedOnUser
        }
    }
}



$Results = Get-WMILoggedOnUsers


YACKPipe-ReturnCSV -PowershellObjects $Results -OutputName "LoggedOnUsers.csv"

