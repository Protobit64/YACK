
<#
.SYNOPSIS
Win8+ the Amcache.hve replaces RecentFilceCache.bcf. Amcache contains the recent processes that 
were run and lists the path of the files and hash


.NOTES
This requires that Amcache.hve was collected with Get-RawFile.ps1.

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


$BinPath = "$ParsersPath\_Dependencies\AmcacheParser.exe"
$TargetDataPath = "$TargetFolder\Exec_Historical\Amcache\Amcache.hve"
$OutputFolder = "$TargetFolder\Exec_Historical\Amcache\"


#check if binary exists
if (Test-Path $BinPath) 
{
    #Check if Data exists
    if (Test-Path $TargetDataPath)
    {
        $temp = (& $BinPath "-f" "$TargetDataPath" "--csv" "$OutputFolder")

        #Read in results
        $AmcacheResults = Get-ChildItem $OutputFolder

        #Rename file for uniformity
        foreach ($CSV in $AmcacheResults) { if ($CSV) #PS2.0 check
        {
            $ind = $CSV.Name.IndexOf("Amcache_")
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
