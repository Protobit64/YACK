
#Server 2008
# C:\inetpub\logs\LogFiles\W3SVC1\u_ex180924
# iis 7.5 
# %SystemDrive%\inetpub\logs\LogFiles\


# HKLM\SOFTWARE\Microsoft\WebManagement\Server\LoggingDirectory 

#Server 2016



#HTTPERR
#%SystemDrive%\Windows\System32\LogFiles\HTTPERR


#Method 1...

$CollectorResult = "" | Select-Object Error, ErrorMessage, OutputType, OutputName, OutputFolder, Content

#modify execution policy for this session
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope Process -Confirm:$false


#Import web aministration ps modules
$ImportWorked = $true
try {
    Import-Module WebAdministration
    $ImportWorked = $true
}
catch {
    $ImportWorked = $false
}


if ($ImportWorked)
{
    $WebInfo = Get-Website 

    if ($null -ne $WebInfo)
    {
        #Build logs folders (if there are multiple)
        $LogFolders = @()
        foreach ($web in $WebInfo)
        {
            if ($LogFolders -notcontains $web.LogFile.directory)
            {
                $LogFolders += $web.LogFile.directory
            }
        }

        foreach ($LogFolder in $LogFolders)
        {
            #Export each folder
        }

    }
}


#method 2
# C:\Windows\System32\inetsrc\config\applicationHost.config
# centralW3CLogFile location
# Site-level logging creates individual log file directories for each site on your server, where each folder contains only the log files for that site.
# https://docs.microsoft.com/en-us/iis/configuration/system.applicationhost/log/
