<#
.DEPENDENCY 
.PSM_DEPENDENCY DataTransfer.psm1 

.SYNOPSIS
Gets ARP table contents

.NOTES
License: Apache License 2.0
Credits: kansa(github).
#>



$AllEvents = New-Object System.Collections.ArrayList

#Parse arp.exe into an array.
$IpPattern = "\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}"

foreach ($Line in (& $env:windir\system32\arp.exe -a)) 
{
    if ($null -ne $Line) # PS2.0 check
    {
        $Line = $Line.Trim()
        if ($Line.Length -gt 0) 
        {
            if ($Line -match 'Interface:\s(?<Interface>\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\s.*') 
            {
                $Interface = $matches['Interface']
            } 
            elseif ($Line -match '(?<IpAddr>\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\s+(?<Mac>[0-9A-Fa-f]{2}\-[0-9A-Fa-f]{2}\-[0-9A-Fa-f]{2}\-[0-9A-Fa-f]{2}\-[0-9A-Fa-f]{2}\-[0-9A-Fa-f]{2})*\s+(?<Type>dynamic|static)') 
            {
                $IpAddr = $matches['IpAddr']
                if ($matches['Mac']) 
                {
                    $Mac = $matches['Mac']
                } 
                else 
                {
                    $Mac = ""
                }   
                $Type   = $matches['Type']
                $Obj = "" | Select-Object Interface, IpAddr, Mac, Type
                $Obj.Interface, $Obj.IpAddr, $Obj.Mac, $Obj.Type = $Interface, $IpAddr, $Mac, $Type

                [void]$AllEvents.Add($Obj)
            }
        }
    }
}



YACKPipe-ReturnCSV -PowershellObjects $AllEvents.ToArray() -OutputName "ARPTable.csv" 

