<#
.SYNOPSIS
A file for storing the functions used to run parsers

.NOTES
Credit: Connor Martin
License: Apache 2.0
#>

#$Script:ScriptPath = Split-Path $script:MyInvocation.MyCommand.Path
#$Script:FunctionFolder = "$Script:ScriptPath\Internals\Functions\"
#. $Script:FunctionFolder\Log.ps1



function Start-Parsers ($YACKResultFolder, $ScriptLogPath, $ParsersPath, $ParserListPath)
{
    <#
    .SYNOPSIS
    Starts running the parsers
    
    .NOTES
    License: Apache License 2.0
    Credits: Connor Martin.
    #>

    Write-Log $ScriptLogPath "Starting Parsers."  


    #Build the list of collection results to parse. This is determined by if the folder has a parser log
    $ResultsToParse = New-Object System.Collections.ArrayList
    #List all the collection folder results
    $CollectionFolders = Get-ChildItem $YACKResultFolder | Sort-Object Name -Descending

    foreach ($CollectionFolder in $CollectionFolders)  { if ($CollectionFolder) #PS2.0 Check
    {
        $HostFolders = Get-ChildItem $($CollectionFolder.FullName) | Sort-Object CreationTimeUtc -Descending

        foreach ($HostFolder in $HostFolders)  { if ($HostFolder) #PS2.0 Check
        {
            $ParseLogExists = $(Test-Path "$($HostFolder.FullName)\Parse.log")
            #if (!$ParseLogExists)
            #{
                $null = $ResultsToParse.Add($($HostFolder.FullName))
            #}
        }}
    }}


    #Build parser run list
    $Parsers = Read-Parsers $ParserListPath $ParsersPath $ScriptLogPath

    #for each result folder runt he parsers
    foreach ($ResultToPar in $ResultsToParse)  { if ($ResultToPar) #PS2.0 Check
    {
        #Create Parse Log
        $ParserLogPath = "$($ResultToPar)\\parse.log"
        $null = New-Item -Path "$ParserLogPath" -Force -ItemType "file"
        Write-Log $ScriptLogPath "Parsing $($ResultToPar)"  

        #Logging variables
        $CurrentNum = 1
        $TotalNum = @($Parsers).Count

        #Run each parser
        foreach ($Parser in $Parsers)  { if ($Parser) #PS2.0 Check
        {
            Write-Log $ParserLogPath "[$CurrentNum/$TotalNum] Launching Collector: $($Parser.ParserName)"

            #Attach the mandatory args
            $MandatoryArgs = @($ParsersPath, $ResultToPar)
            $Parser.Arguments = $MandatoryArgs + $Parser.Arguments 

            try 
            {
                $null = Invoke-Command -ScriptBlock $Parser.ScriptBlock -ArgumentList  $Parser.Arguments 
                Write-Log $ParserLogPath "[$CurrentNum/$TotalNum]     Parsing sucessful."
            }
            catch 
            {
                Write-Log $ParserLogPath "[$CurrentNum/$TotalNum]     !!! ERROR: $($_.FullyQualifiedErrorId) At $($_.InvocationInfo.ScriptName):$($_.InvocationInfo.ScriptLineNumber)"
            }
            $CurrentNum++
        }}
    }}
}



function Read-Parsers ($ParserListPath, $ParserPath, $ScriptLogPath) 
{
    <#
    .SYNOPSIS
    Parses Parsers powershell scripts from disk into a Parser PSObject array.

    .PARAMETER ParserListPath
    The path to the collecotr .conf file which contains the Parsers to be ran.
    
    .PARAMETER ParserPath
    The path to where the Parsers reside.
    
    .PARAMETER DependenciesPath
    The path to where the binary dependencies reside.
    
    .PARAMETER ScriptLogPath
    The path to where the script log is.
    
    .NOTES
    Credit: Connor Martin
    License: 
    #>

    $Parsers = @()

    #Iterate through each line in the .conf file
    foreach ($Line in $(Get-Content -Path $ParserListPath)) 
    {
        if ($null -ne $Line) #ps 2.0 check
        {
            $Line = $Line.TrimStart()
            $Line = $Line.TrimEnd()

            if ($Line.StartsWith("#") -eq $false) 
            {
                if ($Line.Trim() -ne "") 
                {
                    #Split Parser name and the arguements based on spaces.
                    
                    $Ind = $Line.IndexOf(" ")

                    if ($Ind -ne -1) 
                    {
                        #Parser's relative path
                        $RelPath = $Line.Substring(0, $Ind)

                        #Parse Arguments
                        $argm_str = $Line.Substring($Ind, $Line.Length - $Ind).TrimStart()
                        $Arguments = @()
                        foreach ($s in $argm_str.split('"')) 
                        {
                            if (($null -ne $s) -and ($s.Trim() -ne "") )
                            {
                                $Arguments += $s
                            }
                        }
                    }
                    else 
                    {
                        #If there are no arguements then the Relative path is just the line.
                        $RelPath = $Line
                        $Arguments = $null
                    }
                    
                    #Full path to the Parser.
                    $FullPath = $($ParserPath + "$RelPath")

                    #Create Parser object
                    $Parser = New-Object PSObject
                    $Parser | Add-Member -Type NoteProperty -Name "ParserName" -Value $RelPath
                    $Parser | Add-Member -Type NoteProperty -Name "Error" -Value $false
                    $Parser | Add-Member -Type NoteProperty -Name "ErrorMessage" -Value ""
                    $Parser | Add-Member -Type NoteProperty -Name "ScriptBlock" -Value $null
                    $Parser | Add-Member -Type NoteProperty -Name "Dependencies" -Value $null
                    $Parser | Add-Member -Type NoteProperty -Name "PSMDependencies" -Value $null
                    $Parser | Add-Member -Type NoteProperty -Name "Path" -Value $FullPath
                    $Parser | Add-Member -Type NoteProperty -Name "Arguments" -Value $Arguments
            
                    #Check if the Parser exists
                    if ($(Test-Path $Parser.Path) -eq $true) 
                    {
                        #Read the Parsers script block.
                        $Parser.ScriptBlock = $(get-command $Parser.Path | Select-Object -ExpandProperty ScriptBlock)
                    }
                    else 
                    {
                        #Record error if there was an error.
                        $Parser.Error = $true
                        $Parser.ErrorMessage += "Parser not found. "
                    }
                    $Parsers += $Parser
                }
            }
        }
    }

    return $Parsers
}