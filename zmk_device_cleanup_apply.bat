@echo off
rem =====================================================================
rem  ZMK device cleanup - APPLY
rem
rem  Double-click this file to actually remove the ghost entries.
rem  Flow: show report  ->  ask Y/N  ->  run with admin rights (UAC).
rem
rem  Target: VID_1D50 (all ZMK-family PIDs incl. 6160).
rem  Removes: Status=Unknown (ghost) + Status=Error (Code 10) entries.
rem  Connected (OK) devices are always skipped.
rem
rem  Right-click "Run as administrator" works too (skips the UAC step).
rem  "/nopause" : do not wait for a key press at the end.
rem =====================================================================
setlocal EnableExtensions
title ZMK cleanup - APPLY

set "HERE=%~dp0"
if "%HERE:~-1%"=="\" set "HERE=%HERE:~0,-1%"
set "PS1=%HERE%\zmk_device_cleanup.ps1"

set "NOPAUSE="
for %%A in (%*) do if /i "%%~A"=="/nopause" set "NOPAUSE=1"
set "CONFIRMED="
if /i "%~1"=="confirmed" set "CONFIRMED=1"

if not exist "%PS1%" goto missing

set "PSHOST=powershell.exe"
where pwsh.exe >nul 2>&1
if not errorlevel 1 set "PSHOST=pwsh.exe"

if defined CONFIRMED goto do_apply

echo ============================================================
echo  ZMK ghost device cleanup - APPLY
echo ============================================================
echo.
echo  * Unplug the keyboard from USB before continuing.
echo  * Only entries with Status "Unknown" (ghosts) are removed.
echo.
"%PSHOST%" -NoProfile -ExecutionPolicy Bypass -File "%PS1%"
echo.
echo ------------------------------------------------------------
choice /c YN /n /m "Remove the ghost entries above? [Y=yes / N=no] "
if errorlevel 2 goto cancel
if errorlevel 1 goto confirmed_yes
goto cancel

:confirmed_yes
echo.
call :is_admin
if not errorlevel 1 goto do_apply

echo Requesting administrator rights (UAC) ...
%PSHOST% -NoProfile -ExecutionPolicy Bypass -Command ^
 "$p = Start-Process -FilePath '%~f0' -ArgumentList 'confirmed' -Verb RunAs -PassThru -Wait -WorkingDirectory '%HERE%'; exit $p.ExitCode"
if errorlevel 1 goto elev_failed
echo.
echo Elevated session finished.
goto finish_ok

:do_apply
echo Running cleanup with administrator rights ...
echo.
"%PSHOST%" -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -Apply
set "RC=%ERRORLEVEL%"
echo.
echo ------------------------------------------------------------
if "%RC%"=="0" (
    echo Result: OK
    echo Plugging the keyboard back in creates a clean entry again.
) else (
    echo Result: exit code %RC%. Check the messages above.
)
echo A reboot is normally not required.
goto finish

:elev_failed
echo.
echo [ERROR] Elevation was cancelled, or the elevated run reported an error.
echo         Nothing was changed by this window.
set "RC=1"
goto finish

:cancel
echo.
echo Cancelled. Nothing was changed.
set "RC=0"
goto finish

:missing
echo [ERROR] zmk_device_cleanup.ps1 not found next to this file.
echo         Keep the .ps1 and .bat files in the same folder.
set "RC=1"
goto finish

:finish
echo.
if defined NOPAUSE goto end
pause
:end
endlocal & exit /b %RC%

:finish_ok
echo.
if defined NOPAUSE goto end_ok
pause
:end_ok
endlocal & exit /b 0

rem ---------------------------------------------------------------------
:is_admin
net session >nul 2>&1
if not errorlevel 1 exit /b 0
fltmc >nul 2>&1
if not errorlevel 1 exit /b 0
exit /b 1
