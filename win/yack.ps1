
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
    $Script:ScriptPath = $(Resolve-Path .\).Path#"C:\\Users\\connor\\Documents\\YACK\\win\\"

    
    #Derived paths
    $Script:SettingsPath = "$ScriptPath\\Settings\\yack.ini"
    $Script:LogPath = "$ScriptPath\\Settings\\yack.log"
    $Script:HostNamesPath = "$ScriptPath\\Settings\\hostnames.txt"


    #Running Config
    $Script:CollectionMode = "Local" #Local/Remote

    #Module Settings
    $Script:ModulesList = @()
    $Script:ModuleListName = "Test"
    $Script:ModuleListPath = "$ScriptPath\\ModuleLists\\$Script:ModuleListName.txt"


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

    #Populate the hostname list 
    if ($Script:CollectionMode -eq "Local") 
    {
        $Script:HostNames = $($Env:COMPUTERNAME)
    }
    elseif ($Script:CollectionMode -eq "Remote") 
    {
        #Check if hostname file exists
        if (Test-Path -Path "$Script:HostNamesPath")
        {
            #Read the contents
            $Script:HostNames = $(Get-Content -Path "$Script:HostNamesPath")
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
        Write-Host "Number of Hosts: $($Script:HostNames.Length)"
        Write-Host "Module Mode: $Script:ModuleList"
        Write-Host "Number of Modules: $($Script:ModulesList.Length)"

        # Prompt user for a slection
        $selection = Read-Host "Is this correct? (y/n)"
        Write-Host ""

        if ($selection -eq "y")
        {
            return $true
        }
        elseif ($selection -eq "n") {
            return $false
        }
    }
}

function Start-Collection_Local
{
    Write-Log "Starting Local Collection on $Script:HostNames"
    
    for ($i = 0; $i -lt $($Script:ModulesList.Length); $i++)
    {
        $module = $($Script:ModulesList[$i])
        Write-Log "Running : $($i+1) / $($Script:ModulesList.Length) : $module"
        $results = $(&$module)
        Write-Log "Results: $results"
    }  

    Write-Log "Finished Local Collection on $Script:HostNames" 
}

function Start-Collection_Remote
{
    foreach ($HostN in $Script:HostNames)
    {
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
    "$timestamp : $Text" | Out-File -Append "$Script:ScriptPath\Settings\yack.log"
    #Write to console
    Write-Host "$timestamp : $Text"
}



######################## Collection MODULES ########################

#This will be populated as it goes.
function Get-GeneralInfo
{
    $ComputerName = 
    $ProcessNames = $()
    $Drives = $()

    return "Success"
}

function Get-Processes
{
    $ComputerName
    return "hi"
}

function Get-Hostname
{
    Write-Host "My hostname is bob"
}

########################## ########################



# Starts the main function (c style)
main

