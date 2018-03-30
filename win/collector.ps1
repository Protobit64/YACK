# ============================================================================
# Description: Runs the modules in the provided list
# Arguments:
# 	ModulePath - 
# 	OutputPath -
#
# Example
# .\Collection_Scripts\Collect_Light.bat 
# "C:\\Users\\connor\\Documents\\output\\"
# "C:\\Users\\connor\\Documents\\YACK\\win\\
# "C:\\Users\\connor\\Documents\\YACK\\win\\Settings\\Light_List.txt"
# ============================================================================

Param(
    [string]$OutputPath,
    [string]$ContentPath,
    [string]$ModuleListPath
)



function Initialize
{
    # Setup Variables
    $Script:ModuleFolderPath = "$ContentPath\Modules\"

    #Create Status Log
    "" | Out-File "$OutputPath\CollectorLog.txt"
    LogAndEcho "Starting the Script."
}


function RunModules
{
	# Parse the module file
    $ModuleList = @()

    LogAndEcho "Parsing the module list"

    foreach ($line in $(Get-Content -Path $ModuleListPath))
    {
        if ($line.StartsWith("#") -eq $false)
        {
            if ($line.Trim() -ne "") {
                $ModuleList += $line
            }
        }
           
    }
    LogAndEcho "Found: $($ModuleList.Length) modules"

    $count = 1

    foreach ($Module in $ModuleList)
    {
        #Log we attempting to run it
        LogAndEcho "$count / $($ModuleList.Length) : Running $Module"

        #Check if the file exists
        $FileExists=$(Test-Path -Path $ModuleFolderPath$Module)

        # If the file exists
        if ($FileExists -eq $true)
        {
            #Run it
            RunModule $ModuleFolderPath$Module
        }
        else 
        {
            #Log it doesn't exist
            LogAndEcho "Result: Module does does not exist."

        }

        #Increment the count
        $count = $count + 1
    }

    LogAndEcho "All modules complete on: $env:computername"
}


function RunModule ($ModulePath)
{
    #Check file type
    $FileExtension = $(Get-ItemPropertyValue -Name Extension $ModulePath)

    ## Working here to run ps modules
    switch ($FileExtension) {
        #Batch File
        '.bat' { 
            LogAndEcho "Batch file type."
            Write-Host "Complete"
        }
        
        #Powershell Script
        '.ps1' { 
            #LogAndEcho "Powershell script file type."
            &$ModulePath $Script:OutputPath $Script:ModuleFolderPath 
        }

        #Powershell Module
        '.psm1' { 
            LogAndEcho "Powershell Module file type."
        }

        #Undefined file type
        Default {
            LogAndEcho "File type not supported."
        }
    }
}

function LogAndEcho ($Text)
{
    $timestamp = $((get-date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ"))

    #Write to Log
    "$timestamp : $Text" | Out-File -Append "$OutputPath\CollectorLog.txt"
    #Write to console
    Write-Host "$timestamp : $Text"
}



#######

Initialize

#Launch variable
RunModules 
