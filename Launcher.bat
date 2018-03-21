@ECHO OFF
REM # ============================================================================
REM # Description: The launching script for host collection
REM #  This is capable of doing both remote and local
REM # Copyright:
REM # Version: 0.1
REM # Date: 18MAR18
REM # Compatibility: XP+ (uses wmic)
REM # ============================================================================


REM # start local variable environment
setlocal ENABLEDELAYEDEXPANSION


call :Initialize
call :PrintBanner

call :Menu_Main
REM # call :CheckLog_Blocking %StatusLogPath%

Exit /B 0


REM # ============================================================================
REM # ================================ Functions =================================
REM # ============================================================================

:Initialize

    REM # Default Paths
    SET OutputPath=C:\Users\connor\Documents\output\

	REM # Configure Settings
	SET ScriptPath=%~dp0\Modules\Collector.bat
	SET StatusLogPath=%OutputPath%\Collected_Data\StatusLog.txt
	SET ScriptVersion=0.1
	REM # How many second between each check of the log
	SET LogStatusInterval=3
	
	SET OptionSelected=0
	EXIT /B 0

	
:PrintBanner
	echo Collection Script Version: v%ScriptVersion%
	EXIT /B 0


	
REM # ============================================================================
REM # ============================== Menu  =======================================
REM # ============================================================================
	
:Menu_Main

	REM # Print the main menu options
	echo.
	echo ================== Main Menu ==================
	echo 1) Local Script Execution
	echo 2) Local Priviledge Test
	echo 3) Remote Script Execution
	echo 4) Remote Priviledge Test
	echo 9) Exit
	echo.

	REM # Prompt user for a slection
	set /p OptionSelected="Enter Option: "
	echo.

	
	REM # Call a function based on the selection
	IF /I "%OptionSelected%" EQU "1" call :Menu_LocalScriptExe
	IF /I "%OptionSelected%" EQU "2" call :Menu_LocalPrivCheck
	IF /I "%OptionSelected%" EQU "3" call :Menu_RemoteScriptExe
	IF /I "%OptionSelected%" EQU "4" call :Menu_RemotePrivCheck
	IF /I "%OptionSelected%" EQU "9" Exit /B 0
	

	REM # Loop back to the start
	GOTO :Menu_Main
	

:Menu_LocalScriptExe

	REM # Print the current settings
	echo.
	echo.
	echo ========= Local Script Execution =========
	echo Script Settings
	echo Path Mode: Absolute
	echo Script Path: %ScriptPath%
	echo Output Path: %OutputPath%
	echo.
	
	REM # Ask user if settings are correct
	set /p OptionSelected="Is this correct? (y/n)"
	
	
	REM # Execute script if it's correct
	IF /I "%OptionSelected%" EQU "y" (
		call :LocalScriptExe
		echo Script complete.
		set /p OptionSelected="Press ENTER to continue."
		EXIT /B 0
	)
	
	REM # Exit Otherwise
	IF /I "%OptionSelected%" EQU "n" (
		echo Change the config in the ini file.
        echo.
		set /p OptionSelected="Press ENTER to continue."
		EXIT /B 0
	)
	
	REM # If a option wasn't selected then reprint
	GOTO :Menu_LocalScriptExe
	
	
	
:Menu_RemoteScriptExe
	
	REM # Host HTTP?
	
	REM # -- RCE
	REM # rpc
	REM # wmic
	
	REM # -- File Transers
	REM # FTP
	REM # SMB
	REM # PSRemoteSession

    REM # Launch and forget vs monitor

:Menu_LocalPrivCheck
	
	REM # Check for..
	REM # Ability to read output log
	REM # Ability to transfer data
	REM # Ability to execute
	REM # Admin Privs
	


:Menu_RemotePrivCheck
	
	

	
	
REM # ============================================================================
REM # ======================== Script Execution ==================================
REM # ============================================================================

:LocalScriptExe

	REM # Log that you are launching it
	echo.
	call :LogAndEcho "Launching script locally."
	
	REm # Launch the collection script
	call "cmd /c start %ScriptPath% parm1test " 
	
	REM # Wait for the completion of the script
	call :CheckLog_Blocking %StatusLogPath%
	
	call :LogAndEcho "Locally launched script finished."

	Exit /B 0

:RemoteScriptExe

	
	
REM # ============================================================================
REM # ======================== Checks ==================================
REM # ============================================================================


REM # ==================================================================
REM # Description: Checks the log file for parameters.
REM # Parameters:
REM #		- StatusLogPath
REM #			The output path of the log file.
REM # 		- LoopUntilComplete (T/F)
REM #			Determines if this is a blocking function.
REM # Usage:
REM #	call :CheckLog_Blocking C:/log.txt
REM # ==================================================================
:CheckLog_Blocking
	
	SET Param_StatusLogPath=%~1
	
	
	SET /a LastPrintedNum=0
	
	:LogCheck_Loop
	
		set /a CurrentLine=0
	
		REM # Prints new lines in the status log until it reaches a "Complete" line
		FOR /F "eol=# tokens=1,2,3,4,5* delims=, " %%i in (%Param_StatusLogPath%) do (
			set /a CurrentLine=!CurrentLine!+1
			
			If /I "!CurrentLine!" GTR "!LastPrintedNum!" (
			
				echo %%i %%j %%k %%l %%m %%n
				set /a "LastPrintedNum=!CurrentLine!" 
				
				if /I "%%i" EQU "Complete" (
					EXIT /B 0
				)
			)
		)
		
		REM # Janky 2 second delay
		ping -n %LogStatusInterval% 127.0.0.1 > nul
	
	REM # Infinite Loop until reaching complete
	goto :LogCheck_Loop
	
	

REM # ============================================================================
REM # ======================== Misc Functions ====================================
REM # ============================================================================

:LogAndEcho
	SET Param_Text=%~1
	
	call :Update_UTCtimestamp

	echo %UTCtimestamp% :: %COMPUTERNAME% :: %Param_Text%
	echo %UTCtimestamp% :: %COMPUTERNAME% :: %Param_Text% >> %OutputPath%\Launcher.log

Rem # ISO 8601 format
:Update_UTCtimestamp
	
	for /f "delims=" %%a in ('wmic OS Get localdatetime  ^| find "."') do set "dt=%%a"
	set "TS_YYYY=%dt:~0,4%"
	set "TS_MM=%dt:~4,2%"
	set "TS_DD=%dt:~6,2%"
	set "TS_HH=%dt:~8,2%"
	set "TS_Min=%dt:~10,2%"
	set "TS_Sec=%dt:~12,2%"
	set "TS_Milisec=%dt:~15,3%"
	set "TS_PlusMinus=%dt:~21,1%"
	set /a "TZ_Mins=%dt:~22,3%"
	
	REM # Calc timezone offset
	set /a "TZ_Hours=%TZ_Mins%/60"
	set /a "TZ_Mins_Mod=%TZ_Mins%%%60"

	REM # Pad zeros
	IF %TZ_Hours% LSS 10 SET TZ_Hours=0%TZ_Hours%
	IF %TZ_Mins_Mod% LSS 10 SET TZ_Mins_Mod=0%TZ_Mins_Mod%

	REM # set this variable as the UTC timestamp
	set UTCtimestamp=%TS_YYYY%-%TS_MM%-%TS_DD%T%TS_HH%:%TS_Min%:%TS_Sec%.%TS_Milisec%%TS_PlusMinus%%TZ_Hours%:%TZ_Mins_Mod%
	
	Exit /B 0


	