#Requires -Version 5.1
<#
.SYNOPSIS
    LLM Security Hardening Suite – Main Menu (Windows)
    Detects OS details and provides interactive menu to run audit/hardening scripts
.NOTES
    PREFERRED: Run via llm-hardening-menu.bat (handles signing + UAC automatically)
    DIRECT:    powershell.exe -ExecutionPolicy Bypass -File llm-hardening-menu.ps1
    POLICY:    Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
#>

# ─── Execution Policy Guard ───────────────────────────────────────────────────
# If this script was somehow launched directly and the policy blocks it, the
# error fires before we get here. But if we DO get here under a restrictive
# policy (AllSigned), warn the user and offer the correct launch method.
$currentPolicy = (Get-ExecutionPolicy -Scope CurrentUser)
if ($currentPolicy -eq 'AllSigned' -or $currentPolicy -eq 'Restricted') {
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "║  EXECUTION POLICY WARNING                                ║" -ForegroundColor Red
    Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Current policy: $currentPolicy" -ForegroundColor Yellow
    Write-Host "  This script is not digitally signed." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  RECOMMENDED: Run the .bat launcher instead —" -ForegroundColor Cyan
    Write-Host "    llm-hardening-menu.bat" -ForegroundColor White
    Write-Host ""
    Write-Host "  ALTERNATIVE: Run directly with bypass (this session only) —" -ForegroundColor Cyan
    Write-Host "    powershell.exe -ExecutionPolicy Bypass -File llm-hardening-menu.ps1" -ForegroundColor White
    Write-Host ""
    Write-Host "  PERMANENT FIX (current user only, does not require Admin) —" -ForegroundColor Cyan
    Write-Host "    Set-ExecutionPolicy RemoteSigned -Scope CurrentUser" -ForegroundColor White
    Write-Host ""
    $choice = Read-Host "  Attempt to continue anyway? [y/N]"
    if ($choice -notmatch '^[Yy]$') { exit 1 }
}

$ErrorActionPreference = 'SilentlyContinue'

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$PlatformDir = Join-Path $ScriptRoot 'windows'

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)

function Show-Banner {
    Clear-Host
    Write-Host @"
╔═══════════════════════════════════════════════════════════════╗
║          Local LLM Security Hardening Suite                  ║
║          Federal Contractor Security Guidance                 ║
╚═══════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

    Write-Host "  Platform: " -NoNewline; Write-Host "$([System.Environment]::OSVersion.VersionString)" -ForegroundColor White
    Write-Host "  Host:     " -NoNewline; Write-Host "$env:COMPUTERNAME" -ForegroundColor White
    Write-Host "  User:     " -NoNewline; Write-Host "$env:USERNAME" -ForegroundColor White
    Write-Host "  Date:     " -NoNewline; Write-Host "$(Get-Date)" -ForegroundColor White

    if ($isAdmin) {
        Write-Host "  Admin:    " -NoNewline; Write-Host "YES (full functionality available)" -ForegroundColor Green
    } else {
        Write-Host "  Admin:    " -NoNewline; Write-Host "NO (run as Administrator for firewall/service controls)" -ForegroundColor Yellow
    }
    Write-Host ""
}

function Invoke-PlatformScript {
    param([string]$ScriptName)
    $path = Join-Path $PlatformDir $ScriptName
    if (-not (Test-Path $path)) {
        Write-Host "[ERROR] Script not found: $path" -ForegroundColor Red
        Read-Host "Press Enter to continue"
        return
    }
    Write-Host "`n─── Running: $path ───" -ForegroundColor Cyan
    Write-Host ""
    try {
        # Use a child PowerShell process with ExecutionPolicy Bypass so
        # individual sub-scripts are never blocked by signing policy.
        $result = powershell.exe -NoProfile -ExecutionPolicy Bypass -File $path
        $result
    } catch {
        Write-Host "[ERROR] Script failed: $_" -ForegroundColor Red
    }
    Write-Host ""
    Read-Host "Press Enter to return to menu"
}

function Invoke-QuickScan {
    Write-Host "`n─── Quick Scan: Identify + Audit ───" -ForegroundColor Cyan
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PlatformDir 'identify.ps1')
    Write-Host "`n─── Running audit checklist... ───" -ForegroundColor Cyan
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PlatformDir 'audit.ps1')
    Read-Host "`nPress Enter to return to menu"
}

function Invoke-FullAudit {
    $evidenceDir = "$env:USERPROFILE\llm-audit-evidence-$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    New-Item -ItemType Directory -Path $evidenceDir -Force | Out-Null

    Write-Host "`n─── Full Audit & Evidence Collection ───" -ForegroundColor Cyan
    Write-Host "Evidence will be saved to: $evidenceDir"

    # Collect raw evidence
    @"
=== LLM Audit Evidence ===
Date: $(Get-Date)
Host: $env:COMPUTERNAME
User: $env:USERNAME

=== Ollama Models ===
$(try { ollama list 2>$null } catch { "Ollama not available" })

=== Model Files Found ===
$(Get-ChildItem -Path $env:USERPROFILE -Recurse -Include '*.gguf','*.safetensors' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)

=== Network Ports ===
$(netstat -an 2>$null | Select-String '11434|1234|8080')

=== OLLAMA_HOST ===
$([System.Environment]::GetEnvironmentVariable('OLLAMA_HOST', 'User'))
"@ | Out-File "$evidenceDir\evidence.txt" -Encoding UTF8

    # Run scripts via bypass process and capture output
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PlatformDir 'identify.ps1') | Out-File "$evidenceDir\identify.txt" -Encoding UTF8
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PlatformDir 'audit.ps1')    | Out-File "$evidenceDir\audit.txt"    -Encoding UTF8
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PlatformDir 'mcp-audit.ps1') | Out-File "$evidenceDir\mcp-audit.txt" -Encoding UTF8

    # Show audit results
    Get-Content "$evidenceDir\audit.txt" 2>$null

    Write-Host "`nEvidence bundle saved to: $evidenceDir" -ForegroundColor Green
    Get-ChildItem $evidenceDir | Format-Table Name,Length -AutoSize
    Read-Host "`nPress Enter to return to menu"
}

function Show-Readme {
    $readmePath = Join-Path $ScriptRoot 'README.md'
    if (Test-Path $readmePath) {
        if (Get-Command 'bat' 2>$null) {
            bat $readmePath
        } else {
            Get-Content $readmePath | Out-Host -Paging
        }
    } else {
        Write-Host "README.md not found at: $readmePath" -ForegroundColor Yellow
    }
    Read-Host "Press Enter to continue"
}

function Ensure-Scripts {
    if (-not (Test-Path $PlatformDir)) {
        Write-Host "[ERROR] Windows script directory not found: $PlatformDir" -ForegroundColor Red
        Write-Host "Ensure you are running from the repo root."
        exit 1
    }
    foreach ($s in @('identify.ps1','harden.ps1','audit.ps1','mcp-audit.ps1')) {
        if (-not (Test-Path (Join-Path $PlatformDir $s))) {
            Write-Host "[WARN] Missing script: $s" -ForegroundColor Yellow
        }
    }
}

# ─── Handle CLI Args ──────────────────────────────────────────────────────────
if ($args -contains '--identify') { & (Join-Path $PlatformDir 'identify.ps1'); exit }
if ($args -contains '--audit')    { & (Join-Path $PlatformDir 'audit.ps1');    exit }
if ($args -contains '--harden')   { & (Join-Path $PlatformDir 'harden.ps1');   exit }
if ($args -contains '--mcp')      { & (Join-Path $PlatformDir 'mcp-audit.ps1'); exit }
if ($args -contains '--help') {
    Write-Host "Usage: .\llm-hardening-menu.ps1 [--identify|--audit|--harden|--mcp|--help]"
    Write-Host "  Without arguments: launches interactive menu"
    exit
}

# ─── Main Menu Loop ───────────────────────────────────────────────────────────
Ensure-Scripts

while ($true) {
    Show-Banner
    Write-Host "  Main Menu" -ForegroundColor White
    Write-Host "  ─────────────────────────────────────────────"
    Write-Host "  1)  Identify LLM installations on this system"
    Write-Host "  2)  Run security audit checklist"
    Write-Host "  3)  Apply hardening controls"
    Write-Host "  4)  Run MCP (Model Context Protocol) audit"
    Write-Host "  5)  Quick scan (Identify + Audit)"
    Write-Host "  6)  Full audit + collect evidence bundle"
    Write-Host "  ─────────────────────────────────────────────"
    Write-Host "  7)  View README / documentation"
    Write-Host "  Q)  Quit"
    Write-Host ""

    $choice = Read-Host "  Select option"
    switch ($choice.ToUpper()) {
        '1' { Invoke-PlatformScript 'identify.ps1' }
        '2' { Invoke-PlatformScript 'audit.ps1' }
        '3' { Invoke-PlatformScript 'harden.ps1' }
        '4' { Invoke-PlatformScript 'mcp-audit.ps1' }
        '5' { Invoke-QuickScan }
        '6' { Invoke-FullAudit }
        '7' { Show-Readme }
        'Q' { Write-Host "`nGoodbye.`n" -ForegroundColor Green; exit 0 }
        default { Write-Host "Invalid option." -ForegroundColor Yellow; Start-Sleep 1 }
    }
}
