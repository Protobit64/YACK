<#
.DEPENDENCY RamCapturer
.PSM_DEPENDENCY DataTransfer.psm1 

.SYNOPSIS
Captures memory and outputs to a directory.

.DESCRIPTION
Captures memory onto disk, then exports it. 
Unless you can figure out doublehop problems then I'm unsure how to solve this.


.PARAMETER OutputPath
Path of the file to retrieve. Envr Variables are supported.

.PARAMETER CaptureMode
This parameter is passed to this module by yack.
Local - Output Results to OutputFolder

.EXAMPLE
.\Capture-Memory.ps1 
    Captures memory into local output directory because the parameter is passed to it via the script

.\Capture-Memory.ps1 \\10.1.1.10\test


.NOTES
License: 
Credits: Connor Martin
#>

Param(
    [Parameter(Mandatory=$false,Position=0)]
        $OutputPath = "$env:SystemRoot\yack\",
        [Parameter(Mandatory=$False,Position=1)]
        $YACKOutputFolder = $null
        #$OutputPath = "\\YACK-2016-1\Test\"
)



#Get total memory size
$MemorySize = $(Get-WMIObject -class Win32_PhysicalMemory | Measure-Object -Property capacity -Sum ).Sum

#Get available disk space
$AvailableSpace = $(Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='C:'").FreeSpace
#Add a 10GB buffer space just in case
$AvailableSpace = $AvailableSpace - 10GB

#Check if disk space is available
if ($AvailableSpace -gt $MemorySize)
{
    #Dump memory to disk
    $OutputPath = [Environment]::ExpandEnvironmentVariables($OutputPath)
    if (Test-Path $OutputPath) 
    {
        #Get appropriate binary path
        if ([System.IntPtr]::Size -eq 4) 
        { 
            $BinaryPath = "$env:SystemRoot\yack\RamCapturer\x86\RamCapture.exe"
        } 
        else 
        { 
            $BinaryPath = "$env:SystemRoot\yack\RamCapturer\x64\RamCapture64.exe"
        }

        #If binary exists
        if (Test-Path $BinaryPath) 
        {
            #Change location to output folder and run ram capture
            $CurrentPath = Get-Location
            Set-Location $OutputPath
            $null = (& $BinaryPath "Capture")
            Set-Location $CurrentPath

            YACKPipe-ReturnFile -SourceFilePath "$OutputPath/Capture" -YACKOutputFolder "Memory" -GZIP $false -ChunkSize 10MB 

            Remove-Item -Path "$OutputPath/Capture"
        }
        else 
        {
            YACKPipe-ReturnError "Binary not found."
        }
    }
    else 
    {
        YACKPipe-ReturnError "Cannot reach output path. $OutputPath"
    }

}
else 
{
    YACKPipe-ReturnError "Not enough disk space. $OutputPath"
}

