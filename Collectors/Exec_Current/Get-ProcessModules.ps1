<#
.DEPENDENCY 
.PSM_DEPENDENCY DataTransfer.psm1 

.SYNOPSIS
Enumerates all running processes and their loaded modules.

.NOTES
License: Apache License 2.0
Credits: kansa(github) // Connor Martin
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
    
$AllEvents = New-Object System.Collections.ArrayList
$HashT = @{}

#expands the modules of each process, hashes the exe, and adds it to allEvents.
Get-Process | % { 
    $MM = $_.MainModule | Select-Object -ExpandProperty FileName
    $ProcModules = $($_.Modules | Select-Object -ExpandProperty FileName)
    $CurrPID = $_.Id
    
    foreach($ProcModule in $ProcModules) 
    {
        if ($ProcModule -ne $null)
        {
            $Obj = "" | Select-Object Name, ParentPath, Hash, ProcessName, ProcPID, CreateUTC, LastAccessUTC, LastWriteUTC
            $Obj.Name = $ProcModule.Substring($ProcModule.LastIndexOf("\") + 1)
            $Obj.ParentPath = $ProcModule.Substring(0, $ProcModule.LastIndexOf("\"))
            if ($HashT.get_item($ProcModule)) 
            {
                $Obj.Hash = $HashT.get_item($ProcModule)
            } 
            else 
            {
                if (Test-Path $ProcModule)
                {
                    $Obj.Hash = Compute-FileHash -FilePath $ProcModule
                    $HashT.Add($ProcModule, $Obj.Hash)
                    $SourceTarget = Get-Item -Force $ProcModule
                }
                else 
                {
                    $HashT.Add($ProcModule, "")
                    $SourceTarget = $null
                }
            }

            $Obj.ProcessName = ($MM.Split('\'))[-1]
            $Obj.ProcPID = $CurrPID
            $Obj.CreateUTC = $SourceTarget.CreationTimeUtc
            $Obj.LastAccessUTC = $SourceTarget.LastAccessTimeUtc
            $Obj.LastWriteUTC = $SourceTarget.LastWriteTimeUtc
            [void]$AllEvents.Add($Obj)
        }
    }
}

YACKPipe-ReturnCSV -PowershellObjects $AllEvents.ToArray() -OutputName "ProcessModules.csv" 