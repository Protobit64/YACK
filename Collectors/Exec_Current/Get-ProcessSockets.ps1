<#
.DEPENDENCY 
.PSM_DEPENDENCY DataTransfer.psm1 

.SYNOPSIS
Acquires netstat -naob output and reformats the data
and ties it back to a process.

.NOTES
License: Apache License 2.0
Credits: kansa(github) // Connor Martin
#>



function Get-AddrPort 
{
    <#
    .SYNOPSIS
    Splits a netstat address:port into seperate variables
    #>

Param([Parameter(Mandatory=$True,Position=0)]
        [String]$AddrPort)

    if ($AddrPort -match '[0-9a-f]*:[0-9a-f]*:[0-9a-f%]*\]:[0-9]+') 
    {
        $Addr, $Port = $AddrPort -split "]:"
        $Addr += "]"
    } 
    else 
    {
        $Addr, $Port = $AddrPort -split ":"
    }
    $Addr, $Port
}
    

$AllEvents = New-Object System.Collections.ArrayList

#Parse netstat output and finds owner processes
$NetstatScriptBlock = { & $env:windir\system32\netstat.exe -naob }
foreach($Line in $(& $NetstatScriptBlock)) 
{
    if ($Line.length -gt 1 -and $Line -notmatch "Active |Proto ") 
    {
        $Line = $Line.trim()
        if ($Line.StartsWith("TCP")) 
        {
            $Protocol, $LocalAddress, $ForeignAddress, $State, $ConPId = ($Line -split '\s{2,}')
            $Component = $Process = $False
        } 
        elseif ($Line.StartsWith("UDP")) 
        { 
            $State = "STATELESS"
            $Protocol, $LocalAddress, $ForeignAddress, $ConPid = ($Line -split '\s{2,}')
            $Component = $Process = $False
        } 
        elseif ($Line -match "^\[[-_a-zA-Z0-9.]+\.(exe|com|ps1)\]$") 
        {
            $Process = $Line.trim('[]')
            if ($Component -eq $False) 
            {
                # No Component given
                $Component = ""
            }
        } 
        elseif ($Line -match "Can not obtain ownership information") 
        {
            $Process = $(Get-Process -Id $ConPId).Name
            $Component = ""
        } 
        else 
        {
            # We have the $Component
            $Component = $Line
        }

        if ($State -match "TIME_WAIT") 
        {
            $Process = $(Get-Process -Id $ConPId).Name
            $Component = ""
        }

        if ($Process) 
        {
            $LocalAddress, $LocalPort = Get-AddrPort($LocalAddress)
            $ForeignAddress, $ForeignPort = Get-AddrPort($ForeignAddress)

            #Select appropriate members
            $Obj = "" | Select-Object "Process", Component, PID, Protocol, LocalAddress, LocalPort, RemoteAddress, RemotePort, State

            $Obj.Process, $Obj.Component, $Obj.PID, $Obj.Protocol, $Obj.LocalAddress, $Obj.LocalPort, $Obj.RemoteAddress, $Obj.RemotePort, $Obj.State = `
                $Process, $Component, $ConPid, $Protocol, $LocalAddress, $LocalPort, $ForeignAddress, $ForeignPort, $State
            
            [void]$AllEvents.Add($Obj)
        }
    }
}


YACKPipe-ReturnCSV -PowershellObjects $AllEvents.ToArray() -OutputName "ProcessSockets.csv" 

