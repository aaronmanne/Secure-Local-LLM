#Requires -Version 5.1
<#
.SYNOPSIS
    Windows MCP Security Audit
    Regulatory basis: NIST AI 100-2; NSA-AI-SECURITY; NIST SP 800-53 SI-3, CA-7
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

function chk_pass { param($t) Write-Host "[PASS] $t" -ForegroundColor Green;  $script:Pass++ }
function chk_warn { param($t) Write-Host "[WARN] $t" -ForegroundColor Yellow; $script:Warn++ }
function chk_fail { param($t) Write-Host "[FAIL] $t" -ForegroundColor Red;    $script:Fail++ }
function hdr      { param($t) Write-Host "`n=== $t ===" -ForegroundColor Cyan }

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "         Windows MCP Security Audit                      " -ForegroundColor Cyan
Write-Host "  Ref: NIST AI 100-2 . NSA-AI-SECURITY . NIST 800-53      " -ForegroundColor Cyan
Write-Host "       SI-3 . CA-7 . SA-12 . IA-5                        " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Date: $(Get-Date) | Host: $env:COMPUTERNAME"

# --- 1. Discover MCP Configs --------------------------------------------------
hdr "1. MCP Config Discovery  [NIST SP 800-53 CM-8]"
$allMcpFiles = [System.Collections.Generic.List[string]]::new()

foreach ($f in $McpConfigPaths) {
    if (Test-Path $f) {
        $c = Get-Content $f -Raw 2>$null
        if ($c -match 'mcpServers') { chk_warn "MCP config: $f"; $allMcpFiles.Add($f) }
    }
}
Get-ChildItem -Path $env:USERPROFILE -Recurse -Filter 'mcp.json' -ErrorAction SilentlyContinue |
    ForEach-Object {
        if (-not $allMcpFiles.Contains($_.FullName)) {
            chk_warn "mcp.json: $($_.FullName)"; $allMcpFiles.Add($_.FullName)
        }
    }
Get-ChildItem -Path $env:APPDATA -Recurse -Filter '*.json' -ErrorAction SilentlyContinue |
    Select-String -Pattern 'mcpServers' -ErrorAction SilentlyContinue |
    ForEach-Object {
        if (-not $allMcpFiles.Contains($_.Path)) {
            chk_warn "JSON with mcpServers: $($_.Path)"; $allMcpFiles.Add($_.Path)
        }
    }
if ($allMcpFiles.Count -eq 0) { chk_pass "No MCP config files found." }

# --- 2. Analyze Configs -------------------------------------------------------
hdr "2. MCP Config Analysis  [NIST AI 100-2; NSA-AI-SECURITY $4]"
foreach ($f in $allMcpFiles) {
    Write-Host "`n  File: $f" -ForegroundColor White
    $c = Get-Content $f -Raw 2>$null; if (-not $c) { continue }

    # Remote servers
    if ($c -match '"url"\s*:') {
        $urls = [regex]::Matches($c, '"url"\s*:\s*"([^"]+)"') | ForEach-Object { $_.Groups[1].Value }
        chk_fail "REMOTE MCP SERVER(S) in $f  [FBI-FOREIGN-AI; NIST AI 600-1 $2.5]"
        $urls | ForEach-Object { Write-Host "    URL: $_" -ForegroundColor Red }
    }
    # Credentials
    if ($c -match '"(api_key|apikey|api-key|token|password|secret|Authorization)"\s*:') {
        chk_fail "CREDENTIALS embedded in $f  [NIST SP 800-53 IA-5]"
    }
    # Temp paths
    if ($c -match '\\\\Temp\\\\|\\\\tmp\\\\|Downloads\\\\') {
        chk_fail "MCP server from temp/download path: $f  [NIST SP 800-53 SI-3]"
    }
    # npx -y
    if ($c -match '"npx"' -and $c -match '"-y"') {
        chk_warn "npx -y (supply chain risk) in $f  [NIST SP 800-218 $2.1]"
    }
    # Broad paths
    if ($c -match '"C:\\\\"\s*[,\]]|"~"\s*[,\]]') {
        chk_warn "Broad filesystem scope in $f  [NIST SP 800-53 AC-6]"
    }
    # Sensitive paths
    foreach ($sp in $SensitivePaths) {
        if ($c -match [regex]::Escape($sp)) {
            chk_fail "Sensitive path '$sp' in $f  [DFARS 252.204-7012; NIST SP 800-171]"
        }
    }
}

# --- 3. Running MCP Processes -------------------------------------------------
hdr "3. Running MCP Processes  [NIST SP 800-53 CM-7]"
$mcpProcs = Get-Process | Where-Object { $_.Name -match 'mcp|modelcontext' }
if ($mcpProcs) { chk_warn "MCP processes:"; $mcpProcs | Format-Table Name,Id -AutoSize }
else { chk_pass "No MCP processes." }
$runtimeProcs = Get-Process | Where-Object { $_.Name -match '^node$|^python$|^python3$' }
if ($runtimeProcs) { chk_warn "Node/Python running (common MCP runtimes) - verify expected." }

# --- 4. Outbound Connections --------------------------------------------------
hdr "4. Outbound Connections from MCP Runtimes  [NIST SP 800-53 SC-7, SI-4]"
if ($runtimeProcs) {
    $pids = $runtimeProcs.Id
    $outbound = Get-NetTCPConnection -State Established -ErrorAction SilentlyContinue |
        Where-Object { $_.OwningProcess -in $pids -and $_.RemoteAddress -notin @('127.0.0.1','::1') }
    if ($outbound) {
        chk_warn "Outbound connections from Node/Python runtimes:"
        $outbound | Format-Table LocalAddress,LocalPort,RemoteAddress,RemotePort,OwningProcess -AutoSize
    } else { chk_pass "No non-localhost outbound connections from Node/Python." }
} else { chk_pass "No Node/Python runtimes running." }

# --- 5. Agent Tool Configs ----------------------------------------------------
hdr "5. AI Agent Tool Configs  [NIST AI 600-1 $2.6]"
@(
    "$env:USERPROFILE\.aider.conf.yml",
    "$env:USERPROFILE\.goose\config.yaml",
    "$env:USERPROFILE\.plandex\config.json",
    "$env:USERPROFILE\.continue\config.json",
    "$env:USERPROFILE\.cody\config.json"
) | Where-Object { Test-Path $_ } | ForEach-Object {
    chk_warn "Agent config: $_"
    $c = Get-Content $_ -Raw 2>$null
    if ($c -match 'url|endpoint|host|api_key|token') {
        chk_warn "  >> External endpoint or credential ref - review!  [NIST AI 600-1 $2.6]"
    }
}

# --- SUMMARY ------------------------------------------------------------------
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "              MCP AUDIT SUMMARY                          " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  PASS: $Pass  " -ForegroundColor Green -NoNewline
Write-Host "WARN: $Warn  "   -ForegroundColor Yellow -NoNewline
Write-Host "FAIL: $Fail"     -ForegroundColor Red
if ($Fail -gt 0)     { Write-Host "CRITICAL: $Fail issue(s) - escalate to InfoSec immediately." -ForegroundColor Red }
elseif ($Warn -gt 0) { Write-Host "REVIEW: $Warn item(s) need manual review." -ForegroundColor Yellow }
else                 { Write-Host "No MCP issues detected." -ForegroundColor Green }

Show-FederalReferences
