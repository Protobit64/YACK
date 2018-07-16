
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
    $Script:OutputPath = "$($(Resolve-Path .\..\..\).Path)\Output\"
    $Script:ScriptPath = $(Resolve-Path .\).Path

    #Derived paths
    $Script:SettingsPath = "$ScriptPath\\Settings\\yack.ini"
    $Script:LogPath = "$ScriptPath\\Settings\\yack.log"
    $Script:HostNamesPath = "$ScriptPath\\Settings\\hostnames.txt"
    $Script:ModulesPath =  "$ScriptPath\\Modules\\"

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
    return $true

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
    $cNum = 0
    $tNum = $Script:ModulesList.Count
    
    $Script:OutputPath

    Write-Log "Starting Collection: $Script:HostNames"
    foreach ($Module in $Script:ModulesList)
    {
        $cNum++
        $mPath = $Script:ModulesPath + "$Module"
        $Results = ""

        Write-Log "[$cNum/$tNum] Starting Module: $Module"

        #Check if module exists
        if ($(Test-Path $mPath) -eq $true)
        {
            $Results = & $mPath
            Write-Log "[$cNum/$tNum]        Finished: $($Results.Count) Results"
        }
        else
        {
            Write-Log "[$cNum/$tNum]        Finished: ERROR - Module Not Found"
        }

        #Output results
        Write-Results $Script:OutputPath $Results

    }

    #Collect process Info
   # $ProcessInfo = & $($Script:ScriptPath + "\Modules\Get-ProcessInfo.ps1")
    
    #collect 

    #$ProcessInfo | Export-Csv -Path "$Script:OutputPath\Program_Execution_Active\ProcessNameList.csv" -NoType
    
    Write-Log "Finished Collection: $Script:HostNames"
}

function Start-Collection_Remote
{
    #Loop through each host
    foreach ($HostN in $Script:HostNames)
    {
        #Run each module
        foreach ($Module in $Script:ModulesList)
        {
            Invoke-Command -ScriptBlock "Start-Collection_$a" -ComputerName $Script:HostNames -ThrottleLimit 3
        }
    }
}

function Write-Log ($Text)
{
    $timestamp = $((get-date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ"))

    #Write to Log
    "$timestamp : $Text" | Out-File -Append "$Script:LogPath"

    #Write to console
    Write-Host "$timestamp : $Text"
}

function Write-Results ($Path, $Results)
{

}


######################## Collection MODULES ########################

#This will be populated as it goes.
function Get-GeneralInfo
{
    $ComputerName = $Env:COMPUTERNAME
    $ProcessNames = $()
    #$Drives = $(Get-PSDrive -PSProvider FileSystem)
    $Drives = $([System.IO.DriveInfo]::getdrives())

    $(Get-ItemProperty $Drives)
    #$Drives[0].Name

    return "Success"
}


# Starts the main function (c style)
main
#Initialize-Settings
#New-Item -ItemType Directory -Force -Path  "$Script:OutputPath\Program_Execution_Active\" 

#Start-Collection_Local



