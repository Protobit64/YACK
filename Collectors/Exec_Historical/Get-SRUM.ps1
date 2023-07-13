
<#
.DEPENDENCY 
.PSM_DEPENDENCY DataTransfer.psm1 

.SYNOPSIS
Copies the SRUM db from the file system. 
Records 30 to 60 days of historical system performance. 
Applications run, user account responsible for each, and application and bytes sent/received per application per hour. -SANS
This is a Win8+ artifact.


.NOTES
License: Apache License 2.0
Credits: Connor Martin
#>


$SRUMFilePath = "C:\Windows\System32\sru\SRUDB.dat"

YACKPipe-ReturnFile -SourceFilePath $SRUMFilePath -YACKOutputFolder $null
