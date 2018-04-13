
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
    ###############################################################
    # Gather Volatile Information
    ###############################################################

    #Get current running processes and sockets
    $ProcessList = $(Get-WmiObject -Class Win32_process)
    $NetstatOutput = $(netstat -a -o -n)

    #Find owners of those processes
    $ProcessOwners = @()
    foreach ($proc in $ProcessList)
    {
        #Find out username/domain of the owner
        $owner = $($proc | Invoke-WmiMethod -Name GetOwner)   
        $ProcessOwners += $owner.User + "\" + $owner.Domain
    }


    ###############################################################
    # Gather Non-volatile Information
    ###############################################################

    #File Executable Hash
    $ProcessExecutableHashes = @()
    $Sha1_Hasher = new-object -TypeName System.Security.Cryptography.SHA1CryptoServiceProvider
    foreach ($proc in $ProcessList)
    {
        # Compute Hash of the file
        $hash = 0
        if ($proc.ExecutablePath -ne $null)
        {
            $hash = [System.BitConverter]::ToString($Sha1_Hasher.ComputeHash([System.IO.File]::ReadAllBytes($proc.ExecutablePath)))
            $hash = $hash.replace("-", "")
        }
        $ProcessExecutableHashes += $hash
    }

    #File Executable Sig Check
    $ProcessExecutableSigCheck = @()
    $Sha1_Hasher = new-object -TypeName System.Security.Cryptography.SHA1CryptoServiceProvider
    foreach ($proc in $ProcessList)
    {
        if ($proc.ExecutablePath -ne $null)
        {
            # Compute Hash of the file
            $auth = Get-AuthenticodeSignature -FilePath $proc.ExecutablePath
            $ProcessExecutableSigCheck += $auth.Status
        }
        else 
        {
            $ProcessExecutableSigCheck += ""
        }
    }


    ###############################################################
    # Parse Information
    ###############################################################

    ###### Convert netstat output -> variable
    $NetworkConnections = @()
    #Get rid of the output headers
    $NetstatOutput = $NetstatOutput[4..$NetstatOutput.Length]

    #Loop through each line
    foreach ($connection in $NetstatOutput)
    {
        #Remove whitespace form start of line
        $connection = $connection -replace ('^\s+', '')

        #Split items on whitespace
        $connection = $connection -split ('\s+')

        #Parse items based on observed outcomes
        if ($connection.Length -eq 5) #All fields present
        {
            $properties = @{
                Protocol = $connection[0]
                LocalAddress = $connection[1]
                ForeignAddress = $connection[2]
                State = $connection[3]
                PID = $connection[4]
            }
        }
        elseif ($connection.Length -eq 4) #State is missing
        {
            $properties = @{
                Protocol = $connection[0]
                LocalAddress = $connection[1]
                ForeignAddress = $connection[2]
                State = ""
                PID = $connection[3]
            }
        }
        else { #Something went wrong
            $properties = @{
                Protocol = ""
                LocalAddress = ""
                ForeignAddress = ""
                State = ""
                PID = ""
            }
        }

        #Add to resulting object
        $NetworkConnections += New-Object -TypeName PSObject -Property $properties
    }


    ###### Create connection lists
    $ProcessConnectionList = @()

    foreach ($proc in $ProcessList)
    {
        $Connections = ""
        foreach ($conn in $NetworkConnections)
        {
            if ($conn.PID -eq $proc.ProcessId)
            {
                $Connections += $conn.LocalAddress + "`n"
            }
        }
        $ProcessConnectionList += $Connections.Trim()
    }

    #Determine parent process names
    $ProcessParentNames = @()
    foreach ($proc in $ProcessList)
    {
        $ParentName = ""
        foreach ($parentProc in $ProcessList)
        {
            if ($proc.ProcessId -eq $parentProc.ProcessId)
            {
                $ParentName = $parentProc.ProcessName
            }
        }
        $ProcessParentNames += $ParentName
    }


    ###############################################################
    # Organize Results
    ###############################################################

    #Append information to results

    for ($i = 0; $i -lt $ProcessList.Length; $i++)
    {
        # Add Results
        $ProcessList[$i] | Add-Member -MemberType NoteProperty -Name "ProcessOwner" -Value $ProcessOwners[$i]
        $ProcessList[$i] | Add-Member -MemberType NoteProperty -Name "SHA1Hash" -Value $ProcessExecutableHashes[$i]
        $ProcessList[$i] | Add-Member -MemberType NoteProperty -Name "Connections" -Value $ProcessConnectionList[$i]
        $ProcessList[$i] | Add-Member -MemberType NoteProperty -Name "ParentProcessName" -Value $ProcessParentNames[$i]
        $ProcessList[$i] | Add-Member -MemberType NoteProperty -Name "ExeSigCheck" -Value $ProcessExecutableSigCheck[$i]
    }

    $ProcessList = $($ProcessList | Select-Object -Property CreationDate, ProcessName, ProcessId, ParentProcessName, ParentProcessId, ProcessOwner, `
                                                            Connections, ExecutablePath, ExeSigCheck, CommandLine, SHA1Hash, CSName, HandleCount, ThreadCount, `
                                                            VirtualSize, ReadOperationCount, ReadTransferCount, WriteOperationCount, WriteTransferCount, `
                                                            UserModeTime, KernelModeTime)

    #$ProcessList | Export-Csv -Path "$Script:OutputPath\Program_Execution_Active\ProcessNameList.csv" -NoType

    return $ProcessList
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


