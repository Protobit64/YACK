<#
.DEPENDENCY 
.PSM_DEPENDENCY DataTransfer.psm1 

.SYNOPSIS
Parses the local HBSS HipShield cache which contains detail event data 
for HIPS. This file is originally in xml formatand can be quite large 
so this can take some time.

.OUTPUTS
A json string formatted for ingest into Splunk.

.NOTES
Credit: Connor Martin
License: 
#>


function ConvertTo-Splunk ($TimeFieldName = $null)
{
    <#
    .SYNOPSIS
    Converts data from a hash table to json formatted for splunk ingest.
    
    .PARAMETER TimeFieldName
    The name of the field which is for time. It gets added to the JSON first.
    #>

    begin
    {
        #As data is being piped in. Add it to an array to digest.
        $Data = @()
    }
    Process
    {
        $Data += $_
    }
    End
    {

        $HashT = $Data[0]
        $JSONResult=''

        #Parse the TimeField first if provided.
        if ($null -ne $TimeFieldName) 
        {
            $JSONResult +='"{0}":"{1}",' -f $TimeFieldName, ($HashT[$TimeFieldName])
            $HashT.Remove("$TimeFieldName")
        }

        #Add each value for the key
        foreach($Key in $HashT.keys) 
        {
            if ($null -ne $Key) # PS2.0 check
            {
                $JSONResult +='"{0}":"{1}",' -f $Key, ($HashT[$Key])
            }
        }

        #Splunk doesn't like tabs and single slashes
        $JSONResult = $JSONResult.Substring(0,$JSONResult.Length-3) -replace "\\", "\\"
        $JSONResult = $JSONResult -replace "`t", " "

        return '{' + $JSONResult + '"}'
    }
}


#Possible HipShield log locations
$HBSSLogPath1 = "C:\Program Data\McAfee\Host Intrusion Prevention\HipShield.log"
$HBSSLogPath2 = "C:\Documents and settings\all users\application data\mcafee\host intrusion prevention\HipShield.log"

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


if ($HBSSLogPath -ne "")
{
    #Read HipShield into a buffer to parse
    $AllText = [IO.File]::ReadAllText($HBSSLogPath)

    #Parse the raw text into a hash table.
    $ParsedIndex = 0
    $AllEvents = New-Object System.Collections.ArrayList
    $EventStart = $AllText.IndexOf("<Event>", $ParsedIndex)

    #While events are still being found in the file.
    while ($EventStart -ne -1)  
    {
        $HashT = @{}

        #Get the start and end index of the event
        $EventDataStart = $AllText.IndexOf("<EventData", $EventStart)
        $EventDataEnd = $AllText.IndexOf("<Params>", $EventDataStart)
        $EventDataSubstring = $AllText.Substring($EventDataStart, $EventDataEnd - $EventDataStart - 4) #extra space
        $EventDataSplit = $EventDataSubstring -split "`n"

        #Parse Event Data from the event
        for ($i = 1; $i -lt $EventDataSplit.Length; $i++) 
        {
            $NameInd = $EventDataSplit[$i].IndexOf("=")
            $NameSubstring = $EventDataSplit[$i].Substring(2,$NameInd-2) #for 2 spaces

            $HashTEnd = $EventDataSplit[$i].LastIndexof('"')
            $HashTStr = $EventDataSplit[$i].Substring($NameInd+1+1, $HashTEnd - $NameInd - 2) #magic numbers for removing qoutes

            #Add event data to hash table
            $null = $HashT.Add($NameSubstring, $HashTStr)
        }
        

        #Find the parameters index
        $ParmsOffset = "</Params>".Length
        $ParmsStart = $EventDataEnd
        $ParmsEnd = $AllText.IndexOf("</Params>", $ParmsStart)
        $ParmsSubstring = $AllText.Substring($ParmsStart, $ParmsEnd - $ParmsStart + $ParmsOffset)
        $ParmsSplit = $ParmsSubstring -split "`n"

        #Parse parms from the event
        for ($i = 1; $i -lt ($ParmsSplit.Length - 1); $i++) 
        {
            $NameStart = $ParmsSplit[$i].IndexOf("=")
            $NameEnd = $ParmsSplit[$i].IndexOf("allowex=", $NameStart)
            $NameSubstring = $ParmsSplit[$i].Substring($NameStart+2, $NameEnd-$NameStart - 4) #magic numbers for removing qoutes

            $ValueStart = $ParmsSplit[$i].IndexOf(">", $NameEnd)
            $ValueEnd = $ParmsSplit[$i].IndexOf("</Param>", $ValueStart)

            $ValueSubstring = $ParmsSplit[$i].Substring($ValueStart+1, $ValueEnd - ($ValueStart+1)) #magic numbers for removing qoutes

            #Add parm data into the hash table.
            $null = $HashT.Add($NameSubstring, $ValueSubstring)
        }

        #increment ParsedIndex to keep searching for the last event
        $ParsedIndex = $ParmsEnd 
        $EventStart = $AllText.IndexOf("<Event>", $ParsedIndex)

        $null = $AllEvents.Add($($HashT | ConvertTo-Splunk "IncidentTime"))
    }

    YACKPipe-ReturnArray -ArrayResult $AllEvents.ToArray() -OutputName "HipShield.json"

}
else 
{
    YACKPipe-ReturnError -ErrorMessage "Could not find HBSS HipShield Log"
}


$CollectorResult

