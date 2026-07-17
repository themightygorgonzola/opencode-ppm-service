@echo off
chcp 65001 >nul 2>&1
setlocal enabledelayedexpansion

:: ============================================================
::   OpenCode PPM Service  â€”  Control Panel
::   Double-click to manage the opencode web service.
::   Requires admin rights â€” will show a UAC prompt once.
:: ============================================================

net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

set "ROOT=%~dp0"
set "ROOT=%ROOT:~0,-1%"
set "SVC=OpenCode-PPM"

:: Disable Quick Edit Mode (prevents accidental pause from clicking)
powershell -NoProfile -ExecutionPolicy Bypass -Command "$t=Add-Type -PassThru -Name K32QE -MemberDefinition '[DllImport(\"kernel32.dll\")]public static extern IntPtr GetStdHandle(int n);[DllImport(\"kernel32.dll\")]public static extern bool GetConsoleMode(IntPtr h,out uint m);[DllImport(\"kernel32.dll\")]public static extern bool SetConsoleMode(IntPtr h,uint m);';$h=$t::GetStdHandle(-10);[uint32]$m=0;$t::GetConsoleMode($h,[ref]$m);$t::SetConsoleMode($h,($m-band(-bnot 0x40)))" >nul 2>&1

:: â”€â”€â”€ MAIN MENU â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
:MENU
cls
echo.
echo  ============================================================
echo    OpenCode PPM Service  ^|  Control Panel
echo  ============================================================
echo.

:: -- Service state --
set "SVC_STATE=UNKNOWN"
for /f "tokens=4" %%s in ('sc query %SVC% 2^>nul ^| findstr "STATE"') do set "SVC_STATE=%%s"

if "!SVC_STATE!"=="RUNNING"       set "SVC_LINE=  [RUNNING]   OpenCode is live at http://algonaoffice:6969"
if "!SVC_STATE!"=="STOPPED"       set "SVC_LINE=  [STOPPED]   Service installed but not running"
if "!SVC_STATE!"=="PAUSED"        set "SVC_LINE=  [PAUSED]    ** Crashed â€” choose Restart **"
if "!SVC_STATE!"=="START_PENDING" set "SVC_LINE=  [STARTING]  Service is starting up..."
if "!SVC_STATE!"=="STOP_PENDING"  set "SVC_LINE=  [STOPPING]  Service is shutting down..."
if "!SVC_STATE!"=="UNKNOWN"       set "SVC_LINE=  [NOT INSTALLED]  Run install.bat first"

echo    Service:    !SVC_LINE!
echo.
echo  ------------------------------------------------------------
echo.
echo    SERVICE
echo      [1]  Start service
echo      [2]  Stop service
echo      [3]  Restart service
echo.
echo    ACCESS
echo      [4]  Open in browser        (http://algonaoffice:6969)
echo      [5]  Open localhost         (http://localhost:6969)
echo.
echo    DIAGNOSTICS
echo      [6]  View recent logs       (last 30 lines)
echo      [L]  Tail logs live         (Ctrl+C to stop)
echo.
echo    SYSTEM
echo      [I]  Re-run installer       (repair service registration)
echo      [0]  Exit
echo.
echo  ------------------------------------------------------------
echo.
set "CHOICE="
set /p "CHOICE=    Enter choice: " <con

if "!CHOICE!"=="1" goto DO_START
if "!CHOICE!"=="2" goto DO_STOP
if "!CHOICE!"=="3" goto DO_RESTART
if "!CHOICE!"=="4" goto DO_OPEN_WEB
if "!CHOICE!"=="5" goto DO_OPEN_LOCAL
if "!CHOICE!"=="6" goto DO_LOGS
if /i "!CHOICE!"=="L" goto DO_TAIL
if /i "!CHOICE!"=="I" goto DO_INSTALL
if "!CHOICE!"=="0" exit /b
goto MENU


:: â”€â”€â”€ [1] Start â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
:DO_START
echo.
echo   Starting %SVC%...
sc start %SVC% >nul 2>&1
call :WAIT_FOR RUNNING 15
if !ERRORLEVEL! EQU 0 (
    echo   Service started. Open: http://algonaoffice:6969
) else (
    echo   WARNING: Service may not have started cleanly.
    echo   Check logs with option [6].
)
echo   Press any key to return to menu.
pause >nul <con
goto MENU


:: â”€â”€â”€ [2] Stop â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
:DO_STOP
echo.
echo   Stopping %SVC%...
sc stop %SVC% >nul 2>&1
call :WAIT_FOR STOPPED 15
if !ERRORLEVEL! EQU 0 (
    echo   Service stopped.
) else (
    echo   WARNING: Service may still be stopping.
)
echo   Press any key to return to menu.
pause >nul <con
goto MENU


:: â”€â”€â”€ [3] Restart â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
:DO_RESTART
echo.
echo   Stopping %SVC%...
sc stop %SVC% >nul 2>&1
call :WAIT_FOR STOPPED 20
timeout /t 2 /nobreak >nul
echo   Starting %SVC%...
sc start %SVC% >nul 2>&1
call :WAIT_FOR RUNNING 15
if !ERRORLEVEL! EQU 0 (
    echo   Service restarted. Open: http://algonaoffice:6969
) else (
    echo   WARNING: Service may still be starting.
)
echo   Press any key to return to menu.
pause >nul <con
goto MENU


:: â”€â”€â”€ [4] Open in browser (algonaoffice) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
:DO_OPEN_WEB
start "" http://algonaoffice:6969
goto MENU


:: â”€â”€â”€ [5] Open localhost â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
:DO_OPEN_LOCAL
start "" http://localhost:6969
goto MENU


:: â”€â”€â”€ [6] View recent logs â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
:DO_LOGS
echo.
echo   Last 30 lines of service output:
echo  ------------------------------------------------------------
if exist "%ROOT%\logs\service-out.log" (
    powershell -NoProfile -Command "Get-Content '%ROOT%\logs\service-out.log' -Tail 30"
) else (
    echo   (no service-out.log yet â€” service may not have started)
)
echo  ------------------------------------------------------------
if exist "%ROOT%\logs\service-error.log" (
    for %%A in ("%ROOT%\logs\service-error.log") do (
        if %%~zA GTR 0 (
            echo.
            echo   Stderr (last 10 lines):
            echo  ------------------------------------------------------------
            powershell -NoProfile -Command "Get-Content '%ROOT%\logs\service-error.log' -Tail 10"
            echo  ------------------------------------------------------------
        )
    )
)
echo   Press any key to return to menu.
pause >nul <con
goto MENU


:: â”€â”€â”€ [L] Tail logs live â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
:DO_TAIL
echo.
echo   Tailing logs (Ctrl+C to stop)...
echo  ============================================================
if exist "%ROOT%\logs\service-out.log" (
    powershell -NoProfile -Command "Get-Content '%ROOT%\logs\service-out.log' -Wait -Tail 10"
) else (
    echo   No log file yet. Starting tail â€” waiting for output...
    powershell -NoProfile -Command "while (-not (Test-Path '%ROOT%\logs\service-out.log')) { Start-Sleep 1 }; Get-Content '%ROOT%\logs\service-out.log' -Wait"
)
goto MENU


:: â”€â”€â”€ [I] Re-run installer â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
:DO_INSTALL
echo.
echo   Launching install.bat...
start "" /wait "%ROOT%\install.bat"
goto MENU


:: â”€â”€â”€ Subroutine: wait up to N seconds for service to reach a state
:: Usage:  call :WAIT_FOR  TARGET_STATE  MAX_SECONDS
:WAIT_FOR
set "_wf_target=%~1"
set /a "_wf_max=%~2"
set /a "_wf_i=0"
:_WF_LOOP
for /f "tokens=4" %%s in ('sc query %SVC% 2^>nul ^| findstr "STATE"') do set "_wf_cur=%%s"
if "!_wf_cur!"=="!_wf_target!" exit /b 0
if !_wf_i! geq !_wf_max! (
    echo   [timeout] State is !_wf_cur!, expected !_wf_target! after !_wf_max!s
    exit /b 1
)
<nul set /p "=."
timeout /t 1 /nobreak >nul
set /a _wf_i+=1
goto _WF_LOOP
