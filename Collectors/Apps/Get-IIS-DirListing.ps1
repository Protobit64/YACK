<#
.DEPENDENCY 
.PSM_DEPENDENCY DataTransfer.psm1 

.SYNOPSIS
Gets a directory listing of IIS web server folder. It finds it
from the PathWWWRoot registry key.

.OUTPUTS
Returns metadata, entropy and hashes of the files. If it fails
to find it then it will return $null in YACKResult content.

.NOTES
License: Apache License 2.0
Credits: Connor Martin. kansa(github)
#>


#Find web Directory from the registry
$BasePath = $(Get-ItemProperty HKLM:\Software\Microsoft\INetStp -Name "PathWWWRoot" -ErrorAction SilentlyContinue).PathWWWRoot

#The max filesize that this will hash.
[long]$MaxB = 50MB
$HashAlgorithm = [System.Security.Cryptography.MD5]::Create()

#Check if the IIS folder pathe exists.
if (($null -ne $BasePath) -and (Test-Path $BasePath -PathType Container)) 
{
    #Get all of the directory listings.
    $AllFiles = Get-ChildItem -Force -Path $BasePath -Recurse -ErrorAction SilentlyContinue

    # Calculate the entropy and hash for each child item.
    foreach ($ChildItem in $AllFiles) 
    {
        if ($null -ne $ChildItem) # PS2.0 check
        {
            $FileHash = ""
            $FileEntropy = 0.0
            $ByteCounts = @{}
            $ByteTotal = 0
            
            # If the child item is a file and less than the max size.
            if((Test-Path $ChildItem.FullName -PathType Leaf) -and ($ChildItem.Length -lt $MaxB)) 
            {
                #Calculate File Entropy
                $FileName = $ChildItem.FullName
                $FileBytes = [System.IO.File]::ReadAllBytes($FileName)

                foreach ($FileByte in $FileBytes) 
                {
                    if ($null -ne $FileByte) # PS2.0 check
                    {
                        $ByteCounts[$FileByte]++
                        $ByteTotal++
                    }
                }

                foreach($byte in 0..255) 
                {
                    $byteProb = ([double]$ByteCounts[[byte]$byte])/$ByteTotal
                    if ($byteProb -gt 0) {
                        $FileEntropy += (-1 * $byteProb) * [Math]::Log($byteProb, 2.0)
                    }
                }

                #Calculate the file's hash
                $HashBytes = $HashAlgorithm.ComputeHash($FileBytes)

                foreach($Byte in $HashBytes) 
                {
                    if ($null -ne $Byte) # PS2.0 check
                    {
                        $ByteInHex = [String]::Format("{0:X}", $Byte)
                        $FileHash += $ByteInHex.PadLeft(2,"0")
                    }
                }
            }
        
            #Add calculate items to the object
            $ChildItem | Add-Member -MemberType NoteProperty -Name "RelativePath" -Value $ChildItem.FullName.Replace("$BasePath", "")
            $ChildItem | Add-Member -MemberType NoteProperty -Name "Entropy" -Value $FileEntropy
            $ChildItem | Add-Member -MemberType NoteProperty -Name "MD5" -Value $FileHash
        }
    }
    $AllFiles = $AllFiles | Select-Object RelativePath, Length, CreationTimeUtc, LastAccessTimeUtc, LastWriteTimeUtc, Entropy, MD5

    YACKPipe-ReturnCSV -PowershellObjects $AllFiles -OutputName "WebDirListing.csv"
}
else 
{
    YACKPipe-ReturnError "Couldn't find ISS folder"
}
