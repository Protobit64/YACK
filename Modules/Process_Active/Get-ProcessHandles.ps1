############################################################
#.OUTPUT_Type CSV
#.OUTPUT_Name ProcessHandles.csv
#.DEPENDENCY handle.exe handle64.exe
#
#.SYNOPSIS
# Gets all handles for currently running processes.
#
#.DESCRIPTION
# 
#
#.NOTES
# Minor modifications made to kansa
# License: Apache License 2.0
# Credits: https://github.com/davehull/Kansa/blob/master/Modules/Process/Get-Handle.ps1
############################################################





if (Test-Path "$env:temp\yack\handle.exe") {
    $data = (& $env:temp\yack\handle.exe /accepteula -a)
    #("Process","PId","Owner","Type","Perms","Name") -join $Delimiter
    foreach($line in $data) {
        $line = $line.Trim()
        if ($line -match " pid: ") {
            $HandleId = $Type = $Perms = $Name = $null
            $pattern = "(?<ProcessName>^[-a-zA-Z0-9_.]+) pid: (?<PId>\d+) (?<Owner>.+$)"
            if ($line -match $pattern) {
                $ProcessName,$ProcId,$Owner = ($matches['ProcessName'],$matches['PId'],$matches['Owner'])
            }
        } else {
            $pattern = "(?<HandleId>^[a-f0-9]+): (?<Type>\w+)"
            if ($line -match $pattern) {
                $HandleId,$Type = ($matches['HandleId'],$matches['Type'])
                $Perms = $Name = $null
                switch ($Type) {
                    "File" {
                        $pattern = "(?<HandleId>^[a-f0-9]+):\s+(?<Type>\w+)\s+(?<Perms>\([-RWD]+\))\s+(?<Name>.*)"
                        if ($line -match $pattern) {
                            $Perms,$Name = ($matches['Perms'],$matches['Name'])
                        }
                    }
                    default {
                        $pattern = "(?<HandleId>^[a-f0-9]+):\s+(?<Type>\w+)\s+(?<Name>.*)"
                        if ($line -match $pattern) {
                            $Name = ($matches['Name'])
                        }
                    }
                }
                if ($Name -ne $null) {
                    $o = "" | Select-Object ProcessName, ProcId, HandleId, Owner, Type, Perms, Name
                    $o.ProcessName, $o.ProcId, $o.HandleId, $o.Owner, $o.Type, $o.Perms, $o.name = `
                        $ProcessName,$ProcId,("0x" + $HandleId),$Owner,$Type,$Perms,$Name
                    $o
                }
            }
        }
    }

} else {
    Write-Error "Handle.exe not found in $env:SystemRoot."
}