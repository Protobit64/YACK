<#
.DEPENDENCY
.PSM_DEPENDENCY DataTransfer.psm1 

.SYNOPSIS
Collects general information about attached disks.

.NOTES
License:  Creative Commons Attribution-ShareAlike 4.0 International License
Credits: zloeber
https://github.com/zloeber/Powershell/blob/master/OS/Multiple%20Runspace/Get-RemoteDiskInformation.ps1

Connor Martin: I added interoperability support to YACK. 
#>


$ComputerName = $env:computername
$DiskInfos = @()

Write-Verbose -Message ('Get-RemoteDiskInformation: Runspace {0}: Start' -f $ComputerName)
$WMIHast = @{
    ComputerName = $ComputerName
    ErrorAction = 'Stop'
}
if (($LocalHost -notcontains $ComputerName) -and ($Credential -ne $null))
{
    $WMIHast.Credential = $Credential
}

filter ConvertTo-KMG {
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

Write-Verbose -Message ('Get-RemoteDiskInformation: Runspace {0}: Disk information' -f $ComputerName)
$WMI_DiskMountProps   = @('Name','Label','Caption','Capacity','FreeSpace','Compressed','PageFilePresent','SerialNumber')

# WMI data
$wmi_diskdrives = Get-WmiObject  -Class Win32_DiskDrive
$wmi_mountpoints = Get-WmiObject  -Class Win32_Volume -Filter "DriveType=3 AND DriveLetter IS NULL" | Select $WMI_DiskMountProps

$AllDisks = @()
$DiskElements = @('ComputerName','Disk','Model','Partition','Description','PrimaryPartition','VolumeName','Drive','DiskSize','FreeSpace','UsedSpace','PercentFree','PercentUsed','DiskType','SerialNumber')
foreach ($diskdrive in $wmi_diskdrives) 
{
    if ($null -ne $diskdrive) # PS2.0 check
    {
        $partitionquery = "ASSOCIATORS OF {Win32_DiskDrive.DeviceID=`"$($diskdrive.DeviceID.replace('\','\\'))`"} WHERE AssocClass = Win32_DiskDriveToDiskPartition"
        $partitions = @(Get-WmiObject @WMIHast -Query $partitionquery)
        foreach ($partition in $partitions)
        {
            if ($null -ne $partition) # PS2.0 check
            {
                $logicaldiskquery = "ASSOCIATORS OF {Win32_DiskPartition.DeviceID=`"$($partition.DeviceID)`"} WHERE AssocClass = Win32_LogicalDiskToPartition"
                $logicaldisks = @(Get-WmiObject @WMIHast -Query $logicaldiskquery)
                foreach ($logicaldisk in $logicaldisks)
                {
                    if ($null -ne $logicaldisk) # PS2.0 check
                    {
                        $PercentFree = [math]::round((($logicaldisk.FreeSpace/$logicaldisk.Size)*100), 2)
                        $UsedSpace = ($logicaldisk.Size - $logicaldisk.FreeSpace)
                        $diskprops = @{
                                        ComputerName = $ComputerName
                                        Disk = $diskdrive.Name
                                        Model = $diskdrive.Model
                                        Partition = $partition.Name
                                        Description = $partition.Description
                                        PrimaryPartition = $partition.PrimaryPartition
                                        VolumeName = $logicaldisk.VolumeName
                                        Drive = $logicaldisk.Name
                                        DiskSize = if ($RawDriveData) { $logicaldisk.Size } else { $logicaldisk.Size | ConvertTo-KMG }
                                        FreeSpace = if ($RawDriveData) { $logicaldisk.FreeSpace } else { $logicaldisk.FreeSpace | ConvertTo-KMG }
                                        UsedSpace = if ($RawDriveData) { $UsedSpace } else { $UsedSpace | ConvertTo-KMG }
                                        PercentFree = $PercentFree
                                        PercentUsed = [math]::round((100 - $PercentFree),2)
                                        DiskType = 'Partition'
                                        SerialNumber = $diskdrive.SerialNumber
                                        }
                        $DiskInfos += New-Object psobject -Property $diskprops | Select $DiskElements
                    }
                }
            }
        }
    }
}
# Mountpoints are weird so we do them seperate.
if ($wmi_mountpoints)
{
    foreach ($mountpoint in $wmi_mountpoints)
    {
        if ($null -ne $mountpoint) # PS2.0 check
        {
            $PercentFree = [math]::round((($mountpoint.FreeSpace/$mountpoint.Capacity)*100), 2)
            $UsedSpace = ($mountpoint.Capacity - $mountpoint.FreeSpace)
            $diskprops = @{
                    ComputerName = $ComputerName
                    Disk = $mountpoint.Name
                    Model = ''
                    Partition = ''
                    Description = $mountpoint.Caption
                    PrimaryPartition = ''
                    VolumeName = ''
                    VolumeSerialNumber = ''
                    Drive = [Regex]::Match($mountpoint.Caption, "(^.:)").Value
                    DiskSize = if ($RawDriveData) { $mountpoint.Capacity } else { $mountpoint.Capacity | ConvertTo-KMG }
                    FreeSpace = if ($RawDriveData) { $mountpoint.FreeSpace } else { $mountpoint.FreeSpace | ConvertTo-KMG }
                    UsedSpace = if ($RawDriveData) { $UsedSpace } else { $UsedSpace | ConvertTo-KMG }
                    PercentFree = $PercentFree
                    PercentUsed = [math]::round((100 - $PercentFree),2)
                    DiskType = 'MountPoint'
                    SerialNumber = $mountpoint.SerialNumber
                    }
            $DiskInfos += New-Object psobject -Property $diskprops  | Select $DiskElements
        }
    }
}


Write-Verbose -Message ('Get-RemoteDiskInformation: Runspace {0}: End' -f $ComputerName)



YACKPipe-ReturnCSV -PowershellObjects $DiskInfos -OutputName "DiskInfo.csv"
