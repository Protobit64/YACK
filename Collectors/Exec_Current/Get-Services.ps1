<#
.DEPENDENCY autorunsc.exe
.PSM_DEPENDENCY DataTransfer.psm1 

.SYNOPSIS
Retrieves all running services using autorunsc.exe

.NOTES
License: Apache License 2.0
Credits: kansa(github).
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


$CollectorResult = "" | Select-Object Error, ErrorMessage, OutputType, OutputName, OutputFolder, Content
$Services = ""

if (Test-Path "$env:SystemRoot\yack\autorunsc.exe") 
{
    #Select services from autorunsc
    $ServAndDrivers = $( & "$env:SystemRoot\yack\autorunsc.exe" /accepteula -a s -c -s -nobanner -t '*' 2> $null | ConvertFrom-Csv)
    $Services = $ServAndDrivers | Where-Object {($_.Category -eq "Services") -and ($_.Entry -ne "")}

    #For each service compite the hash
    foreach ($Service in $Services)
    {
        if ($null -ne $Service) # PS2.0 check
        {
            $Path = $Service.'Image Path'
            if ($Path -ne "")
            {
                $MD5 = Compute-FileHash $Service.'Image Path'
            }
            else 
            {
                $MD5 = ""
            }
            $Service | Add-Member -MemberType NoteProperty -Name "MD5" -Value $MD5
        }
    }

    $Services = $Services | Select-Object "Time", "Entry", "Description", "Image Path", "Signer", "Company", "Version", "MD5"
    YACKPipe-ReturnCSV -PowershellObjects $Services -OutputName "Services.csv" 
}
else 
{
    YACKPipe-ReturnError "Couldn't find Autorunsc.exe"
}



# $Services = Get-WmiObject win32_service | Select-Object Name, DisplayName, PathName, StartName, StartMode, State, TotalSessions, Description, ProcessId

# foreach ($pi in $Services )
# {
#     $name = $(Get-Process -Id $pi.ProcessId).Name
#     $pi | Add-Member -MemberType NoteProperty -Name "ParentProcess" -Value $name
# }

# return $Services
