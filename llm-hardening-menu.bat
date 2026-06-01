@echo off
:: =============================================================================
:: LLM Security Hardening Suite — Windows Launcher
:: Bypasses script signing requirement and optionally elevates to Administrator.
:: Double-click this file or run from Command Prompt / PowerShell.
:: =============================================================================

setlocal EnableDelayedExpansion

:: ─── Check if already elevated ───────────────────────────────────────────────
net session >nul 2>&1
if %errorlevel% == 0 goto :RunScript

:: ─── Not elevated — offer to re-launch as Administrator ───────────────────────
echo.
echo  ============================================================
echo   LLM Security Hardening Suite
echo  ============================================================
echo.
echo  Some hardening steps (firewall rules, service management)
echo  require Administrator privileges.
echo.
echo  [1] Run as Administrator (recommended for full hardening)
echo  [2] Run as current user  (audit/identify only)
echo  [Q] Quit
echo.
set /p CHOICE=" Select: "

if /i "%CHOICE%"=="1" goto :Elevate
if /i "%CHOICE%"=="2" goto :RunScript
if /i "%CHOICE%"=="q" goto :End
if /i "%CHOICE%"=="Q" goto :End
goto :RunScript

:Elevate
:: Re-launch this .bat as Administrator via PowerShell UAC prompt
powershell -NoProfile -Command ^
  "Start-Process cmd -ArgumentList '/c \"%~f0\"' -Verb RunAs"
goto :End

:RunScript
:: ─── Launch the menu with ExecutionPolicy Bypass ─────────────────────────────
echo.
echo  Starting LLM Hardening Suite...
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass ^
  -File "%~dp0llm-hardening-menu.ps1" %*

if %errorlevel% neq 0 (
    echo.
    echo  [ERROR] PowerShell exited with code %errorlevel%.
    echo  If you see a signing error, ensure you ran this .bat file
    echo  rather than the .ps1 directly.
    echo.
    pause
)

:End
endlocal
