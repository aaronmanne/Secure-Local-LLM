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

# --- 7. SPLIT & BLOB-BASED MODEL STORAGE -------------------------------------
Write-Header "7. Split & Blob-Based Model Storage"
Write-Info "Scanning tools that store models as content-addressed blobs or shards..."
$splitFound = 0

# ── Ollama: content-addressed blob store (sha256-* files, no extension) ───────
# Ollama does NOT use .gguf filenames — it stores models as sha256-named blobs.
$ollamaBlobDir     = "$env:USERPROFILE\.ollama\models\blobs"
$ollamaManifestDir = "$env:USERPROFILE\.ollama\models\manifests"

if (Test-Path $ollamaBlobDir) {
    $blobs      = Get-ChildItem -Path $ollamaBlobDir -File -ErrorAction SilentlyContinue
    $blobCount  = $blobs.Count
    $blobSizeMB = [math]::Round(($blobs | Measure-Object -Property Length -Sum).Sum / 1MB, 1)
    Write-Found "Ollama blob store: $blobCount content-addressed file(s), ~${blobSizeMB}MB  [$ollamaBlobDir]"
    $splitFound++

    if (Test-Path $ollamaManifestDir) {
        # Parse each manifest JSON to map blob hash → model name + size
        Get-ChildItem -Path $ollamaManifestDir -File -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
            $manifestFile = $_.FullName
            $modelId = $manifestFile.Replace($ollamaManifestDir + '\', '').Replace('registry.ollama.ai\', '').Replace('\', '/')
            try {
                $manifest = Get-Content $manifestFile -Raw | ConvertFrom-Json
                foreach ($layer in $manifest.layers) {
                    $mt = $layer.mediaType
                    if ($mt -match 'model|weights') {
                        $digest    = $layer.digest -replace 'sha256:', 'sha256-'
                        $sizeGB    = [math]::Round($layer.size / 1GB, 2)
                        $blobPath  = Join-Path $ollamaBlobDir $digest
                        if (Test-Path $blobPath) {
                            Write-Found "  [${sizeGB}GB] ollama://$modelId  ->  $blobPath"
                        } else {
                            Write-Warn  "  [${sizeGB}GB] ollama://$modelId  ->  BLOB MISSING: $blobPath"
                        }
                    }
                }
            } catch {
                Write-Info "  Could not parse manifest: $manifestFile"
            }
        }

        # Report orphaned blobs — large blobs with no manifest reference
        $blobs | Where-Object { $_.Length -gt 52428800 } | ForEach-Object {  # > 50MB
            $blobName   = $_.Name
            $digestKey  = $blobName -replace 'sha256-', 'sha256:'
            $referenced = Get-ChildItem -Path $ollamaManifestDir -File -Recurse -ErrorAction SilentlyContinue |
                          Where-Object { (Get-Content $_.FullName -Raw 2>$null) -match [regex]::Escape($digestKey) } |
                          Select-Object -First 1
            if (-not $referenced) {
                $sizeMB = [math]::Round($_.Length / 1MB, 1)
                Write-Warn "  [${sizeMB}MB] Orphaned blob (no manifest — leftover from deleted model): $($_.FullName)"
            }
        }
    }
} else {
    Write-Info "Ollama blob store not found (Ollama not installed or no models pulled)."
}

# ── HuggingFace Hub: blob cache + sharded safetensors ─────────────────────────
$hfDir = "$env:USERPROFILE\.cache\huggingface\hub"
if (Test-Path $hfDir) {
    $hfModels  = Get-ChildItem -Path $hfDir -Directory -ErrorAction SilentlyContinue |
                 Where-Object { $_.Name -match '^models--' }
    $hfTotal   = [math]::Round((Get-ChildItem -Path $hfDir -Recurse -ErrorAction SilentlyContinue |
                  Measure-Object -Property Length -Sum).Sum / 1GB, 2)
    Write-Found "HuggingFace Hub cache: $($hfModels.Count) model(s), ~${hfTotal}GB  [$hfDir]"
    $splitFound++
    $hfModels | ForEach-Object {
        $modelName  = $_.Name -replace '^models--', '' -replace '--', '/'
        $modelSizeMB = [math]::Round((Get-ChildItem -Path $_.FullName -Recurse -ErrorAction SilentlyContinue |
                        Measure-Object -Property Length -Sum).Sum / 1MB, 1)
        $shardCount = (Get-ChildItem -Path $_.FullName -Recurse -ErrorAction SilentlyContinue |
                       Where-Object { $_.Name -match 'model-\d+-of-\d+\.safetensors|pytorch_model-\d+-of-\d+\.bin' }).Count
        $blobDir    = Join-Path $_.FullName 'blobs'
        $blobCount  = if (Test-Path $blobDir) {
                          (Get-ChildItem -Path $blobDir -File -ErrorAction SilentlyContinue |
                           Where-Object { $_.Length -gt 52428800 }).Count
                      } else { 0 }
        if ($shardCount -gt 0) {
            Write-Found "  [~${modelSizeMB}MB] HuggingFace: $modelName  ($shardCount weight shards)"
        } elseif ($blobCount -gt 0) {
            Write-Found "  [~${modelSizeMB}MB] HuggingFace: $modelName  ($blobCount large blob(s))"
        } else {
            Write-Found "  [~${modelSizeMB}MB] HuggingFace: $modelName"
        }
    }
}

# ── LM Studio: partial / incomplete downloads ─────────────────────────────────
@("$env:USERPROFILE\.lmstudio", "$env:USERPROFILE\.cache\lm-studio", "$env:APPDATA\LM Studio") | ForEach-Object {
    if (Test-Path $_) {
        Get-ChildItem -Path $_ -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '\.part$|\.download$|\.incomplete$' } |
            ForEach-Object {
                $sizeMB = [math]::Round($_.Length / 1MB, 1)
                Write-Warn "LM Studio partial download [~${sizeMB}MB]: $($_.FullName)"
                $splitFound++
            }
    }
}

# ── GPT4All / Jan: flag suspiciously small .gguf (stub / incomplete) ──────────
@("$env:LOCALAPPDATA\nomic.ai\GPT4All", "$env:USERPROFILE\jan\models") | ForEach-Object {
    if (Test-Path $_) {
        Get-ChildItem -Path $_ -Recurse -Filter '*.gguf' -ErrorAction SilentlyContinue |
            Where-Object { $_.Length -lt 1MB } |
            ForEach-Object {
                $sizeMB = [math]::Round($_.Length / 1KB, 1)
                Write-Warn "Possibly incomplete model file [${sizeMB}KB]: $($_.FullName)"
            }
    }
}

if ($splitFound -eq 0) { Write-Info "No split/blob model stores detected." }

# --- 8. ALL STANDARD MODEL FILES FOUND ----------------------------------------
Write-Header "8. All Standard Model Files Found"
Write-Info "(searching user profile...)"
Get-ChildItem -Path $env:USERPROFILE -Recurse -Include $ModelExtensions -ErrorAction SilentlyContinue |
    ForEach-Object {
        $sizeMB = [math]::Round($_.Length / 1MB, 1)
        Write-Info "[${sizeMB}MB] $($_.FullName)"
    }

# --- 9. PROHIBITED MODEL SCAN -------------------------------------------------
Write-Header "9. Prohibited / Foreign-Origin Model Scan  [FBI-DEEPSEEK; HOUSE-DEEPSEEK]"
Get-ChildItem -Path $env:USERPROFILE -Recurse -Include $ModelExtensions -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match $ProhibitedPattern } |
    ForEach-Object { Write-Prohibited "PROHIBITED: $($_.FullName)" }

if (Get-Command ollama 2>$null) {
    ollama list 2>$null | Where-Object { $_ -match $ProhibitedPattern } |
        ForEach-Object { Write-Prohibited "PROHIBITED OLLAMA MODEL: $_" }
}

# Also check HuggingFace Hub model names
if (Test-Path "$env:USERPROFILE\.cache\huggingface\hub") {
    Get-ChildItem -Path "$env:USERPROFILE\.cache\huggingface\hub" -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^models--' } |
        ForEach-Object {
            $mn = $_.Name -replace '^models--', '' -replace '--', '/'
            if ($mn -match $ProhibitedPattern) {
                Write-Prohibited "PROHIBITED HuggingFace model: $mn"
            }
        }
}

Get-ChildItem -Path $env:USERPROFILE -Recurse -Include $ModelExtensions -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match $ReviewPattern } |
    ForEach-Object { Write-Review "VERIFY ORIGIN: $($_.FullName)" }

# --- 10. NETWORK EXPOSURE -----------------------------------------------------
Write-Header "10. Network Exposure Check  [NIST SP 800-53 SC-7: Boundary Protection]"
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

# --- 11. OLLAMA HOST ENV ------------------------------------------------------
Write-Header "11. Ollama Configuration [NIST SP 800-53 SC-7, IA-3]"
$oh = [System.Environment]::GetEnvironmentVariable('OLLAMA_HOST', 'User')
if ($oh) {
    if ($oh -match '0\.0\.0\.0|^:') { Write-Warn "OLLAMA_HOST=$oh - EXPOSED! [NIST SP 800-53 SC-7]" }
    else { Write-Found "OLLAMA_HOST=$oh" }
} else { Write-Info "OLLAMA_HOST not set (defaults to localhost)." }

# --- 12. MCP CONFIG SCAN ------------------------------------------------------
Write-Header "12. MCP Config Files  [NIST AI 100-2; NSA-AI-SECURITY]"
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
