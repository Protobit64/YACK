<#
.DEPENDENCY rawcopy.exe
.PSM_DEPENDENCY DataTransfer.psm1 

.SYNOPSIS
Retrieves a file by using a binary to read from the raw disk. The file
is returned as a gzip encoded array.

.PARAMETER FilePath
  Path of the file to retrieve. Envr Variables are supported.

.PARAMETER YACKOutputFolder
  The outputfolder which YACK will store the retrieved file.
  This parameters is passed back to YACK.ps1

.EXAMPLE
  .\Get-RawFile.ps1 "%SystemRoot%\System32\config\SYSTEM" 
  Retrieves the SYSTEM hive.

.EXAMPLE
  .\Get-RawFile.ps1 "%SystemRoot%\System32\config\SYSTEM" "Logs"
  Retrieves the SYSTEM hive and stores it in the "Logs" subfolder of the ouput folder

.NOTES
License: Apache License 2.0
Credits: Connor Martin. 
#>

Param(
   [Parameter(Mandatory=$True,Position=0)]
       $SourceFilePath,
   [Parameter(Mandatory=$False,Position=1)]
       $YACKOutputFolder = $null
)


#expand envr var
$SourceFilePath = [Environment]::ExpandEnvironmentVariables($SourceFilePath)
$BinPath = "$env:SystemRoot\yack\rawcopy.exe"

#Check if file exists
if (Test-Path $SourceFilePath) 
{
    #check if binary exists
    if (Test-Path $BinPath) 
    {
        #Determine  Outputfolder and Source Filename
        $OutputFolder = "$env:SystemRoot\yack\"
        $Filename = Split-Path $SourceFilePath -leaf
        $OutputPath = "$OutputFolder$Filename"

        try 
        {
            #Copy protected file to temp directory
            $temp = (& $BinPath "/FilenamePath:$SourceFilePath" "/OutputPath:$OutputFolder")

            #Retrieve meta data
            $SourceTarget = Get-ChildItem $SourceFilePath -Force
            $OutputTarget = Get-ChildItem $OutputPath -Force

            #Result template
            YACKPipe-ReturnFile -SourceFilePath $OutputPath -YACKOutputFolder $YACKOutputFolder -OutputName $null -GZIP $False -ChunkSize 10MB 

            #Remove the copied item from temp
            Remove-Item -Path $OutputPath
        }
        catch 
        {
            YACKPipe-ReturnError -ErrorMessage "Failed Reading $SourceFilePath... $($_.Exception.Message) At $($_.InvocationInfo.ScriptName):$($_.InvocationInfo.ScriptLineNumber) char:$($_.InvocationInfo.OffsetInLine) " 
        }
    }
    else 
    {
        YACKPipe-ReturnError -ErrorMessage "Couldn't find $BinPath"
    }
}
else 
{
    YACKPipe-ReturnError -ErrorMessage "Couldn't find $SourceFilePath"
}