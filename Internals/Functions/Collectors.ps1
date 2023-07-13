<#
.SYNOPSIS
Functions for interacting with Collectors.

.NOTES
Credit: Connor Martin
License: 
#>




function Start-LocalCollection
{
    <#
    .SYNOPSIS
    Runs the collectors listed in $Script:Collectors agaisnt local host.
    #>

    Write-Log $Script:ScriptLogPath "Starting Local Collection on $Script:HostNames"

    #Check if you have local admin
    if (([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
    {
        #Create Output Folder
        $CollectorOutputFolder = "$Script:OutputPath$Script:StartTime\$($Script:HostNames)\"
        $null = New-Item -Path "$CollectorOutputFolder" -ItemType directory -Force

        #Create collection log
        $CollectLogPath = "$CollectorOutputFolder\\collect.log"
        $null = New-Item -Path "$CollectLogPath" -Force -ItemType "file"

        #Local counter variable for logging
        $CurrentNum = 1
        $TotalNum = @($Script:Collectors).Length

        # Transfer the dependency files
        Copy-Dependencies $Script:Collectors $script:DependenciesPath

        # Initialize the powershell module depencies
        Initialize-PSMDependencies  $Script:Collectors $script:DependenciesPath


        #Run each collector
        foreach ($Collector in $Script:Collectors) 
        {
            if ($null -ne $Collector) #Ps 2.0 check
            {
                Write-Log $CollectLogPath "[$CurrentNum/$TotalNum] Launching Collector: $($Collector.CollectorName) $($Collector.Arguments)"

                #Run collector and write output
                $ResultObj = Invoke-Command -ScriptBlock $Collector.ScriptBlock -ArgumentList $Collector.Arguments | `
                    Write-CollectorResult -Collector $Collector -CollectionOutputFolder $CollectorOutputFolder
                
                #Write results
                if ($ResultObj.Error -eq $false)
                {
                    Write-Log $CollectLogPath "[$CurrentNum/$TotalNum]     Collected: $($ResultObj.ItemsCollected) items(s) // $($ResultObj.BytesWritten) byte(s)"
                }
                else 
                {
                    Write-Log $CollectLogPath "[$CurrentNum/$TotalNum]     !!! ERROR: $($ResultObj.ErrorMessage)"
                }

                $CurrentNum++
            }
        }

        #Remove the transfered dependencies
        Remove-Dependencies

        Write-Log $Script:ScriptLogPath "Finished Running $TotalNum Collectors on $Script:HostNames"        
    }
    else 
    {
        Write-Log $Script:ScriptLogPath "!!! ERROR: Script does not have admin privs. Rerun with admin privs."  
    }
}


## The script block that is ran in parrallel locally by startjobs
$SB_RunMods = 
{
    param 
    ( 
        $Creds,
        $OutputFolder,
        $CollectionLogPath,
        $HostN,
        $FunctionFolder,
        #$OutputPath,
        [PSCustomObject[]] $Collectors,
        $DependenciesPath
    )

    #Import functions
    . $Script:FunctionFolder\Collectors.ps1
    . $Script:FunctionFolder\Log.ps1
    . $Script:FunctionFolder\Dependencies.ps1
    #. "C:\Users\conno\Documents\cpt_analytic_support_officers\BDE\YACK\\Collectors\\_Dependencies\\DataTransfer.psm1"

    #Create the ps session that this job will utilize
    $PSSession = New-PSSession -computer $HostN -Credential $Creds -ErrorAction SilentlyContinue


    $CurrentNum = 1
    $TotalNum = @($Collectors).Length

    
    if ($PSSession) 
    {
        #Copy Dependencies
        Copy-DependenciesRemote $Script:Collectors $script:DependenciesPath $PSSession

        #Import PSM dependencies
        Initialize-PSMDependenciesRemote $Collectors $DependenciesPath $PSSession


        #Run each collector over the PS session
        foreach ($Collector in $Collectors) 
        {
            if ($null -ne $Collector) #Ps 2.0 check
            {
                #Script blocks are serialized to strings when passed as an arguement to a job. So you need to recast it.
                $SB = [Scriptblock]::Create($Collector.ScriptBlock)

                Write-Log -LogPath $CollectionLogPath -Text "[$CurrentNum/$TotalNum] Launching Collector: $($Collector.CollectorName) $($Collector.Arguments)" -ConsoleOutput $false

                $ResultObj = Invoke-Command -ScriptBlock $SB -ArgumentList $Collector.Arguments -Session $PSSession | `
                    Write-CollectorResult -Collector $Collector -CollectionOutputFolder "$OutputFolder\"
            
                #Write results
                if ($ResultObj.Error -eq $false)
                {
                    Write-Log -LogPath $CollectionLogPath -Text "[$CurrentNum/$TotalNum]     Collected: $($ResultObj.ItemsCollected) items(s) // $($ResultObj.BytesWritten) byte(s)" -ConsoleOutput $false
                }
                else 
                {
                    Write-Log -LogPath $CollectionLogPath -Text "[$CurrentNum/$TotalNum]     !!! ERROR: $($ResultObj.ErrorMessage)" -ConsoleOutput $false
                }
                $CurrentNum++
            }
        }

        #Remove Dependencies
        $SB =
        {
            $DepFolder = [Environment]::ExpandEnvironmentVariables("%SystemRoot%\YACK\")
            if (Test-Path $DepFolder)
            {
                Remove-Item -Path $DepFolder -Recurse -Force 
            }
        }
        Invoke-Command -Session $PSSession -ScriptBlock $SB


        #Close session once complete
        Remove-PSSession $PSSession
    }
    else 
    {
        Write-Log LogPath $CollectLogPath -Text " !!! Error: `"$HostN`" PSSession failed." -ConsoleOutput $false
    }

}

function Start-RemoteCollection
{
    <#
    .SYNOPSIS
    Runs the collectors listed in $Script:Collectors agaisnt all hosts in $Script:Hostnames.
    This supports simulatenous collection through jobs.
    
    .NOTES
    Target Machine: winrm quickconfig
    Local Machine: winrm s winrm/config/client '@{TrustedHosts="YACK-2008R2-1, 10.20.10.110, YACK-Win7-1, YACK-2012R2-1, YACK-2016-1"}'
    #>

    #For testing purposes


    Write-Log $Script:ScriptLogPath "Starting Remote Collection."
    Write-Log $Script:ScriptLogPath "Press {space} for updates."

    $TotalNum = @($Script:HostNames).Length
    #hash table for hostname job name pairings
    $HostnameJobName = @{}
    $HostnamePSID  = @{}
    $CollectionLogList = @{}

    $i = 0
    $CompletedNum = 0

    while ($CompletedNum -lt $TotalNum)
    {
        #Start a job if max arent running
        if (($i -lt $Script:HostNames.Length) -and `
            $(Get-Job -state running).count -lt $Script:MaxConcurrent)
        {
            #Define and create the Collector output folder
            $CollectorOutputFolder = "$Script:OutputPath$Script:StartTime\$($Script:HostNames[$i])\"
            $null = New-Item -Path "$CollectorOutputFolder" -ItemType directory -Force

            #Create the log path and record it
            $CollectionLogPath = "$CollectorOutputFolder\\collect.log"
            $CollectionLogList[$Script:HostNames[$i]] = $CollectionLogPath

            Write-Log -LogPath $CollectionLogPath -Text "Establishing Remote Connection to $($Script:HostNames[$i])" -ConsoleOutput $false

            #Open PS Session. Transfer files. Then close it. You cant pass sessions to jobs. Note: Removal of dependencies is inside the SB
            $PSSession = New-PSSession -computer $Script:HostNames[$i] -Credential $Script:CollectionCreds -ErrorAction SilentlyContinue
            if ($null -ne $PSSession)
            {
                #Write into the collector log that connection was successful
                Write-Log -LogPath $CollectionLogPath -Text "Connection Successful" -ConsoleOutput $false 


                $SB_CheckPriv =
                {
                    ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
                }

                #if you have admin privs
                if (Invoke-Command -Session $PSSession -ScriptBlock $SB_CheckPriv)
                {
                    #Copy dependencices
                    #Copy-DependenciesRemote $Script:Collectors $script:DependenciesPath $PSSession
                    Remove-PSSession $PSSession

                    #Start Job
                    $Job = Start-Job $SB_RunMods -ArgumentList $Script:CollectionCreds, $CollectorOutputFolder, $CollectionLogPath, $Script:HostNames[$i], `
                                                                $Script:FunctionFolder, @($Script:Collectors), $script:DependenciesPath

                    #Keep track of which jobs is which host
                    $HostnameJobName[$Job.Name] = $Script:HostNames[$i]
                    $HostnamePSID[$Job.Name] = $PSSession.Id
                }
                else
                {
                    Remove-PSSession $PSSession
                    Write-Log -LogPath $CollectionLogPath -Text "     !!! ERROR: Created PSSession did not have admin privs." -ConsoleOutput $false 
                }

                $i++
            }
            else 
            {
                #If the ps session failed to start then this host is complete
                Write-Log -LogPath $CollectionLogPath -Text "     !!! ERROR: Connection Failed" -ConsoleOutput $false 
                $i++
                $CompletedNum++
            }
        }

        #Receive completed jobs
        foreach ($CompletedJob in $(Get-Job -state Completed))
        {
            if ($null -ne $CompletedJob) #ps2.0 check
            {
                #if the completed job is one of the ones we started
                if ($null -ne $HostnameJobName[$CompletedJob.Name])
                {
                    $null = $CompletedJob | Receive-Job

                    $CompletedJob | Remove-Job
                    $CompletedNum++
                }
            }
        }

        #if ($host.ui.rawui.KeyAvailable) 
        if (Test-KeyPress -Key "Space")
        {
            #Read Key
            $null = [console]::ReadKey()

            Write-Log -LogPath $Script:ScriptLogPath -Text "" -ConsoleOutput $true
            Write-Log -LogPath $Script:ScriptLogPath -Text "****************************" -ConsoleOutput $true
            Write-Log $Script:ScriptLogPath "* Collection Update"
            Write-Log -LogPath $Script:ScriptLogPath -Text "****************************" -ConsoleOutput $true
            Write-Log -LogPath $Script:ScriptLogPath -Text "[$CompletedNum/$TotalNum] Collections complete." -ConsoleOutput $true
            
            $JobsRunning = $(Get-Job -state Running)
            foreach ($JobRun in $JobsRunning)
            {
                if ($null -ne $JobRun) #ps2.0 check
                {
                    $JobHost = $HostnameJobName[$JobRun.Name]
                    Write-Log -LogPath $Script:ScriptLogPath -Text "  Collecting... $JobHost" -ConsoleOutput $true
                }  
            }

            #Add some whitespace
            Write-Log -LogPath $Script:ScriptLogPath -Text "****************************" -ConsoleOutput $true
            Write-Log -LogPath $Script:ScriptLogPath -Text "" -ConsoleOutput $true
        }
        Start-Sleep -Milliseconds 200
    }

    #Write Collection Summary... Built from collection logs
    Write-Log $Script:ScriptLogPath ""
    Write-Log -LogPath $Script:ScriptLogPath -Text "****************************" -ConsoleOutput $true
    Write-Log $Script:ScriptLogPath "* Collection Summary"
    Write-Log -LogPath $Script:ScriptLogPath -Text "****************************" -ConsoleOutput $true

    foreach ($Hostname in $Script:HostNames)
    {
        if ($null -ne $Hostname) #ps2.0 check
        {
            #Collection Log
            $LogInfo = Read-CollectionLogInfo $CollectionLogList[$Hostname]  
            Write-Log -LogPath $Script:ScriptLogPath -Text "   [$($LogInfo.Successes)/$($LogInfo.Total)] $Hostname" -ConsoleOutput $true
        }
    }
    Write-Log -LogPath $Script:ScriptLogPath -Text "****************************" -ConsoleOutput $true
}


function Read-Collectors ($CollectorListPath, $CollectorPath, $DependenciesPath, $ScriptLogPath) 
{
    <#
    .SYNOPSIS
    Parses collectors powershell scripts from disk into a Collector PSObject array.

    .PARAMETER CollectorListPath
    The path to the collecotr .conf file which contains the collectors to be ran.
    
    .PARAMETER CollectorPath
    The path to where the collectors reside.
    
    .PARAMETER DependenciesPath
    The path to where the binary dependencies reside.
    
    .PARAMETER ScriptLogPath
    The path to where the script log is.
    
    .NOTES
    Credit: Connor Martin
    License: 
    #>

    $Collectors = @()

    #Iterate through each line in the .conf file
    foreach ($Line in $(Get-Content -Path $CollectorListPath)) 
    {
        if ($null -ne $Line) #ps 2.0 check
        {
            $Line = $Line.TrimStart()
            $Line = $Line.TrimEnd()

            if ($Line.StartsWith("#") -eq $false) 
            {
                if ($Line.Trim() -ne "") 
                {
                    #Split collector name and the arguements based on spaces.
                    
                    $Ind = $Line.IndexOf(" ")

                    if ($Ind -ne -1) 
                    {
                        #collector's relative path
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
                    
                    #Full path to the Collector.
                    $FullPath = $($CollectorPath + "$RelPath")

                    #Create Collector object
                    $Collector = New-Object PSObject
                    $Collector | Add-Member -Type NoteProperty -Name "CollectorName" -Value $RelPath
                    $Collector | Add-Member -Type NoteProperty -Name "Error" -Value $false
                    $Collector | Add-Member -Type NoteProperty -Name "ErrorMessage" -Value ""
                    $Collector | Add-Member -Type NoteProperty -Name "ScriptBlock" -Value $null
                    $Collector | Add-Member -Type NoteProperty -Name "Dependencies" -Value $null
                    $Collector | Add-Member -Type NoteProperty -Name "PSMDependencies" -Value $null
                    $Collector | Add-Member -Type NoteProperty -Name "Path" -Value $FullPath
                    $Collector | Add-Member -Type NoteProperty -Name "Arguments" -Value $Arguments
            
                    #Check if the Collector exists
                    if ($(Test-Path $Collector.Path) -eq $true) 
                    {
                        #Read the Collectors script block.
                        $Collector.ScriptBlock = $(get-command $Collector.Path | Select-Object -ExpandProperty ScriptBlock)

                        #Read the Collector's dependencies
                        $Directive_Flag = ".DEPENDENCY"
                        #$Directive_Text = $($Collector.ScriptBlock.ToString() -split "`n" | ForEach-Object { if ($_ -match $Directive_Flag) {return $_} })
                        #Grab the dependency line
                        $Directive_Text = $($Collector.ScriptBlock.ToString() -split "`n" | ForEach-Object { if ($_.StartsWith($Directive_Flag)) {return $_} })
                        if ($null -ne $Directive_Text ) 
                        {
                            $Dep = $($Directive_Text -replace $Directive_Flag, "").Trim() -split " "
                            if ($Dep -ne "") 
                            {
                                $Collector.Dependencies = $Dep
                            }
                        }

                        #Read the Collector's Script dependencies
                        $Directive_Flag = ".PSM_DEPENDENCY"
                        #$Directive_Text = $($Collector.ScriptBlock.ToString() -split "`n" | ForEach-Object { if ($_ -match $Directive_Flag) {return $_} })
                        #Grab the dependency line
                        $Directive_Text = $($Collector.ScriptBlock.ToString() -split "`n" | ForEach-Object { if ($_.StartsWith($Directive_Flag)) {return $_} })
                        if ($null -ne $Directive_Text ) 
                        {
                            $Dep = $($Directive_Text -replace $Directive_Flag, "").Trim() -split " "
                            if ($Dep -ne "") 
                            {
                                $Collector.PSMDependencies = $Dep
                            }
                        }
                    }
                    else 
                    {
                        #Record error if there was an error.
                        $Collector.Error = $true
                        $Collector.ErrorMessage += "Collector not found. "
                    }
                    $Collectors += $Collector
                }
            }
        }
    }

    #Check if collector dependencies exist
    foreach ($Collector in $Collectors)
    {
        foreach ($Dependency in $Collector.Dependencies)
        {
            if ($null -ne $Dependency)
            {
                if ($(Test-Path "$DependenciesPath$Dependency") -eq $false)
                {
                    $Collector.Error = $true
                    $Collector.ErrorMessage += "`"$Dependency`" dependency not found in the _dependency fodler. "
                }
            }
        }
    }

    #Check if collector Script dependencies exist
    foreach ($Collector in $Collectors)
    {
        foreach ($PSMDependency in $Collector.PSMDependencies)
        {
            if ($null -ne $PSMDependency)
            {
                if ($(Test-Path "$DependenciesPath$PSMDependency") -eq $false)
                {
                    $Collector.Error = $true
                    $Collector.ErrorMessage += "`"$PSMDependency`" dependency not found in the _dependency fodler. "
                }
            }
        }
    }

    return $Collectors
}

function Write-CollectorResult 
{
    <#
    .SYNOPSIS
    Writes the results of a Collector to file.
    
    .DESCRIPTION
    This function writes the results of a Collector to file. Each result must be passed to it 
    in a CollectorResult object. 

    .OUTPUTS
    The function returns the bytes/size of items written. 
    
    .PARAMETER CollectorResult
    The CollectorResult object to be processed.
    
    .PARAMETER Collector
    The Collector object that the results are being received from.
    
    .PARAMETER CollectionOutputFolder
    The path to the collected host's output folder
    
    .EXAMPLE
    $sizeWritten = Invoke-Command -ScriptBlock $mod.ScriptBlock -ArgumentList $mod.Arguments | `
             Write-CollectorResults -Collector $mod -OutputPath $outPath
    
    .NOTES
    Credit: Connor Martin
    License: 
    #>

    [cmdletbinding()]
    param(
        [parameter(
            Mandatory         = $true,
            ValueFromPipeline = $true)]
        $CollectorResults,
        $Collector,
        $CollectionOutputFolder
    )

    Begin 
    {
        #Create the return Object
        [hashtable]$ReturnObj = @{} 
        $ReturnObj.BytesWritten = 0 
        $ReturnObj.ItemsCollected = 0 
        $ReturnObj.Error = $false
        $ReturnObj.ErrorMessage = ""
    }

    Process 
    {
        #Iterate through each result piped
        ForEach ($CollectorResult in $CollectorResults) 
        {
            #Validate that the result is actually a $CollectorResult Object
            if (Get-Member -inputobject $CollectorResult -name "OutputType")
            {
                #Check for errors
                if ($CollectorResult.Error -eq $true)
                {
                    $ReturnObj.Error = $true
                    $ReturnObj.ErrorMessage += "$($CollectorResult.ErrorMessage). "
                    #Clear collector contents for memory saving
                    $CollectorResult.Content = $null
                    continue
                }

                #Write content based on output type
                switch ($CollectorResult.OutputType.ToLower()) 
                {
                    "csv" 
                    {
                        $Res = Write-ResultCSV $Collector $CollectionOutputFolder $CollectorResult
                        $ReturnObj.BytesWritten += $Res.BytesWritten
                        $ReturnObj.ItemsCollected += $Res.ItemsCollected
                        break
                    }

                    "array" 
                    {
                        $ReturnObj.BytesWritten += Write-ResultArray $Collector $CollectionOutputFolder $CollectorResult
                        $ReturnObj.ItemsCollected += 1
                        break
                    }
                    
                    "bytes" 
                    {
                        $ReturnObj.BytesWritten += Write-ResultBytes $Collector $CollectionOutputFolder $CollectorResult
                        $ReturnObj.ItemsCollected += 1
                        break
                    }

                    "gzip" 
                    {
                        $ReturnObj.BytesWritten += Write-ResultGZIP $Collector $CollectionOutputFolder $CollectorResult
                        $ReturnObj.ItemsCollected += 1
                        break
                    }

                    "chunkgzip"
                    {
                        $ReturnObj.BytesWritten += Write-ResultChunkGZIP $Collector $CollectionOutputFolder $CollectorResult
                        $ReturnObj.ItemsCollected += 1
                        break
                    }

                    "chunkbytes"
                    {
                        $ReturnObj.BytesWritten += Write-ResultChunkBytes $Collector $CollectionOutputFolder $CollectorResult
                        $ReturnObj.ItemsCollected += 1
                        break
                    }

                    "folder"
                    {
                        $ReturnObj.BytesWritten += Write-ResultFolder $Collector $CollectionOutputFolder $CollectorResult
                        $ReturnObj.ItemsCollected += 1
                        break
                    }


                }

                #Clear collector contents for memory saving
                $CollectorResult.Content = $null
            }
            else 
            {
                Write-Error "Collector Returned invalid CollectorResult Object."
            }
        }
    }

    End 
    {
        #Return the items/bytes written.
        return $ReturnObj
    }
}

function Write-ResultCSV ($Collector, $CollectionOutputFolder, $CollectorResult) 
{
    <#
    .SYNOPSIS
    Writes a CollectorResult content object to a csv.
    
    .PARAMETER Collector
    The Collector that the result is coming from.
    
    .PARAMETER OutputFolder
    The path to the collected host's output folder
    
    .PARAMETER CollectorResult
    The CollectorResult to be exported.
    
    .NOTES
    Credit: Connor Martin
    License: 
    #>

    if ($null -eq $CollectorResult.content)
    {
        [hashtable]$ReturnObj = @{} 
        $ReturnObj.BytesWritten = 0
        $ReturnObj.ItemsCollected = 0

        return $ReturnObj
    }

    #When PS does remote sessions all arrays are returned as arrayLists. So you must cast it back.
    #https://blogs.msdn.microsoft.com/powershell/2010/01/07/how-objects-are-sent-to-and-from-remote-sessions/
    if ($CollectorResult.content.GetType().Name -eq "ArrayList") 
    {
        $CollectorResult.content = $CollectorResult.content.ToArray()
    }

    #Determine the output folder
    if ($null -ne $CollectorResult.OutputFolder) 
    {
        $CollectorOutputFolder = "$CollectionOutputFolder\$($CollectorResult.OutputFolder)"
    } else 
    {
        $CollectorOutputFolder = Split-Path -Path "$CollectionOutputFolder$($Collector.CollectorName)"
    }
    
    #Determine the output name
    if ($null -ne $CollectorResult.OutputName) 
    {
        $OutputFile = "$CollectorOutputFolder\$($CollectorResult.OutputName)"
    } else 
    {
        $CollectorName =  Split-Path -Path "$CollectorOutputFolder\$($Collector.CollectorName)" -Leaf
        $OutputFile = "$CollectorOutputFolder\$CollectorName"
    }

    #Create output Folder
    $temp = New-Item -Path "$CollectorOutputFolder" -ItemType directory -Force

    #Write output
    $CollectorResult.Content | Export-Csv -NoTypeInformation -Path "$OutputFile"

    $OutputFileProps = Get-ChildItem $OutputFile

    [hashtable]$ReturnObj = @{} 
    $ReturnObj.BytesWritten = $OutputFileProps.Length
    $ReturnObj.ItemsCollected = @($CollectorResult.Content).Length

    return $ReturnObj
}

function Write-ResultArray ($Collector, $CollectionOutputFolder, $CollectorResult) 
{
    <#
    .SYNOPSIS
    Writes a CollectorResult content object to file without manipulating the content.
    
    .PARAMETER Collector
    The Collector that the result is coming from.
    
    .PARAMETER OutputPath
    The path to the collected host's output folder
    
    .PARAMETER CollectorResult
    The CollectorResult to be exported.
    
    .NOTES
    Credit: Connor Martin
    License: 
    #>

    #Determine the output folder
    if ($null -ne $CollectorResult.OutputFolder) 
    {
        $CollectorOutputFolder = "$CollectionOutputFolder\$($CollectorResult.OutputFolder)"
    } 
    else 
    {
        $CollectorOutputFolder = Split-Path -Path "$CollectionOutputFolder$($Collector.CollectorName)"
    }
    
    #Determine the output name
    if ($null -ne $CollectorResult.OutputName) 
    {
        $OutputFile = "$CollectorOutputFolder\$($CollectorResult.OutputName)"
    } 
    else 
    {
        $CollectorName =  Split-Path -Path "$CollectorOutputFolder\$($Collector.CollectorName)" -Leaf
        $OutputFile = "$CollectorOutputFolder\$CollectorName"
    }

    #Create output Folder
    $temp = New-Item -Path "$CollectorOutputFolder" -ItemType directory -Force

    #Write output
    $CollectorResult.Content | Out-File $OutputFile
    return $CollectorResult.Content.Length
}

function Write-ResultGZIP ($Collector, $CollectionOutputFolder, $CollectorResult) 
{
    <#
    .SYNOPSIS
    Writes a CollectorResult content object, that is gzip encoded, to a file.
    
    .PARAMETER Collector
    The Collector that the result is coming from.
    
    .PARAMETER CollectionOutputFolder
    The path to the collected host's output folder
    
    .PARAMETER CollectorResult
    The CollectorResult to be exported.
    
    .NOTES
    Credit: Connor Martin. Kansa (github)
    License: Apache 2.0
    #>

    #Determine the output folder
    if ($null -ne $CollectorResult.OutputFolder) 
    {
        $CollectorOutputFolder = "$CollectionOutputFolder\$($CollectorResult.OutputFolder)"
    } 
    else 
    {
        $CollectorOutputFolder = Split-Path -Path "$CollectionOutputFolder$($Collector.CollectorName)"
    }
    
    #Determine the output name
    if ($null -ne $CollectorResult.OutputName) 
    {
        $OutputFile = "$CollectorOutputFolder\$($CollectorResult.OutputName)"
    } 
    else 
    {
        $CollectorName =  Split-Path -Path "$CollectorOutputFolder\$($Collector.CollectorName)" -Leaf
        $OutputFile = "$CollectorOutputFolder\$CollectorName"
    }

    if ($null -ne $CollectorResult.Content)
    {
        #Create output Folder
        $temp = New-Item -Path "$CollectorOutputFolder" -ItemType directory -Force

        # Create a memory stream to store compressed data
        $CompressedByteStream = New-Object System.IO.MemoryStream(@(,$CollectorResult.Content))
        # Create an empty memory stream to store decompressed data
        $DecompressedStream = new-object -TypeName System.IO.MemoryStream
        # Decompress the memory stream
        $StreamDecompressor = New-Object System.IO.Compression.GZipStream $CompressedByteStream, ([System.IO.Compression.CompressionMode]::Decompress)

        
        #Decompress compressed stream into  $DecompressedStream by 16k chunks
        $BuffSize = 16384
        $Buffer = [System.Byte[]]::CreateInstance([System.Byte],$BuffSize)
        do
        {
            $Count = $StreamDecompressor.Read($Buffer, 0, $BuffSize)
            if ($Count -gt 0)
            {
                $DecompressedStream.Write($Buffer, 0, $Count)
            }
        }
        while ($Count -gt 0)

        #Convert stream to an array
        $DecStream = $DecompressedStream.ToArray()

        # Write the bytes to disk
        [System.IO.File]::WriteAllBytes($OutputFile, $DecStream)

        #Cleanup
        $CompressedByteStream.Dispose()
        $DecompressedStream.Dispose()
        $StreamDecompressor.Dispose()

        #Modify timestamps of created file to match the original.
        $sysFile = Get-ChildItem $OutputFile
        $sysFile.CreationTimeUtc = $CollectorResult.OutputCreationTimeUtc
        $sysFile.LastAccessTimeUtc = $CollectorResult.OutputLastAccessTimeUtc
        $sysFile.LastWriteTimeUtc = $CollectorResult.OutputLastWriteTimeUtc

        #Return the number of bytes in the array
        return $DecStream.Length
    }
    else 
    {
        return 0
    }

}


function Write-ResultChunkGZIP ($Collector, $CollectionOutputFolder, $CollectorResult) 
{
    <#
    .SYNOPSIS
    Writes a CollectorResult content object, that is chunked gzip encoded file, to a file.
    
    .PARAMETER Collector
    The Collector that the result is coming from.
    
    .PARAMETER CollectionOutputFolder
    The path to the collected host's output folder
    
    .PARAMETER CollectorResult
    The CollectorResult to be exported.
    
    .NOTES
    Credit: Connor Martin. Kansa (github)
    License: Apache 2.0
    #>

    #Determine the output folder
    if ($null -ne $CollectorResult.OutputFolder) 
    {
        $CollectorOutputFolder = "$CollectionOutputFolder\$($CollectorResult.OutputFolder)"
    } 
    else 
    {
        $CollectorOutputFolder = Split-Path -Path "$CollectionOutputFolder$($Collector.CollectorName)"
    }
    
    #Determine the output name
    if ($null -ne $CollectorResult.OutputName) 
    {
        $OutputFile = "$CollectorOutputFolder\$($CollectorResult.OutputName)"
    } 
    else 
    {
        $CollectorName =  Split-Path -Path "$CollectorOutputFolder\$($Collector.CollectorName)" -Leaf
        $OutputFile = "$CollectorOutputFolder\$CollectorName"
    }

    #Create output Folder
    $temp = New-Item -Path "$CollectorOutputFolder" -ItemType directory -Force

    #If it's the first chunk then create the file
    if ($CollectorResult.CurrentChunk -eq 0)
    {
        $temp = New-Item $OutputFile -ItemType file -Force
    }

    # Create a memory stream to store compressed data
    $CompressedByteStream = New-Object System.IO.MemoryStream(@(,$CollectorResult.Content))
    # Create an empty memory stream to store decompressed data
    $DecompressedStream = new-object -TypeName System.IO.MemoryStream
    # Decompress the memory stream
    $StreamDecompressor = New-Object System.IO.Compression.GZipStream $CompressedByteStream, ([System.IO.Compression.CompressionMode]::Decompress)
    # And copy decompressed bytes to $DecompressedStream
    #$StreamDecompressor.CopyTo($DecompressedStream)


    #Decompress compressed stream into  $DecompressedStream by 16k chunks
    $BuffSize = 16384
    $Buffer = [System.Byte[]]::CreateInstance([System.Byte],$BuffSize)
    do
    {
        $Count = $StreamDecompressor.Read($Buffer, 0, $BuffSize)
        if ($Count -gt 0)
        {
            $DecompressedStream.Write($Buffer, 0, $Count)
        }
    }
    while ($Count -gt 0)

    #Convert stream to an array
    $DecStream = $DecompressedStream.ToArray()

    $FileStream = New-Object IO.FileStream $OutputFile, "Append", "Write"
    $temp = $FileStream.Write($DecStream, 0, $DecStream.Length)

    #Cleanup
    $FileStream.Close()
    $CompressedByteStream.Dispose()
    $DecompressedStream.Dispose()
    $StreamDecompressor.Dispose()

    #Modify timestamps of created file to match the original.
    $sysFile = Get-ChildItem $OutputFile
    $sysFile.CreationTimeUtc = $CollectorResult.OutputCreationTimeUtc
    $sysFile.LastAccessTimeUtc = $CollectorResult.OutputLastAccessTimeUtc
    $sysFile.LastWriteTimeUtc = $CollectorResult.OutputLastWriteTimeUtc

    #Return the number of bytes in the array
    return $DecStream.Length 
}

function Write-ResultChunkBytes ($Collector, $CollectionOutputFolder, $CollectorResult) 
{

    <#
    .SYNOPSIS
    Writes a CollectorResult content object, that is chunked raw, to a file.
    
    .PARAMETER Collector
    The Collector that the result is coming from.
    
    .PARAMETER CollectionOutputFolder
    The path to the collected host's output folder
    
    .PARAMETER CollectorResult
    The CollectorResult to be exported.
    
    .NOTES
    Credit: Connor Martin. Kansa (github)
    License: Apache 2.0
    #>

    #Determine the output folder
    if ($null -ne $CollectorResult.OutputFolder) 
    {
        $CollectorOutputFolder = "$CollectionOutputFolder\$($CollectorResult.OutputFolder)"
    } 
    else 
    {
        $CollectorOutputFolder = Split-Path -Path "$CollectionOutputFolder$($Collector.CollectorName)"
    }
    
    #Determine the output name
    if ($null -ne $CollectorResult.OutputName) 
    {
        $OutputFile = "$CollectorOutputFolder\$($CollectorResult.OutputName)"
    } 
    else 
    {
        $CollectorName =  Split-Path -Path "$CollectorOutputFolder\$($Collector.CollectorName)" -Leaf
        $OutputFile = "$CollectorOutputFolder\$CollectorName"
    }

    #Create output Folder
    $temp = New-Item -Path "$CollectorOutputFolder" -ItemType directory -Force

    #If it's the first chunk then create the file
    if ($CollectorResult.CurrentChunk -eq 0)
    {
        $temp = New-Item $OutputFile -ItemType file -Force
    }


    $FileStream = New-Object IO.FileStream $OutputFile, "Append", "Write"
    $temp = $FileStream.Write($CollectorResult.Content, 0, $CollectorResult.Content.Length)
    # [System.IO.File]::OpenWrite($OutputFile)

    #Cleanup
    $FileStream.Close()

    #Modify timestamps of created file to match the original.
    $sysFile = Get-ChildItem $OutputFile
    $sysFile.CreationTimeUtc = $CollectorResult.OutputCreationTimeUtc
    $sysFile.LastAccessTimeUtc = $CollectorResult.OutputLastAccessTimeUtc
    $sysFile.LastWriteTimeUtc = $CollectorResult.OutputLastWriteTimeUtc

    #Return the number of bytes in the array
    return $DecStream.Length 
}

function Write-ResultFolder ($Collector, $CollectionOutputFolder, $CollectorResult) 
{

    <#
    .SYNOPSIS
    Writes a CollectorResult content object, that is a folder, to a folder.
    
    .PARAMETER Collector
    The Collector that the result is coming from.
    
    .PARAMETER CollectionOutputFolder
    The path to the collected host's output folder
    
    .PARAMETER CollectorResult
    The CollectorResult to be exported.
    
    .NOTES
    Credit: Connor Martin. Kansa (github)
    License: Apache 2.0
    #>

    #Determine the output folder
    if ($null -ne $CollectorResult.OutputFolder) 
    {
        $CollectorOutputFolder = "$CollectionOutputFolder\$($CollectorResult.OutputFolder)"
    } 
    else 
    {
        $CollectorOutputFolder = Split-Path -Path "$CollectionOutputFolder$($Collector.CollectorName)"
    }
    
    #Determine the output name
    if ($null -ne $CollectorResult.OutputName) 
    {
        $OutputFile = "$CollectorOutputFolder\$($CollectorResult.OutputName)"
    } 
    else 
    {
        $CollectorName =  Split-Path -Path "$CollectorOutputFolder\$($Collector.CollectorName)" -Leaf
        $OutputFile = "$CollectorOutputFolder\$CollectorName"
    }

    #Create output Folder
    $temp = New-Item -Path "$CollectorOutputFolder" -ItemType directory -Force

    return 1
}

function Write-ResultBYTES ($Collector, $CollectionOutputFolder, $CollectorResult) 
{
    <#
    .SYNOPSIS
    Writes a CollectorResult content object to file without manipulating the content.
    
    .PARAMETER Collector
    The Collector that the result is coming from.
    
    .PARAMETER OutputPath
    The path to the collected host's output folder
    
    .PARAMETER CollectorResult
    The CollectorResult to be exported.
    
    .NOTES
    Credit: Connor Martin
    License: 
    #>

    #Determine the output folder
    if ($null -ne $CollectorResult.OutputFolder) 
    {
        $CollectorOutputFolder = "$CollectionOutputFolder\$($CollectorResult.OutputFolder)"
    } 
    else 
    {
        $CollectorOutputFolder = Split-Path -Path "$CollectionOutputFolder$($Collector.CollectorName)"
    }
    
    #Determine the output name
    if ($null -ne $CollectorResult.OutputName) 
    {
        $OutputFile = "$CollectorOutputFolder\$($CollectorResult.OutputName)"
    } 
    else 
    {
        $CollectorName =  Split-Path -Path "$CollectorOutputFolder\$($Collector.CollectorName)" -Leaf
        $OutputFile = "$CollectorOutputFolder\$CollectorName"
    }

    #Create output Folder
    $temp = New-Item -Path "$CollectorOutputFolder" -ItemType directory -Force

    #Write Results
    $FileStream = New-Object IO.FileStream $OutputFile, "Append", "Write"
    $temp = $FileStream.Write($CollectorResult.Content, 0, $CollectorResult.Content.Length)
    # [System.IO.File]::OpenWrite($OutputFile)

    #Cleanup
    $FileStream.Close()


    return $CollectorResult.Content.Length
}
