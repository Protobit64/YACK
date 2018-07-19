
# Attempt #3 of doing this
# fer werk
# Description: This will launch the collection script on local/remote systems 
#              and will allow for the checking of privledges.


function main
{
    #Print the main banner
    Write-Host "==========================================================================="
	Write-Host "                   Yb  dP    db    .d88b  8  dP"
 	Write-Host "                    YbdP    dPYb   8P     8wdP "
	Write-Host "                     YP    dPwwYb  8b     88Yb "
 	Write-Host "                     88   dP    Yb  Y88P  8  Yb"
	Write-Host "==========================================================================="

    #Initialize the settings
    Initialize-Settings

    #Get User confirmation of settings
    if ($(Compare-Settings) -eq $true)
    {
        If ($CollectionMode -eq "Local")
        {
            Start-Collection_Local
        }
        elseif ($CollectionMode -eq "Remote")
        {
            Start-Collection_Remote
        }
    }
    else
    {
        #If it's incorrect then fix the ini file
        Write-Host "Please fix the settings in the yack.ini file."
    }
}


#TODO: Add reading from a ini file
function Initialize-Settings
{
    #Meta Data
    $Script:ScriptVersion="0.1"

    # Configure Paths
    $Script:ScriptPath = $(Resolve-Path .\).Path
    $Script:OutputPath = "$ScriptPath\\Output\\"

    #Derived paths
    $Script:SettingsPath = "$ScriptPath\\Settings\\yack.ini"
    $Script:ScriptLogPath = "$ScriptPath\\Settings\\yack.log"
    $Script:HostNamesPath = "$ScriptPath\\Settings\\hostnames.txt"
    $Script:ModulesPath =  "$ScriptPath\\Modules\\"
    $Script:DependenciesPath =  "$ScriptPath\\Modules\\_Dependencies\\"

    #Running Config
    $Script:CollectionMode = "Local" #Local/Remote

    #Module Settings
    $Script:ModulesList = @()
    $Script:ModuleListPath = "$ScriptPath\\Settings\\modules.txt"

    #Hostnames to run modules on.
    $Script:HostNames = @()

    #Populate Modules
    foreach ($line in $(Get-Content -Path $Script:ModuleListPath))
    {
        if ($line.StartsWith("#") -eq $false)
        {
            if ($line.Trim() -ne "") {
                $Script:ModulesList += $line
            }
        }
    }

    #Populate Hostnames
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
                if ($line.StartsWith("#") -eq $false)
                {
                    if ($line.Trim() -ne "") {
                        $Script:HostNames += $line
                    }
                }
            }
        }
    }
}


function Compare-Settings
{
    #return $true

    #Print the current settings
    while($true)
    {
        Write-Host ""
        Write-Host "Before the script executes please verify the settings."
        Write-Host "Collection Mode: $Script:CollectionMode"
        if ($Script:CollectionMode -eq "Remote")
        {
            Write-Host "Number of Hosts: $($Script:HostNames.Length)"
        }
        Write-Host "Number of Modules: $($Script:ModulesList.Length)"

        # Prompt user for a selection
        $selection = Read-Host "Is this correct? (y/n)"
        Write-Host ""

        if ($selection -eq "y")
        {
            return $true
        }
        elseif ($selection -eq "n")
        {
            return $false
        }
    }
}

function Start-Collection_Local
{
    #Create Output Folder
    New-Item -Path "$Script:OutputPath$Script:HostNames" -ItemType directory -Force
    $CollectLogPath = "$Script:OutputPath$Script:HostNames\\collect.log"

    Write-Log $Script:ScriptLogPath "Starting Local Collection on $Script:HostNames"

    #Local counter variable for logging
    $cNum = 1
    $tNum = $Script:ModulesList.Count

    # Read every binary dependency
    # Move all required binaries for the modules

    $mods = Read-Modules $Script:ModulesList

    Write-Dependencies $mods

    #Runt the modules
    foreach ($mod in $mods)
    {
        Write-Log $CollectLogPath "[$cNum/$tNum] Launching Module: $($mod.ModuleName)"

        if ($mod.Error -eq $false)
        {
            #Run Module
            $mod.Results = Invoke-Command -ScriptBlock $mod.ScriptBlock
            Write-Log $CollectLogPath "[$cNum/$tNum]        Finished: $($mod.Results.Count) Results"

            #Output results
            Write-ModResults "$Script:OutputPath$Script:HostNames\" $mod
        }
        else
        {
            Write-Log  $CollectLogPath "[$cNum/$tNum]        Finished: ERROR - $($mod.ErrorMessage)"
        }

        #Increment Counter
        $cNum++
    }

    Remove-Dependencies
    Write-Log $Script:ScriptLogPath "Finished Running $tNum Modules on $Script:HostNames"
}

#Currently does not much
function Start-Collection_Remote
{
    #Loop through each host
    foreach ($HostN in $Script:HostNames)
    {
        #Run each module
        foreach ($ModuleN in $Script:ModulesList)
        {
            Invoke-Command -ScriptBlock "Start-Collection_$a" -ComputerName $Script:HostNames -ThrottleLimit 3
        }
    }
}

function Write-Log ($LogPath, $Text)
{
    $timestamp = $((get-date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ"))

    #Write to Log
    "$timestamp : $Text" | Out-File -Append "$LogPath"

    #Write to console
    Write-Host "$timestamp : $Text"
}

function Write-ModResults ($outputPath, $Module)
{
    $oPath = "$outputPath$($Module.ModuleName)"
    $mFolder = Split-Path -Path $oPath

    #Create Output Folder
    New-Item -Path "$mFolder" -ItemType directory -Force

    if ($Module.OutputType -eq "CSV")
    {
        $Module.Results | Export-Csv -NoTypeInformation -Path "$mFolder\$($Module.OutputName)"
    }
}

function Write-Dependencies ($Modules, $wPath)
{
    $TranferFolder = "$env:TEMP\yack"
    
    #Create Dependencies List
    $Dependencies = @()

    #Build dependencies list
    foreach ($mod in $Modules)
    {
        foreach ($dep in $mod.Dependencies)
        {
            if ($Dependencies.Contains($dep) -ne $true)
            {
                $Dependencies += $dep
            }
        }
    }

    #Validate that the Module dependencies exist
    foreach ($mod in $Modules)
    {
        foreach ($dep in $mod.Dependencies)
        {
            if ($(Test-Path "$Script:DependenciesPath$dep") -eq $false)
            {
                $mod.Error = $true
                $mod.ErrorMessage = "Module dependencies not found"
                break
            }
        }
    }

    #Create Transfer Folder
    New-Item -Path "$TranferFolder" -ItemType directory -Force

    #Transfer Dependencies
    foreach ($dep in $Dependencies)
    {
        $depPath = "$Script:DependenciesPath$dep"
        if ($(Test-Path $depPath) -eq $true)
        {
            Copy-Item -Path $depPath -Destination $TranferFolder
        }
    }
}

function Remove-Dependencies ($Modules, $wPath)
{
    $TranferFolder = "$env:TEMP\yack"

    Remove-Item -Path $TranferFolder -Recurse
}


function Read-Modules ($mNames)
{
    $Modules = @()

    foreach ($mName in $mNames)
    {

        $Module = New-Object PSObject
        $Module | Add-Member -Type NoteProperty -Name "ModuleName" -Value $mName
        $Module | Add-Member -Type NoteProperty -Name "Error" -Value $false
        $Module | Add-Member -Type NoteProperty -Name "ErrorMessage" -Value ""
        $Module | Add-Member -Type NoteProperty -Name "Results" -Value $null
        $Module | Add-Member -Type NoteProperty -Name "ScriptBlock" -Value $null
        $Module | Add-Member -Type NoteProperty -Name "OutputType" -Value $null
        $Module | Add-Member -Type NoteProperty -Name "OutputName" -Value $null
        $Module | Add-Member -Type NoteProperty -Name "Dependencies" -Value $null
        $Module | Add-Member -Type NoteProperty -Name "Path" -Value $($Script:ModulesPath + "$mName")

        if ($(Test-Path $Module.Path) -eq $true)
        {
            #Read Script Block
            $Module.ScriptBlock = $(get-command $Module.Path | Select-Object -ExpandProperty ScriptBlock)

            #Read OutputType
            $Directive_Flag = "#.OUTPUT_Type "
            $Directive_Text = $($Module.ScriptBlock.ToString() -split "`n" | ForEach-Object { if ($_ -match $Directive_Flag) {return $_} })
            $Module.OutputType = $($Directive_Text -replace $Directive_Flag, "").Trim()

            #Read Output Name
            $Directive_Flag = "#.OUTPUT_Name "
            $Directive_Text = $($Module.ScriptBlock.ToString() -split "`n" | ForEach-Object { if ($_ -match $Directive_Flag) {return $_} })
            $Module.OutputName = $($Directive_Text -replace $Directive_Flag, "").Trim()

            #Read Dependency
            $Directive_Flag = "#.DEPENDENCY "
            $Directive_Text = $($Module.ScriptBlock.ToString() -split "`n" | ForEach-Object { if ($_ -match $Directive_Flag) {return $_} })
            if ($Directive_Text -ne $null)
            {
                $Module.Dependencies = $($Directive_Text -replace $Directive_Flag, "").Trim() -split " "
            }

            $Module.Error = $false
        }
        else
        {
            $Module.Error = $true
            $Module.ErrorMessage = "Module Not Found"
            
        }


        $Modules += $Module
    }

    return $Modules

}



########################
main
