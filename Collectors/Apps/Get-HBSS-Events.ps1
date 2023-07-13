<#
.DEPENDENCY 
.PSM_DEPENDENCY DataTransfer.psm1 

.SYNOPSIS
Parses the local HBSS event cache.

.NOTES
Credit: Connor Martin
License: 
When HBSS event logs reach max size then it is prepended with .1 and so on.
#>


################################## Start Collector Code ##################################################


# Rather than checking OS version just see if the files exist.
# Although I dont support XP anyways so it shouldn't matter.
$HBSSLogPath1 = "C:\Program Data\McAfee\Host Intrusion Prevention\event.log"
$HBSSLogPath2 = "C:\Documents and settings\all users\application data\mcafee\host intrusion prevention\event.log"

#Select Folder
if (Test-Path $HBSSLogPath1) 
{
    $HBSSLogPath =$HBSSLogPath1
}
elseif (Test-Path $HBSSLogPath2)
{
    $HBSSLogPath = $HBSSLogPath2
}
else 
{
    $HBSSLogPath = ""
}

#If the file was found
if ($HBSSLogPath -ne "") 
{
    $ClientControlBinPath = "C:\Program Files\McAfee\Host Intrusion Prevention\ClientControl.exe"
    if (Test-path $ClientControlBinPath)
    {
        $OutputFolder = "$env:temp\yack\"
        #Create Folder
        $temp = New-Item -Path $OutputFolder -ItemType directory -Force

        #Parse mcafee formatted log into a more readable format. Using mcafee's local tool
        &$ClientControlBinPath /export /s "$HBSSLogPath" "$OutputFolder\mcafee_events.log"

        #Read in the parsed file and split into an event array
        #$AllEvents = Get-Content -Raw "$OutputFolder\mcafee_events.log" -Encoding Unicode
        $RawText = [IO.File]::ReadAllText("$OutputFolder\mcafee_events.log", [System.Text.Encoding]::Unicode)
        $AllEvents = $RawText -split "(?=`nTime:)"
        
        $ParsedEvents = @()

        #Parse the human readable format into a PSObject
        for ($i = 1; $i -le $AllEvents.Length; $i++) 
        {
            #Parse the fields into a hash table
            $HashT = @{}
            $KeyValuePairs = $AllEvents[$i] -split "`n"

            #Parse out the key and value pairings
            foreach($Pair in $KeyValuePairs) 
            {
                if ($null -ne $Pair) # PS2.0 check
                {
                    $Ind = $Pair.indexof(":")
                    if ($Ind -gt 0) {
                        $Name = $Pair.substring(0, $Ind)
                        $Value = $Pair.substring($Ind + 1, $Pair.length - $Ind - 1).TrimStart().TrimEnd()
                        $HashT.Add($Name,$Value)
                    }
                }
            }
            #Convert Hash Table to PS Object and add to events if it's not blank
            if ($HashT.Count -gt 0)
            {
                $ParsedEvents += New-Object psobject -Property $HashT
            }
        }
        #Cleanup folder
        $temp = Remove-Item -Path $OutputFolder -Recurse
        
        # Because HBSS Event objects have different properties you have to build a list of all the properties
        # and select all properties so that it exports to csv correctly.
        $properties = $ParsedEvents | ForEach-Object { 
            $_ | Get-Member -MemberType Property, NoteProperty
            } | Select-Object -ExpandProperty Name -Unique

        $ParsedEvents = $ParsedEvents | Select-Object ([String[]]$properties)

        YACKPipe-ReturnCSV -PowershellObjects $ParsedEvents -OutputName "HBSSEvents.csv"
    }
    else 
    {
        YACKPipe-ReturnError "Could not find McAfee's ClientControl Binary."
    }
}
else
{
    YACKPipe-ReturnError "Could not find HBSS Events Log"
}
