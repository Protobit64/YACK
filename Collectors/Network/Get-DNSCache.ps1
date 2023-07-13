<#
.DEPENDENCY
.PSM_DEPENDENCY DataTransfer.psm1 

.SYNOPSIS
Collects DNS records present on the system.

.NOTES
License: Apache 2.0
Credits: kansa github. Connor Martin.
#>



$AllEvents = New-Object System.Collections.ArrayList
$Obj = "" | Select-Object TimeToLive, Caption, Description, ElementName,
    InstanceID, Data, DataLength, Entry, Name, Section, Status, Type

$(& ipconfig /displaydns | Select-Object -Skip 3 | % { $_.Trim() }) | % { 
    switch -Regex ($_) 
    {
        "-----------" {
        }
        "Record Name[\s|\.]+:\s(?<RecordName>.*$)" 
        {
            $Name = ($matches['RecordName'])
        } 

        "Record Type[\s|\.]+:\s(?<RecordType>.*$)" 
        {
            $RecordType = ($matches['RecordType'])
        }

        "Time To Live[\s|\.]+:\s(?<TTL>.*$)" 
        {
            $TTL = ($matches['TTL'])
        }

        "Data Length[\s|\.]+:\s(?<DataLength>.*$)" 
        {
            $DataLength = ($matches['DataLength'])
        }

        "Section[\s|\.]+:\s(?<Section>.*$)" 
        {
            $Section = ($matches['Section'])
        }

        "(?<Type>[A-Za-z()\s]+)\s.*Record[\s|\.]+:\s(?<Data>.*$)" 
        {
            $Type,$Data = ($matches['Type'],$matches['Data'])
            $Obj.TimeToLive  = $TTL
            $Obj.Caption     = ""
            $Obj.Description = ""
            $Obj.ElementName = ""
            $Obj.InstanceId  = ""
            $Obj.Data        = $Data
            $Obj.DataLength  = $DataLength
            $Obj.Entry       = $Entry
            $Obj.Name        = $Name
            $Obj.Section     = $Section
            $Obj.Status      = ""
            $Obj.Type        = $Type


            [void]$AllEvents.Add($Obj)
        }

        "^$" 
        {
            $Obj = "" | Select-Object TimeToLive, Caption, Description, ElementName,
            InstanceID, Data, DataLength, Entry, Name, Section, Status, Type
        }
        default 
        {
            $Entry = $_
        }
    }
}




YACKPipe-ReturnCSV -PowershellObjects $AllEvents.ToArray() -OutputName "DNSCache.csv" 
