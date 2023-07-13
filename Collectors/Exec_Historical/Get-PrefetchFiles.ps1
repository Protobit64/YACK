
<#
.DEPENDENCY 
.PSM_DEPENDENCY DataTransfer.psm1 

.SYNOPSIS
Prints a listing of prefetch files.

Prefetch files contain the name of the executable, a Unicode list of DLLs used 
by that executable, a count of how many times the executable has been run, and a 
timestamp indicating the last time the program was run. (https://www.forensicswiki.org/wiki/Prefetch)
Disabled by default on servers. Enabled since Win XP+ and for win8+ the embedded Timestamps for the last 
8 times the application was run is saved.


.NOTES
License: Apache License 2.0
Credits: kansa(github).
#>


$SRUMFilePath = "C:\Windows\Prefetch"

YACKPipe-ReturnFolderOrFile -SourceFilePath $SRUMFilePath -YACKOutputFolder "Exec_Historical\Prefetch\"


