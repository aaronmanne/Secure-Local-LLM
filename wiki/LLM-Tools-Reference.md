# LLM Tools Reference

Detailed reference for all local LLM inference servers and runtimes detected by the hardening scripts. For each tool: default port, model storage locations, how to verify it is running, and key security notes.

> ⚠️ **Any service binding to `0.0.0.0` is network-exposed.** All should be restricted to `127.0.0.1` per [NIST SP 800-53 SC-7](https://csrc.nist.gov/publications/detail/sp/800-53/rev-5/final).

---

## Full Tool Reference Table

| Tool | Default Port(s) | Windows Model Dir | macOS Model Dir | Linux Model Dir | Notes |
|---|---|---|---|---|---|
| **Ollama** | `11434` | `%USERPROFILE%\.ollama\models` | `~/.ollama/models` | `/usr/share/ollama/.ollama/models` | Config via `OLLAMA_HOST` |
| **LM Studio** | `1234` | `%USERPROFILE%\.lmstudio\models` | `~/.lmstudio/models` | `~/.lmstudio/models` | GUI-based config |
| **LocalAI** | `8080` | `./models` | `./models` | `/usr/share/local-ai/models` | Often binds `0.0.0.0` |
| **GPT4All** | varies | `%LOCALAPPDATA%\nomic.ai\GPT4All` | `~/Library/Application Support/nomic.ai/GPT4All/` | `~/.local/share/nomic.ai/GPT4All/` | Local GUI or server |
| **Jan.ai** | varies | `~/jan/models/` | `~/jan/models/` | `~/jan/models/` | Folder-based |
| **LM Deploy** | `8000` | N/A | `~/.lmdeploy/` | `~/.lmdeploy/` | HuggingFace backend |
| **text-generation-webui** | `7860` | `~/text-generation-webui/models` | same | same | Gradio UI; also `5000` |
| **KoboldCPP / KoboldAI** | `5001` | `~/koboldcpp/` | `~/.cache/koboldcpp/` | `~/.cache/koboldcpp/` | Formerly `50013` |
| **TabbyML / Tabby** | `8080` / `5000` | `%LOCALAPPDATA%\Programs\Tabby` | `~/.tabby/` | `~/.tabby/` | AI coding server |
| **vLLM** | `8000` | N/A | N/A | pip-installed | GPU inference; cluster-capable |
| **Xinference** | `9997` | N/A | `~/.cache/xinference/` | `~/.cache/xinference/` | Distributed inference |
| **PrivateGPT** | `8001` | `~/privategpt/models` | same | same | RAG-enabled local LLM |
| **AnythingLLM** | `3001` | `%LOCALAPPDATA%\Programs\AnythingLLM` | `~/anythingllm/` | `~/anythingllm/` | Multi-model frontend |
| **Msty** | varies | `%LOCALAPPDATA%\Programs\Msty` | `~/Library/Application Support/Msty/` | N/A | Desktop GUI |
| **SillyTavern** | `8000` | `~/SillyTavern/` | same | same | Chat frontend / RP |
| **Open WebUI** | `3000` | Docker / pip | Docker / pip | Docker / pip | Ollama frontend |
| **LibreChat** | `3080` | Docker | Docker | Docker | Multi-provider chat UI |
| **LlamaFile** | `8080` | portable binary | portable binary | portable binary | Self-contained WASM |
| **Nitro / Cortex** | `39291` | `%USERPROFILE%\.cortex/` | `~/.cortex/` | `~/.cortex/` | Jan.ai inference engine |
| **SGLang** | `30000` | pip | pip | pip | Structured generation server |
| **FastChat** | `8000` | pip | pip | pip | Vicuna/ChatGLM serving |

---

## Per-Tool Detail

### Ollama

**Default model storage:**
- Windows: `%USERPROFILE%\.ollama\models`
- macOS: `~/.ollama/models`
- Linux: `/usr/share/ollama/.ollama/models` or `~/.ollama/models`

**Default API port:** `11434`
**Config:** `OLLAMA_HOST` environment variable; files under `~/.ollama/` (manifests, model registrations)

**How to check if running:**
```bash
ollama list
curl http://localhost:11434/api/tags
```

**How to check what models are loaded:**
```bash
ollama list
ls -la ~/.ollama/models
cat ~/.ollama/manifests/*
```

> ⚠️ **WARNING:** If Ollama is bound to `0.0.0.0` (all interfaces) it is **network-exposed**. Check `echo $OLLAMA_HOST` and the [Network Exposure Checks](Network-Exposure-Checks) page.

---

### LM Studio

**Default model storage:**
- Windows: `C:\Users\<user>\.lmstudio\models` or `%USERPROFILE%\.cache\lm-studio\models`
- macOS: `~/.lmstudio/models` or `~/Library/Application Support/LM Studio/`
- Linux: `~/.lmstudio/models`

**Default local server port:** `1234` (when running server mode)
**Config:** GUI-based; check server/API settings for bind address and port

**How to check if running:**
```bash
# macOS/Linux
curl http://localhost:1234/v1/models

# Windows PowerShell
Invoke-RestMethod -Uri http://localhost:1234/v1/models
```

> 📝 LM Studio often caches models in multiple locations — check both `.lmstudio` and application support directories.

---

### LocalAI

**Default model directories:** `/usr/share/local-ai/models` or `./models`
**Default port:** `8080`

**How to check if running:**
```bash
curl http://localhost:8080/v1/models
sudo systemctl status localai
```

> ⚠️ **WARNING:** LocalAI deployments in containers or systemd units commonly bind to `0.0.0.0` — confirm bind address before use.

---

### GPT4All

**Default storage:**
- Windows: `C:\Users\<user>\AppData\Local\nomic.ai\GPT4All\`
- macOS: `~/Library/Application Support/nomic.ai/GPT4All/`
- Linux: `~/.local/share/nomic.ai/GPT4All/`

**Port:** varies (local GUI or optional local server)

---

### Jan.ai

**Typical model folder:** `~/jan/models/`
**Port:** varies by deployment

---

### Open WebUI / Frontends Connecting to Ollama Backend

Many WebUIs and frontends proxy requests to Ollama or LocalAI backends. Check WebUI configs for backend URLs. Look for config files like `config.json`, `webui-settings.json`, or direct command-line arguments.

---

## Useful Commands Reference Card

```bash
# Find all model files (macOS/Linux)
sudo find / -type f \( -name "*.gguf" -o -name "*.bin" -o -name "*.safetensors" \) 2>/dev/null | tee /tmp/llm-find-results.txt

# List Ollama models
ollama list

# Check LM Studio server
curl http://localhost:1234/v1/models

# Kill Ollama process
ps aux | grep ollama
kill <PID>

# Check Ollama env var
echo $OLLAMA_HOST

# Scan for open LLM ports
ss -tlnp | grep -E "11434|1234|8080" || netstat -an | grep -E "11434|1234|8080"

# Check Ollama manifests
ls -la ~/.ollama/models
grep -R "FROM\|source\|url" ~/.ollama -n || true
```

```powershell
# Windows – search for model files
Get-ChildItem -Path "$env:USERPROFILE" -Recurse -Include *.gguf,*.bin,*.safetensors -ErrorAction SilentlyContinue
```

---

← [Back to Wiki Home](Home)
