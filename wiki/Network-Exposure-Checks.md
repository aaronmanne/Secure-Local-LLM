# Network Exposure Checks

Services should bind to `localhost (127.0.0.1)`. If bound to `0.0.0.0` or an external IP, **treat as exposed** and apply mitigations immediately.

> **Regulatory basis:** NIST SP 800-53 [SC-7 (Boundary Protection)](https://csrc.nist.gov/publications/detail/sp/800-53/rev-5/final)

---

## Common LLM Service Ports

| Service | Default Port |
|---|---|
| Ollama | `11434` |
| LM Studio | `1234` |
| LocalAI | `8080` |
| text-generation-webui | `7860`, `5000` |
| KoboldCPP | `5001` |
| TabbyML | `8080`, `5000` |
| vLLM | `8000` |
| AnythingLLM | `3001` |
| Open WebUI | `3000` |
| LibreChat | `3080` |
| LlamaFile | `8080` |
| Nitro/Cortex | `39291` |
| SGLang | `30000` |
| FastChat | `8000` |
| Flowise | `3000` |
| Dify | `3000` |
| Qdrant | `6333`, `6334` |
| Weaviate | `8080` |
| Milvus | `19530` |

---

## Network Binding Check Commands

### Linux / macOS

```bash
# Check what is listening on common LLM ports
netstat -an | grep -E "11434|1234|8080|7860|5001|3001|3000|3080|39291|30000|6333|19530"
ss -tlnp | grep -E "11434|1234|8080|7860|5001|3001|3000|3080|39291|30000|6333|19530"
sudo lsof -i -P -n | grep -E "11434|1234|8080|7860|5001|3001|3000|3080|39291|30000|6333|19530"

# BAD:  0.0.0.0:11434 — exposed to entire network
# GOOD: 127.0.0.1:11434 — local only
```

**Check Ollama specific binding:**
```bash
echo $OLLAMA_HOST
# Should be empty or 127.0.0.1 — NOT 0.0.0.0
```

### Windows PowerShell

```powershell
netstat -an | findstr "11434 1234 8080 7860 5001 3001 3000 3080 39291 30000 6333 19530"
Get-NetTCPConnection -LocalPort 11434,1234,8080,7860,5001,3001,3000,3080,39291,30000 -ErrorAction SilentlyContinue
```

---

## Mitigations for Exposed Services

### Immediate Actions

1. **Reconfigure bind address to `127.0.0.1`**
   - Ollama: set `OLLAMA_HOST=127.0.0.1:11434`
   - Other tools: check tool-specific config for bind address or host setting

2. **Add host firewall rules**

   **Linux (ufw):**
   ```bash
   sudo ufw deny in 11434
   sudo ufw deny in 1234
   sudo ufw deny in 8080
   ```

   **Linux (iptables):**
   ```bash
   sudo iptables -A INPUT -p tcp --dport 11434 -j DROP
   ```

   **macOS (pf) — add to `/etc/pf.conf`:**
   ```
   block in quick proto tcp from any to any port {11434, 1234, 8080}
   ```

   **Windows (PowerShell as Administrator):**
   ```powershell
   New-NetFirewallRule -DisplayName "Block Ollama" -Direction Inbound -Protocol TCP -LocalPort 11434 -Action Block
   New-NetFirewallRule -DisplayName "Block LM Studio" -Direction Inbound -Protocol TCP -LocalPort 1234 -Action Block
   ```

3. **Stop the service if unauthorized**
   ```bash
   ps aux | grep ollama
   kill <PID>
   sudo systemctl stop ollama || true
   ```

4. **Remove auto-restart units** — if a service is running without authorization, disable its auto-start:
   ```bash
   sudo systemctl disable ollama
   sudo launchctl unload /Library/LaunchDaemons/ollama.plist 2>/dev/null || true
   ```

---

## Checking for Outbound Connections from LLM Processes

Agent frameworks and MCP servers may establish unexpected outbound connections:

```bash
# macOS/Linux
sudo lsof -i -P -n | grep -E "node|python|ollama" | grep ESTABLISHED

# Windows
Get-NetTCPConnection -State Established |
  Where-Object { $_.OwningProcess -in (Get-Process node,python,ollama -ErrorAction SilentlyContinue).Id }
```

---

← [Back to Wiki Home](Home)
