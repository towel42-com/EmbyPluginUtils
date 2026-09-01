@echo off
setlocal enabledelayedexpansion

:: Initialize option flags to false
set "DEBUG_MODE=false"
set "BUILD_MODE=false"
set "LAUNCH_ARG="
set "TARGET_PATH="
set "EMBY_SERVER=EmbyServer.exe"
if defined EMBY_ROOT (
    set "EMBY_ROOT_DIR=%EMBY_ROOT%"
) else (
    set "EMBY_ROOT_DIR=%APPDATA%\\Roaming\\Emby-Server"
)

set "SCRIPT_DIR=%~dp0"


goto :parse_args
:usage
echo ==============================
echo Usage: %~nx0 -TargetPath ^<plugin_path^> -EmbyRoot ^<path^> ^<-Debug^|-Build^> 
echo     -TargetPath ^<plugin_path^> - Location of the plugin path to be copied
echo     -EmbyRoot ^<path^> - Location of the Emby Server, overrides the EMBY_ROOT environment variable
echo          Either -EmbyRoot or the environment variable EMBY_ROOT must be set and exist
echo          Set this to the install directory. Often '%APPDATA%\\Roaming\\Emby-Server'
echo          Default: '%APPDATA%\\Roaming\\Emby-Server'
if  defined EMBY_ROOT (
echo          EMBY_ROOT='%EMBY_ROOT%'
)
echo          The %EMBY_SERVER% must exists at %%EMBY_ROOT%%\\system\\%EMBY_SERVER%
echo     -Build - Simply copies the plugin into the correct location %%EMBY_ROOT%%\\programdata\\plugins\\.
echo     -Debug - Copies the plugin, kills any running EmbyServer and EmbyTray processes, and relaunches the EmbyServer
echo         Default -Debug
pause
goto :eof


:: Loop through all command line arguments
:parse_args
:: echo CurrArg='%~1'
:: echo CurrParam='%~2'

if "%~1"=="" goto :validate_args

if /i "%~1"=="-Debug" (
    set "DEBUG_MODE=true"
    shift
    goto :parse_args
)

if /i "%~1"=="-Build" (
    set "BUILD_MODE=true"
    shift
    goto :parse_args
)

if /i "%~1"=="-TargetPath" (
    set "TARGET_PATH=%~2"
    shift
    shift
    goto :parse_args
)

if /i "%~1"=="-EmbyRoot" (
    set "EMBY_ROOT_DIR=%~2"
    shift
    shift
    goto :parse_args
)

:: Handle unexpected arguments
echo [ERROR] Unknown parameter: %~1
call :usage
exit /b 1


:validate_args
:: echo "Finished parsing args"

:: Validate that the required TargetPath parameter is present
:: echo "Validating TargetPath"
if "%TARGET_PATH%"=="" (
    echo [ERROR] Missing required parameter: -TargetPath
    call :usage
    exit /b 2
)

:: echo "TargetPath Set"
if not exist "%TARGET_PATH%" (
    echo [ERROR] TargetPath '%TARGET_PATH% does not exist
    call :usage
    exit /b 3
)

:: echo "validating EMBY_ROOT_DIR exists"
::echo EMBY_ROOT_DIR=%EMBY_ROOT_DIR%

if not exist "%EMBY_ROOT_DIR%\." (
    echo "[ERROR] The Emby Root directory '%EMBY_ROOT_DIR%\.' could not be found."
    call :usage
    exit /b 4
)

:: echo "Validating EMBY_ROOT_DIR\programdata\plugins exists"
if not exist "%EMBY_ROOT_DIR%\programdata\plugins\." (
    echo "[ERROR] The Emby Server plugin directory '%EMBY_ROOT_DIR%\programdata\plugins\.' could not be found."
    call :usage
    exit /b 5
)

:: echo "Validating EMBY_ROOT_DIR\system exists"
if not exist "%EMBY_ROOT_DIR%\system\." (
    echo "[ERROR] The Emby Server system directory %EMBY_ROOT_DIR%\system\.could not be found."
    call :usage
    exit /b 6
)

:: echo "Validating EMBY_ROOT_DIR\system\%EMBY_SERVER% exists"
if not exist "%EMBY_ROOT_DIR%\system\%EMBY_SERVER%" (
    echo "[ERROR] The Emby Server executable could not be found."
    call :usage
    exit /b 7
)

:: Check that both options are not set simultaneously
if "%DEBUG_MODE%"=="true" if "%BUILD_MODE%"=="true" (
    echo [ERROR] Cannot set both -Debug and -Build at the same time.
    call :usage
    exit /b 8
)

if "%DEBUG_MODE%"=="false" if "%BUILD_MODE%"=="false" (
    set "DEBUG_MODE=true"
)

:: kill current processes

:kill_processes
tasklist /NH /FI "imagename eq %EMBY_SERVER%" 2>nul | find /i "%EMBY_SERVER%" >nul

if %errorlevel% equ 0 (
    if /I not "%BUILD_MODE%"=="true" (
        echo Killing existing EmbyServer processes
        taskkill /T /f /im "%EMBY_SERVER%"
    )
)

:copy_plugin
:: copy the dll
for %%A in ("%TARGET_PATH%") do (
    set "FULLNAME=%%~nxA"
)

set CLEAN_EMBY_ROOT=%EMBY_ROOT_DIR:"=%
set CLEAN_EMBY_ROOT=%CLEAN_EMBY_ROOT:\\=\%

echo Copying '%FULLNAME%' to '%CLEAN_EMBY_ROOT%\programdata\plugins'
copy /y "%TARGET_PATH%" "%EMBY_ROOT_DIR%\programdata\plugins"

:launch_emby
:: launch emby Server
if /I not "%DEBUG_MODE%"=="false" (
    echo Launching %EMBY_ROOT_DIR%\system\%EMBY_SERVER%
    for /f %%A in ('%LOCALAPPDATA%\Microsoft\WindowsApps\pwsh -WorkingDirectory "%EMBY_ROOT_DIR%\system" -Command "(Start-Process "%EMBY_ROOT_DIR%\system\%EMBY_SERVER%" -PassThru).Id"') do echo "Emby Process ID: %%A"
    call timeout /t 5
)

endlocal
