<#
.SYNOPSIS
Prints a listing of prefetch files.

Prefetch files contain the name of the executable, a Unicode list of DLLs used 
by that executable, a count of how many times the executable has been run, and a 
timestamp indicating the last time the program was run. (https://www.forensicswiki.org/wiki/Prefetch)

Win XP+

Windows 8+
Embedded Timestamps for the last 8 times the application was run 

.DESCRIPTION
This requires that the prefetch file were collected with Get-PrefetchFiles.

.NOTES
License: Apache License 2.0
Credits: Connor Martin.
#>


Param(
    [Parameter(Mandatory=$true,Position=0)]
        $ParsersPath,
      [Parameter(Mandatory=$true,Position=1)]
        $TargetFolder = $null
)



$BinPath = "$ParsersPath\_Dependencies\winprefetchview\WinPrefetchView.exe"
$TargetDataPath = "$TargetFolder\Exec_Historical\Prefetch"
$OutputFolder = "$TargetFolder\Exec_Historical\"

if (Test-Path $BinPath)
{
  if (Test-Path $TargetDataPath)
  {
    & $BinPath  "/scomma" "$OutputFolder\PrefetchTemp.csv" "/folder" "$TargetDataPath" | Out-Null


    #Ingest output
    $Headers = @("Filename", "CreatedTime", "ModifiedTime", "FileSize", "ProcessEXE", "ProcessPath", "RunCounter", "LastRunTime", "MissingProcess")
    $PrefetchTimes = Import-Csv "$OutputFolder\PrefetchTemp.csv"  -Header $Headers


    #Create an entry for each LastRunTIme
    $RunTimeList = New-Object System.Collections.ArrayList
    foreach ($PrefetchTime in $PrefetchTimes)
    {
      if ($null -ne $PrefetchTime)
      {
        $LastRunTimes = $PrefetchTime.LastRunTime.split(',')

        #Add each Last Run time to the list
        foreach ($LastRunTime in $LastRunTimes)
        {
          if ($null -ne $LastRunTime)
          {
            $RunTime = New-Object -TypeName PSObject -Property @{
                  'RunTimeUTC' = $(Get-Date -Date $LastRunTime.TrimStart()).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
                  'ProcessEXE' = $PrefetchTime.ProcessEXE
                  'ProcessPath' = $PrefetchTime.ProcessPath
                  'Filename' = $PrefetchTime.Filename
                  'FileSize' = $PrefetchTime.FileSize
            }
            $RunTime = $RunTime | Select-Object RunTimeUTC, ProcessEXE, ProcessPath, Filename, FileSize
            $null = $RunTimeList.Add($RunTime)
          }
        }
      }
    }



    #Sort newest to oldest and export
    $RunTimeList | Sort-Object RunTimeUTC -Descending | Export-Csv -Path "$OutputFolder\PrefetchTimeline.csv" -NoTypeInformation

    #Remove Temp item
    Remove-Item -Path "$OutputFolder\PrefetchTemp.csv" -Force 

    return $true
  }
  else 
  {
    #Bin path does not exist
    throw [System.IO.FileNotFoundException] "Target data not found."
  }
}
else 
{
  #Bin path does not exist
  throw [System.IO.FileNotFoundException] "Parser dependencies not found."
}


