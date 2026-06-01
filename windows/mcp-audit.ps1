#Requires -Version 5.1
<#
.SYNOPSIS
    Windows MCP (Model Context Protocol) Security Audit
#>

$ErrorActionPreference = 'SilentlyContinue'
$Pass = 0; $Warn = 0; $Fail = 0

function chk_pass { param($t) Write-Host "[PASS] $t" -ForegroundColor Green;  $script:Pass++ }
function chk_warn { param($t) Write-Host "[WARN] $t" -ForegroundColor Yellow; $script:Warn++ }
function chk_fail { param($t) Write-Host "[FAIL] $t" -ForegroundColor Red;    $script:Fail++ }
function hdr      { param($t) Write-Host "`n=== $t ===" -ForegroundColor Cyan }

Write-Host @"
╔══════════════════════════════════════════════════════════╗
║         Windows MCP Security Audit                      ║
╚══════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan
Write-Host "Date: $(Get-Date) | Host: $env:COMPUTERNAME"

# ─── 1. Find MCP Config Files ─────────────────────────────────────────────────
hdr "1. MCP Config File Discovery"

$knownPaths = @(
    "$env:APPDATA\Claude\claude_desktop_config.json",
    "$env:USERPROFILE\.cursor\mcp.json",
    "$env:USERPROFILE\.continue\config.json",
    "$env:APPDATA\Code\User\settings.json",
    "$env:APPDATA\Cursor\User\settings.json"
)

$allMcpFiles = [System.Collections.Generic.List[string]]::new()

foreach ($f in $knownPaths) {
    if (Test-Path $f) {
        $content = Get-Content $f -Raw 2>$null
        if ($content -match 'mcpServers') {
            chk_warn "MCP config: $f"
            $allMcpFiles.Add($f)
        }
    }
}

Get-ChildItem -Path $env:USERPROFILE -Recurse -Filter 'mcp.json' -ErrorAction SilentlyContinue |
    ForEach-Object {
        if (-not $allMcpFiles.Contains($_.FullName)) {
            chk_warn "mcp.json: $($_.FullName)"
            $allMcpFiles.Add($_.FullName)
        }
    }

# Search all JSON files for mcpServers key
Get-ChildItem -Path $env:APPDATA -Recurse -Filter '*.json' -ErrorAction SilentlyContinue |
    Select-String -Pattern 'mcpServers' -ErrorAction SilentlyContinue |
    ForEach-Object {
        if (-not $allMcpFiles.Contains($_.Path)) {
            chk_warn "JSON with mcpServers: $($_.Path)"
            $allMcpFiles.Add($_.Path)
        }
    }

if ($allMcpFiles.Count -eq 0) { chk_pass "No MCP config files found." }

# ─── 2. Analyze Each Config ───────────────────────────────────────────────────
hdr "2. MCP Config Analysis"
foreach ($f in $allMcpFiles) {
    Write-Host "`n  File: $f" -ForegroundColor White
    $content = Get-Content $f -Raw 2>$null
    if (-not $content) { continue }

    # Remote servers
    if ($content -match '"url"\s*:') {
        $urls = [regex]::Matches($content, '"url"\s*:\s*"([^"]+)"') | ForEach-Object { $_.Groups[1].Value }
        chk_fail "REMOTE MCP SERVER(S) in $f"
        $urls | ForEach-Object { Write-Host "    URL: $_" -ForegroundColor Red }
    }

    # Embedded credentials
    if ($content -match '"(api_key|apikey|api-key|token|password|secret|Authorization)"\s*:') {
        chk_fail "CREDENTIALS embedded in MCP config: $f"
    }

    # Scripts from temp paths
    if ($content -match '\\\\Temp\\\\|\\\\tmp\\\\|Downloads\\\\') {
        chk_fail "MCP server running from temp/download path: $f"
    }

    # npx -y supply chain risk
    if ($content -match '"npx"' -and $content -match '"-y"') {
        chk_warn "npx -y pattern (supply chain risk) in: $f"
    }

    # Broad filesystem paths
    if ($content -match '"C:\\\\"\s*[,\]]|"~"\s*[,\]]') {
        chk_warn "Broad filesystem path (C:\\ or ~) in MCP config: $f"
    }

    # Sensitive path references
    foreach ($sensitive in @('.ssh','.aws','.env','.gnupg','credentials','id_rsa')) {
        if ($content -match [regex]::Escape($sensitive)) {
            chk_fail "Sensitive path '$sensitive' referenced in: $f"
        }
    }
}

# ─── 3. Running MCP Processes ─────────────────────────────────────────────────
hdr "3. Running MCP-Related Processes"
$mcpProcs = Get-Process | Where-Object { $_.Name -match 'mcp|modelcontext' }
if ($mcpProcs) {
    chk_warn "MCP-related processes running:"
    $mcpProcs | Format-Table Name,Id,Path -AutoSize
} else { chk_pass "No MCP-specific processes detected." }

$nodeProcs = Get-Process | Where-Object { $_.Name -match '^node$|^python$|^python3$' }
if ($nodeProcs) {
    chk_warn "Node/Python processes running (common MCP runtimes):"
    $nodeProcs | Format-Table Name,Id -AutoSize
}

# ─── 4. Outbound Connections ──────────────────────────────────────────────────
hdr "4. Outbound Connections from MCP Runtimes"
if ($nodeProcs) {
    $nodePids = $nodeProcs.Id
    $outbound = Get-NetTCPConnection -State Established -ErrorAction SilentlyContinue |
        Where-Object { $_.OwningProcess -in $nodePids -and $_.RemoteAddress -ne '127.0.0.1' }
    if ($outbound) {
        chk_warn "Outbound connections from Node/Python:"
        $outbound | Format-Table LocalAddress,LocalPort,RemoteAddress,RemotePort,OwningProcess -AutoSize
    } else {
        chk_pass "No suspicious outbound connections from Node/Python."
    }
} else {
    chk_pass "No Node/Python runtimes running to check."
}

# ─── SUMMARY ──────────────────────────────────────────────────────────────────
Write-Host "`n╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║              MCP AUDIT SUMMARY                          ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host "  PASS: $Pass  " -ForegroundColor Green -NoNewline
Write-Host "WARN: $Warn  " -ForegroundColor Yellow -NoNewline
Write-Host "FAIL: $Fail" -ForegroundColor Red
Write-Host ""
if ($Fail -gt 0)     { Write-Host "CRITICAL: $Fail issue(s) require immediate action. Escalate to InfoSec." -ForegroundColor Red }
elseif ($Warn -gt 0) { Write-Host "REVIEW: $Warn item(s) need manual review." -ForegroundColor Yellow }
else                 { Write-Host "No MCP issues detected." -ForegroundColor Green }
Write-Host ""
