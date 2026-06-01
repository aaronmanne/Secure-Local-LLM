#Requires -Version 5.1
<#
.SYNOPSIS
    Windows LLM Security Audit Checklist
#>

$ErrorActionPreference = 'SilentlyContinue'
$ProhibitedPattern = 'deepseek|qwen|qwq|yi-\d|baichuan|chatglm|internlm|minimax|ernie|hunyuan|tigerbot|aquila|moss|belle|rugpt|saiga|fred-t5|falcon'
$Pass = 0; $Warn = 0; $Fail = 0

function chk_pass { param($t) Write-Host "[PASS] $t" -ForegroundColor Green;  $script:Pass++ }
function chk_warn { param($t) Write-Host "[WARN] $t" -ForegroundColor Yellow; $script:Warn++ }
function chk_fail { param($t) Write-Host "[FAIL] $t" -ForegroundColor Red;    $script:Fail++ }
function hdr      { param($t) Write-Host "`n=== $t ===" -ForegroundColor Cyan }

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

Write-Host @"
╔══════════════════════════════════════════════════════════╗
║        Windows LLM Security Audit Checklist             ║
╚══════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan
Write-Host "Date: $(Get-Date) | Host: $env:COMPUTERNAME | User: $env:USERNAME"
if (-not $isAdmin) { Write-Host "[NOTE] Not running as Administrator - some checks limited." -ForegroundColor Yellow }

# ─── Check 1: LLM Software ────────────────────────────────────────────────────
hdr "Check 1: LLM Software Detection"
$found = $false
foreach ($cmd in 'ollama','localai') {
    if (Get-Command $cmd 2>$null) { chk_warn "CLI installed: $cmd"; $found = $true }
}
Get-Process | Where-Object { $_.Name -match 'ollama|lmstudio|localai|gpt4all|jan' } |
    ForEach-Object { chk_warn "Running: $($_.Name)"; $found = $true }
@(
    "$env:LOCALAPPDATA\Programs\Ollama",
    "$env:LOCALAPPDATA\Programs\LM-Studio",
    "$env:LOCALAPPDATA\Jan"
) | Where-Object { Test-Path $_ } | ForEach-Object { chk_warn "App dir: $_"; $found = $true }
if (-not $found) { chk_pass "No LLM software detected." }

# ─── Check 2: Models ──────────────────────────────────────────────────────────
hdr "Check 2: Models Present"
$totalModels = 0
@(
    "$env:USERPROFILE\.ollama\models",
    "$env:USERPROFILE\.lmstudio\models",
    "$env:USERPROFILE\.cache\lm-studio\models",
    "$env:LOCALAPPDATA\nomic.ai\GPT4All",
    "$env:USERPROFILE\jan\models"
) | Where-Object { Test-Path $_ } | ForEach-Object {
    $cnt = (Get-ChildItem -Path $_ -Recurse -Include '*.gguf','*.bin','*.safetensors' -ErrorAction SilentlyContinue | Measure-Object).Count
    chk_warn "Model dir: $_ ($cnt files)"
    $totalModels += $cnt
}
if ($totalModels -eq 0) { chk_pass "No model files found in default locations." }

# ─── Check 3: Prohibited Models ───────────────────────────────────────────────
hdr "Check 3: Prohibited / Foreign-Origin Models"
$pCount = 0
Get-ChildItem -Path $env:USERPROFILE -Recurse -Include '*.gguf','*.bin','*.safetensors' -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match $ProhibitedPattern } |
    ForEach-Object { chk_fail "PROHIBITED: $($_.FullName)"; $pCount++ }
if (Get-Command ollama 2>$null) {
    ollama list 2>$null | Where-Object { $_ -match $ProhibitedPattern } |
        ForEach-Object { chk_fail "PROHIBITED OLLAMA MODEL: $_"; $pCount++ }
}
if ($pCount -eq 0) { chk_pass "No prohibited models detected." }

# ─── Check 4: Network Binding ─────────────────────────────────────────────────
hdr "Check 4: Network Binding"
foreach ($port in @(11434, 1234, 8080)) {
    $conns = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
    if ($conns) {
        foreach ($c in $conns) {
            if ($c.LocalAddress -in @('0.0.0.0','::')) {
                chk_fail "Port $port EXPOSED on all interfaces ($($c.LocalAddress))"
            } else {
                chk_warn "Port $port listening on $($c.LocalAddress) — verify localhost-only"
            }
        }
    } else { chk_pass "Port $port not listening." }
}

# ─── Check 5: OLLAMA_HOST ─────────────────────────────────────────────────────
hdr "Check 5: OLLAMA_HOST"
$oh = [System.Environment]::GetEnvironmentVariable('OLLAMA_HOST', 'User')
$ohm = [System.Environment]::GetEnvironmentVariable('OLLAMA_HOST', 'Machine')
if ($oh -and $oh -match '0\.0\.0\.0|^:') { chk_fail "OLLAMA_HOST (user)=$oh — NETWORK EXPOSED" }
elseif ($oh) { chk_warn "OLLAMA_HOST (user)=$oh — verify" }
else { chk_pass "OLLAMA_HOST not set in user scope (defaults to localhost)." }
if ($ohm -and $ohm -match '0\.0\.0\.0|^:') { chk_fail "OLLAMA_HOST (machine)=$ohm — NETWORK EXPOSED" }
elseif ($ohm) { chk_warn "OLLAMA_HOST (machine)=$ohm" }

# ─── Check 6: Firewall ────────────────────────────────────────────────────────
hdr "Check 6: Windows Firewall"
if ($isAdmin) {
    $fwProfiles = netsh advfirewall show allprofiles state 2>$null
    if ($fwProfiles -match 'State\s+ON') { chk_pass "Windows Firewall is ON for at least one profile." }
    else { chk_fail "Windows Firewall appears OFF." }

    foreach ($port in @(11434, 1234, 8080)) {
        $rule = Get-NetFirewallRule -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -match "LLM-Block-$port" }
        if ($rule) { chk_pass "Firewall block rule found for port $port." }
        else { chk_warn "No LLM hardening firewall rule for port $port." }
    }
} else {
    chk_warn "Firewall check requires Administrator."
}

# ─── Check 7: API Authentication ──────────────────────────────────────────────
hdr "Check 7: API Authentication"
foreach ($port in @(11434, 1234)) {
    $conn = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
    if ($conn) {
        try {
            $resp = Invoke-WebRequest -Uri "http://127.0.0.1:$port" -TimeoutSec 2 -ErrorAction Stop
            if ($resp.StatusCode -eq 200) {
                chk_warn "Port $port responds unauthenticated (HTTP 200) — FAIL if network-exposed."
            }
        } catch { chk_pass "Port $port did not return unauthenticated 200." }
    }
}

# ─── Check 8: MCP Configs ─────────────────────────────────────────────────────
hdr "Check 8: MCP Configurations"
$mcpFound = 0
@(
    "$env:APPDATA\Claude\claude_desktop_config.json",
    "$env:USERPROFILE\.cursor\mcp.json",
    "$env:USERPROFILE\.continue\config.json",
    "$env:APPDATA\Code\User\settings.json",
    "$env:APPDATA\Cursor\User\settings.json"
) | Where-Object { Test-Path $_ } | ForEach-Object {
    $content = Get-Content $_ -Raw 2>$null
    if ($content -match 'mcpServers') {
        chk_warn "MCP config: $_"; $mcpFound++
        if ($content -match '"url"') { chk_fail "REMOTE MCP server in: $_" }
        if ($content -match '"api_key"|"token"|"password"|"Authorization"') { chk_fail "Credentials in MCP config: $_" }
    }
}
Get-ChildItem -Path $env:USERPROFILE -Recurse -Filter 'mcp.json' -ErrorAction SilentlyContinue |
    ForEach-Object { chk_warn "mcp.json: $($_.FullName)"; $mcpFound++ }
if ($mcpFound -eq 0) { chk_pass "No MCP configurations found." }

# ─── Check 9: Auto-Start ──────────────────────────────────────────────────────
hdr "Check 9: Auto-Start Entries"
@('HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run','HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run') |
    ForEach-Object {
        Get-ItemProperty $_ 2>$null | ForEach-Object {
            $_.PSObject.Properties | Where-Object { $_.Value -match 'ollama|lmstudio|localai|gpt4all|jan' } |
                ForEach-Object { chk_warn "Startup entry: $($_.Name) = $($_.Value)" }
        }
    }
$svc = Get-Service 'ollama' -ErrorAction SilentlyContinue
if ($svc -and $svc.StartType -eq 'Automatic') { chk_warn "Ollama service set to Automatic start." }

# ─── SUMMARY ──────────────────────────────────────────────────────────────────
Write-Host "`n╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                  AUDIT SUMMARY                          ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host "  PASS: $Pass  " -ForegroundColor Green -NoNewline
Write-Host "WARN: $Warn  " -ForegroundColor Yellow -NoNewline
Write-Host "FAIL: $Fail" -ForegroundColor Red
Write-Host ""
if ($Fail -gt 0)          { Write-Host "ACTION REQUIRED: $Fail critical issue(s). Run harden.ps1 or escalate." -ForegroundColor Red }
elseif ($Warn -gt 0)      { Write-Host "REVIEW: $Warn warning(s) found." -ForegroundColor Yellow }
else                      { Write-Host "System appears compliant." -ForegroundColor Green }
Write-Host ""
