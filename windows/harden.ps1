#Requires -Version 5.1
<#
.SYNOPSIS
    Windows LLM Hardening Script
    Applies security controls to restrict local LLM tool exposure
    Run as Administrator for firewall and service operations
#>

$ErrorActionPreference = 'SilentlyContinue'

$ProhibitedPattern = 'deepseek|qwen|qwq|yi-\d|baichuan|chatglm|internlm|minimax|ernie|hunyuan|tigerbot|aquila|moss|belle|rugpt|saiga|fred-t5|falcon'

function Write-Header  { param($t) Write-Host "`n=== $t ===" -ForegroundColor Cyan }
function Write-Ok      { param($t) Write-Host "[OK]     $t" -ForegroundColor Green }
function Write-Warn    { param($t) Write-Host "[WARN]   $t" -ForegroundColor Yellow }
function Write-Action  { param($t) Write-Host "[ACTION] $t" -ForegroundColor Cyan }
function Write-Skip    { param($t) Write-Host "  [SKIP] $t" }
function Confirm-Step  {
    param($msg)
    $r = Read-Host "$msg [y/N]"
    return ($r -match '^[Yy]$')
}

# Check for admin
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

Write-Host @"
╔══════════════════════════════════════════════════════════╗
║           Windows LLM Hardening Script                  ║
╚══════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

if (-not $isAdmin) {
    Write-Warn "Not running as Administrator. Some steps (firewall, service) will be skipped."
    Write-Warn "Re-run as Administrator for full hardening."
}

Write-Host "Date: $(Get-Date)"
Write-Host "Host: $env:COMPUTERNAME / User: $env:USERNAME"
Write-Host ""

if (-not (Confirm-Step "Continue with hardening?")) { Write-Host "Aborted."; exit 0 }

# ─── 1. STOP LLM PROCESSES ────────────────────────────────────────────────────
Write-Header "1. Stop Running LLM Processes"
$llmNames = @('ollama','lmstudio','lm-studio','localai','jan')
foreach ($name in $llmNames) {
    $procs = Get-Process -Name $name -ErrorAction SilentlyContinue
    if ($procs) {
        if (Confirm-Step "  Stop process '$name'?") {
            Stop-Process -Name $name -Force
            Write-Ok "Stopped: $name"
        }
    } else {
        Write-Skip "$name not running."
    }
}

# Stop Ollama service if it exists
$ollamaSvc = Get-Service -Name 'ollama' -ErrorAction SilentlyContinue
if ($ollamaSvc) {
    Write-Action "Stopping Ollama Windows service..."
    Stop-Service -Name 'ollama' -Force
    Write-Ok "Ollama service stopped."
}

# ─── 2. RESTRICT OLLAMA TO LOCALHOST ──────────────────────────────────────────
Write-Header "2. Restrict Ollama to Localhost"

$currentOllamaHost = [System.Environment]::GetEnvironmentVariable('OLLAMA_HOST', 'User')
if ($currentOllamaHost -and $currentOllamaHost -notmatch '127\.0\.0\.1') {
    Write-Warn "OLLAMA_HOST is currently: $currentOllamaHost"
}

Write-Action "Setting OLLAMA_HOST=127.0.0.1 for current user..."
[System.Environment]::SetEnvironmentVariable('OLLAMA_HOST', '127.0.0.1', 'User')
Write-Ok "OLLAMA_HOST set to 127.0.0.1 (user scope)."

if ($isAdmin) {
    [System.Environment]::SetEnvironmentVariable('OLLAMA_HOST', '127.0.0.1', 'Machine')
    Write-Ok "OLLAMA_HOST set to 127.0.0.1 (machine scope)."

    # Update Ollama service environment if service exists
    $svcReg = 'HKLM:\SYSTEM\CurrentControlSet\Services\ollama'
    if (Test-Path $svcReg) {
        $env = (Get-ItemProperty $svcReg).Environment
        $newEnv = ($env | Where-Object { $_ -notmatch 'OLLAMA_HOST' }) + 'OLLAMA_HOST=127.0.0.1'
        Set-ItemProperty -Path $svcReg -Name 'Environment' -Value $newEnv
        Write-Ok "Updated Ollama service registry with OLLAMA_HOST=127.0.0.1"
    }
}

# ─── 3. WINDOWS FIREWALL RULES ────────────────────────────────────────────────
Write-Header "3. Windows Firewall – Block LLM Ports"
if (-not $isAdmin) {
    Write-Warn "Firewall rules require Administrator. Skipping."
} else {
    $llmPorts = @(11434, 1234, 8080)
    foreach ($port in $llmPorts) {
        # Remove any existing rule for this port
        Remove-NetFirewallRule -DisplayName "LLM-Block-$port" -ErrorAction SilentlyContinue

        # Block inbound from non-localhost
        New-NetFirewallRule -DisplayName "LLM-Block-$port" `
            -Direction Inbound `
            -Protocol TCP `
            -LocalPort $port `
            -RemoteAddress '0.0.0.0/0' `
            -Action Block `
            -Profile Any `
            -Description "LLM Hardening: block external access to port $port" | Out-Null

        # Allow inbound from localhost only
        Remove-NetFirewallRule -DisplayName "LLM-Allow-Localhost-$port" -ErrorAction SilentlyContinue
        New-NetFirewallRule -DisplayName "LLM-Allow-Localhost-$port" `
            -Direction Inbound `
            -Protocol TCP `
            -LocalPort $port `
            -RemoteAddress '127.0.0.1' `
            -Action Allow `
            -Profile Any `
            -Description "LLM Hardening: allow localhost access to port $port" | Out-Null

        Write-Ok "Firewall: port $port blocked (external) / allowed (localhost)."
    }
}

# ─── 4. FILE PERMISSIONS ──────────────────────────────────────────────────────
Write-Header "4. Restrict Model Directory Permissions"
$modelDirs = @(
    "$env:USERPROFILE\.ollama",
    "$env:USERPROFILE\.lmstudio",
    "$env:USERPROFILE\jan",
    "$env:USERPROFILE\.cache\lm-studio"
)
foreach ($dir in $modelDirs) {
    if (Test-Path $dir) {
        Write-Action "Restricting permissions on $dir"
        $acl = Get-Acl $dir
        $acl.SetAccessRuleProtection($true, $false)  # disable inheritance
        # Remove all except current user
        $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            $currentUser, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
        $acl.ResetAccessRule($rule)
        Set-Acl -Path $dir -AclObject $acl -ErrorAction SilentlyContinue
        Write-Ok "Permissions restricted to current user only: $dir"
    }
}

# ─── 5. PROHIBITED MODEL REMOVAL ──────────────────────────────────────────────
Write-Header "5. Prohibited Model Removal"
$quarantineDir = "$env:USERPROFILE\llm-quarantine-$(Get-Date -Format 'yyyyMMdd_HHmmss')"
$foundProhibited = 0

Get-ChildItem -Path $env:USERPROFILE -Recurse -Include '*.gguf','*.bin','*.safetensors' -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match $ProhibitedPattern } |
    ForEach-Object {
        if ($foundProhibited -eq 0) {
            New-Item -ItemType Directory -Path $quarantineDir -Force | Out-Null
            Write-Warn "Prohibited models found. Quarantine: $quarantineDir"
        }
        $foundProhibited++
        if (Confirm-Step "  Quarantine: $($_.FullName)?") {
            Move-Item -Path $_.FullName -Destination $quarantineDir -Force
            Write-Ok "Quarantined: $($_.Name)"
        }
    }

if (Get-Command ollama 2>$null) {
    ollama list 2>$null | Where-Object { $_ -match $ProhibitedPattern } | ForEach-Object {
        $modelName = ($_ -split '\s+')[0]
        if (Confirm-Step "  Remove Ollama model: $modelName?") {
            ollama rm $modelName
            Write-Ok "Removed Ollama model: $modelName"
        }
    }
}
if ($foundProhibited -eq 0) { Write-Ok "No prohibited models found." }

# ─── 6. DISABLE AUTO-START ────────────────────────────────────────────────────
Write-Header "6. Disable LLM Auto-Start"
if ($isAdmin) {
    $ollamaSvc2 = Get-Service -Name 'ollama' -ErrorAction SilentlyContinue
    if ($ollamaSvc2 -and $ollamaSvc2.StartType -ne 'Disabled') {
        if (Confirm-Step "  Disable Ollama Windows service auto-start?") {
            Set-Service -Name 'ollama' -StartupType Disabled
            Write-Ok "Ollama service startup disabled."
        }
    }
} else {
    Write-Skip "Service management requires Administrator."
}

# Check for startup registry entries
$startupKeys = @(
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
)
foreach ($key in $startupKeys) {
    $props = Get-ItemProperty $key 2>$null
    if ($props) {
        $props.PSObject.Properties | Where-Object { $_.Value -match 'ollama|lmstudio|localai|gpt4all|jan' } | ForEach-Object {
            Write-Warn "Startup entry: $($_.Name) = $($_.Value)"
            if (Confirm-Step "  Remove startup entry '$($_.Name)'?") {
                Remove-ItemProperty -Path $key -Name $_.Name -ErrorAction SilentlyContinue
                Write-Ok "Removed startup entry: $($_.Name)"
            }
        }
    }
}

# ─── 7. AUDIT LOG ─────────────────────────────────────────────────────────────
Write-Header "7. Hardening Log"
$logFile = "$env:USERPROFILE\llm-hardening-$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

@"
LLM Hardening Report – Windows
Date: $(Get-Date)
Host: $env:COMPUTERNAME
User: $env:USERNAME
Admin: $isAdmin

--- OLLAMA_HOST ---
$([System.Environment]::GetEnvironmentVariable('OLLAMA_HOST', 'User'))

--- Ollama Models ---
$(try { ollama list 2>$null } catch { "Ollama not available" })

--- Listening Ports ---
$(netstat -an | Select-String '11434|1234|8080')

--- Firewall Profile ---
$(netsh advfirewall show currentprofile 2>$null | Select-String 'State')
"@ | Out-File -FilePath $logFile -Encoding UTF8

Write-Ok "Log saved: $logFile"

Write-Host "`n=== Hardening Complete ===" -ForegroundColor Green
Write-Host "Run audit.ps1 to verify posture."
