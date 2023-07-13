
<#
.DEPENDENCY
.PSM_DEPENDENCY DataTransfer.psm1 

.SYNOPSIS
Retreives all shared directories on this pc.

.NOTES
License: 
Credits: Connor Martin.

# You can get share ACLs 
# $acl = WMIObject -Class Win32_LogicalShareSecuritySetting
# $acl.GetSecurityDescriptor().Descriptor.DACL
# $acl.GetSecurityDescriptor().Descriptor.DACL.Trustee
# Newer version of windows have Get-smbShare which is superior
#>


$ShareType = @{
    "0" = "Disk Drive"
    "1" = "Print Queue"
    "2" = "Device"
    "3" = "IPC"
    "2147483648" = "Disk Drive Admin"
    "2147483649" = "Print Queue Admin"
    "2147483650" = "Device Admin"
    "2147483651" = "IPC Admin"
}


$Shares = Get-WmiObject -Class win32_share  | Select-Object PSComputername, Name, Path, Description, @{l="Type";e={$ShareType["$($_.Type)"]}}


YACKPipe-ReturnCSV -PowershellObjects $Shares -OutputName "NetworkShares.csv"
