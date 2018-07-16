



REM # Parse arguments
set ModuleFolderPath=%1
set OutputPath=%2


REM # Finish your script with an output to the status log
set "Results=8455MB captured"
echo  %Results%
echo  %Results% >> %OutputPath%\StatusLog.txt