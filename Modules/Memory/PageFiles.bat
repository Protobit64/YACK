@ECHO OFF


REM # ============================================================================
REM # things happen


REM # Janky 3 second delay
ping -n 4 127.0.0.1 > nul
	
	
REM # Finish your script with an output to the status log
set "Results=No pagefiles found"
echo  %Results%
echo  %Results% >> %OutputPath%\StatusLog.txt

