<#
.DEPENDENCY autorunsc.exe
.PSM_DEPENDENCY DataTransfer.psm1 

.SYNOPSIS
Runs autorunsc.exe and returns the running drivers.

.NOTES
License: Apache License 2.0
Credits: kansa(github).

Services and Drivers are stored in HKLM:\System\CurrentControlSet\Services\
Drivers require signing from vista 64bit and onwards. Services do not.
PnP drivers are installed when a PNP device is attached. Windows services INF for a compatible .inf script
Windows checks the files against a .cat file (which is a digital sig of all the files)
The term "PnP driver" refers to any Windows driver that supports the interfaces described in this section.
#>


function Compute-FileHash 
{
    <#
    .SYNOPSIS
    Computes the hash of a file.
    
    .PARAMETER FilePath
    The path to the file to hash
    
    .PARAMETER HashType
    The type of hash to compute
    #>
    Param(
        [Parameter(Mandatory = $true, Position=1)]
        [string]$FilePath,
        [ValidateSet("MD5","SHA1","SHA256","SHA384","SHA512","RIPEMD160")]
        [string]$HashType = "MD5"
    )
    
    switch ( $HashType.ToUpper() )
    {
        "MD5"       { $hash = [System.Security.Cryptography.MD5]::Create() }
        "SHA1"      { $hash = [System.Security.Cryptography.SHA1]::Create() }
        "SHA256"    { $hash = [System.Security.Cryptography.SHA256]::Create() }
        "SHA384"    { $hash = [System.Security.Cryptography.SHA384]::Create() }
        "SHA512"    { $hash = [System.Security.Cryptography.SHA512]::Create() }
        "RIPEMD160" { $hash = [System.Security.Cryptography.RIPEMD160]::Create() }
        default     { "Invalid hash type selected." }
    }

    if (Test-Path $FilePath) 
    {
        #Read the file and compute the hash
        $FileName = Get-ChildItem -Force $FilePath | Select-Object -ExpandProperty Fullname
        $FileData = [System.IO.File]::ReadAllBytes($FileName)
        $HashBytes = $hash.ComputeHash($FileData)

        #Convert hash bytes into a string
        $PaddedHex = ""
        foreach($Byte in $HashBytes) 
        {
            if ($null -ne $Byte) # PS2.0 check
            {
                $ByteInHex = [String]::Format("{0:X}", $Byte)
                $PaddedHex += $ByteInHex.PadLeft(2,"0")
            }
        }
        $PaddedHex
        
    } 
    else 
    {
        "$FilePath is invalid or locked."
        Write-Error -Message "$FilePath is invalid or locked." -Category InvalidArgument
    }
}


$Drivers = ""

#Check if autorunsc.exe exists
if (Test-Path "$env:SystemRoot\yack\autorunsc.exe") 
{
    #Get all running Drivers and Services
    $ServAndDrivers = $( & "$env:SystemRoot\yack\autorunsc.exe" /accepteula -a s -c -s -nobanner -t '*' 2> $null | ConvertFrom-Csv)


    #Get Drivers and remove empty entries.
    $Drivers = $ServAndDrivers | Where-Object {($_.Category -eq "Drivers") -and ($_.Entry -ne "")}

    #Compute the hash of each driver
    foreach ($Driver in $Drivers)
    {
        if ($null -ne $Driver) # PS2.0 check
        {
            $Path = $Driver.'Image Path'
            if ($Path -ne "")
            {
                $MD5 = Compute-FileHash $Driver.'Image Path'
            }
            else {
                $MD5 = ""
            }
            $Driver | Add-Member -MemberType NoteProperty -Name "MD5" -Value $MD5
        }
    }
    $Drivers = $Drivers | Select-Object "Time", "Entry", "Description", "Image Path", "Signer", "Company", "Version", "MD5"
    
    YACKPipe-ReturnCSV -PowershellObjects $Drivers -OutputName "Drivers.csv" 
}
else 
{
    YACKPipe-ReturnError "Couldn't find Autorunsc.exe"
}




#https://docs.microsoft.com/en-us/windows/desktop/api/Winsvc/nf-winsvc-createservicea
#Service Types
# 0x00000001 SERVICE_KERNEL_DRIVER        Driver service
# 0x00000002 SERVICE_FILE_SYSTEM_DRIVER   File system driver service. 
# 0x00000004 SERVICE_ADAPTER              Reserved.
# 0x00000008 SERVICE_RECOGNIZER_DRIVER    Reserved.
# 0x00000010 SERVICE_WIN32_OWN_PROCESS    Service that runs in its own process. 
# 0x00000020 SERVICE_WIN32_SHARE_PROCESS  Service that shares a process with one or more other services.
# 0x00000050 SERVICE_USER_OWN_PROCESS     The service runs in its own process under the logged-on user account. 
# 0x00000060 SERVICE_USER_SHARE_PROCESS   The service shares a process with one or more other services that run under the logged-on user account. 

#Start Types
# 0x00000000 SERVICE_BOOT_START   A device driver started by the system loader. This value is valid only for driver services.
# 0x00000001 SERVICE_SYSTEM_START A device driver started by the IoInitSystem function. This value is valid only for driver services. 
# 0x00000002 SERVICE_AUTO_START   A service started automatically by the service control manager during system startup. For more information, see Automatically Starting Services.
# 0x00000003 SERVICE_DEMAND_START A service started by the service control manager when a process calls the StartService function. For more information, see Starting Services on Demand.
# 0x00000004 SERVICE_DISABLED     A service that cannot be started. Attempts to start the service result in the error code ERROR_SERVICE_DISABLED.



# $RegPath = 'HKLM:\System\CurrentControlSet\Services\*'

# $AllDrivers= Get-ItemProperty $RegPath | `
#      Select-Object @{l="ComputerName";e={$env:COMPUTERNAME}}, DisplayName, ErrorControl, ImagePath, Owners, Start, Tag, Type | `
#      Where-Object {$_.Type -eq 2}

# $AllDrivers #| Sort-Object -Property ImagePath
