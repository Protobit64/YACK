<#
.DEPENDENCY 
.PSM_DEPENDENCY DataTransfer.psm1 

.SYNOPSIS
Retrieves a directory listing for a path. If the path is blank then
it will do the entire file system.

.PARAMETER FolderPath
Path of the file to retrieve. Envr Variables are supported.

.EXAMPLE
.\Get-DirectoryListing.ps1 
  Retrieves a directory listing of all local drives

.EXAMPLE
.\Get-DirectoryListing.ps1 "%SystemRoot%\System32\""
  Retrieves a directory listing of the system32 folder

.NOTES
Credit: Kansa(github)
License: Apache License 2.0
#>

Param(
    [Parameter(Mandatory=$false,Position=0)]
        $FolderPath = ""
)



#If a path wasn't provided
if ("" -eq $FolderPath)
{
    #Find all filesystem letters
    $DriveLetters = Get-WmiObject win32_logicaldisk -Filter "DriveType='3'" | Select-Object -ExpandProperty DeviceID
    $Listings = @()

    #Iterate through each filesystme drive
    foreach ($Letter in $DriveLetters) 
    {
        if ($null -ne $Letter) # PS2.0 check
        {
            #Get all of the directories.
            $Listings += $(Get-ChildItem -Path $Letter\  -Recurse -Force -ErrorAction SilentlyContinue  | `
                Select-Object FullName, Name, Mode, Length, CreationTimeUtc, LastAccessTimeUtc, LastWriteTimeUtc)
        }
    }

    YACKPipe-ReturnCSV -PowershellObjects $Listings -OutputName "DirListing_Full.csv"

}
else 
{
    #Expand the path
    $FolderPathExp = [Environment]::ExpandEnvironmentVariables($FolderPath)
    $Listings = @()

    #Ensure the folder exists
    #if (Test-Path $FolderPathExp)
    if ($true)
    {
        $Listings += $(Get-ChildItem -Path $FolderPathExp  -Recurse -Force -ErrorAction SilentlyContinue  | `
            Select-Object FullName, Name, Mode, Length, CreationTimeUtc, LastAccessTimeUtc, LastWriteTimeUtc)
        
        #Construct filename
        $Outputname = $FolderPath -replace "\\", "-"
        $Outputname = $FolderPath -replace "/", "-"

        YACKPipe-ReturnCSV -PowershellObjects $Listings -OutputName "DirListing_$Outputname.csv"
    }
    else 
    {
        YACKPipe-ReturnError "Couldn't find $FolderPath"
    }
}