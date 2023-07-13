<#
.SYNOPSIS
Functions for interacting with YACK settings.

.NOTES
Credit: Connor Martin
License: Apache 2.0
#>



function Read-Settings
{
    <#
    .SYNOPSIS
    Reads the configuration files and collectors into script variables.
    #>

    # Laxy error handling.
    try 
    {
        #Parse Config file into a hash table. Credit: http://tlingenf.spaces.live.com/blog/cns!B1B09F516B5BAEBF!213.entry
        $Script:YACKConfigPath = "$($Script:ScriptPath)\Internals\Config\yack.conf"
        Get-Content $Script:YACKConfigPath | ForEach-Object {if($_.StartsWith("#") -eq $false) {return $_}} `
            | foreach-object -begin {$YACKConfig=@{}} -process { $k = [regex]::split($_,'='); if(($k[0].CompareTo("") -ne 0) -and ($k[0].StartsWith("[") -ne $True)) { $YACKConfig.Add($k[0], $k[1]) } }
        
        #YACKConfig
        $Script:ScriptVersion=$YACKConfig["Version"]

        #Build Output path
        if ($YACKConfig["OutputPath"] -eq "Relative") 
        {
            $Script:OutputPath = "$ScriptPath\\Output\\"
        } 
        else 
        {
            $Script:OutputPath = $YACKConfig["OutputPath"] -replace '\s',''
        }
        
        #Derive paths
        $Script:SettingsPath = "$ScriptPath\\Internals\\yack.ini"
        $Script:ScriptLogPath = "$ScriptPath\\Internals\\yack.log"
        $Script:HostNamesPath = "$ScriptPath\\Internals\\Config\\Hostnames.conf"
        $Script:ConfigFolder = "$ScriptPath\\Internals\\Config\\"
        $Script:CollectorsPath =  "$ScriptPath\\Collectors\\"
        $Script:DependenciesPath =  "$ScriptPath\\Collectors\\_Dependencies\\"
        $Script:CollectorsListPath = "$ScriptPath\\Internals\\Config\\Collectors.conf"
        
        $Script:ParsersPath =  "$ScriptPath\\Parsers\\"
        $Script:ParsersListPath = "$ScriptPath\\Internals\\Config\\Parsers.conf"

        #Running Config
        $Script:RunCollectors = [System.Convert]::ToBoolean($YACKConfig["RunCollectors"])
        $Script:CollectionMode = $YACKConfig["CollectionMode"].ToLower() -replace '\s',''
        $Script:MaxConcurrent = [int]$YACKConfig["MaxConcurrent"] 
        $Script:InteractiveMode = [System.Convert]::ToBoolean($YACKConfig["InteractiveMode"])
        $Script:StatusUpdateRate = [int]$YACKConfig["StatusUpdateRate"] 
        $Script:RunParsers = [System.Convert]::ToBoolean($YACKConfig["RunParsers"])
        $Script:AuthenticationMode = $YACKConfig["AuthenticationMode"].ToLower() -replace '\s',''

        #Script Start Time
        $Script:StartTime = $((get-date).ToUniversalTime().ToString("yyyyMMddHHmmss"))
    }
    catch 
    {
        Write-Log $Script:ScriptLogPath "Failed to parse yack.conf... $($_.Exception.Message) At $($_.InvocationInfo.ScriptName):$($_.InvocationInfo.ScriptLineNumber) char:$($_.InvocationInfo.OffsetInLine)"
        
        return $false
    }
    
    #Build Hostname list
    $Script:HostNames = @()
    if ($Script:CollectionMode -eq "Local") 
    {
        $Script:HostNames = $($Env:COMPUTERNAME)
    } 
    elseif ($Script:CollectionMode -eq "Remote") 
    {
        #Check if hostname file exists
        if (Test-Path -Path "$Script:HostNamesPath") 
        {
            #Read the hostnames file
            foreach ($line in $(Get-Content -Path $Script:HostNamesPath)) 
            {
                if ($null -ne $line) #ps2.0 check
                {
                    if ($line.StartsWith("#") -eq $false) 
                    {
                        if ($line.Trim() -ne "") 
                        {
                            $Script:HostNames += $line
                        }
                    }
                }
            }
        }
    }

    #Read Collectors
    Write-Log $Script:ScriptLogPath "Reading Collectors"
    $Script:Collectors = Read-Collectors $Script:CollectorsListPath $Script:CollectorsPath $script:DependenciesPath $script:ScriptLogPath


    # Load Credentials if needed
    if ($Script:CollectionMode -eq "remote") 
    {
        if ($Script:AuthenticationMode -eq "testing")
        {
            $Username = Get-Content "$Script:ConfigFolder\Cred_Username.txt"
            $Password = Get-Content "$Script:ConfigFolder\Cred_SecurePassword.txt" | ConvertTo-SecureString
            $Script:CollectionCreds = New-Object -typename System.Management.Automation.PSCredential -argumentlist $Username, $Password 

            #$Script:CollectionCreds = Import-CliXml -Path "$Script:ConfigFolder\SecureCreds.xml"
            
        }
        elseif (($Script:AuthenticationMode -eq "ntlm") -or ($Script:AuthenticationMode -eq "kerberos"))
        {
            $Script:CollectionCreds = Get-Credential
        }
        else 
        {
            Write-Log $Script:ScriptLogPath "Invalid authentication method selected. Check yack.conf."
            return $false
        }

    }
    

    return $true
}

function Test-Settings
{
    <#
    .SYNOPSIS
    Tests script settings and asks for user validation.
    #>

    ### Testing
    #return $true

    #Print collector errors.
    $IsCollectorError = $false
    foreach ($Collector in $Script:Collectors) 
    {
        #ps2.0 check and if the collector has an error
        if (($Collector -ne $null) -and ($Collector.Error -eq $true))
        {
            Write-Log $ScriptLogPath "        ERROR: $($Collector.CollectorName) - $($Collector.ErrorMessage)"
            $IsCollectorError = $true
        }
    }

    #Return false if there was an error.
    if ($IsCollectorError)
    {
        Write-Log $ScriptLogPath "Fix collector error(s) and run again."
        return $false
    }


    #Endless loop for user input if the settings are correct. And interactive mode
    while($true -and $Script:InteractiveMode) 
    {
        Write-Host ""
        Write-Host "Before the script executes please verify the settings."
        Write-Host "Output Path: $Script:OutputPath"
        Write-Host "Collection Mode: $Script:CollectionMode"

        if ($Script:CollectionMode -eq "Remote") 
        {
            Write-Host "Number of Hosts: $(@($Script:Hostnames).Length)"
        }
        Write-Host "Number of Collectors: $(@($Script:Collectors).Length)"

        # Prompt user for a selection
        $Selection = Read-Host "Is this correct? (y/n)"
        
        Write-Host ""

        #boolean on user selection
        if ($Selection -eq "y") 
        {
            break
        } 
        elseif ($Selection -eq "n") 
        {
            Write-Host "Please fix the settings in the yack.conf file."
            return $false
        }
    }

    return $true
}
