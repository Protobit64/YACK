
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
    
    #Loop through each module and log/run it
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
    "$timestamp : $Text" | Out-File -Append "$Script:ScriptPath\Settings\yack.log"
    #Write to console
    Write-Host "$timestamp : $Text"
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
########################## Program Execution Active
function Get-ProcessNames
{
    # Get privs of the process as well
    # Also username
    # Hash executable path

    $ProcessList = $(Get-WmiObject -Class Win32_process)

    $Sha1_Hasher = new-object -TypeName System.Security.Cryptography.SHA1CryptoServiceProvider
    foreach ($proc in $ProcessList)
    {
        #Find out username/domain of the launcher
        $owner = $($proc | Invoke-WmiMethod -Name GetOwner)      

        # Compute Hash
        $hash = 0
        if ($proc.ExecutablePath -ne $null)
        {
            $hash = [System.BitConverter]::ToString($Sha1_Hasher.ComputeHash([System.IO.File]::ReadAllBytes($proc.ExecutablePath)))
            $hash = $hash.replace("-", "")
        }


        # Add Results
        $proc | Add-Member -MemberType NoteProperty -Name "user_name" -Value $owner.user
        $proc | Add-Member -MemberType NoteProperty -Name "user_domain" -Value $owner.Domain
        $proc | Add-Member -MemberType NoteProperty -Name "sha1" -Value $hash
    }

    $ProcessList | Export-Csv -Path "$Script:OutputPath\Program_Execution_Active\ProcessNameList2.csv" -NoType

        # Parent Process ID
        # Command Line Args

    #$AdditionalInformation = $(Get-Process |  Select-Object -property ID, Path, FileVersion, Description, Company, Product, ProductVersion, MainWindowHandle, MainWindowTitle)





    #Faster Export Csv
    #$csv = $(ConvertTo-Csv -InputObject $ProcessList[0])
    #for ($i = 1; $i -lt $ProcessList.Length; $i++)
    #{
    #    $csv += $(ConvertTo-Csv -InputObject $ProcessList[$i])[2]
    #}





    
    #$ProcessList | Out-File -FilePath "$Script:OutputPath\Program_Execution_Active\test.txt"


    # Modules
    # Executable Location
        # Executable Hash
        # Sig check
    
    # Args
    # dlls
    # Sockets
    # handles 

    
    #Export to multiple files

    return "hi"
}


function Process_Token
{
    #https://github.com/FuzzySecurity/PowerShell-Suite/blob/master/Get-TokenPrivs.ps1
}

function Get-Hostname
{
    Write-Host "My hostname is bob"
}

########################## ########################



# Starts the main function (c style)
# main
Initialize-Settings
New-Item -ItemType Directory -Force -Path  "$Script:OutputPath\Program_Execution_Active\" 

Get-ProcessNames


