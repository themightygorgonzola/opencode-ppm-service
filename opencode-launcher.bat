@echo off
REM OpenCode Launcher for PPM — sets DeepSeek API key from CC settings then launches opencode
REM Usage: opencode-launcher [project-dir]

setlocal

REM Ensure user npm bin is on PATH (where opencode lives)
set "PATH=%APPDATA%\npm;%PATH%"

REM CRITICAL: Override ANTHROPIC_BASE_URL inherited from CC settings.
REM CC routes Anthropic calls through DeepSeek (api.deepseek.com/anthropic),
REM but @ai-sdk/anthropic reads ANTHROPIC_BASE_URL and would route OpenCode's
REM Anthropic provider to the wrong endpoint. Force it back to the real API.
REM ANTHROPIC_API_KEY is also cleared — OpenCode uses auth.json for API keys.
set "ANTHROPIC_BASE_URL=https://api.anthropic.com/v1"
set "ANTHROPIC_API_KEY="

REM Extract DEEPSEEK_API_KEY from Claude Code settings (same key CC uses)
for /f "tokens=*" %%i in ('powershell -NoProfile -Command "(Get-Content $env:USERPROFILE\.claude\settings.json | ConvertFrom-Json).env.ANTHROPIC_API_KEY"') do set "DEEPSEEK_API_KEY=%%i"

if "%DEEPSEEK_API_KEY%"=="" (
    echo [opencode-launcher] WARNING: Could not extract DEEPSEEK_API_KEY from ~/.claude/settings.json
    echo [opencode-launcher] Falling back to system env var...
) else (
    echo [opencode-launcher] DeepSeek API key loaded from CC settings
)

if not "%~1"==="" cd /d "%~1"
echo [opencode-launcher] Starting OpenCode in %cd%...
echo [opencode-launcher] Provider: DeepSeek (via Anthropic-compatible endpoint)
echo [opencode-launcher] MCP: ppm tools available (ppm_system, ppm_logs, etc.)

opencode %*

endlocal
