<#
.DEPENDENCY 

.SYNOPSIS
This script does nothing.

.NOTES
License: 
Credits: Connor Martin.
#>

#$null = Start-Sleep -Seconds 4

$CollectorResult = "" | Select-Object Error, ErrorMessage, OutputType, OutputName, OutputFolder, Content
$CollectorResult.OutputType = "array"
$CollectorResult.OutputName = "Nothing.txt"
$CollectorResult.Content = $null


$CollectorResult