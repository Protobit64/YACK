<#
.DEPENDENCY 

.SYNOPSIS
Parse an evtx binary to a JSON file. Currently under dev.

.OUTPUTS
A json string formatted for ingest into Splunk.

.NOTES
Credit: Connor Martin
License: Apache 2.0
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
            if ($null -ne $Key) #ps2.0 check
            {
                $JSONResult +='"{0}":"{1}",' -f $Key, ($HashT[$key])
            }
        }

        #Splunk doesn't like tabs and single slashes
        $JSONResult = $JSONResult.Substring(0,$JSONResult.Length-3) -replace "\\", "\\"
        $JSONResult = $JSONResult -replace "`t", " "

        return '{' + $JSONResult + '"}'
    }
}


#Use wevtutil to read the log into xml
$EventsXML = wevtutil qe "Security" /f:xml
$EventsNewlined = "$EventsXML" -replace "</Event> <Event", "</Event>`n<Event"

#Parse the xml into event substrings
$Events =  $EventsNewlined -split "`n"

$AllEvents = New-Object System.Collections.ArrayList

#Iterate through each event and parse the data into a hash table
for ($i = 0; $i -lt $Events.Length; $i++) 
{
    $HashT = @{}
    #regex for system
    $temp = $($Events[$i] -match '<System[\s\S]*?<\/System>')
    if ($temp -eq $true) 
    {
        #Convert the string to an xml item
        $SystemXML = $($matches[0] |Select-Xml -XPath "//System").Node

        #Select the vars from it
        $HashT.Add("Provider",$SystemXML['Provider'].Name)
        $HashT.Add("EventRecordID",$SystemXML['EventRecordID'].'#text')

        $HashT.Add("Channel",$SystemXML['Channel'].'#text')
        $HashT.Add("Computer",$SystemXML['Computer'].'#text')

        $HashT.Add("EventID",$SystemXML['EventID'].'#text')
        $HashT.Add("TimeCreated",$SystemXML['TimeCreated'].SystemTime)

        #Parse the event data
        $temp = $($Events[$i] -match '<EventData>[\s\S]*?<\/EventData>')
        if ($temp -eq $true) 
        {
            #Convert the string to an xml objext
            $EventdataXML = $($matches[0] |Select-Xml -XPath "//EventData").Node

            #Add each key/value pair to Hash Table
            foreach ($Eventdata in $EventdataXML.Data) 
            {
                if ($null -ne $EventData.Name) 
                {
                    $HashT.Add($Eventdata.Name,$EventdataText)
                }
            }
        }
        #Convert the hash table to a Splunk formatted json string.
        [void]$AllEvents.Add($($HashT | ConvertTo-Splunk))
    }
}


#Result template
$CollectorResult = "" | Select-Object Error, ErrorMessage, OutputType, OutputName, OutputFolder, Content
$CollectorResult.OutputType = "array"
$CollectorResult.OutputName = "WinEvent_Security.json" 
$CollectorResult.Content = $AllEvents.ToArray()

$CollectorResult

