
Param(
    [string]$OutputPath,
    [string]$ModuleFolderPath

  )
 
  
function LogAndEcho ($Text)
{
    $timestamp = $((get-date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ"))

    #Write to Log
    "$timestamp : $Text" | Out-File -Append "$Script:OutputPath\StatusLog.txt"
    #Write to console
    Write-Host "$timestamp : $Text"
}


#fsutil dirty query %systemdrive% >nul
#echo %errorlevel%


#Write-Host "hiberfil"
#Start-Sleep 2
#net session
#sleep 1

#Output Results to Statuslog
LogAndEcho "Result: No hibernation File Found"
