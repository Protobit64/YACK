@ECHO OFF


REM # ============================================================================
REM # Description: Gathers current running processes
REM # Author: 
REM # 
REM # ============================================================================
REM # Allows expansion in for loops
setlocal ENABLEDELAYEDEXPANSION


REM # Parse arguments
set ModuleFolderPath=%1
set OutputPath=%2

REM # Set variables
set OutputSubfolder=Program_Execution
set OutputFilename=Processes.csv

REM # Create output directory subfolder
if not exist "%OutputPath%%OutputSubfolder%" mkdir %OutputPath%%OutputSubfolder%



REM # Run the command
REM #%SYSTEMROOT%\system32\wbem\wmic.exe process get ^* /format:csv > %OutputPath%%OutputSubfolder%\%OutputFilename%


REM # Measure the results
set /a LineCount=0
for /F "tokens=* delims= " %%i in (%OutputPath%%OutputSubfolder%\%OutputFilename%) do echo 1

for %%i in (%OutputPath%%OutputSubfolder%\%OutputFilename%) do (
    set /a LineCount=!LineCount!+1
    echo 1
)
REM # Finish your script with an output to the status log
set "Results=Processes captured: %LineCount%"
echo  %Results%
echo  %Results% >> %OutputPath%\StatusLog.txt

