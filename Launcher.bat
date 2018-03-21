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

REM # call :Menu_Main
call :CheckLog_Blocking %StatusLogPath%

Exit /B 0


REM # ============================================================================
REM # ================================ Functions =================================
REM # ============================================================================

:Initialize
	REM # Configure Settings
	SET ScriptPath=%~dp0\Collector.bat
	SET StatusLogPath=%~dp0\Collected_Data\StatusLog.txt
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
	echo.
	echo ================== Main Menu ==================
	echo 1) Local Script Execution
	echo 2) Local Priviledge Check
	echo 3) Remote Script Execution
	echo 4) Remote Priviledge Check
	echo 9) Exit
	echo.
	set /p OptionSelected="Enter Option: "
	echo.

	
	REM # Switch statement essentially
	IF /I "%OptionSelected%" EQU "1" call :Menu_LocalScriptExe
	IF /I "%OptionSelected%" EQU "2" call :Menu_LocalPrivCheck
	IF /I "%OptionSelected%" EQU "3" call :Menu_RemoteScriptExe
	IF /I "%OptionSelected%" EQU "4" call :Menu_RemotePrivCheck
	IF /I "%OptionSelected%" EQU "9" Exit /B 0
	
	REM # Infinite Loop
	GOTO :Menu_Main
	
	
	

:Menu_LocalScriptExe
	echo.
	echo.
	echo ========= Local Script Execution =========
	echo Script Settings
	echo Relative Path: 
	echo Script Path: %ScriptPath%
	echo Output Path: 
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
		echo Change the configuration in Settings.ini then.
		set /p OptionSelected="Press ENTER to continue."
		EXIT /B 0
	)
	
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
	echo Launching Script...
	
	REM # Relative
	call "cmd /c start %ScriptPath% parm1test " 
	

	call :CheckLog_Blocking %StatusLogPath%
	
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
	
	
	
	