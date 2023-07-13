<#
.DEPENDENCY
.PSM_DEPENDENCY DataTransfer.psm1 

.SYNOPSIS
Retreives all local Groups and the members.

.NOTES
License: Apache 2.0
Credits: Nitesh. Connor Martin.
#>


$ComputerName = $Env:COMPUTERNAME

#Get Groups
$Groups = Get-WmiObject -Class win32_group -filter "Domain = '$ComputerName'"

#Add members
Foreach($Group in $Groups)
 {
    if ($null -ne $Group) # PS2.0 check
    {
        $Users = net localgroup $Group.Name | Where-Object {$_ -notmatch "command completed successfully"} | Select-Object -skip 6
        #Removes empty strings
        $Users = $Users | Where-Object {$_}  
        $UserStr = $Users -join ", "
        $Group | Add-Member -MemberType NoteProperty -Name "Members" -Value $UserStr
    }

 }


YACKPipe-ReturnCSV -PowershellObjects $Groups -OutputName "LocalGroups.csv"
