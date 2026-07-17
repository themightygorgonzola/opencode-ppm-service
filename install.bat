@echo off
setlocal enabledelayedexpansion
:: ============================================================
:: OpenCode PPM Service â€” Installer
:: Run ONCE as Administrator on a new machine.
:: Installs opencode web as a Windows service (NSSM) so it
:: survives reboots and power cycles.
::
:: After install: http://algonaoffice:6969 from any browser
:: ============================================================
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

set "ROOT=%~dp0"
set "ROOT=%ROOT:~0,-1%"
set "NSSM=%ROOT%\nssm.exe"
set "NODE=%ProgramFiles%\nodejs\node.exe"
set "SCRIPT=%ROOT%\server.js"
set "SVC=OpenCode-PPM"

echo.
echo ============================================================
echo   OpenCode PPM Service â€” Installing
echo ============================================================
echo.

:: Check Node.js
if not exist "%NODE%" (
    echo ERROR: Node.js not found at "%NODE%"
    echo Please install Node.js from https://nodejs.org then re-run.
    pause
    exit /b 1
)
echo [OK] Node.js found

:: Check nssm.exe
if not exist "%NSSM%" (
    echo ERROR: nssm.exe not found at "%NSSM%"
    pause
    exit /b 1
)
echo [OK] nssm.exe found

:: Remove existing service if present
sc query %SVC% >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo Removing existing %SVC% service...
    net stop %SVC% >nul 2>&1
    timeout /t 2 /nobreak >nul
    "%NSSM%" remove %SVC% confirm >nul 2>&1
)

:: Install service via NSSM
echo Installing Windows service...
"%NSSM%" install %SVC% "%NODE%" "%SCRIPT%"
if %ERRORLEVEL% neq 0 (
    echo ERROR: Service installation failed
    pause
    exit /b 1
)

:: Configure service
"%NSSM%" set %SVC% AppDirectory "%ROOT%"
"%NSSM%" set %SVC% DisplayName "OpenCode PPM Service"
"%NSSM%" set %SVC% Description "OpenCode web UI â€” AI coding agent accessible from any browser at :6969"
"%NSSM%" set %SVC% Start SERVICE_AUTO_START
"%NSSM%" set %SVC% AppExit Default Restart
"%NSSM%" set %SVC% AppRestartDelay 5000
"%NSSM%" set %SVC% AppThrottle 0

:: Log stdout/stderr (optional but useful)
"%NSSM%" set %SVC% AppStdout "%ROOT%\logs\service-out.log"
"%NSSM%" set %SVC% AppStderr "%ROOT%\logs\service-error.log"

:: Create logs directory
if not exist "%ROOT%\logs" mkdir "%ROOT%\logs"

:: Extract API key from opencode's auth.json (not hardcoded)
set "AUTH_FILE=%USERPROFILE%\.local\share\opencode\auth.json"
set "DK_KEY="
if exist "%AUTH_FILE%" (
    for /f "usebackq delims=" %%a in (`powershell -NoProfile -Command "(Get-Content '%AUTH_FILE%' | ConvertFrom-Json).deepseek.key"`) do set "DK_KEY=%%a"
)
if "!DK_KEY!"=="" (
    echo WARNING: Could not read DeepSeek key from %AUTH_FILE%
    echo The service will start but you may need to configure API keys in opencode's TUI.
    echo.
)

:: Set environment variables for Anthropicâ†’DeepSeek routing
:: auth.json gives native DeepSeek; these env vars make the Anthropic provider route to DeepSeek too
:: Common env vars (always set)
set "ENV_COMMON=HOME=%USERPROFILE% USERPROFILE=%USERPROFILE% OPENCODE_USER=%USERNAME% NODE_ENV=production ANTHROPIC_BASE_URL=https://api.deepseek.com/anthropic ANTHROPIC_MODEL=deepseek-v4-pro ANTHROPIC_DEFAULT_OPUS_MODEL=deepseek-v4-pro ANTHROPIC_DEFAULT_SONNET_MODEL=deepseek-v4-flash ANTHROPIC_DEFAULT_HAIKU_MODEL=deepseek-v4-flash"

if not "!DK_KEY!"=="" (
    "%NSSM%" set %SVC% AppEnvironmentExtra %ENV_COMMON% "ANTHROPIC_API_KEY=!DK_KEY!" "ANTHROPIC_AUTH_TOKEN=!DK_KEY!"
) else (
    "%NSSM%" set %SVC% AppEnvironmentExtra %ENV_COMMON%
)

:: Grant non-admin users permission to check service status
sc sdset %SVC% "D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWRPWPDTLOCRRC;;;AU)" >nul
echo [OK] Service installed (auto-start on boot, restarts on crash)

:: Create Desktop shortcut
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$s=(New-Object -COM WScript.Shell).CreateShortcut([Environment]::GetFolderPath('Desktop')+'\OpenCode Control.lnk');$s.TargetPath='%ROOT%\OpenCode-Control.bat';$s.WorkingDirectory='%ROOT%';$s.Description='OpenCode PPM Service Control Panel';$s.Save()"
echo [OK] Desktop shortcut created

:: Start the service
echo.
echo Starting service...
sc start %SVC% >nul 2>&1
timeout /t 3 /nobreak >nul

:: Verify it started
sc query %SVC% | findstr "RUNNING" >nul
if %ERRORLEVEL% EQU 0 (
    echo [OK] Service started and running
) else (
    echo NOTE: Service may still be starting â€” check status in a moment
)

echo.
echo ============================================================
echo   Installation complete!
echo.
echo   Service:   OpenCode-PPM (auto-starts on boot)
echo   Web UI:    http://algonaoffice:6969
echo   Control:   Double-click "OpenCode Control" on Desktop
echo ============================================================
echo.
pause
