#Requires -Version 5.1
<#
.SYNOPSIS
    Windows LLM Installation Identifier
    Identifies locally installed LLM tools, models, and related software
#>

$ErrorActionPreference = 'SilentlyContinue'

$ProhibitedPattern = 'deepseek|qwen|qwq|yi-\d|baichuan|chatglm|internlm|minimax|ernie|hunyuan|tigerbot|aquila|moss|belle|rugpt|saiga|fred-t5|falcon'

function Write-Header  { param($t) Write-Host "`n=== $t ===" -ForegroundColor Cyan }
function Write-Found   { param($t) Write-Host "[FOUND] $t" -ForegroundColor Green }
function Write-Warn    { param($t) Write-Host "[WARN]  $t" -ForegroundColor Yellow }
function Write-Prohibited { param($t) Write-Host "[PROHIBITED] $t" -ForegroundColor Red }
function Write-Info    { param($t) Write-Host "  $t" }

Write-Host @"
╔══════════════════════════════════════════════════════════╗
║        Windows LLM Installation Identifier              ║
╚══════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

Write-Host "Date: $(Get-Date)"
Write-Host "Host: $env:COMPUTERNAME"
Write-Host "User: $env:USERNAME"
Write-Host ""

# ─── 1. RUNNING PROCESSES ─────────────────────────────────────────────────────
Write-Header "Running LLM Processes"
$llmProcs = Get-Process | Where-Object { $_.Name -match 'ollama|lmstudio|lm-studio|localai|gpt4all|jan|llamafile' }
if ($llmProcs) {
    $llmProcs | ForEach-Object { Write-Found "Process: $($_.Name) (PID: $($_.Id))" }
} else {
    Write-Info "No LLM processes currently running."
}

# ─── 2. INSTALLED APPLICATIONS ────────────────────────────────────────────────
Write-Header "Installed LLM Applications"
$regPaths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
)
$found = $false
foreach ($path in $regPaths) {
    Get-ItemProperty $path 2>$null |
        Where-Object { $_.DisplayName -match 'ollama|lm.?studio|localai|gpt4all|jan\.ai|jan |llamafile|anything.?llm' } |
        ForEach-Object {
            Write-Found "Installed: $($_.DisplayName) $($_.DisplayVersion)"
            $found = $true
        }
}

# Check common install paths
$appPaths = @(
    "$env:LOCALAPPDATA\Programs\Ollama",
    "$env:LOCALAPPDATA\Programs\LM-Studio",
    "$env:PROGRAMFILES\Ollama",
    "$env:PROGRAMFILES\LM Studio",
    "$env:LOCALAPPDATA\Jan"
)
foreach ($p in $appPaths) {
    if (Test-Path $p) { Write-Found "App directory: $p"; $found = $true }
}

# CLI tools
foreach ($cmd in 'ollama','localai','llamafile') {
    $loc = Get-Command $cmd 2>$null
    if ($loc) { Write-Found "CLI: $cmd ($($loc.Source))"; $found = $true }
}

if (-not $found) { Write-Info "No LLM applications found." }

# ─── 3. MODEL DIRECTORIES ─────────────────────────────────────────────────────
Write-Header "Model Directories"
$modelDirs = @(
    "$env:USERPROFILE\.ollama\models",
    "$env:USERPROFILE\.lmstudio\models",
    "$env:USERPROFILE\.cache\lm-studio\models",
    "$env:APPDATA\LM Studio",
    "$env:LOCALAPPDATA\nomic.ai\GPT4All",
    "$env:USERPROFILE\jan\models",
    "$env:USERPROFILE\.localai\models"
)
foreach ($dir in $modelDirs) {
    if (Test-Path $dir) {
        $count = (Get-ChildItem -Path $dir -Recurse -Include '*.gguf','*.bin','*.safetensors','*.ggml' -ErrorAction SilentlyContinue | Measure-Object).Count
        $size = (Get-ChildItem -Path $dir -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        $sizeMB = [math]::Round($size / 1MB, 1)
        Write-Found "Dir: $dir ($count model files, ~${sizeMB}MB)"
    }
}

# ─── 4. LIST OLLAMA MODELS ────────────────────────────────────────────────────
Write-Header "Ollama Registered Models"
if (Get-Command ollama 2>$null) {
    try { ollama list } catch { Write-Info "Ollama installed but not responding." }
} else {
    Write-Info "Ollama CLI not found."
}

# ─── 5. ALL MODEL FILES ───────────────────────────────────────────────────────
Write-Header "Model Files Found"
Write-Info "(Searching user profile — may take a moment...)"
Get-ChildItem -Path $env:USERPROFILE -Recurse -Include '*.gguf','*.safetensors','*.ggml' -ErrorAction SilentlyContinue |
    ForEach-Object {
        $sizeMB = [math]::Round($_.Length / 1MB, 1)
        Write-Info "[${sizeMB}MB] $($_.FullName)"
    }

# ─── 6. PROHIBITED MODEL SCAN ─────────────────────────────────────────────────
Write-Header "Prohibited / Foreign-Origin Model Scan"
$prohibitedFound = 0
Get-ChildItem -Path $env:USERPROFILE -Recurse -Include '*.gguf','*.bin','*.safetensors' -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match $ProhibitedPattern } |
    ForEach-Object {
        Write-Prohibited "PROHIBITED MODEL: $($_.FullName)"
        $prohibitedFound++
    }

if (Get-Command ollama 2>$null) {
    ollama list 2>$null | Where-Object { $_ -match $ProhibitedPattern } |
        ForEach-Object { Write-Prohibited "PROHIBITED OLLAMA MODEL: $_" }
}
Write-Info "Prohibited model scan complete."

# ─── 7. NETWORK EXPOSURE CHECK ────────────────────────────────────────────────
Write-Header "Network Exposure Check"
$llmPorts = @(11434, 1234, 8080, 3000, 8000, 5000)
foreach ($port in $llmPorts) {
    $conn = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
    if ($conn) {
        foreach ($c in $conn) {
            if ($c.LocalAddress -in @('0.0.0.0', '::')) {
                Write-Warn "Port $port EXPOSED on all interfaces! (Address: $($c.LocalAddress))"
            } else {
                Write-Found "Port $port listening on: $($c.LocalAddress) (local only)"
            }
        }
    }
}

# ─── 8. OLLAMA ENV VARIABLE ───────────────────────────────────────────────────
Write-Header "Ollama Configuration"
$ollamaHost = [System.Environment]::GetEnvironmentVariable('OLLAMA_HOST')
if ($ollamaHost) {
    if ($ollamaHost -match '0\.0\.0\.0|^:') {
        Write-Warn "OLLAMA_HOST=$ollamaHost — EXPOSED TO NETWORK!"
    } else {
        Write-Found "OLLAMA_HOST=$ollamaHost"
    }
} else {
    Write-Info "OLLAMA_HOST not set (defaults to localhost:11434)"
}

# ─── 9. MCP CONFIG SCAN ───────────────────────────────────────────────────────
Write-Header "MCP Config Files"
$mcpPaths = @(
    "$env:APPDATA\Claude\claude_desktop_config.json",
    "$env:USERPROFILE\.cursor\mcp.json",
    "$env:USERPROFILE\.continue\config.json",
    "$env:APPDATA\Code\User\settings.json",
    "$env:APPDATA\Cursor\User\settings.json"
)
foreach ($f in $mcpPaths) {
    if (Test-Path $f) {
        $content = Get-Content $f -Raw -ErrorAction SilentlyContinue
        if ($content -match 'mcpServers') {
            Write-Warn "MCP config found: $f"
            if ($content -match '"url"') { Write-Warn "  >> Contains remote MCP server (url key)!" }
        }
    }
}
Get-ChildItem -Path $env:USERPROFILE -Recurse -Filter 'mcp.json' -ErrorAction SilentlyContinue |
    ForEach-Object { Write-Warn "mcp.json: $($_.FullName)" }

Write-Host "`n=== Scan Complete ===" -ForegroundColor Cyan
Write-Host "Run audit.ps1 for full checklist or harden.ps1 to apply controls."
