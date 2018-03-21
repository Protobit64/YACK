@ECHO OFF


REM # ============================================================================
REM # things happen


REM # Finish your script with an output to the status log
set "Results=56 Processes"
echo  %Results%
echo  %Results% >> %OutputPath%\StatusLog.txt

