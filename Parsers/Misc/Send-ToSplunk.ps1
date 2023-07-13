<#
.SYNOPSIS
Sends all supported formats into a splunk indexer. You must enable HTTP Event 
Collector (NOT HTTPS... TLS is not supported) in splunk and then 
generate a token.

https://docs.splunk.com/Documentation/Splunk/7.1.2/Data/UsetheHTTPEventCollector

.PARAMETER SplunkIP
The IP address of the splunk indexer.

.PARAMETER HECPort
The configured port to forward HEC events into.

.PARAMETER HECToken
The SPLUNK generated HEC token to authenticate with.


.NOTES
License: Apache License 2.0
Credits: Connor Martin.
#>

#Requires -Version 3.0

Param(
    [Parameter(Mandatory=$true,Position=0)]
    $ParsersPath,
    [Parameter(Mandatory=$true,Position=1)]
    $TargetFolder,
    [Parameter(Mandatory=$true,Position=2)]
    $SplunkIP,
    [Parameter(Mandatory=$true,Position=3)]
    $HECPort,
    [Parameter(Mandatory=$true,Position=4)]
    $HECToken
)


function ConvertTo-SplunkJSON ($object) 
{
    <#
    .SYNOPSIS
    Converts data from a hash table to json formatted for splunk ingest.
    
    .PARAMETER TimeFieldName
    The name of the field which is for time. It gets added to the JSON first.
    #>

    $JSONResult = ""
    
    foreach ($prop in $object.psobject.properties) { if ($prop) 
    { 
        $JSONResult +='"{0}":"{1}",' -f $prop.name, $prop.Value
    }}

    #Splunk doesn't like tabs and single slashes
    $JSONResult = $JSONResult.Substring(0,$JSONResult.Length-3) -replace "\\", "\\"
    $JSONResult = $JSONResult -replace "`t", " "

    return '{' + $JSONResult + '"}'

}
function Send-CsvToSplunk($FilePath, $CollectionHostname)
{
    
    $token = $script:SplunkToken
    $server = $script:SplunkServer
    $port = $script:SplunkPort

    #Import data 
    $DataEvents = Import-Csv $FilePath

    $Filename = $FilePath | Split-Path -leaf

    #Configure url for upload
    $url = "http://${SplunkIP}:$HECPort/services/collector/event"
    $header = @{Authorization = "Splunk $HECToken"}

    foreach ($DataEvent in $DataEvents)  { if ($DataEvent) #PS2.0 Check
    {
        $eventData = ConvertTo-SplunkJSON $DataEvent
        $jsonbody = "{`"host`": `"$CollectionHostname`",`"source`": `"YACK`",`"sourcetype`": `"$Filename`",`"event`":$eventData}"

        Invoke-RestMethod -Method Post -Uri $url -Headers $header -Body $jsonbody
        #Invoke-WebRequest -Method Post -Uri $url -Headers $header -Body $jsonbody
    }}

}

$CollectionHostname = $TargetFolder | Split-Path -Leaf
$CollectedDataFolders = Get-ChildItem $TargetFolder | ?{ $_.PSIsContainer }

foreach ($DataFolder in $CollectedDataFolders)  { if ($DataFolder) #PS2.0 Check
{
    $DataFiles = Get-ChildItem $DataFolder.FullName | ?{ !$_.PSIsContainer }

    foreach ($DataFile in $DataFiles)  { if ($DataFile) #PS2.0 Check
    {
        if ($DataFile.Extension -eq '.csv') 
        {
            Send-CsvToSplunk $DataFile.FullName $CollectionHostname
        }
    }}
}}











