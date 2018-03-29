# ============================================================================
# Description: This will launch the collection script on local/remote systems 
# 	and will allow for the checking of privledges
# Copyright:
# Version: 0.1
# Date: 18MAR18
# Compatibility: powershell2.0
# Example: PowerShell -ExecutionPolicy Bypass -Command "launcher_win.ps1"
# ============================================================================




function Initialize
{
    #Meta Data
    $Script:ScriptVersion="0.1"

    # Configure Paths
    $Script:OutputPath="C:\\Users\\connor\\Documents\\output\\"
	$Script:ContentPath="C:\\Users\\connor\\Documents\\YACK\\win\\"

	$Script:ModuleListPath="$ContentPath\\Settings\\Light_List.txt"
	$Script:ScriptPath="$ContentPath\\collector.ps1"
	$Script:StatusLogPath="$OutputPath\\StatusLog.txt"

    $Script:PathMode="Absolute"
    




    ### Script execution 
    #SequentialBackground
    $Script:CollectionMode="Sequential"

    #Initate the host list
	$Script:HostListPath="$ContentPath\\Settings\\HostList.txt"
    $Script:HostList=$()


    ### Log Monitoring 
    # How many second between each check of the log
    $Script:CollectorLogCompletionStr="All modules complete on:"
    $Script:CheckCollectorLogInterval=2


    #Log this to the launcher log
    LogAndEcho "Starting the launcher on $env:computername."

}

function PrintBanner
{
	Write-Host "==========================================================================="
	Write-Host "                   Yb  dP    db    .d88b  8  dP"
 	Write-Host "                    YbdP    dPYb   8P     8wdP "
	Write-Host "                     YP    dPwwYb  8b     88Yb "
 	Write-Host "                     88   dP    Yb  Y88P  8  Yb"
	Write-Host ""
	Write-Host "Description: This will launch the collection script on local/remote systems "
	Write-Host "              and will allow for the checking of privledges."
	Write-Host "Version: $ScriptVersion"
	Write-Host "==========================================================================="
}


function MainMenu 
{
    while ($true) 
    {
        # Print the main menu options
        Write-Host ""
        Write-Host " ================== Main Menu =================="
        Write-Host " 1) Run Collection Script"
        Write-Host " 2) Priviledge Test"
        Write-Host " 9) Exit"
        Write-Host ""

        # Prompt user for a slection
        $selection = Read-Host "Enter Option: "
        Write-Host ""

        # Call a function based on the selection
        switch ($selection) {
            "1" {  
                ExecutionMenu
            }

            "2"{

            }

            "9"{
                return
            }
        }
	}
}

function ExecutionMenu
{
    while ($true) 
    {
        Write-Host ""
        Write-Host " =============== Execution Menu ================"
        Write-Host " 1) Run Locally"
        Write-Host " 2) Run Remotely"
        Write-Host " 4) Check Progress"
        Write-Host " 5) Monitor Progress (Blocking)"
        Write-Host " 9) Main Menu"
        Write-Host ""

        # Prompt user for a slection
        $selection = Read-Host "Enter Option: "
        Write-Host ""

        # Call a function based on the selection
        switch ($selection) {
            # Run Local
            "1" {  
                if (CheckSettings -eq $true)
                {
                    RunCollectionScript_Local
                }
            }

            # Run Remote
            "2"{
                if (CheckSettings -eq $true)
                {
                    RunCollectionScript_Remote
                }
            }

            # Check Progress
            "4"{
                CheckCollectorLog
            }

            # Monitor progress
            "5"{
                MonitorCollectorLog_Blocking
                LogAndEcho "Finished collection script on: $Host"
            }

            "9"{
                return
            }
        }
    }
}


function CheckSettings
{
    while ($true)
    {
        #Print the settings
        Write-Host "TODO: Print the current settings"
        $selection = Read-Host "Are the settings correct (y/n): "

        if ($selection -eq "y")
        {
            return $true
        }
        elseif ( $selection -eq "n")
        {
            Write-Host "Please modify settings in the ini file."
            return $false
        }
    }
}


# Functional
function RunCollectionScript_Local
{
    #Setup the host list
    $Hostn = $env:computername
    $Script:HostList = $Hostn
    
    LogAndEcho "Launching collection script on: $Hostn"

    #Run the collector script
    &$Script:ScriptPath $Script:OutputPath $Script:ContentPath $Script:ModuleListPath
}

function RunCollectionScript_Remote
{

    #TODO:
    #Populate HostList
    #Log how many hosts

    #Loop through each host
    foreach ($Host in $Script:HostList)
    {

        LogAndEcho "Launching collection script on: $Host"

        #It's being ran locally
        if ($Host -eq $env:computername)
        {
            &$Script:ScriptPath $Script:OutputPath $Script:ContentPath $Script:ModuleListPath
        }
        #It's being ran remotely
        else 
        {
            
        }

        #Give the collection script some time to startup
        Start-Sleep -Seconds 2
        
        
        MonitorCollectorLog_Blocking
        LogAndEcho "Finished collection script on: $Host"
    }
}

#Currently Only works for local
function CheckCollectorLog()
{
    foreach ($Hostn in $Script:HostList)
    {
        Write-Host "Checking Status Host: $Hostn"

        #Check if we can reach it
        if (-Not (Test-Path -Path "$Script:OutputPath\CollectorLog.txt"))
        {
            #Log and abort it
            LogAndEcho "Aborting: Cannot find the collector log for monitoring."
            return
        }


        #Grab the last 4 lines
        $CollectorLogLines = $(Get-Content -Path "$Script:OutputPath\CollectorLog.txt" | Select-Object -Last 4)
        $CollectorLogLastLine =$( $CollectorLogLines | Select-Object -Last 1)

        
        #Check the last line if it's completed
        if ($CollectorLogLastLine -like "*$Script:CollectorLogCompletionStr*")
        {
            Write-Host $CollectorLogLastLine
        }
        else 
        {
            Write-Host "..."
            #Print the lines
            foreach ($line in $CollectorLogLines)
            {
                Write-Host $line
            }
        }
        Write-Host ""
    }
}

function MonitorCollectorLog_Blocking()
{
    #Check if we can reach the collector log
    if (-Not (Test-Path -Path "$Script:OutputPath\CollectorLog.txt"))
    {
        #Log and abort it
        LogAndEcho "Aborting: Cannot find the collector log for monitoring."
        return
    }

    $LastReadLine=0
    
    #Loop until it finds the completion condition in the log
    while ($true) 
    {
        #Read the contents of the collector log
        $CollectorLogLines = $(Get-Content -Path "$Script:OutputPath\CollectorLog.txt")

        #Loop through new additions to the file
        for ($i=$LastReadLine; $i -lt $CollectorLogLines.Length; $i++)
        {
            #Write the new lines
            Write-Host $CollectorLogLines[$i]

            #If the log indicates completion then return
            if ($CollectorLogLines[$i] -like "*$Script:CollectorLogCompletionStr*") 
            {
                return
            }
        }

        $LastReadLine = $CollectorLogLines.Length

        #Sleep the script between reads
        Start-Sleep -Seconds $Script:CheckCollectorLogInterval        
    }
}





function LogAndEcho ($Text)
{
    $timestamp = $((get-date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ"))

    #Write to Log
    "$timestamp : $Text" | Out-File -Append "$OutputPath\LauncherLog.txt"
    #Write to console
    Write-Host "$timestamp : $Text"
}


################


Initialize
PrintBanner
MainMenu

#$Script:CheckCollectorLogMode="Background"
#MonitorCollectorLog_Blocking

