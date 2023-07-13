
<#
.SYNOPSIS
The controlling script to run collectors agaisnt target machines.

.DESCRIPTION
This script will run forensic triage collection collectors agaisnt local or remote machines
and return the results to local output folder. PSRemoting most be enabled in the domain
if remote collection is to be used.

.EXAMPLE
An example

.NOTES
Inspired by kansa(github) so large portions of this script are similar.
Credit: Connor Martin // kansa(github)
License: Depends on the section
#>


#Includes
$Script:ScriptPath = Split-Path $script:MyInvocation.MyCommand.Path
$Script:FunctionFolder = "$Script:ScriptPath\Internals\Functions\"
. $Script:FunctionFolder\Settings.ps1
. $Script:FunctionFolder\Collectors.ps1
. $Script:FunctionFolder\Log.ps1
. $Script:FunctionFolder\Dependencies.ps1
. $Script:FunctionFolder\Parsers.ps1




################################################################################################


#Print the main banner
Write-Host "==========================================================================="
Write-Host "                   Yb  dP     db     .d88b   8  dP"
Write-Host "                    YbdP     dPYb    8P      8wdP "
Write-Host "                     YP     dPwwYb   8b      88Yb "
Write-Host "                     88    dP    Yb   Y88P   8  Yb"
Write-Host "==========================================================================="

#Initialize the settings
if (Read-Settings)
{
    #Get User confirmation of settings
    if ($(Test-Settings) -eq $true) 
    {
        #If collectors are enabled
        if ($Script:RunCollectors)
        {
            #Start collection according to which mode
            if ($Script:CollectionMode -eq "Local") 
            {
                Start-LocalCollection
            }
            elseif ($Script:CollectionMode -eq "Remote") 
            {
                Start-RemoteCollection
            }
        }

        #If parsers are enabled then run them.
        if ($Script:RunParsers)
        {
            Start-Parsers -YACKResultFolder $Script:OutputPath -ScriptLogPath $Script:ScriptLogPath `
                -ParsersPath $Script:ParsersPath -ParserListPath $Script:ParsersListPath
        }
    }
}
