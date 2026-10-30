@echo off
rem =====================================================================
rem  ZMK device cleanup - launcher
rem
rem    zmk_device_cleanup.bat               report only (no admin needed)
rem    zmk_device_cleanup.bat apply         remove stale USB/HID (UAC)
rem    zmk_device_cleanup.bat ble           report + Bluetooth LE keys
rem    zmk_device_cleanup.bat apply ble     remove both (UAC)
rem
rem    /nopause : do not wait for a key at the end
rem =====================================================================
setlocal EnableExtensions
title ZMK device cleanup

set "HERE=%~dp0"
if "%HERE:~-1%"=="\" set "HERE=%HERE:~0,-1%"
set "SCRIPT=%HERE%\zmk_device_cleanup.ps1"

if not exist "%SCRIPT%" (
    echo [ERROR] Script not found:
    echo         %SCRIPT%
    set "RC=1"
    goto finish
)

rem --- pick a PowerShell host (prefer PowerShell 7) ---
set "PSHOST=powershell.exe"
where pwsh.exe >nul 2>&1
if not errorlevel 1 set "PSHOST=pwsh.exe"

set "PARGS="
set "WANT_ADMIN="
set "NOPAUSE="

:parse
if "%~1"=="" goto parsed
if /i "%~1"=="apply" goto opt_apply
if /i "%~1"=="-apply" goto opt_apply
if /i "%~1"=="ble" goto opt_ble
if /i "%~1"=="-includeeble" goto opt_ble
if /i "%~1"=="/nopause" goto opt_nopause
if /i "%~1"=="help" goto usage
if /i "%~1"=="-h" goto usage
if /i "%~1"=="/?" goto usage
echo [ERROR] Unknown option: %~1
goto usage

:opt_apply
set "PARGS=%PARGS% -Apply"
set "WANT_ADMIN=1"
shift
goto parse

:opt_ble
set "PARGS=%PARGS% -IncludeBle"
shift
goto parse

:opt_nopause
set "NOPAUSE=1"
shift
goto parse

:parsed
if not defined WANT_ADMIN goto run
call :is_admin
if not errorlevel 1 goto run
goto elevate

:run
echo Host: %PSHOST%
echo.
%PSHOST% -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" %PARGS%
set "RC=%ERRORLEVEL%"
echo.
echo Exit code: %RC%
if not "%RC%"=="0" set "NOPAUSE="
goto finish

:elevate
echo This action needs administrator rights. Requesting elevation ...
%PSHOST% -NoProfile -ExecutionPolicy Bypass -Command ^
 "$p = Start-Process -FilePath '%~f0' -ArgumentList '%*' -Verb RunAs -PassThru -Wait -WorkingDirectory '%HERE%'; exit $p.ExitCode"
if errorlevel 1 (
    echo.
    echo [ERROR] Elevation was cancelled, or the cleanup reported an error.
    echo         Check the elevated window for details.
    set "RC=1"
    set "NOPAUSE=1"
    goto finish
)
set "RC=%ERRORLEVEL%"
set "NOPAUSE=1"
goto finish

rem ---------------------------------------------------------------------
:is_admin
net session >nul 2>&1
if not errorlevel 1 exit /b 0
fltmc >nul 2>&1
if not errorlevel 1 exit /b 0
exit /b 1

rem ---------------------------------------------------------------------
:usage
echo.
echo Usage: %~nx0 [apply] [ble] [/nopause]
echo.
echo   (no option)   report only, nothing is changed
echo   apply         remove Status=Unknown entries (asks for UAC)
echo   ble           also inspect Bluetooth LE registry keys
echo   /nopause      do not wait for a key press at the end
echo.
set "RC=1"
goto finish

:finish
if defined NOPAUSE goto end
echo.
pause
:end
endlocal & exit /b %RC%
