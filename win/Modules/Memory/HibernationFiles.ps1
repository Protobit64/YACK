
Param(
    [string]$ModuleFolderPath,
    [string]$OutputPath
  )
  
  
  #fsutil dirty query %systemdrive% >nul
  #echo %errorlevel%
  
  
  #Write-Host "hiberfil"
  #Start-Sleep 2
  #net session
  
  #Output Results to Statuslog
  $Results="No hibernation FIle Found"
  $Results | Out-File -Encoding ascii -Append $OutputPath\StatusLog.txt