<#
.DEPENDENCY rawcopy.exe
.PSM_DEPENDENCY DataTransfer.psm1 

.SYNOPSIS
Iterates through each user's directory and copies usrclass.dat using rawcopy.

.OUTPUTS
This returns each file, gzip encoded, in a seperate YACKResult object. So
if there are 5 users then 5 YACKResult object are piped out of this module.

.NOTES
Credit: Connor Martin
License: 
#>


#Get parent to current user's personal folder
$UserFolders = Split-Path $env:USERPROFILE | Get-ChildItem
$OutputFolder = "$env:SystemRoot\yack\"

#Iterate through each user folder
foreach ($Folder in $UserFolders) 
{
    if ($null -ne $Folder) # PS2.0 check
    {
        #Create full path and see if it exists
        $UsrClassPath = "$($Folder.FullName)\AppData\Local\Microsoft\Windows\UsrClass.dat"
        if(Test-path $UsrClassPath) 
        {
            $Filename = Split-Path $UsrClassPath -leaf
            $OutputFilePath = "$OutputFolder$Filename"

            #Copy protected file to temp directory
            $temp = (& $env:SystemRoot\yack\rawcopy.exe "/FileNamePath:$UsrClassPath" "/OutputPath:$OutputFilePath")
            
            #Get file metadata
            $SourceTarget = Get-ChildItem $UsrClassPath -Force
            $OutputTarget = Get-ChildItem $OutputFilePath -Force

            #Get Username from folder path
            $Username = $Folder  | Split-Path -Leaf
            $OutputName = "$($SourceTarget.BaseName)_$Username$($SourceTarget.Extension)" #NTUSER_conno.DAT

            #Result template
            YACKPipe-ReturnFile -SourceFilePath $OutputTarget -OutputName $OutputName -YACKOutputFolder "System"

            #remove from temp
            Remove-Item -Path $OutputFilePath

        }
    }
}


