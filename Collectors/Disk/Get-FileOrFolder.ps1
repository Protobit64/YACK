<#
.DEPENDENCY 
.PSM_DEPENDENCY DataTransfer.psm1 

.SYNOPSIS
Reads a file or folder from the filesystem. 

.DESCRIPTION
Each file is optionally gzip encoded. Larger files are broken into chunks

.PARAMETER SourceFilePath
Path of the folder to retrieve. Envr Variables are supported.

.PARAMETER YACKOutputFolder
The outputfolder which YACK will store the retrieved file.
This parameters is passed back to YACK.ps1

.EXAMPLE
.\Get-Folder.ps1 %SystemRoot%\System32\Winevt\Logs\
  Retrieves the Security Log.

.EXAMPLE
.\Get-File.ps1 %SystemRoot%\System32\Winevt\Logs\Application.evtx Logs
  Retrieves the Application Log and stores it in the "Logs" folder of the ouput

.NOTES
License: Apache License 2.0
Credits: Connor Martin. kansa(github)
#>




Param(
    [Parameter(Mandatory=$true,Position=0)]
        $SourceFilePath,
      [Parameter(Mandatory=$true,Position=1)]
        $YACKOutputFolder = $null,
      [Parameter(Mandatory=$false,Position=2)]
        $GZIP = "false",
      [Parameter(Mandatory=$false,Position=3)]
        $ParmChunkSize = 10MB

)


#Parse string parm
$Gzip = [boolean]::parse($GZIP)


YACKPipe-ReturnFolderOrFile $SourceFilePath $YACKOutputFolder $GZIP $ParmChunkSize