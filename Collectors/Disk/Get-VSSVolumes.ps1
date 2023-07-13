<#
.DEPENDENCY 
.PSM_DEPENDENCY DataTransfer.psm1 

.SYNOPSIS
Returns properties from VSS Volumes being utilized.

.NOTES
License: Microsoft Public License (Ms-PL)
Credits: Zachary Loeber. 
#>


filter ConvertTo-KMG  
{
    <#
    .SYNOPSIS
    Converts a byte count into the human readable format.
    1213123 -> 1.2MB
    #>

    $bytecount = $_
    switch ([math]::truncate([math]::log($bytecount,1024)))  
    {
        0 {"$bytecount Bytes"}
        1 {"{0:n2} KB" -f ($bytecount / 1kb)}
        2 {"{0:n2} MB" -f ($bytecount / 1mb)}
        3 {"{0:n2} GB" -f ($bytecount / 1gb)}
        4 {"{0:n2} TB" -f ($bytecount / 1tb)}
        default {"{0:n2} PB" -f ($bytecount / 1pb)}
    }
}


$wmi_shadowcopyareas = Get-WmiObject -Class win32_shadowstorage
$wmi_volumeinfo =  Get-WmiObject -Class win32_volume
$ShadowCopyVolumes = @()
$VolumeIndex = 0
foreach ($shadow in $wmi_shadowcopyareas) { if ($shadow) #PS2.0 Check
{
    foreach ($volume in $wmi_volumeinfo) { if ($volume) #PS2.0 Check
    {
        if ($shadow.Volume -like "*$($volume.DeviceId.trimstart("\\?\Volume").trimend("\"))*") 
        {
            $VolInfo = New-Object PSObject
            $VolInfo | Add-Member -MemberType NoteProperty -Name "Index" -Value $VolumeIndex
            $VolInfo | Add-Member -MemberType NoteProperty -Name "Drive" -Value $volume.Name
            $VolInfo | Add-Member -MemberType NoteProperty -Name "DriveCapacity" -Value $($volume.Capacity | ConvertTo-KMG)
            $VolInfo | Add-Member -MemberType NoteProperty -Name "ShadowSizeMax" -Value $($shadow.MaxSpace | ConvertTo-KMG)
            $VolInfo | Add-Member -MemberType NoteProperty -Name "ShadowSizeUsed" -Value $($shadow.UsedSpace | ConvertTo-KMG)
            $VolInfo | Add-Member -MemberType NoteProperty -Name "ShadowCapacityUsed" -Value $([math]::round((($shadow.UsedSpace/$shadow.MaxSpace) * 100),2))
            $VolInfo | Add-Member -MemberType NoteProperty -Name "VolumeCapacityUsed" -Value $([math]::round((($shadow.UsedSpace/$volume.Capacity) * 100),2))

            $ShadowCopyVolumes += $VolInfo

            $VolumeIndex++
        }
    }}
}}

#Reorder the output
$ShadowCopyVolumes = $ShadowCopyVolumes | Select-Object Index, Drive, DriveCapacity, ShadowSizeMax, ShadowSizeUsed, ShadowCapacityUsed, VolumeCapacityUsed


YACKPipe-ReturnCSV -PowershellObjects $ShadowCopyVolumes -OutputName "VSSVolumesInfo.csv"


