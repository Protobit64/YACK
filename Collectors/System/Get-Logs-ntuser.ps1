<#
.DEPENDENCY rawcopy.exe
.PSM_DEPENDENCY DataTransfer.psm1 

.SYNOPSIS
Iterates through each user's directory and copies ntuser.dat using rawcopy.

.OUTPUTS
This returns each file, gzip encoded, in a seperate YACKResult object. So
if there are 5 users then 5 YACKResult object are piped out of this module.

.NOTES
Credit: Connor Martin
License: 
#>




#Determine  Outputfolder and filename
$OutputFolder = "$env:SystemRoot\yack\"

#Get parent to current user's personal folder
$UserFolders = Split-Path $env:USERPROFILE | Get-ChildItem

#Iterate through each user folder
foreach ($Folder in $UserFolders) 
{
    if ($null -ne $Folder) # PS2.0 check
    {
        #Create full path and see if it exists
        $NTuserPath = "$($Folder.FullName)\NTUSER.DAT"

        if(Test-path $NTuserPath) 
        {
            $Filename = Split-Path $NTuserPath -leaf
            $OutputFilePath = "$OutputFolder$Filename"

            #Copy protected file to temp directory
            $temp = (& $env:SystemRoot\yack\rawcopy.exe "/FileNamePath:$NTuserPath" "/OutputPath:$OutputFilePath")

            #Get file metadata
            $SourceTarget = Get-ChildItem $NTuserPath -Force
            $OutputTarget = Get-ChildItem $OutputFilePath -Force

            #Get Username from folder path
            $Username = $NTuserPath | Split-Path  | Split-Path -Leaf
            $OutputName = "$($SourceTarget.BaseName)_$Username$($SourceTarget.Extension)" #NTUSER_conno.DAT

            #Result template
            YACKPipe-ReturnFile -SourceFilePath $OutputTarget -OutputName $OutputName -YACKOutputFolder "System"

            #remove from temp
            Remove-Item -Path $OutputFilePath

        }
    }
}

