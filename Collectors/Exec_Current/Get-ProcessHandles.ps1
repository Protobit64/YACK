<#
.DEPENDENCY handle.exe
.PSM_DEPENDENCY DataTransfer.psm1 

.SYNOPSIS
Gets all handles for currently running processes.

.NOTES
License: Apache License 2.0
Credits: kansa(github) // Connor Martin
#>



$AllEvents = New-Object System.Collections.ArrayList

if (Test-Path "$env:SystemRoot\yack\handle.exe") 
{
    $HandleResults = (& $env:SystemRoot\yack\handle.exe /accepteula -a)

    foreach($Line in $HandleResults) 
    {
        if ($null -ne $Line) # PS2.0 check
        {
            $Line = $Line.Trim()
            if ($Line -match " pid: ") 
            {
                $HandleId = $Type = $Perms = $Name = $null
                $Pattern = "(?<ProcessName>^[-a-zA-Z0-9_.]+) pid: (?<PId>\d+) (?<Owner>.+$)"
                if ($Line -match $Pattern) 
                {
                    $ProcessName,$ProcId,$Owner = ($matches['ProcessName'],$matches['PId'],$matches['Owner'])
                }
            } 
            else 
            {
                $Pattern = "(?<HandleId>^[a-f0-9]+): (?<Type>\w+)"
                if ($Line -match $Pattern) 
                {
                    $HandleId,$Type = ($matches['HandleId'],$matches['Type'])
                    $Perms = $Name = $null
                    switch ($Type) 
                    {
                        "File" 
                        {
                            $Pattern = "(?<HandleId>^[a-f0-9]+):\s+(?<Type>\w+)\s+(?<Perms>\([-RWD]+\))\s+(?<Name>.*)"
                            if ($Line -match $Pattern) 
                            {
                                $Perms,$Name = ($matches['Perms'],$matches['Name'])
                            }
                        }
                        default 
                        {
                            $Pattern = "(?<HandleId>^[a-f0-9]+):\s+(?<Type>\w+)\s+(?<Name>.*)"
                            if ($Line -match $Pattern) 
                            {
                                $Name = ($matches['Name'])
                            }
                        }
                    }
                    if ($null -ne $Name) 
                    {
                        $Obj = "" | Select-Object ProcessName, ProcId, HandleId, Owner, Type, Perms, Name
                        $Obj.ProcessName, $Obj.ProcId, $Obj.HandleId, $Obj.Owner, $Obj.Type, $Obj.Perms, $Obj.name = `
                            $ProcessName,$ProcId,("0x" + $HandleId),$Owner,$Type,$Perms,$Name
                        [void]$AllEvents.Add($Obj)
                    }
                }
            }
        }
    }

    #Rename an attribute for consistency
    foreach ($Hand in $AllEvents)
    {
        if (($null -ne $Hand) -and ($Hand.Owner -eq '\<unable to open process>'))
        {
            $Hand.Owner = '\'
        }
    }


    YACKPipe-ReturnCSV -PowershellObjects $AllEvents.ToArray() -OutputName "ProcessHandles.csv" 
} 
else 
{
    YACKPipe-ReturnError "Couldn't find Handle.exe"
}

