<#
.DEPENDENCY
.PSM_DEPENDENCY DataTransfer.psm1 

.SYNOPSIS
Retreives all logons that require interaction.

.NOTES
License: MIT License
Credits: Raymond Piller.
#>


$Users = (((quser) -replace '^>', '') -replace '\s{2,}', ',')
foreach ($User in $Users)
{
    if ($null -ne $User)
    {
        $User = $User.Trim()
    }
}
$Results = $Users | ForEach-Object {
    if ($_.Split(',').Count -eq 5) {
        Write-Output ($_ -replace '(^[^,]+)', '$1,')
    } else {
        Write-Output $_
    }
} | ConvertFrom-Csv



YACKPipe-ReturnCSV -PowershellObjects $Results -OutputName "InteractiveUsers.csv"

