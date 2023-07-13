<#
.DEPENDENCY 
.PSM_DEPENDENCY DataTransfer.psm1 

.SYNOPSIS
Grabs files from the windows VSS.

.PARAMETER SourceFilePath
Path of the file to retrieve. Envr Variables are supported.

.PARAMETER VSSSearchMode
Which VSS to copy files from. 
- Oldest: Will mount the each VSS looking for the oldest version that the file exists in.
- All: Will copy the file from all VSS's.
- fresh: Will create a new VSS, mount it, search for the file and then delete the VSS.
    The allows you to bypass system file protections in some cases.

.PARAMETER YACKOutputFolder
The outputfolder which YACK will store the retrieved file. This parameters is passed 
back to YACK.ps1

.OUTPUTS
The result will be YACKResult with the file GZIP encoded.
Depending on the VSSMode will control the number/names
    Oldest - Output will be the filename_{timestamp}
    All - Output will be the filename_{timestamp}. 
    fresh - Output will be filename.
    
.EXAMPLE
.\Get-VSSFile.ps1 "%SystemRoot%\System32\config\SYSTEM" "Oldest" "Logs"
Retrieves the oldest VSS version of the SYSTEM hive.

.NOTES
License: Apache License 2.0 // BSD 3-Clause
Credits: Connor Martin. Chris Campbell (@obscuresec)
#>

Param(
    [Parameter(Mandatory=$True,Position=1)]
       $VSSSearchMode = "Oldest",
   [Parameter(Mandatory=$True,Position=0)]
       $SourceFilePath,
   [Parameter(Mandatory=$False,Position=1)]
       $YACKOutputFolder = $null

)


function Split-DriveLetter ($Path)
{
    $DriveLetterInd = $Path.IndexOf(":")
    if ($DriveLetterInd -ne -1)
    {
        $DriveLetter = $Path.Substring(0, $DriveLetterInd + 1)
        return $DriveLetter
    }
    else 
    {
        return $null    
    }
}



function VSSMode-Fresh ($SourceFilePath, $MountFolder, $YACKOutputFolder) 
{
    <#
    .SYNOPSIS
    Copies files from disk by creating a vss and coping form there.
    
    .PARAMETER SourceFilePath
    The file path you want to copy
    
    .PARAMETER MountFolder
    The folder you want to mount VSS to temporarily.
    
    .PARAMETER YACKOutputFolder
    The folder which YACK will output the results to
    
    #>

    #Check if file exists
    if (Test-Path $SourceFilePath) 
    {
        #Retrieve meta data
        $SourceTarget = Get-ChildItem $SourceFilePath -Force

        #Parse out drive letter and relative apth
        $DriveLetter = $SourceTarget[0].PSDrive.Name
        $RelativePath = $SourceFilePath -replace "$($DriveLetter):", ""

        #Create a VSS
        $VSSCreated = (Get-WmiObject -List Win32_ShadowCopy).Create("$($DriveLetter):\", "ClientAccessible")
        $VSSObject = Get-WmiObject Win32_ShadowCopy | Where-Object { $_.ID -eq $VSSCreated.ShadowID }

        #Get VSS ID
        $DeviceObject  = $VSSObject.DeviceObject + "\" 

        #If Mount Folder Already exists then unmount it
        if (Test-Path $MountFolder)
        {
            [System.IO.directory]::Delete($MountFolder)
        }

        #Mount VSS via a symbolic link
        $temp = $(cmd /c mklink /j $MountFolder "$DeviceObject")


        #Return the vss file
        YACKPipe-ReturnFolderOrFile -SourceFilePath "$MountFolder$RelativePath" -YACKOutputFolder $YACKOutputFolder #-OutputName $SourceTarget.Name

        #Remove created VSS
        $VSSObject.Delete()

        #Remove-Item $vssFolder -Force
        [System.IO.directory]::Delete($MountFolder)
    } 
    else 
    {
        YACKPipe-ReturnError "Couldn't find $SourceFilePath on live system." 
    }
}

function VSSMode-Oldest ($SourceFilePath, $MountFolder, $YACKOutputFolder) 
{
    <#
    .SYNOPSIS
    Copies the oldest version of a file in VSS.
    
    .PARAMETER SourceFilePath
    The file path you want to copy.
    
    .PARAMETER MountFolder
    The folder you want to mount VSS to temporarily.
    
    .PARAMETER YACKOutputFolder
    The folder which YACK will output the results to
    
    #>

    #Build the file path
    #$DriveLetter = $(Get-Item $SourceFilePath -ErrorAction SilentlyContinue).PSDrive.Name
    $DriveLetter = Split-DriveLetter $SourceFilePath
   
    #I need to fix this. If the file doesn't exist on the current directory then it wont be found on older VSS. Do string splins?

    if ($null -ne $DriveLetter)
    {
        $RelativePath = $SourceFilePath -replace "$($DriveLetter)", ""
        $VSSFilePath = "$MountFolder$RelativePath"

        #Get all Shadows
        $Shadows = get-wmiobject win32_shadowcopy
        
        #Mount each shadow until a match is found
        foreach ($Shadow in $Shadows) 
        {
            if ($null -ne $Shadow) # PS2.0 check
            {
                $DeviceObject  = $Shadow.DeviceObject + "\" 

                #If Mount Folder Already exists then unmount it
                if (Test-Path $MountFolder)
                {
                    [System.IO.directory]::Delete($MountFolder)
                }

                #Mount VSS via a symbolic link
                $null = $(cmd /c mklink /j $MountFolder "$DeviceObject")

                #Check if the file exists inside the mounted vss
                if (Test-Path $VSSFilePath) 
                {
                    #Retrieve meta data
                    $SourceTarget = Get-ChildItem $VSSFilePath -Force
                    $Timestamp = [Management.ManagementDateTimeConverter]::ToDateTime($Shadow.InstallDate) |  Get-Date -UFormat "%Y%m%d%H%M"
                    $VSSOutputFilename = "$($SourceTarget.BaseName)_$Timestamp$($SourceTarget.Extension)"


                    YACKPipe-ReturnFolderOrFile -SourceFilePath $VSSFilePath -YACKOutputFolder $YACKOutputFolder 
                    #Remove symbolic link
                    [System.IO.directory]::Delete($MountFolder)
                    break;
                }
                #Remove symbolic link
                [System.IO.directory]::Delete($MountFolder)
            }
            if ($null -eq $CollectorResult.Content) 
            {
                YACKPipe-ReturnError "Could not find $SourceFilePath" 
            }
        }
    }
    else 
    {
        YACKPipe-ReturnError "Invalid path: $SourceFilePath" 
    }
}


function VSSMode-All ($SourceFilePath, $MountFolder, $YACKOutputFolder) 
{
    <#
    .SYNOPSIS
    Copies all versions of a file from VSS
    
    .PARAMETER SourceFilePath
    The file path you want to copy
    
    .PARAMETER MountFolder
    The folder you want to mount VSS to temporarily.
    
    .PARAMETER YACKOutputFolder
    The folder which YACK will output the results to
    
    #>

    #Build the file path
    #$DriveLetter = $(Get-Item $SourceFilePath).PSDrive.Name
    $DriveLetter = Split-DriveLetter $SourceFilePath
    
    if ($null -ne $DriveLetter)
    {
        $RelativePath = $SourceFilePath -replace "$($DriveLetter)", ""
        $VSSFilePath = "$MountFolder$RelativePath"

        $CopyWasFound = $False

        #Get all Shadows
        $Shadows = get-wmiobject win32_shadowcopy
        
        #Mount each shadow until a match is found
        foreach ($Shadow in $Shadows) 
        {
            if ($null -ne $Shadow) # PS2.0 check
            {
                $DeviceObject  = $Shadow.DeviceObject + "\" 

                #If Mount Folder Already exists then unmount it
                if (Test-Path $MountFolder)
                {
                    [System.IO.directory]::Delete($MountFolder)
                }

                #Mount VSS via a symbolic link
                $null = $(cmd /c mklink /j $MountFolder "$DeviceObject")

                #Check if the file exists inside the mounted vss
                if (Test-Path $VSSFilePath) 
                {
                    #Retrieve meta data
                    $SourceTarget = Get-ChildItem $VSSFilePath -Force
                    $Timestamp = [Management.ManagementDateTimeConverter]::ToDateTime($Shadow.InstallDate) |  Get-Date -UFormat "%Y%m%d%H%M"

                    YACKPipe-ReturnFolderOrFile -SourceFilePath $VSSFilePath -YACKOutputFolder $YACKOutputFolder -OutputNameModifier "_$Timestamp"

                    
                    $CopyWasFound = $true
                }
                #Remove symbolic link
                [System.IO.directory]::Delete($MountFolder)
            }
        }
    }
    else 
    {
        YACKPipe-ReturnError "Invalid path: $SourceFilePath"  
    }
}

#expand envr var
$SourceFilePath = [Environment]::ExpandEnvironmentVariables($SourceFilePath)
$MountFolder = "$env:SystemRoot\yackvss\"

#Get VSS Mode.
$VSSCurrentMode = (Get-WmiObject -Query "Select StartMode From Win32_Service Where Name='vss'").StartMode

#If disabled then start it
if ($VssStartMode -eq "Disabled") 
{
    Set-Service vss -StartUpType Manual
} 

#Start the service if needed.
$VssStatus = (Get-Service vss).status  
if ($VssStatus -ne "Running") 
{
    Start-Service vss
} 

#Collect the file based on the searchmode
switch ($VSSSearchMode.ToLower()) 
{
    "fresh" 
    {  
        VSSMode-Fresh $SourceFilePath $MountFolder $YACKOutputFolder
    }

    "oldest" 
    {
        VSSMode-Oldest $SourceFilePath $MountFolder $YACKOutputFolder
    }

    "all" 
    {
        VSSMode-All $SourceFilePath $MountFolder $YACKOutputFolder
    }
    
}

#Return "vss" service to previous state 
If ($VssStatus -eq "Stopped") 
{
    Stop-Service vss
} 
If ($VSSCurrentMode -eq "Disabled") 
{
    Set-Service vss -StartupType Disabled
} 

