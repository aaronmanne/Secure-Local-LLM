#Requires -Version 5.1
<#
.SYNOPSIS
    Windows LLM Hardening Script
    Regulatory basis: NIST SP 800-53 SC-7, AC-6, AU-2, CM-7;
                      NIST AI 600-1; DFARS 252.204-7012; CMMC 2.0
#>

# ─── Execution Policy Guard ───────────────────────────────────────────────────
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

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

function Write-Header  { param($t) Write-Host "`n=== $t ===" -ForegroundColor Cyan }
function Write-Ok      { param($t) Write-Host "[OK]     $t" -ForegroundColor Green }
function Write-Warn    { param($t) Write-Host "[WARN]   $t" -ForegroundColor Yellow }
function Write-Action  { param($t) Write-Host "[ACTION] $t" -ForegroundColor Cyan }
function Write-Skip    { param($t) Write-Host "  [SKIP] $t" }
function Confirm-Step  { param($m) ($Host.UI.PromptForChoice('', $m, @('&Yes','&No'), 1)) -eq 0 }

Write-Host @"
╔══════════════════════════════════════════════════════════╗
║           Windows LLM Hardening Script                  ║
║  Ref: NIST SP 800-53 SC-7 · AC-6 · AU-2 · CM-7         ║
║       NIST AI 600-1 · DFARS 252.204-7012 · CMMC 2.0    ║
╚══════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan
Write-Host "Date: $(Get-Date) | Host: $env:COMPUTERNAME | User: $env:USERNAME"
if (-not $isAdmin) { Write-Warn "Not running as Administrator — firewall/service steps will be skipped." }
Write-Host ""
if (-not (Confirm-Step "Continue with hardening?")) { Write-Host "Aborted."; exit 0 }

# ─── 1. STOP PROCESSES / SERVICES ─────────────────────────────────────────────
Write-Header "1. Stop LLM / Agent Processes  [NIST SP 800-53 CM-7]"
$stopNames = @('ollama','lmstudio','lm-studio','localai','jan','koboldcpp','tabby','text-generation-webui','vllm')
foreach ($name in $stopNames) {
    $procs = Get-Process -Name $name -ErrorAction SilentlyContinue
    if ($procs -and (Confirm-Step "  Stop process '$name'?")) {
        Stop-Process -Name $name -Force; Write-Ok "Stopped: $name"
    }
}
$ollamaSvc = Get-Service 'ollama' -ErrorAction SilentlyContinue
if ($ollamaSvc) { Stop-Service 'ollama' -Force; Write-Ok "Ollama service stopped." }

# ─── 2. RESTRICT OLLAMA TO LOCALHOST ──────────────────────────────────────────
Write-Header "2. Restrict Ollama to Localhost  [NIST SP 800-53 SC-7, IA-3]"
[System.Environment]::SetEnvironmentVariable('OLLAMA_HOST', '127.0.0.1', 'User')
Write-Ok "OLLAMA_HOST=127.0.0.1 (user scope)"
if ($isAdmin) {
    [System.Environment]::SetEnvironmentVariable('OLLAMA_HOST', '127.0.0.1', 'Machine')
    Write-Ok "OLLAMA_HOST=127.0.0.1 (machine scope)"
    $svcReg = 'HKLM:\SYSTEM\CurrentControlSet\Services\ollama'
    if (Test-Path $svcReg) {
        $env = (Get-ItemProperty $svcReg).Environment
        $newEnv = ($env | Where-Object { $_ -notmatch 'OLLAMA_HOST' }) + 'OLLAMA_HOST=127.0.0.1'
        Set-ItemProperty -Path $svcReg -Name 'Environment' -Value $newEnv
        Write-Ok "Ollama service registry updated."
    }
}

# ─── 3. WINDOWS FIREWALL ──────────────────────────────────────────────────────
Write-Header "3. Firewall Rules  [NIST SP 800-53 SC-7; CMMC AC.L2-3.1.3]"
if (-not $isAdmin) { Write-Skip "Firewall rules require Administrator."; }
else {
    foreach ($portEntry in $LLM_Ports.GetEnumerator()) {
        $port = $portEntry.Key; $tool = $portEntry.Value
        Remove-NetFirewallRule -DisplayName "LLM-Block-$port" -ErrorAction SilentlyContinue
        Remove-NetFirewallRule -DisplayName "LLM-Allow-Localhost-$port" -ErrorAction SilentlyContinue
        New-NetFirewallRule -DisplayName "LLM-Block-$port" -Direction Inbound -Protocol TCP `
            -LocalPort $port -RemoteAddress '0.0.0.0/0' -Action Block -Profile Any `
            -Description "LLM Hardening [NIST SC-7]: block external access to $tool port $port" | Out-Null
        New-NetFirewallRule -DisplayName "LLM-Allow-Localhost-$port" -Direction Inbound -Protocol TCP `
            -LocalPort $port -RemoteAddress '127.0.0.1' -Action Allow -Profile Any `
            -Description "LLM Hardening [NIST SC-7]: allow localhost access to $tool port $port" | Out-Null
        Write-Ok "Firewall: $port ($tool) — blocked external / allowed localhost"
    }
}

# ─── 4. FILE PERMISSIONS ──────────────────────────────────────────────────────
Write-Header "4. Restrict Model Directory Permissions  [NIST SP 800-53 AC-3, AC-6]"
foreach ($dir in $ModelDirs) {
    if (Test-Path $dir) {
        $acl = Get-Acl $dir
        $acl.SetAccessRuleProtection($true, $false)
        $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            $currentUser, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
        $acl.ResetAccessRule($rule)
        Set-Acl -Path $dir -AclObject $acl -ErrorAction SilentlyContinue
        Write-Ok "Owner-only permissions: $dir  [NIST AC-6]"
    }
}

# ─── 5. PROHIBITED MODEL REMOVAL ──────────────────────────────────────────────
Write-Header "5. Prohibited Model Removal  [FBI-DEEPSEEK; HOUSE-DEEPSEEK; NIST AI 600-1 §2.5]"
$quarantineDir = "$env:USERPROFILE\llm-quarantine-$(Get-Date -Format 'yyyyMMdd_HHmmss')"
$foundProhibited = 0
Get-ChildItem -Path $env:USERPROFILE -Recurse -Include $ModelExtensions -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match $ProhibitedPattern } |
    ForEach-Object {
        if ($foundProhibited -eq 0) {
            New-Item -ItemType Directory -Path $quarantineDir -Force | Out-Null
            Write-Warn "Quarantine: $quarantineDir"
        }
        $foundProhibited++
        if (Confirm-Step "  Quarantine: $($_.FullName)?") {
            Move-Item -Path $_.FullName -Destination $quarantineDir -Force
            Write-Ok "Quarantined: $($_.Name)"
        }
    }
if (Get-Command ollama 2>$null) {
    ollama list 2>$null | Where-Object { $_ -match $ProhibitedPattern } | ForEach-Object {
        $m = ($_ -split '\s+')[0]
        if (Confirm-Step "  Remove Ollama model '$m'?") { ollama rm $m; Write-Ok "Removed: $m" }
    }
}
if ($foundProhibited -eq 0) { Write-Ok "No prohibited models found." }

# ─── 6. DISABLE AUTO-START ────────────────────────────────────────────────────
Write-Header "6. Disable Auto-Start  [NIST SP 800-53 CM-7]"
if ($isAdmin -and $ollamaSvc -and $ollamaSvc.StartType -ne 'Disabled') {
    if (Confirm-Step "  Disable Ollama service auto-start?") {
        Set-Service -Name 'ollama' -StartupType Disabled; Write-Ok "Ollama service disabled."
    }
}
@('HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run','HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run') |
    ForEach-Object {
        $key = $_
        Get-ItemProperty $key 2>$null | ForEach-Object {
            $_.PSObject.Properties | Where-Object { $_.Value -match 'ollama|lmstudio|localai|gpt4all|jan|kobold|tabby|oobabooga|anythingllm' } |
                ForEach-Object {
                    if (Confirm-Step "  Remove startup entry '$($_.Name)'?") {
                        Remove-ItemProperty -Path $key -Name $_.Name -ErrorAction SilentlyContinue
                        Write-Ok "Removed startup: $($_.Name)"
                    }
                }
        }
    }

# ─── 7. AUDIT LOG ─────────────────────────────────────────────────────────────
Write-Header "7. Hardening Log  [NIST SP 800-53 AU-2, AU-12]"
$logFile = "$env:USERPROFILE\llm-hardening-$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
@"
LLM Hardening Report — Windows
Date: $(Get-Date)
Host: $env:COMPUTERNAME  |  User: $env:USERNAME  |  Admin: $isAdmin
Regulatory basis: NIST SP 800-53, NIST AI 600-1, DFARS 252.204-7012, CMMC 2.0

--- OLLAMA_HOST ---
$([System.Environment]::GetEnvironmentVariable('OLLAMA_HOST','User'))

--- Ollama Models ---
$(try { ollama list 2>$null } catch { "N/A" })

--- Listening Ports ---
$(netstat -an 2>$null | Select-String ($LLM_PortArray -join '|'))

--- Firewall ---
$(netsh advfirewall show currentprofile 2>$null | Select-String 'State')
"@ | Out-File -FilePath $logFile -Encoding UTF8
Write-Ok "Log saved: $logFile  [NIST AU-2]"

# ─── REFERENCES ───────────────────────────────────────────────────────────────
Show-FederalReferences

Write-Host "`n=== Hardening Complete ===" -ForegroundColor Green
Write-Host "Run audit.ps1 to verify posture."
