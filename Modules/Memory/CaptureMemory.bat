@ECHO OFF


REM # ============================================================================
REM # things happen
REM # ============================================================================


REM # Parse arguments
set ModuleFolderPath=%1
set OutputPath=%2


REM # Janky 2 second delay
ping -n 3 127.0.0.1 > nul




REM # Finish your script with an output to the status log
set "Results=8455MB captured"
echo  %Results%
echo  %Results% >> %OutputPath%\StatusLog.txt

