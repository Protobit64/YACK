
# ============================================================================
# Description: Collect Processor and related attributes.
# Arguments:
# 	ModulePath - 
# 	OutputPath -
# Example:
# ============================================================================

Param(
    [string]$OutputPath,
    [string]$ContentPath
)



function Get-BetterTasklist {
	[cmdletbinding()]
	Param([bool] $NoHash = $false)
	$TimeGenerated = get-date -format r
	$betterPsList = Get-WmiObject -Class Win32_process `
		| select -property Name,ProcessID,ParentProcessId,ExecutablePath,CommandLine `
		| Foreach {
			if ($_.ExecutablePath -ne $null -AND -NOT $NoHash) {
				$sha1 = New-Object -TypeName System.Security.Cryptography.SHA1CryptoServiceProvider
				$hash = [System.BitConverter]::ToString($sha1.ComputeHash([System.IO.File]::ReadAllBytes($_.ExecutablePath)))
				$_ | Add-Member -MemberType NoteProperty SHA_1 $($hash -replace "-","")
			} else {
				$_ | Add-Member -MemberType NoteProperty SHA_1 $null
			}
			$_ | Add-Member -MemberType NoteProperty TimeGenerated $TimeGenerated
			$_
		}
	$betterPsList | Select TimeGenerated,Name,ProcessID,ParentProcessId,ExecutablePath,SHA_1,CommandLine
}

function LogAndEcho ($Text)
{
    $timestamp = $((get-date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ"))

    #Write to Log
    "$timestamp : $Text" | Out-File -Append "$OutputPath\CollectorLog.txt"
    #Write to console
    Write-Host "$timestamp : $Text"
}



$Output = $(Get-BetterTasklist)

$Output | Export-Csv -Path "$OutputPath/Program_Execution/Processes.csv"

LogAndEcho "Results: $($Output.Count) Processes"

