# Incident Response

Procedures for responding to unauthorized LLM installations, prohibited model discoveries, exposed inference services, and MCP credential exposure incidents.

> **Escalation:** Category: `LLM Unauthorized Installation / Prohibited Model Found` | Severity: **HIGH**
> Include in ticket: Host, username, model filename(s), evidence bundle

---

## Step-by-Step Response Procedure

### 1. Isolate / Quarantine — Stop the Service Immediately

```bash
# Find the process
ps aux | grep -E "ollama|lmstudio|localai|gpt4all|jan"

# Kill the process
kill <PID>

# Stop systemd unit (Linux)
sudo systemctl stop ollama || true
sudo systemctl stop localai || true

# Disable auto-restart (Linux)
sudo systemctl disable ollama || true

# Stop macOS launch daemon
sudo launchctl unload /Library/LaunchDaemons/com.ollama.ollama.plist 2>/dev/null || true

# Windows — stop service
Stop-Service -Name "ollama" -ErrorAction SilentlyContinue
```

---

### 2. Collect Evidence

Document and preserve evidence before any remediation:

```bash
# Create evidence directory
mkdir -p /tmp/llm-audit-evidence

# Copy model directory listing
ls -laR ~/.ollama/models > /tmp/llm-audit-evidence/model-listing.txt 2>/dev/null
ls -laR ~/.lmstudio > /tmp/llm-audit-evidence/lmstudio-listing.txt 2>/dev/null

# List registered Ollama models
ollama list > /tmp/llm-audit-evidence/ollama-list.txt 2>/dev/null

# Capture open ports
ss -tlnp > /tmp/llm-audit-evidence/ss.txt
netstat -an > /tmp/llm-audit-evidence/netstat.txt

# Capture process list at time of discovery
ps aux > /tmp/llm-audit-evidence/ps-aux.txt

# Capture Ollama environment
env | grep -i ollama > /tmp/llm-audit-evidence/ollama-env.txt

# Capture Ollama manifest files
cp -a ~/.ollama/manifests /tmp/llm-audit-evidence/ 2>/dev/null || true

# Compute checksums of suspicious model files
find ~/.ollama/models -type f -exec sha256sum {} \; > /tmp/llm-audit-evidence/checksums.txt 2>/dev/null

# Archive everything
tar -czf /tmp/llm-audit-evidence-$(hostname)-$(date +%Y%m%d).tar.gz /tmp/llm-audit-evidence/
```

---

### 3. Document & Escalate

Create a **HIGH severity incident ticket** including:
- Hostname and IP address
- Username of the account under which the LLM tool was running
- Model filenames and paths
- Output of `ollama list`
- Network binding information (was it exposed to the network?)
- MCP configuration files, if found
- Evidence archive path or attachment

---

### 4. Remove or Quarantine Prohibited Model Files

```bash
# Create quarantine directory
sudo mkdir -p /var/quarantine/llm-removed

# Move and lock suspicious models
sudo mv ~/.ollama/models/<suspicious-model-name> /var/quarantine/llm-removed/
sudo chmod 000 /var/quarantine/llm-removed/<suspicious-model-name>

# For LM Studio models
sudo mv ~/.lmstudio/models/<suspicious-model> /var/quarantine/llm-removed/
sudo chmod 000 /var/quarantine/llm-removed/<suspicious-model>
```

**Do not delete model files** until forensic review is complete — they may be needed as evidence.

---

### 5. Credential Exposure Response (MCP / Config Files)

If API keys, tokens, passwords, or other credentials were found in MCP config files or LLM tool configurations:

1. **Escalate immediately** — do not wait; treat as a credential compromise incident
2. Identify all credentials exposed (API keys, AWS access keys, database passwords, etc.)
3. **Rotate all exposed credentials immediately** through the appropriate service/provider
4. Review access logs for the exposed credentials going back to the date the MCP config was created
5. Assess whether any unauthorized access occurred using the exposed credentials
6. File a separate credential compromise incident ticket

---

### 6. Reinforce Network and Host Controls

After containment:

```bash
# Linux — add firewall rules (ufw)
sudo ufw deny in 11434
sudo ufw deny in 1234
sudo ufw deny in 8080
sudo ufw reload

# macOS — add pf rules (add to /etc/pf.conf)
# block in quick proto tcp from any to any port {11434, 1234, 8080}
# sudo pfctl -f /etc/pf.conf
```

**Windows (PowerShell as Administrator):**
```powershell
New-NetFirewallRule -DisplayName "Block Ollama" -Direction Inbound -Protocol TCP -LocalPort 11434 -Action Block
New-NetFirewallRule -DisplayName "Block LM Studio" -Direction Inbound -Protocol TCP -LocalPort 1234 -Action Block
New-NetFirewallRule -DisplayName "Block LocalAI" -Direction Inbound -Protocol TCP -LocalPort 8080 -Action Block
```

---

### 7. Follow Up with InfoSec / Compliance

- If CUI or other regulated data may have been processed or transmitted through the unauthorized LLM tool, follow the DFARS 252.204-7012(c) cyber incident reporting requirements — report to the DoD within 72 hours
- Engage the organization's compliance officer for assessment under applicable frameworks (CMMC, HIPAA, PCI DSS, etc.)
- Determine whether a broader forensic analysis of the system is warranted

---

### 8. Restore / Remediate

- Reimage or purge user data per policy if the system is assessed as compromised
- Re-enroll the system through standard configuration management
- Apply the hardening scripts in this repository before returning the system to service

---

## Regulatory Reporting Requirements

| Regulation | Reporting Requirement |
|---|---|
| **DFARS 252.204-7012** | Report cyber incidents to DoD within **72 hours** of discovery; preserve and submit images of compromised systems if required |
| **FISMA** | Report to US-CERT / CISA per agency policy |
| **HIPAA** | Report PHI breaches to HHS; notify affected individuals within 60 days |
| **CMMC** | Report incidents per the organization's System Security Plan (SSP) and Incident Response Plan (IRP) |

---

← [Back to Wiki Home](Home)
