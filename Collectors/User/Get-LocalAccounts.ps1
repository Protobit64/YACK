<#
.DEPENDENCY
.PSM_DEPENDENCY DataTransfer.psm1 

.SYNOPSIS
Retreives all local Accounts.

.NOTES
License: 
Credits: Connor Martin.
#>


$ComputerName = $Env:COMPUTERNAME

$UserAccounts = Get-WmiObject -Class win32_useraccount -filter "Domain = '$ComputerName'" `
    | Select-Object PSComputername, Name, Domain, Caption, Disabled, LocalAccount, `
        Lockout, AccountType, PasswordChangeable, PasswordExpires, PasswordRequired, SID, Description

foreach ($UAcc in $UserAccounts)
{
    if ($null -ne $UAcc) # PS2.0 check
    {
        switch ($UAcc.AccountType)
        {
            256 {
                $UAcc.AccountType = "TEMP_DUPLICATE_ACCOUNT"
            }
            512 {
                $UAcc.AccountType = "NORMAL_ACCOUNT"
            }
            2048 {
                $UAcc.AccountType = "INTERDOMAIN_TRUST_ACCOUNT"
            }
            4096 {
                $UAcc.AccountType = "WORKSTATION_TRUST_ACCOUNT"
            }
            8192 {
                $UAcc.AccountType = "SERVER_TRUST_ACCOUNT"
            }

            default { 
                $UAcc.AccountType = "UNKOWN"
            }

            
        }
    }
}

#"The system account is an internal account that does not show up in User Manager, cannot be added to any groups, 
# and cannot have user rights assigned to it. However, "
$SystemAccounts = Get-WmiObject -Class Win32_SystemAccount -filter "Domain = '$ComputerName'" `
    | Select-Object PSComputername, Name, Domain, Caption, Disabled, LocalAccount, `
        Lockout, @{l="AccountType";e={"SYSTEM_ACCOUNT"}}, PasswordChangeable, PasswordExpires, PasswordRequired, SID, Description


YACKPipe-ReturnCSV -PowershellObjects $($UserAccounts + $SystemAccounts) -OutputName "LocalAccounts.csv"

