<#
.DEPENDENCY
.PSM_DEPENDENCY DataTransfer.psm1 

.SYNOPSIS
This file is the template for creating collectors

.DESCRIPTION
A collector is a stand alone powershell script that will be ran on the target system.
If it depends on external resource then you must put those resource in the
folder _Dependencies and include it's name after the ".DEPENDENCY" directive.
This file or folder will then be transfered to the target's %SystemRoot%/YACK folder.
Results from the collector need to be returned to the scripts in a CollectorResult Object
which is templated below. YACK.ps1 supports returning multiple seperate $CollectorResults from
the same script.

.PARAMETER CollectorParameter
A description of a parameter that needs to be defined in the yack.conf file.

.EXAMPLE
.\Template.ps1 "YourValue"
  AN example of the collector being called.

.NOTES
License: {Insert license here}
Credits: {Your Name here}
#>




################################
# Run your powershell code here


$TemplateResults = $null


YACKPipe-ReturnCSV -PowershellObjects $TemplateResults -OutputName "template.csv" -YACKOutputFolder "misc"
