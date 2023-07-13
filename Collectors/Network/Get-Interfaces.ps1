<#
.DEPENDENCY 
.PSM_DEPENDENCY DataTransfer.psm1 

.SYNOPSIS
Gets information about all network interfaces

.NOTES
License: 
Credits: Connor Martin
#>



#Connection Status struct
$ConnectionStatus = @{""=""; "0"="Disconnected"; "1"="Connecting"; "2"="Connected"; "4"="Hardware Not Present"; 
    "5"="Hardware Disabled"; "6"="Hardware Malfunction"; "7"="Media Disconnected"; "8"="Authenticating"; "9"="Authentication Succeeded";
    "10"="Authentication Failed"; "11"="Invalid Address"; "12"="Credentials Required"}


#Get both wmi classes
$NetAdapters = Get-WmiObject -Class Win32_NetworkAdapter
[array] $Interfaces = Get-WmiObject -Class Win32_NetworkAdapterConfiguration

#Combine the two classes and enrich some data.
foreach ($Interf in $Interfaces)
 {
    if ($null -ne $Interf) # PS2.0 check
    {
        #Parse IP Address into either IPv4 or IPv6
        $IPv4 = ""
        $IPv6 = ""
        foreach ($IP in $Interf.IPAddress) 
        {
            if ($null -ne $IP) # PS2.0 check
            {
                if ($IP.indexof('.') -ne -1)
                {
                    $IPv4 += $IP + " "
                }
                elseif ($IP.indexof(':') -ne -1)
                {
                    $IPv6 += $IP + " "
                }

                # [ipaddress]$Addr = $null
                # if ([ipaddress]::TryParse($IP, [ref]$Addr)) 
                # {
                #     if ($Addr.AddressFamily -eq "InterNetwork") 
                #     {
                #         $IPv4 += $Addr.IPAddressToString + " "
                #     }
                #     elseif ($Addr.AddressFamily -eq "InterNetworkV6") 
                #     {
                #         $IPv6 += $Addr.IPAddressToString + " "
                #     }
                # } 
            }
        }
        
        #Add address to results
        $Interf | Add-Member -MemberType NoteProperty -Name "IPv4Address" -Value $IPv4
        $Interf | Add-Member -MemberType NoteProperty -Name "IPv6Address" -Value $IPv6  


        #Parse Default Gateway into either IPv4 or IPv6
        $IPv4 = ""
        $IPv6 = ""
        foreach ($IP in $Interf.DefaultIPGateway) 
        {
            if ($null -ne $IP) # PS2.0 check
            {
                if ($IP.indexof('.') -ne -1)
                {
                    $IPv4 += $IP + " "
                }
                elseif ($IP.indexof(':') -ne -1)
                {
                    $IPv6 += $IP + " "
                }
            }
        }

        #Add gateway to results
        $Interf | Add-Member -MemberType NoteProperty -Name "DefaultIPv4Gateway" -Value $IPv4
        $Interf | Add-Member -MemberType NoteProperty -Name "DefaultIPv6Gateway" -Value $IPv6  


        #Grab Additional fields from $NetAdapter
        foreach ($NetA in $NetAdapters)
        {
            if ($null -ne $NetA) # PS2.0 check
            {
                if ($NetA.InterfaceIndex -eq $Interf.InterfaceIndex)
                {
                    $Interf | Add-Member -MemberType NoteProperty -Name "NetConnectionID" -Value $NetA.NetConnectionID
                    $Interf | Add-Member -MemberType NoteProperty -Name "NetConnectionStatus" -Value $ConnectionStatus["$($NetA.NetConnectionStatus)"]
                    break;
                }
            }
        }
    }
}


$Interfaces = $Interfaces | Select-Object "PSComputerName", "Index", "NetConnectionID", "ServiceName", "Description", "IPEnabled", "NetConnectionStatus", `
        "DHCPEnabled", `
        "MACAddress", "IPv4Address", "IPv6Address", `
        "DefaultIPv4Gateway", "DefaultIPv6Gateway", "DNSHostName", "DHCPServer", "DNSDomain", `
        "DHCPLeaseExpires", "DHCPLeaseObtained",  "WINSPrimaryServer", "WINSSecondaryServer"


YACKPipe-ReturnCSV -PowershellObjects $Interfaces -OutputName "Interfaces.csv" 
