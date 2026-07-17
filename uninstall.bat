@echo off
:: ============================================================
:: OpenCode PPM Service â€” Uninstaller
:: Run as Administrator to remove the Windows service.
:: Does NOT delete project files, config, or session history.
:: ============================================================
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

set "ROOT=%~dp0"
set "ROOT=%ROOT:~0,-1%"
set "NSSM=%ROOT%\nssm.exe"
set "SVC=OpenCode-PPM"

echo.
echo ============================================================
echo   OpenCode PPM Service â€” Uninstalling
echo ============================================================
echo.

:: Stop service
echo Stopping service...
net stop %SVC% >nul 2>&1
timeout /t 2 /nobreak >nul

:: Remove service
echo Removing Windows service...
"%NSSM%" remove %SVC% confirm
if %ERRORLEVEL% EQU 0 (
    echo [OK] Service removed
) else (
    echo [--] Service was not installed or already removed
)

:: Remove desktop shortcut
del "%USERPROFILE%\Desktop\OpenCode Control.lnk" >nul 2>&1
echo [OK] Desktop shortcut removed

echo.
echo ============================================================
echo   Uninstall complete.
echo.
echo   What's preserved:
echo     â€¢ %ROOT%
echo     â€¢ opencode config (~/.config/opencode/)
echo     â€¢ Session history (~/.local/share/opencode/)
echo     â€¢ API keys (~/.local/share/opencode/auth.json)
echo.
echo   To fully wipe: delete this folder + ~/.config/opencode/
echo                  + ~/.local/share/opencode/ + ~/.cache/opencode/
echo ============================================================
echo.
pause
