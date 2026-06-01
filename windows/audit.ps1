#Requires -Version 5.1
<#
.SYNOPSIS
    Windows LLM & Agent Security Audit Checklist
    Regulatory basis: NIST SP 800-53; NIST AI 600-1; CMMC 2.0;
                      DFARS 252.204-7012; EO 14110; FBI-DEEPSEEK
#>

# --- Execution Policy Guard ---------------------------------------------------
# Run via llm-hardening-menu.bat, or:
#   powershell.exe -ExecutionPolicy Bypass -File <this-script>
if ($MyInvocation.ScriptName -ne '' -and
    (Get-ExecutionPolicy -Scope CurrentUser) -in @('AllSigned','Restricted')) {
    Write-Host ""
    Write-Host "[WARN] Script is not digitally signed." -ForegroundColor Yellow
    Write-Host "  Use llm-hardening-menu.bat to launch, or run:" -ForegroundColor Yellow
    Write-Host "  powershell.exe -ExecutionPolicy Bypass -File `"$($MyInvocation.ScriptName)`"" -ForegroundColor Cyan
    Write-Host ""
}


$ErrorActionPreference = 'SilentlyContinue'
$ScriptRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

. (Join-Path $ScriptRoot 'common\patterns.ps1')
. (Join-Path $ScriptRoot 'common\references.ps1')

$Pass = 0; $Warn = 0; $Fail = 0

function chk_pass   { param($t) Write-Host "[PASS]   $t" -ForegroundColor Green;   $script:Pass++ }
function chk_warn   { param($t) Write-Host "[WARN]   $t" -ForegroundColor Yellow;  $script:Warn++ }
function chk_fail   { param($t) Write-Host "[FAIL]   $t" -ForegroundColor Red;     $script:Fail++ }
function chk_review { param($t) Write-Host "[REVIEW] $t" -ForegroundColor Magenta; $script:Warn++ }
function hdr        { param($t) Write-Host "`n=== $t ===" -ForegroundColor Cyan }

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "     Windows LLM & Agent Security Audit Checklist        " -ForegroundColor Cyan
Write-Host "  Ref: NIST SP 800-53 . NIST AI 600-1 . CMMC 2.0          " -ForegroundColor Cyan
Write-Host "       DFARS 252.204-7012 . EO 14110 . FBI-DEEPSEEK      " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Date: $(Get-Date) | Host: $env:COMPUTERNAME | User: $env:USERNAME"
if (-not $isAdmin) { Write-Host "[NOTE] Not running as Administrator - some checks limited." -ForegroundColor Yellow }

# --- Check 1: Inference Servers -----------------------------------------------
hdr "Check 1: Inference Server Software  [NIST SP 800-53 CM-7]"
$F = 0
Get-Process | Where-Object { $_.Name -match $LLM_ProcessPattern } |
    ForEach-Object { chk_warn "Running: $($_.Name)"; $F++ }
foreach ($cmd in $LLM_CLITools) { if (Get-Command $cmd 2>$null) { chk_warn "CLI: $cmd"; $F++ } }
@("$env:LOCALAPPDATA\Programs\Ollama","$env:LOCALAPPDATA\Programs\LM-Studio","$env:LOCALAPPDATA\Jan","$env:LOCALAPPDATA\Programs\Msty") |
    Where-Object { Test-Path $_ } | ForEach-Object { chk_warn "App dir: $_"; $F++ }
if ($F -eq 0) { chk_pass "No inference server software detected." }

# --- Check 2: AI Agents -------------------------------------------------------
hdr "Check 2: AI Agent Frameworks  [NIST AI 600-1 $2.6; NIST SP 800-53 SA-4]"
$F = 0
Get-Process | Where-Object { $_.Name -match $Agent_ProcessPattern } |
    ForEach-Object { chk_warn "Agent process: $($_.Name)"; $F++ }
foreach ($cmd in $Agent_CLITools) { if (Get-Command $cmd 2>$null) { chk_warn "Agent CLI: $cmd"; $F++ } }
@("$env:USERPROFILE\.autogpt","$env:USERPROFILE\AutoGPT","$env:USERPROFILE\.crewai",
  "$env:USERPROFILE\.autogen","$env:USERPROFILE\.opendevin","$env:USERPROFILE\.openhands",
  "$env:USERPROFILE\.goose","$env:USERPROFILE\.plandex","$env:USERPROFILE\.aider",
  "$env:USERPROFILE\flowise","$env:USERPROFILE\.n8n","$env:USERPROFILE\.memgpt",
  "$env:USERPROFILE\dify","$env:USERPROFILE\anythingllm") |
    Where-Object { Test-Path $_ } | ForEach-Object { chk_warn "Agent config: $_"; $F++ }
if ($F -eq 0) { chk_pass "No AI agent frameworks detected." }

# --- Check 3: Vector Databases ------------------------------------------------
hdr "Check 3: Vector Databases  [NIST SP 800-53 SC-28]"
$F = 0
Get-Process | Where-Object { $_.Name -match $VectorDBPattern } |
    ForEach-Object { chk_warn "Vector DB: $($_.Name)"; $F++ }
if ($F -eq 0) { chk_pass "No vector database processes detected." }

# --- Check 4: Models Present --------------------------------------------------
hdr "Check 4: Model Files Present  [NIST AI 600-1 $2.5]"
$totalModels = 0
foreach ($dir in $ModelDirs) {
    if (Test-Path $dir) {
        $cnt = (Get-ChildItem -Path $dir -Recurse -Include $ModelExtensions -ErrorAction SilentlyContinue | Measure-Object).Count
        chk_warn "Model dir: $dir ($cnt files)"; $totalModels += $cnt
    }
}
if ($totalModels -eq 0) { chk_pass "No model files in default locations." }

# --- Check 5: Prohibited Models -----------------------------------------------
hdr "Check 5: Prohibited Models  [FBI-DEEPSEEK; HOUSE-DEEPSEEK; NIST AI 600-1 $2.5]"
$pCount = 0
Get-ChildItem -Path $env:USERPROFILE -Recurse -Include $ModelExtensions -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match $ProhibitedPattern } |
    ForEach-Object { chk_fail "PROHIBITED: $($_.FullName)  [FBI-DEEPSEEK]"; $pCount++ }
if (Get-Command ollama 2>$null) {
    ollama list 2>$null | Where-Object { $_ -match $ProhibitedPattern } |
        ForEach-Object { chk_fail "PROHIBITED OLLAMA MODEL: $_"; $pCount++ }
}
if ($pCount -eq 0) { chk_pass "No prohibited models detected." }

# --- Check 6: Review-Warranted Models ----------------------------------------
hdr "Check 6: Models Requiring Provenance Review  [NIST AI 600-1 $2.5]"
$rCount = 0
Get-ChildItem -Path $env:USERPROFILE -Recurse -Include $ModelExtensions -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match $ReviewPattern } |
    ForEach-Object { chk_review "Verify origin: $($_.FullName)"; $rCount++ }
if ($rCount -eq 0) { chk_pass "No review-warranted models detected." }

# --- Check 7: Network Binding -------------------------------------------------
hdr "Check 7: Network Port Binding  [NIST SP 800-53 SC-7: Boundary Protection]"
foreach ($portEntry in $LLM_Ports.GetEnumerator()) {
    $port = $portEntry.Key; $tool = $portEntry.Value
    $conns = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
    if ($conns) {
        foreach ($c in $conns) {
            if ($c.LocalAddress -in @('0.0.0.0','::')) {
                chk_fail "Port $port ($tool) EXPOSED  [NIST SP 800-53 SC-7]"
            } else {
                chk_warn "Port $port ($tool) listening on $($c.LocalAddress) — verify localhost-only"
            }
        }
    } else { chk_pass "Port $port ($tool) not listening." }
}

# ─── Check 8: OLLAMA_HOST ─────────────────────────────────────────────────────
hdr "Check 8: OLLAMA_HOST  [NIST SP 800-53 SC-7, IA-3]"
$oh = [System.Environment]::GetEnvironmentVariable('OLLAMA_HOST','User')
$ohm = [System.Environment]::GetEnvironmentVariable('OLLAMA_HOST','Machine')
if ($oh -and $oh -match '0\.0\.0\.0|^:') { chk_fail "OLLAMA_HOST(user)=$oh EXPOSED  [NIST SC-7]" }
elseif ($oh) { chk_warn "OLLAMA_HOST(user)=$oh — verify" }
else { chk_pass "OLLAMA_HOST not set in user scope." }
if ($ohm -and $ohm -match '0\.0\.0\.0|^:') { chk_fail "OLLAMA_HOST(machine)=$ohm EXPOSED" }

# ─── Check 9: Firewall ────────────────────────────────────────────────────────
hdr "Check 9: Windows Firewall  [NIST SP 800-53 SC-7; CMMC AC.L2-3.1.3]"
if ($isAdmin) {
    $fwState = netsh advfirewall show allprofiles state 2>$null
    if ($fwState -match 'State\s+ON') { chk_pass "Windows Firewall ON for at least one profile." }
    else { chk_fail "Windows Firewall appears OFF.  [NIST SP 800-53 SC-7]" }
    foreach ($portEntry in $LLM_Ports.GetEnumerator()) {
        $p = $portEntry.Key; $t = $portEntry.Value
        $rule = Get-NetFirewallRule -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match "LLM.*$p" }
        if ($rule) { chk_pass "Firewall block rule for port $p ($t)." }
        else        { chk_warn "No LLM hardening firewall rule for $p ($t)." }
    }
} else { chk_warn "Firewall check requires Administrator." }

# ─── Check 10: API Auth ───────────────────────────────────────────────────────
hdr "Check 10: API Authentication  [NIST SP 800-53 IA-2, IA-3]"
foreach ($p in @(11434, 1234, 8080, 7860, 8000, 8001, 5001)) {
    if (Get-NetTCPConnection -LocalPort $p -State Listen -ErrorAction SilentlyContinue) {
        try {
            $r = Invoke-WebRequest -Uri "http://127.0.0.1:$p" -TimeoutSec 2 -ErrorAction Stop
            if ($r.StatusCode -eq 200) { chk_warn "Port $p unauthenticated (HTTP 200)  [NIST SP 800-53 IA-2]" }
        } catch { chk_pass "Port $p — no unauthenticated 200 response." }
    }
}

# ─── Check 11: MCP Configs ────────────────────────────────────────────────────
hdr "Check 11: MCP Configurations  [NIST AI 100-2; NSA-AI-SECURITY]"
$mcpFound = 0
foreach ($f in $McpConfigPaths) {
    if (Test-Path $f) {
        $c = Get-Content $f -Raw 2>$null
        if ($c -match 'mcpServers') {
            chk_warn "MCP config: $f"; $mcpFound++
            if ($c -match '"url"') { chk_fail "REMOTE MCP server in $f  [FBI-FOREIGN-AI; NIST AI 600-1]" }
            if ($c -match '"api_key"|"token"|"password"|"Authorization"') { chk_fail "Credentials in $f  [NIST SP 800-53 IA-5]" }
            if ($c -match '"npx"' -and $c -match '"-y"') { chk_warn "npx -y supply chain risk in $f  [NIST SP 800-218]" }
        }
    }
}
Get-ChildItem -Path $env:USERPROFILE -Recurse -Filter 'mcp.json' -ErrorAction SilentlyContinue |
    ForEach-Object { chk_warn "mcp.json: $($_.FullName)"; $mcpFound++ }
if ($mcpFound -eq 0) { chk_pass "No MCP configurations found." }

# ─── Check 12: Auto-Start ────────────────────────────────────────────────────
hdr "Check 12: Auto-Start Entries  [NIST SP 800-53 CM-7]"
@('HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run','HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run') |
    ForEach-Object {
        Get-ItemProperty $_ 2>$null | ForEach-Object {
            $_.PSObject.Properties |
                Where-Object { $_.Value -match 'ollama|lmstudio|localai|gpt4all|jan|kobold|tabby|oobabooga|anythingllm|autogpt|crewai' } |
                ForEach-Object { chk_warn "Startup: $($_.Name) = $($_.Value)  [NIST SP 800-53 CM-7]" }
        }
    }
$ollamaSvc = Get-Service 'ollama' -ErrorAction SilentlyContinue
if ($ollamaSvc -and $ollamaSvc.StartType -eq 'Automatic') { chk_warn "Ollama service set to Automatic start." }

# ─── SUMMARY ──────────────────────────────────────────────────────────────────
Write-Host "`n╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                  AUDIT SUMMARY                          ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host "  PASS: $Pass  " -ForegroundColor Green -NoNewline
Write-Host "WARN: $Warn  " -ForegroundColor Yellow -NoNewline
Write-Host "FAIL: $Fail" -ForegroundColor Red
Write-Host ""
if ($Fail -gt 0)     { Write-Host "ACTION REQUIRED: $Fail critical issue(s). Run harden.ps1 or escalate." -ForegroundColor Red }
elseif ($Warn -gt 0) { Write-Host "REVIEW: $Warn warning(s) found." -ForegroundColor Yellow }
else                 { Write-Host "System appears compliant." -ForegroundColor Green }

Show-FederalReferences
