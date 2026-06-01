#Requires -Version 5.1
<#
.SYNOPSIS
    Windows LLM & AI Agent Installation Identifier
    Regulatory basis: NIST SP 800-53 CM-8; NIST AI 600-1; CMMC 2.0 CM.L2-3.4.1
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

function Write-Header     { param($t) Write-Host "`n=== $t ===" -ForegroundColor Cyan }
function Write-Found      { param($t) Write-Host "[FOUND]      $t" -ForegroundColor Green }
function Write-Warn       { param($t) Write-Host "[WARN]       $t" -ForegroundColor Yellow }
function Write-Prohibited { param($t) Write-Host "[PROHIBITED] $t" -ForegroundColor Red }
function Write-Review     { param($t) Write-Host "[REVIEW]     $t" -ForegroundColor Magenta }
function Write-Info       { param($t) Write-Host "  $t" }

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "     Windows LLM & AI Agent Installation Identifier      " -ForegroundColor Cyan
Write-Host "  Ref: NIST SP 800-53 CM-8 . NIST AI 600-1                " -ForegroundColor Cyan
Write-Host "       CMMC 2.0 CM.L2-3.4.1 . DFARS 252.204-7012          " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Date: $(Get-Date) | Host: $env:COMPUTERNAME | User: $env:USERNAME"
Write-Host ""

# --- 1. RUNNING INFERENCE SERVER PROCESSES ------------------------------------
Write-Header "1. Running Inference Server Processes"
$inferenceProcs = Get-Process | Where-Object { $_.Name -match $LLM_ProcessPattern }
if ($inferenceProcs) {
    $inferenceProcs | ForEach-Object { Write-Found "Process: $($_.Name) (PID: $($_.Id))" }
} else { Write-Info "No inference server processes running." }

# --- 2. RUNNING AI AGENT PROCESSES -------------------------------------------
Write-Header "2. Running AI Agent / Framework Processes"
$agentProcs = Get-Process | Where-Object { $_.Name -match $Agent_ProcessPattern }
if ($agentProcs) {
    $agentProcs | ForEach-Object { Write-Warn "Agent process: $($_.Name) (PID: $($_.Id))" }
} else { Write-Info "No AI agent processes running." }

# --- 3. INSTALLED APPLICATIONS ------------------------------------------------
Write-Header "3. Installed LLM / Agent Applications"
$regPaths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
)
$foundApps = $false
foreach ($rp in $regPaths) {
    Get-ItemProperty $rp 2>$null |
        Where-Object { $_.DisplayName -match 'ollama|lm.?studio|localai|gpt4all|jan\.ai|jan |llamafile|anything.?llm|msty|tabby|kobold|openwebui|open.?webui|oobabooga|cursor|windsurf|continue|cody|autogpt|crewai|opendevin|openhands|flowise|dify' } |
        ForEach-Object { Write-Found "Installed: $($_.DisplayName) $($_.DisplayVersion)"; $foundApps = $true }
}
foreach ($p in $AppPaths) {
    if (Test-Path $p) { Write-Found "App dir: $p"; $foundApps = $true }
}
foreach ($cmd in ($LLM_CLITools + $Agent_CLITools)) {
    $loc = Get-Command $cmd 2>$null
    if ($loc) { Write-Found "CLI: $cmd ($($loc.Source))"; $foundApps = $true }
}
# pip packages
$pip = Get-Command pip3,pip 2>$null | Select-Object -First 1
if ($pip) {
    & $pip.Name list 2>$null |
        Where-Object { $_ -match 'ollama|llama.?cpp|transformers|langchain|langgraph|autogen|crewai|openai|anthropic|huggingface|text.generation|vllm|sglang|open.interpreter|aider|plandex|mentat|goose.ai|memgpt|mem0|letta|phidata|dspy|haystack|xinference|privategpt|localai' } |
        ForEach-Object { Write-Warn "Python package: $_" }
}
if (-not $foundApps) { Write-Info "No LLM/agent applications found." }

# --- 4. AGENT CONFIG DIRECTORIES ----------------------------------------------
Write-Header "4. Agent Config / Workspace Directories"
$agentDirs = @(
    "$env:USERPROFILE\.autogpt", "$env:USERPROFILE\AutoGPT", "$env:USERPROFILE\Auto-GPT",
    "$env:USERPROFILE\.crewai", "$env:USERPROFILE\.autogen",
    "$env:USERPROFILE\.opendevin", "$env:USERPROFILE\.openhands",
    "$env:USERPROFILE\.aider", "$env:USERPROFILE\.goose",
    "$env:USERPROFILE\.plandex", "$env:USERPROFILE\.mentat",
    "$env:USERPROFILE\.continue", "$env:USERPROFILE\.cody",
    "$env:USERPROFILE\flowise", "$env:USERPROFILE\.n8n",
    "$env:USERPROFILE\.memgpt", "$env:USERPROFILE\.letta",
    "$env:USERPROFILE\langchain", "$env:USERPROFILE\dify",
    "$env:USERPROFILE\privategpt", "$env:USERPROFILE\anythingllm"
)
foreach ($d in $agentDirs) {
    if (Test-Path $d) { Write-Warn "Agent config dir: $d" }
}

# --- 5. MODEL DIRECTORIES -----------------------------------------------------
Write-Header "5. Model Directories  [NIST AI 600-1 $2.5: Model Provenance]"
foreach ($dir in $ModelDirs) {
    if (Test-Path $dir) {
        $count = (Get-ChildItem -Path $dir -Recurse -Include $ModelExtensions -ErrorAction SilentlyContinue | Measure-Object).Count
        $sizeMB = [math]::Round((Get-ChildItem -Path $dir -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB, 1)
        Write-Found "$dir ($count model files, ~${sizeMB}MB)"
    }
}

# --- 6. OLLAMA REGISTERED MODELS ----------------------------------------------
Write-Header "6. Ollama Registered Models"
if (Get-Command ollama 2>$null) {
    try { ollama list } catch { Write-Info "Ollama not responding." }
} else { Write-Info "Ollama not installed." }

# --- 7. ALL MODEL FILES FOUND -------------------------------------------------
Write-Header "7. All Model Files Found"
Write-Info "(searching user profile...)"
Get-ChildItem -Path $env:USERPROFILE -Recurse -Include $ModelExtensions -ErrorAction SilentlyContinue |
    ForEach-Object {
        $sizeMB = [math]::Round($_.Length / 1MB, 1)
        Write-Info "[${sizeMB}MB] $($_.FullName)"
    }

# --- 8. PROHIBITED MODEL SCAN -------------------------------------------------
Write-Header "8. Prohibited / Foreign-Origin Model Scan  [FBI-DEEPSEEK; HOUSE-DEEPSEEK]"
Get-ChildItem -Path $env:USERPROFILE -Recurse -Include $ModelExtensions -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match $ProhibitedPattern } |
    ForEach-Object { Write-Prohibited "PROHIBITED: $($_.FullName)" }

if (Get-Command ollama 2>$null) {
    ollama list 2>$null | Where-Object { $_ -match $ProhibitedPattern } |
        ForEach-Object { Write-Prohibited "PROHIBITED OLLAMA MODEL: $_" }
}
Get-ChildItem -Path $env:USERPROFILE -Recurse -Include $ModelExtensions -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match $ReviewPattern } |
    ForEach-Object { Write-Review "VERIFY ORIGIN: $($_.FullName)" }

# --- 9. NETWORK EXPOSURE ------------------------------------------------------
Write-Header "9. Network Exposure Check  [NIST SP 800-53 SC-7: Boundary Protection]"
foreach ($portEntry in $LLM_Ports.GetEnumerator()) {
    $port = $portEntry.Key; $tool = $portEntry.Value
    $conns = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
    if ($conns) {
        foreach ($c in $conns) {
            if ($c.LocalAddress -in @('0.0.0.0','::','*')) {
                Write-Warn "Port $port ($tool) EXPOSED on all interfaces! [NIST SP 800-53 SC-7]"
            } else {
                Write-Found "Port $port ($tool) - localhost-bound ($($c.LocalAddress))"
            }
        }
    }
}

# --- 10. OLLAMA HOST ENV ------------------------------------------------------
Write-Header "10. Ollama Configuration [NIST SP 800-53 SC-7, IA-3]"
$oh = [System.Environment]::GetEnvironmentVariable('OLLAMA_HOST', 'User')
if ($oh) {
    if ($oh -match '0\.0\.0\.0|^:') { Write-Warn "OLLAMA_HOST=$oh - EXPOSED! [NIST SP 800-53 SC-7]" }
    else { Write-Found "OLLAMA_HOST=$oh" }
} else { Write-Info "OLLAMA_HOST not set (defaults to localhost)." }

# --- 11. MCP CONFIG SCAN ------------------------------------------------------
Write-Header "11. MCP Config Files  [NIST AI 100-2; NSA-AI-SECURITY]"
foreach ($f in $McpConfigPaths) {
    if (Test-Path $f) {
        $content = Get-Content $f -Raw 2>$null
        if ($content -match 'mcpServers') {
            Write-Warn "MCP config: $f"
            if ($content -match '"url"') { Write-Warn "  >> REMOTE server detected  [FBI-FOREIGN-AI]" }
        }
    }
}
Get-ChildItem -Path $env:USERPROFILE -Recurse -Filter 'mcp.json' -ErrorAction SilentlyContinue |
    ForEach-Object { Write-Warn "mcp.json: $($_.FullName)" }

# --- SUMMARY ------------------------------------------------------------------
Write-Host "`n=== Scan Complete ===" -ForegroundColor Cyan
Write-Host "Run audit.ps1 for full checklist or harden.ps1 to apply controls."
Show-FederalReferences
