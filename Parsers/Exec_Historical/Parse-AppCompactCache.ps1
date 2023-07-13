
<#
.SYNOPSIS
AKA ShimCache
Tracks the executables file name, file size, last modified time, and in Windows XP the last update time  - SANS


.NOTES
This requires that the SYSTEM hive and it's associated LOG files were collected.
SYSTEM
SYSTEM.LOG
SYSTEM.LOG1
SYSTEM.LOG2

Credit: Eric Zimmerman. Connor Martin for YACK
License: MIT License
https://github.com/EricZimmerman/AppCompatCacheParser
#>


Param(
    [Parameter(Mandatory=$true,Position=0)]
        $ParsersPath,
      [Parameter(Mandatory=$true,Position=1)]
        $TargetFolder = $null
)


$BinPath = "$ParsersPath\_Dependencies\AppCompatCacheParser.exe"
$TargetDataPath = "$TargetFolder\Logs\SYSTEM"
$OutputFolder = "$TargetFolder\Exec_Historical\"


#check if binary exists
if (Test-Path $BinPath) 
{
    #Check if Data exists
    if (Test-Path $TargetDataPath)
    {
        $temp = (& $BinPath "-f" "$TargetDataPath" "--csv" "$OutputFolder" "-t")

        #Read in results
        $AmcacheResults = Get-ChildItem $OutputFolder

        #Rename file for uniformity
        foreach ($CSV in $AmcacheResults) { if ($CSV) #PS2.0 check
        {
            $ind = $CSV.Name.IndexOf("AppCompatCache.csv")
            if ($ind -gt -1)
            {
                $NewFileName = $CSV.Name.Substring($ind, $CSV.Name.Length - $ind)
                $Destination = Join-Path -Path $CSV.Directory.FullName -ChildPath $NewFileName
                Move-Item -Path $CSV.FullName -Destination $Destination -Force
            }
            #$CSV
        }}

        if (!$AmcacheResults)
        {
            throw [System.IO.FileNotFoundException] "No results from AmcacheParser were produced."  
        }
    }
    else 
    {
        throw [System.IO.FileNotFoundException] "Target data not found."
    }
}
else 
{
    throw [System.IO.FileNotFoundException] "Couldn't find $BinPath"
}
