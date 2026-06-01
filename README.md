# Securing Local LLM Software
### Best Practices and Federal Contractor Considerations

> **Regulatory Coverage:** NIST AI 100-1 · NIST AI 600-1 · NIST SP 800-53 Rev 5 · NIST SP 800-171 Rev 3 · EO 14110 · OMB M-24-10 · CISA AI Guidance · NSA-AI-SECURITY · FBI DeepSeek Advisory · DFARS 252.204-7012 · CMMC 2.0 · FISMA

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Key Risks](#key-risks)
3. [Best Practices for Securing Local LLM Tools](#best-practices-for-securing-local-llm-tools)
4. [Common Local LLM Tools – What to Know](#common-local-llm-tools--what-to-know)
   - [Inference Servers & Runtimes](#inference-servers--runtimes)
   - [AI Agent Frameworks & Coding Agents](#ai-agent-frameworks--coding-agents)
   - [Vector Databases (RAG Backends)](#vector-databases-rag-backends)
5. [Model File Types to Know](#model-file-types-to-know)
6. [Foreign / Prohibited Model Names to Watch For](#foreign--prohibited-model-names-to-watch-for)
7. [How to Search for These on a System](#how-to-search-for-these-on-a-system)
8. [How to Identify Model Origin](#how-to-identify-model-origin)
9. [Network Exposure Checks](#network-exposure-checks)
10. [Quick Audit Checklist for IT Staff](#quick-audit-checklist-for-it-staff)
11. [What to Do When You Find a Violation](#what-to-do-when-you-find-a-violation)
12. [Approved Model Sources](#approved-model-sources-reference)
13. [Useful Commands Reference Card](#useful-commands-reference-card)
14. [MCP (Model Context Protocol) Security](#mcp-model-context-protocol-security)
15. [U.S. Federal Guidance & Regulatory Citations](#us-federal-guidance--regulatory-citations)
16. [Using the Hardening Scripts in This Repo](#using-the-hardening-scripts-in-this-repo)

---

## Executive Summary

Local LLM tools such as **Ollama** and **LM Studio** can provide valuable capabilities for development, testing, and isolated workflows, but they also introduce significant security and compliance risk when deployed without proper safeguards. Exposed local inference services, weak or absent authentication, unrestricted model downloads, unsafe tool-enabled workflows, and insufficient monitoring can lead to:

- Unauthorized access
- Data leakage
- Resource abuse
- Loss of control over model provenance and use

For **federal contractors and other regulated organizations**, these risks extend beyond technical hardening to include governance, contractual compliance, and data handling obligations. Organizations should ensure that:

- Only approved models and configurations are used
- Local services are restricted to `localhost` unless explicitly authorized
- Appropriate controls for authentication, encryption, logging, and review of plugins/integrations are applied before treating these tools as suitable for enterprise use

---

## Key Risks

The primary risks arise when local developer-oriented tooling is used as an enterprise service **without corresponding controls**:

- **Network exposure** of local inference endpoints (e.g., Ollama on port `11434`, LM Studio on port `1234`)
- **Lack of native authentication**, or failure to require API tokens when supported
- **Plain-text or weakly protected traffic** when requests leave localhost
- **Unrestricted model acquisition** from public sources without provenance review
- **Execution of high-risk tool, plugin, or MCP-enabled workflows**
- **Prompt injection, jailbreak, or sensitive data disclosure** through downstream applications
- **GPU, CPU, memory, and storage exhaustion** caused by untrusted or excessive requests
- **Use of models that are not contractually, legally, or organizationally approved**

---

## Best Practices for Securing Local LLM Tools

Any local LLM tool should be treated as a **developer-oriented component**, not an internet-facing production service.

| Control | Recommendation |
|---|---|
| Network binding | Keep local inference services bound to `127.0.0.1` (localhost) |
| Remote access | If required, place behind a hardened reverse proxy with auth, TLS, rate limiting, and logging |
| Firewall | Block direct exposure to LLM ports via host firewall, cloud security groups, and network segmentation |
| File permissions | Restrict permissions for model files and configuration directories |
| OS hardening | Apply operating system hardening standards |
| Updates | Keep LLM software and dependencies updated |
| Model sources | Limit downloads to approved sources only |
| Optional features | Enable tool use, plugins, MCP, CORS, or network serving only after security review |

---

## Common Local LLM Tools – What to Know

### Inference Servers & Runtimes

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

> ⚠️ **Any service binding to `0.0.0.0` is network-exposed.** All should be restricted to `127.0.0.1` per [NIST SP 800-53 SC-7](https://csrc.nist.gov/publications/detail/sp/800-53/rev-5/final).

---

### AI Agent Frameworks & Coding Agents

AI agent frameworks present a **distinct and elevated risk profile** from inference servers. They can autonomously execute code, read/write files, browse the web, call external APIs, and chain multi-step actions — often with the developer's own credentials and without per-action confirmation. Each framework below must be inventoried and its external integrations reviewed before use on federal or sensitive systems.

> **Regulatory basis:** [NIST AI 600-1 §2.6](https://doi.org/10.6028/NIST.AI.600-1) (Third-Party Integrations); [NIST SP 800-53 SA-4](https://csrc.nist.gov/publications/detail/sp/800-53/rev-5/final) (Acquisition Process); [NSA CSI: Deploying AI Systems Securely](https://media.defense.gov/2024/Apr/15/2003439257/-1/-1/0/CSI-DEPLOYING-AI-SYSTEMS-SECURELY.PDF)

| Tool / Framework | Category | Config Location | Key Risk | Approval Required? |
|---|---|---|---|---|
| **AutoGPT** | Autonomous agent | `~/.autogpt/` / `~/AutoGPT/` | Autonomous web/shell access | ✅ Yes |
| **AgentGPT** | Autonomous agent | Browser-based / `~/.agentgpt/` | Cloud-hosted; data leaves device | ✅ Yes |
| **BabyAGI** | Task-chaining agent | pip / `~/babyagi/` | Persistent task loops; API calls | ✅ Yes |
| **SuperAGI** | Multi-agent platform | Docker / `~/superagi/` | Tool use; external integrations | ✅ Yes |
| **CrewAI** | Multi-agent framework | pip / `~/.crewai/` | Agents call external APIs autonomously | ✅ Yes |
| **AutoGen** (Microsoft) | Multi-agent framework | pip / `~/.autogen/` | Code execution; network access | ✅ Yes |
| **OpenDevin / OpenHands** | Software dev agent | pip / `~/.opendevin/` | Full shell + repo write access | ✅ Yes |
| **GPT-Engineer** | Code generation agent | pip / `~/gpt-engineer/` | Writes and runs code autonomously | ✅ Yes |
| **Open Interpreter** | Shell/code interpreter | pip; CLI `interpreter` | Direct OS shell execution | ✅ Yes |
| **Aider** | AI coding assistant | pip; `~/.aider*` | Reads/writes entire repo; git commits | ✅ Review |
| **Goose** (Block) | Developer agent | pip; `~/.goose/` | Shell execution; file R/W | ✅ Yes |
| **Plandex** | Code planning agent | binary; `~/.plandex/` | Multi-file rewrites | ✅ Review |
| **Mentat** | AI coding assistant | pip; `~/.mentat/` | Repo-wide file edits | ✅ Review |
| **OpenClaw** | Autonomous agent | varies | Shell + API access | ✅ Yes |
| **SWE-agent** | GitHub issue solver | pip / Docker | Runs code; submits PRs | ✅ Yes |
| **Devika** | Software dev agent | pip / `~/devika/` | Browser + shell + code | ✅ Yes |
| **Sweep** | GitHub AI assistant | GitHub App / pip | Writes code; opens PRs | ✅ Review |
| **GPT-Pilot** | Full-stack dev agent | pip / `~/gpt-pilot/` | Scaffolds + runs full apps | ✅ Yes |
| **LangChain / LangGraph** | Agent orchestration | pip; `~/.langchain/` | Chains of tool calls; external APIs | ✅ Review |
| **Haystack** | NLP / RAG pipeline | pip | Document processing; API calls | ✅ Review |
| **Flowise** | Visual agent builder | npm; `~/flowise/` | Port `3000`; no auth by default | ✅ Yes |
| **Dify** | LLM app platform | Docker; `~/dify/` | Port `3000`; external integrations | ✅ Yes |
| **n8n** | Workflow automation | npm/Docker; `~/.n8n/` | Connects to any external service | ✅ Yes |
| **MemGPT / Letta** | Long-context agent | pip; `~/.memgpt/` / `~/.letta/` | Persistent memory; tool use | ✅ Review |
| **mem0** | Agent memory layer | pip; `~/.mem0/` | Stores sensitive context | ✅ Review |
| **TaskWeaver** (Microsoft) | Data analytics agent | pip / Docker | Code execution; data access | ✅ Yes |
| **Phidata / Agno** | Agent framework | pip | Multi-modal; external APIs | ✅ Review |
| **DSPy** | LM programming | pip | Optimizes prompts; API calls | ✅ Review |
| **Hermes Agent** | Nous Research agent framework | varies | Tool-calling; external integrations | ✅ Review |
| **ActivePieces** | Workflow automation | Docker | External API connections | ✅ Yes |
| **PraisonAI** | Multi-agent framework | pip | Orchestrates multiple agents | ✅ Review |

> 🔴 **No AI agent framework should be granted access to CUI, PII, PHI, credentials, or production systems without a formal security review aligned to [NIST AI 600-1](https://doi.org/10.6028/NIST.AI.600-1) and [DFARS 252.204-7012](https://www.acquisition.gov/dfars/252.204-7012-safeguarding-covered-defense-information-and-cyber-incident-reporting.).**

---

### Vector Databases (RAG Backends)

Vector databases store embedded representations of documents and are often connected to LLM pipelines (RAG). They can inadvertently expose sensitive document content and should be treated as data stores requiring the same protections as the underlying data.

| Tool | Default Port | Notes |
|---|---|---|
| **Qdrant** | `6333` (REST), `6334` (gRPC) | No auth by default in local mode |
| **Chroma / ChromaDB** | `8000` | Embedded or server mode |
| **Weaviate** | `8080` | GraphQL API; no auth by default |
| **Milvus** | `19530` | Production-grade; auth optional |
| **pgvector** | `5432` (PostgreSQL) | Inherits Postgres auth |
| **Redis Stack** | `6379` | Redis with vector search |

> **Ref:** [NIST SP 800-53 SC-28](https://csrc.nist.gov/publications/detail/sp/800-53/rev-5/final) (Protection of Information at Rest)

---

### Comparison Table (Original Core Tools)

| Tool | Windows Default Model Dir | macOS Default | Linux Default | Default Port | Notes |
|---|---|---|---|---|---|
| **Ollama** | `%USERPROFILE%\.ollama\models` | `~/.ollama/models` | `/usr/share/ollama/.ollama/models` or `~/.ollama/models` | `11434` | Config via `OLLAMA_HOST` env var |
| **LM Studio** | `C:\Users\<user>\.lmstudio\models` or `%USERPROFILE%\.cache\lm-studio\models` | `~/.lmstudio/models` or `~/Library/Application Support/LM Studio/` | `~/.lmstudio/models` | `1234` (server mode) | GUI-based config |
| **LocalAI** | varies – often `./models` | same | `/usr/share/local-ai/models` or `./models` | `8080` | Often binds `0.0.0.0` by default |
| **GPT4All** | `C:\Users\<user>\AppData\Local\nomic.ai\GPT4All\` | `~/Library/Application Support/nomic.ai/GPT4All/` | `~/.local/share/nomic.ai/GPT4All/` | varies | Local GUI or server |
| **Jan.ai** | `~/jan/models/` | `~/jan/models/` | `~/jan/models/` | varies | Folder-based models |

---

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

> ⚠️ **WARNING:** If Ollama is bound to `0.0.0.0` (all interfaces) it is **network-exposed**. See [Network Exposure Checks](#network-exposure-checks).

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

> 📝 **NOTE:** LM Studio often caches models in multiple locations — check both `.lmstudio` and application support directories.

---

### LocalAI

**Default model directories:** `/usr/share/local-ai/models` or `./models`  
**Default port:** `8080`

**How to check if running:**
```bash
curl http://localhost:8080/v1/models
sudo systemctl status localai
```

> ⚠️ **WARNING:** LocalAI deployments in containers or systemd units commonly bind to `0.0.0.0` — confirm bind address.

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

### Open WebUI / Anything Connecting to Ollama Backend

Many WebUIs and frontends can proxy requests to Ollama or LocalAI backends. Check WebUI configs for backend URLs. Look for config files like `config.json`, `webui-settings.json`, or direct command-line arguments.

---

## Model File Types to Know

| Extension | Description |
|---|---|
| `.gguf` | Most common modern single-file format; includes metadata |
| `.bin` | Older binary weight files (common extension, hard to isolate) |
| `.safetensors` | Hugging Face-compatible safe tensor format |
| `.ggml` | Older GGML formats |
| `.pt` / `.pth` | PyTorch weight files |
| `.q4_0`, `.q4_k_m`, `.q8_0` | Quantized version suffixes |

---

## Foreign / Prohibited Model Names to Watch For

> 🚨 **WARNING:** Chinese-origin models are **HIGH RISK** — flag immediately for security review per federal guidance.

| Pattern / Name | Typical Origin | Action |
|---|---|---|
| `deepseek`, `deepseek-r1`, `deepseek-v2`, `deepseek-coder` | DeepSeek AI (China) | 🔴 **PROHIBITED** – Flag/Remove immediately |
| `qwen`, `qwen2`, `qwen2.5`, `qwq` | Alibaba Cloud (China) | 🔴 **PROHIBITED** – Flag/Remove immediately |
| `yi`, `yi-34b`, `yi-6b` | 01.AI (China) | 🔴 **PROHIBITED** – Flag/Remove immediately |
| `baichuan`, `baichuan2` | Baichuan AI (China) | 🔴 **PROHIBITED** – Flag/Remove immediately |
| `chatglm`, `glm-4`, `codegeex` | Zhipu AI / Tsinghua (China) | 🔴 **PROHIBITED** – Flag/Remove immediately |
| `internlm`, `internlm2` | Shanghai AI Lab (China) | 🔴 **PROHIBITED** – Flag/Remove immediately |
| `minimax` | MiniMax (China) | 🔴 **PROHIBITED** – Flag/Remove immediately |
| `ernie`, `ernie-bot` | Baidu (China) | 🔴 **PROHIBITED** – Flag/Remove immediately |
| `hunyuan` | Tencent (China) | 🔴 **PROHIBITED** – Flag/Remove immediately |
| `tigerbot` | TigerBot (China) | 🔴 **PROHIBITED** – Flag/Remove immediately |
| `aquila` | BAAI – Beijing Academy of AI (China) | 🔴 **PROHIBITED** – Flag/Remove immediately |
| `moss` | Fudan University (China) | 🔴 **PROHIBITED** – Flag/Remove immediately |
| `belle` | BELLE Group (China) | 🔴 **PROHIBITED** – Flag/Remove immediately |
| `chinese-alpaca`, `chinese-llama` | Chinese community fine-tunes | 🔴 **PROHIBITED** – Flag/Remove immediately |
| `falcon` (TII, UAE) | Technology Innovation Institute, UAE | 🔴 **PROHIBITED** – Flag/Remove immediately |
| `rugpt`, `rugpt3` | Sber AI (Russia) | 🔴 **PROHIBITED** – Flag/Remove immediately |
| `saiga` | Russian fine-tunes | 🔴 **PROHIBITED** – Flag/Remove immediately |
| `fred-t5` | Sber AI (Russia) | 🔴 **PROHIBITED** – Flag/Remove immediately |

---

## How to Search for These on a System

**Windows PowerShell:**
```powershell
Get-ChildItem -Path "$env:USERPROFILE\.ollama\models" -Recurse -File |
  Where-Object { $_.Name -match "deepseek|qwen|qwq|yi-|baichuan|chatglm|internlm|minimax|ernie|hunyuan|tigerbot|aquila|moss|belle|rugpt|saiga" }
```

**macOS / Linux (bash):**
```bash
find ~/.ollama/models -type f | grep -iE "deepseek|qwen|qwq|yi-[0-9]|baichuan|chatglm|internlm|minimax|ernie|hunyuan|tigerbot|aquila|moss|belle|rugpt|saiga"

find ~/.lmstudio -type f -name "*.gguf" | grep -iE "deepseek|qwen|qwq|yi-[0-9]|baichuan|chatglm|internlm|minimax|ernie|hunyuan|tigerbot|aquila|moss|belle|rugpt|saiga"
```

**Check registered Ollama models:**
```bash
ollama list
```

---

## How to Identify Model Origin

- **Model card / Hugging Face:** Check `huggingface.co/[org]/[model]` — look at organization and country.
- **Organization name:** Names like `deepseek-ai`, `qwen`, `baichuan` are strong indicators.
- **Ollama manifests / FROM lines:**
  ```bash
  grep -R "FROM\|source\|url" ~/.ollama -n || true
  ```
- **Inspect `.gguf` metadata:**
  ```bash
  gguf-dump metadata path/to/model.gguf
  strings path/to/model.gguf | head -n 200
  ```

**🚩 Red flags:**
- Model card/README primarily in Chinese
- Organization or repo registered in China
- `FROM` lines pointing to Chinese registries
- Filenames matching prohibited patterns

---

## Network Exposure Checks

Services should bind to `localhost (127.0.0.1)`. If bound to `0.0.0.0` or an external IP, **treat as exposed**.

**Linux / macOS:**
```bash
netstat -an | grep -E "11434|1234|8080"
ss -tlnp | grep -E "11434|1234|8080"
sudo lsof -i -P -n | grep -E "11434|1234|8080"
# BAD:  0.0.0.0:11434 (exposed to network)
# GOOD: 127.0.0.1:11434 (local only)
```

**Windows PowerShell:**
```powershell
netstat -an | findstr "11434 1234 8080"
Get-NetTCPConnection -LocalPort 11434,1234,8080
```

**Check Ollama host binding:**
```bash
echo $OLLAMA_HOST
# Should be empty or 127.0.0.1, NOT 0.0.0.0
```

**Mitigations:**
1. Reconfigure bind address to `127.0.0.1` or firewall the port immediately
2. Use OS firewall to block external access
3. Stop the service if unauthorized

---

## Quick Audit Checklist for IT Staff

- [ ] Identify whether LLM software is installed — check processes: `ollama`, `lmstudio`, `localai`, `gpt4all`, `jan`
- [ ] List models present — run `ollama list` and inspect model directories
- [ ] Search for prohibited/foreign model names (see [Foreign Model Names](#foreign--prohibited-model-names-to-watch-for))
- [ ] Check network bindings — confirm bind address is `127.0.0.1`
- [ ] Check firewall rules — verify port blocking
- [ ] Check API authentication — is the API reachable without auth?
- [ ] Check for plugins / MCP / third-party integrations
- [ ] Document findings in ticket and escalate if violations found

---

## What to Do When You Find a Violation

> **Escalation:** Category: `LLM Unauthorized Installation / Prohibited Model Found` | Severity: **HIGH**  
> Include: Host, user, model filename(s), evidence bundle

1. **Isolate / Quarantine** — stop the service immediately:
   ```bash
   ps aux | grep ollama
   kill <PID>
   sudo systemctl stop ollama || true
   ```

2. **Collect evidence** — save directory listings, model filenames, checksums, `ollama list` output:
   ```bash
   mkdir -p /tmp/llm-audit-evidence
   cp -a ~/.ollama/models /tmp/llm-audit-evidence/
   ollama list > /tmp/llm-audit-evidence/ollama-list.txt
   ss -tlnp > /tmp/llm-audit-evidence/ss.txt
   ```

3. **Document & Escalate** — create a HIGH severity ticket with evidence attached

4. **Remove or quarantine model files:**
   ```bash
   sudo mkdir -p /var/quarantine/llm-removed
   sudo mv ~/.ollama/models/<suspicious-model> /var/quarantine/llm-removed/
   sudo chmod 000 /var/quarantine/llm-removed/<suspicious-model>
   ```

5. **Reinforce network and host controls** — add firewall rules, remove auto-restart units

6. **Follow up with InfoSec / Compliance** for deeper forensic analysis

7. **Restore / Remediate** — reimage or purge user data per policy if needed

---

## Approved Model Sources (Reference)

| Model Family | Typical Origin | Status |
|---|---|---|
| Meta Llama | Meta AI (USA) | ✅ OK with approval |
| Mistral | Mistral AI (France/EU) | ✅ OK – verify contract |
| Microsoft Phi series | Microsoft (USA) | ✅ OK – check license |
| Google Gemma | Google (USA) | ✅ OK – check license |
| OpenAI (via API) | OpenAI (USA) | ✅ OK – authorized environments |
| Anthropic Claude (API) | Anthropic (USA) | ✅ OK – managed API access |
| Cohere | Canada/USA | ✅ OK – verify contract |
| IBM Granite | IBM (USA) | ✅ OK – check license |
| Amazon Titan (Bedrock) | AWS (USA) | ✅ OK – FedRAMP options available |

> 📝 **Note:** All models must go through the organization's **model approval workflow** before use on federal work.

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
# Windows – search for prohibited model names
Get-ChildItem -Path "$env:USERPROFILE" -Recurse -Include *.gguf,*.bin,*.safetensors -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -match "deepseek|qwen|qwq|yi-|baichuan|chatglm|internlm|minimax|ernie|hunyuan|tigerbot|aquila|moss|belle|rugpt|saiga" }
```

---

## MCP (Model Context Protocol) Security

### What Is MCP and Why It Matters for Security

**MCP (Model Context Protocol)** is an open protocol that allows AI coding tools — such as Claude Desktop, VS Code Copilot, Cursor, Continue.dev, and Ollama frontends — to connect to external "MCP servers" that provide executable tools, data resources, and prompt templates to the AI. MCP servers can run:

- **Locally** as subprocesses on the developer's machine (`stdio` transport)
- **Remotely** over HTTP/SSE on third-party infrastructure

Because MCP servers can execute code, read files, query databases, and call external APIs **on behalf of the AI** — often with the developer's own credentials — they represent a **significant and rapidly growing attack surface** that IT security teams must actively audit.

---

### MCP Attack Surface Overview

| Component | Description | Risk Level | Example Threat |
|---|---|---|---|
| Local MCP Server (stdio) | Runs as subprocess on developer machine | **HIGH** | Reads local files, `.env` vars, SSH keys, AWS credentials |
| Remote MCP Server (HTTP/SSE) | Runs on third-party infrastructure | **CRITICAL** | Data exfiltration to unknown/foreign party; no data sovereignty |
| MCP Tools | Executable functions the AI can call | **HIGH** | Shell execution, file read/write, database queries, API calls |
| MCP Resources | Data sources the AI can read | **MEDIUM-HIGH** | Indirect prompt injection via malicious document or DB record content |
| MCP Prompts | Reusable system prompt templates | **MEDIUM** | Malicious system prompt injection into AI context |

---

### Prohibited MCP Server Categories

The following MCP server types are **PROHIBITED** without explicit security team review and approval:

- 🔴 Any **remote MCP server operated by a foreign entity** — data sent to these servers may be logged, stored, or used for training outside your jurisdiction
- 🔴 MCP servers installed from **unvetted sources** — random GitHub repos, blog posts, npm/PyPI packages without code review and provenance verification
- 🔴 MCP servers with **shell/command execution capabilities** — unless explicitly authorized in writing by the security team
- 🔴 MCP servers that **connect to external APIs** without a signed data handling agreement
- 🔴 MCP servers with access to **production databases, patient records, HR systems, or financial data** without formal security review
- 🔴 **Any MCP server that has not been reviewed and approved** by the security team — approval required before installation on any work device

---

### Where MCP Servers Are Configured (How to Find Them)

**Claude Desktop:**
- macOS: `~/Library/Application Support/Claude/claude_desktop_config.json`
- Windows: `%APPDATA%\Claude\claude_desktop_config.json`

**VS Code (GitHub Copilot / Continue.dev / other extensions):**
- Workspace: `.vscode/mcp.json` or `.vscode/settings.json` (look for `mcp` or `mcpServers` keys)
- User-level (macOS): `~/Library/Application Support/Code/User/settings.json`
- User-level (Windows): `%APPDATA%\Code\User\settings.json`

**Cursor:**
- Global: `~/.cursor/mcp.json`
- Project-level: `.cursor/mcp.json` in any project directory
- macOS settings: `~/Library/Application Support/Cursor/User/settings.json`

**Continue.dev:**
- `~/.continue/config.json` — look for the `mcpServers` array

**General search (macOS/Linux):**
```bash
# Find Claude Desktop config
find ~ -name "claude_desktop_config.json" 2>/dev/null

# Find any mcp.json files
find ~ -name "mcp.json" 2>/dev/null

# Search all JSON files for mcpServers key
grep -r "mcpServers" ~/.config ~/.cursor ~/Library/Application\ Support ~/.continue 2>/dev/null | head -30
```

**General search (Windows PowerShell):**
```powershell
# Search APPDATA for any JSON files containing mcpServers
Get-ChildItem -Path "$env:APPDATA" -Recurse -Filter "*.json" -ErrorAction SilentlyContinue |
  Select-String -Pattern "mcpServers" | Select-Object Path

# Find mcp.json files under user profile
Get-ChildItem -Path "$env:USERPROFILE" -Recurse -Filter "mcp.json" -ErrorAction SilentlyContinue

# Find Claude Desktop config
Get-ChildItem -Path "$env:APPDATA\Claude" -Filter "claude_desktop_config.json" -ErrorAction SilentlyContinue
```

---

### How to Read an MCP Config File

MCP configurations follow a standard JSON structure. Example `claude_desktop_config.json` showing legitimate and suspicious entries:

```json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/Users/dev/projects"]
    },
    "suspicious-server": {
      "command": "node",
      "args": ["/tmp/mcp-server.js"]
    },
    "remote-server": {
      "url": "https://mcp.some-foreign-service.com/sse",
      "headers": { "Authorization": "Bearer sk-..." }
    }
  }
}
```

**🚩 Red flags to look for in any MCP config:**
- `url` key pointing to external/remote servers — especially unknown, foreign, or consumer-grade domains
- `command` running scripts from `/tmp`, `Downloads`, or unrecognized/temporary paths
- `npx -y` arguments — auto-installs npm packages at runtime without pinning versions (supply chain risk)
- API keys, tokens, or passwords embedded directly in the config file (credential exposure)
- Filesystem servers with broad root paths such as `/`, `~`, or `C:\`
- Database connection strings referencing production systems
- Any server name or URL you cannot immediately identify as an approved internal tool

---

### MCP Audit Commands

**macOS / Linux:**
```bash
# Find all MCP config files
find ~ -name "claude_desktop_config.json" -o -name "mcp.json" 2>/dev/null
grep -r "mcpServers" ~ --include="*.json" 2>/dev/null | grep -v ".git"

# Check for running MCP server processes
ps aux | grep -iE "mcp|modelcontext" | grep -v grep

# Check for suspicious outbound connections from common MCP runtimes
lsof -i -P -n | grep -iE "node|python|npx" | grep ESTABLISHED

# Check for node processes (most MCP servers run on Node.js)
ps aux | grep node | grep -v grep
```

**Windows PowerShell:**
```powershell
# Find Claude Desktop MCP config
Get-ChildItem -Path "$env:APPDATA\Claude" -Filter "claude_desktop_config.json" -ErrorAction SilentlyContinue

# Find all mcp.json files under user profile
Get-ChildItem -Path "$env:USERPROFILE" -Recurse -Filter "mcp.json" -ErrorAction SilentlyContinue

# Check running node/python processes (common MCP server runtimes)
Get-Process | Where-Object { $_.Name -match "node|python" }

# Check established network connections from those processes
Get-NetTCPConnection -State Established |
  Where-Object { $_.OwningProcess -in (Get-Process node,python -ErrorAction SilentlyContinue).Id }
```

---

### What to Do When You Find an Unauthorized MCP Server

1. **Document** the full contents of the config file; copy the JSON and note the file path, hostname, and username
2. **Classify** the server type: local (`command`/`args` keys) vs. remote (`url` key)
3. For **remote servers**: note the full URL; flag any unknown or foreign-operated domains immediately
4. For **local servers**: identify the command being run, its source path, and whether it was installed from a vetted package
5. **Check for embedded credentials**: scan the config for API keys, tokens, passwords, or connection strings — if found, treat as a **credential exposure incident**
6. If **unauthorized**: remove the server entry from the config file and kill any associated running processes
7. If **credentials were exposed**: escalate to InfoSec immediately for credential rotation — do not wait
8. Create a **HIGH severity ticket** with the config file contents, file path, hostname, username, and any credential exposure details

---

### MCP Security Best Practices for Developers

- Only install MCP servers from **sources reviewed and approved by the security team**
- **Never connect to remote MCP servers** without security team approval — treat them the same as connecting to an unknown third-party SaaS
- **Never grant MCP servers access to directories containing secrets** — explicitly exclude `.env`, `.ssh`, `~/.aws`, `~/.config`, and any credentials directories
- Apply the **principle of least privilege** — restrict filesystem MCP servers to the specific project directory only
- **Never use `npx -y`** for MCP servers in sensitive environments — pin to a specific, reviewed package version
- **Review MCP server source code** before installation; if you cannot read the source, do not install it
- Do not use MCP servers that require **broad system permissions** (root access, full filesystem, shell execution) unless formally approved
- Treat all MCP tool results as **untrusted input** — malicious content can inject instructions into the AI (indirect prompt injection)
- **Report any unexpected AI behavior** — unusual file reads, unexpected API calls, or requests to send data externally — to the security team immediately

---

### Data Classification and MCP

| Data Type | Examples | MCP Access Allowed? |
|---|---|---|
| PII | Names, SSNs, addresses, email addresses | 🔴 **NEVER** without a signed DPA and security review |
| PHI | Patient records, medical data, HIPAA-covered data | 🔴 **NEVER** without a signed DPA and security review |
| CUI | Controlled Unclassified Information | 🔴 **NEVER** via unapproved MCP server |
| Financial data | Payment card numbers, bank records, PCI-scoped data | 🔴 **NOT** without PCI DSS review and approval |
| Source code (proprietary) | Internal codebases, proprietary algorithms | ⚠️ Only via approved local MCP — **NO remote MCP servers** |
| API keys / credentials | `.env` files, SSH keys, cloud credentials | 🔴 **NEVER** — restrict MCP filesystem access to exclude credential paths |
| Corporate IP | Trade secrets, unreleased product designs, M&A data | ⚠️ Only via approved local MCP — **NO remote MCP servers** |

---

## U.S. Federal Guidance & Regulatory Citations

The controls and recommendations in this document and the accompanying hardening scripts are grounded in the following U.S. federal guidance frameworks. Federal contractors handling Controlled Unclassified Information (CUI), operating under DFARS clauses, or pursuing CMMC certification **must** comply with the applicable standards below before deploying local LLM tooling in covered environments.

---

### NIST AI Framework & Controls

| Citation | Title | URL |
|---|---|---|
| **NIST AI 100-1** | AI Risk Management Framework (AI RMF 1.0) | [doi.org/10.6028/NIST.AI.100-1](https://doi.org/10.6028/NIST.AI.100-1) |
| **NIST AI 100-2** | Adversarial Machine Learning: A Taxonomy and Terminology | [doi.org/10.6028/NIST.AI.100-2](https://csrc.nist.gov/pubs/ai/100/2/e2025/final) |
| **NIST AI 600-1** | AI Risk Management Framework for Generative AI *(directly covers LLMs)* | [doi.org/10.6028/NIST.AI.600-1](https://doi.org/10.6028/NIST.AI.600-1) |
| **NIST SP 800-53 Rev 5** | Security & Privacy Controls for Information Systems | [doi.org/10.6028/NIST.SP.800-53r5](https://doi.org/10.6028/NIST.SP.800-53r5) |
| **NIST SP 800-171 Rev 3** | Protecting CUI in Nonfederal Systems *(contractor baseline)* | [doi.org/10.6028/NIST.SP.800-171r3](https://doi.org/10.6028/NIST.SP.800-171r3) |
| **NIST SP 800-218** | Secure Software Development Framework (SSDF) | [doi.org/10.6028/NIST.SP.800-218](https://doi.org/10.6028/NIST.SP.800-218) |

**Key NIST SP 800-53 controls directly applicable to local LLM deployments:**

| Control | ID | LLM Application |
|---|---|---|
| Boundary Protection | SC-7 | Bind services to `127.0.0.1`; firewall LLM ports |
| Least Privilege | AC-6 | Restrict model file permissions to owner only |
| Identification & Authentication | IA-2, IA-3 | Require API tokens; never expose unauthenticated endpoints |
| Cryptographic Protection | SC-8, SC-28 | Encrypt traffic and model files at rest |
| Audit Events | AU-2, AU-12 | Log all inference requests, model loads, and config changes |
| Least Functionality | CM-7 | Disable unused LLM features: CORS, network serving, plugins |
| Component Inventory | CM-8 | Maintain an inventory of all models, tools, and agent frameworks |
| Supply Chain Protection | SA-12 | Verify model provenance; prohibit foreign-origin models |
| Malicious Code Protection | SI-3 | Scan agent plugins and MCP servers for malicious behavior |
| Information System Monitoring | SI-4 | Monitor for unauthorized LLM processes and outbound connections |

---

### Executive Orders

| Citation | Title | URL |
|---|---|---|
| **EO 14110** *(Oct 30, 2023)* | Executive Order on Safe, Secure, and Trustworthy Development and Use of AI | [federalregister.gov](https://www.federalregister.gov/documents/2023/11/01/2023-24283/safe-secure-and-trustworthy-development-and-use-of-artificial-intelligence) |
| **EO 14179** *(Jan 23, 2025)* | Removing Barriers to American Leadership in Artificial Intelligence | [whitehouse.gov](https://www.whitehouse.gov/presidential-actions/2025/01/removing-barriers-to-american-leadership-in-artificial-intelligence/) |

---

### OMB Policy Memoranda

| Citation | Title | URL |
|---|---|---|
| **OMB M-24-10** | Advancing Governance, Innovation, and Risk Management for Agency Use of AI | [whitehouse.gov (PDF)](https://www.whitehouse.gov/wp-content/uploads/2024/03/M-24-10-Advancing-Governance-Innovation-and-Risk-Management-for-Agency-Use-of-Artificial-Intelligence.pdf) |
| **OMB M-24-18** | Driving Efficient Acquisition of Artificial Intelligence in Government | [whitehouse.gov (PDF)](https://www.whitehouse.gov/wp-content/uploads/2025/02/M-25-22-Driving-Efficient-Acquisition-of-Artificial-Intelligence-in-Government.pdf) |

---

### CISA Advisories & Guidance

| Citation | Title | URL |
|---|---|---|
| **CISA AI Roadmap** | CISA Roadmap for Artificial Intelligence 2023–2024 | [cisa.gov (PDF)](https://www.cisa.gov/resources-tools/resources/roadmap-ai) |
| **CISA/NCSC Secure AI Dev** | Guidelines for Secure AI System Development *(joint with UK NCSC, ASD, CCCS, BSI)* | [ncsc.gov.uk (PDF)](https://www.ncsc.gov.uk/files/Guidelines-for-secure-AI-system-development.pdf) |
| **CISA AI Threats** | Defending AI Systems Against Adversarial Attacks | [cisa.gov/ai](https://www.cisa.gov/ai) |

---

### NSA Cybersecurity Guidance

| Citation | Title                                                                                 | URL |
|---|---------------------------------------------------------------------------------------|---|
| **NSA CSI: Deploying AI Securely** *(Apr 2024)* | Cybersecurity Information Sheet: Best Practices for Deploying AI Systems              | [media.defense.gov (PDF)](https://media.defense.gov/2024/Apr/15/2003439257/-1/-1/0/CSI-DEPLOYING-AI-SYSTEMS-SECURELY.PDF) |
| **NSA** | Model Context Protocol (MCP): Security Design Considerations for AI-Driven Automation | [nsa.gov](https://www.nsa.gov/Portals/75/documents/Cybersecurity/CSI_MCP_SECURITY.pdf?ver=bmgiSbNQLP6Z_GiWtRt6bg%3d%3d) |

---

### DOJ / FBI / Intelligence Community Warnings

> 🚨 **These advisories directly inform the prohibited model list in this repository.**

| Citation                         | Title | URL                                                                                                                 |
|----------------------------------|---|---------------------------------------------------------------------------------------------------------------------|
| **DOJ** *(DEC 2025)*             | U.S. Authorities Shut Down Major China-Linked AI Tech Smuggling Network | [justice.gov](https://www.justice.gov/opa/pr/us-authorities-shut-down-major-china-linked-ai-tech-smuggling-network) |
| **FBI/CISA Foreign AI Advisory** | Foreign State-Sponsored AI Tool Threats to U.S. Organizations | [fbi.gov](https://www.fbi.gov/investigate/counterintelligence/the-china-threat)                                     |

**Agencies and organizations that have formally banned or restricted DeepSeek and Chinese-origin AI models (as of 2025):**
- U.S. Navy
- NASA
- U.S. Congress (House and Senate IT systems)
- Pentagon / DoD components
- Multiple state governments (Texas, Virginia, others)
- Several allied foreign governments

---

### DoD / CMMC / DFARS

| Citation | Title | URL                                                                                                                                      |
|---|---|------------------------------------------------------------------------------------------------------------------------------------------|
| **CMMC 2.0** | DoD Cybersecurity Maturity Model Certification | [dodcio.defense.gov/CMMC](https://dodcio.defense.gov/CMMC/)                                                                              |
| **DOD Adopts Ethical Principles for Artificial Intelligence ** | Adopted Feb 2020 | [war.gov (PDF)](https://www.war.gov/News/Releases/release/article/2091996/dod-adopts-ethical-principles-for-artificial-intelligence/)    |
| **DFARS 252.204-7012** | Safeguarding Covered Defense Information and Cyber Incident Reporting | [acquisition.gov](https://www.acquisition.gov/dfars/252.204-7012-safeguarding-covered-defense-information-and-cyber-incident-reporting.) |
| **DISA STIGs** | Application Security & Development STIG *(applies to AI/ML components)* | [public.cyber.mil/stigs](https://public.cyber.mil/stigs/)                                                                                |

**Applicable CMMC 2.0 practices for LLM deployments:**

| Practice ID | Domain | Requirement |
|---|---|---|
| AC.L2-3.1.3 | Access Control | Control CUI flow; restrict to authorized users only |
| AC.L2-3.1.14 | Access Control | Route remote access via managed access control points |
| CM.L2-3.4.1 | Config Management | Establish and maintain baseline configurations |
| CM.L2-3.4.6 | Config Management | Employ principle of least functionality |
| CM.L2-3.4.7 | Config Management | Restrict/prohibit use of non-essential programs |
| IA.L2-3.5.3 | Identification & Auth | Use multifactor authentication for privileged accounts |
| SI.L2-3.14.2 | System Integrity | Provide protection from malicious code |
| SI.L2-3.14.7 | System Integrity | Identify unauthorized use of systems |

---

### FedRAMP

| Citation | Title | URL |
|---|---|---|
| **FedRAMP AI Guidance** | FedRAMP Guidance on AI/ML Services Authorization | [fedramp.gov/ai](https://www.fedramp.gov/ai/) |

> Cloud-based LLM APIs (OpenAI, Anthropic, Cohere, AWS Bedrock, etc.) used in federal contractor environments **must** be FedRAMP authorized or operate under an equivalent authorization framework. Local LLM tools are not subject to FedRAMP directly but must comply with all other applicable controls.

---

### Congressional & Legislative

| Citation | Title | URL                                                                                                                                                                       |
|---|---|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **NDAA FY2024 §1553** | National Defense Authorization Act AI Security Provisions | [congress.gov](https://www.congress.gov/bill/118th-congress/house-bill/2670)                                                                                              |
| **House CCP Committee Letter** *(Jan 2025)* | House Select Committee on CCP: Letter on DeepSeek Risks | [chinaselectcommittee.house.gov](https://chinaselectcommittee.house.gov/sites/evo-subsites/selectcommitteeontheccp.house.gov/files/evo-media-document/letter-to-doc-nvidia-deepseek-pla-use_final.pdf) |

---

### FISMA

| Citation | Title | URL |
|---|---|---|
| **FISMA 2014** | Federal Information Security Modernization Act | [cisa.gov](https://www.cisa.gov/topics/cyber-threats-and-advisories/federal-information-security-modernization-act) |

---

### Quick Reference: Control-to-Hardening Mapping

| Hardening Action | Applicable Controls |
|---|---|
| Bind LLM services to `127.0.0.1` | NIST SP 800-53 **SC-7**; CMMC **AC.L2-3.1.3** |
| Block LLM ports via firewall | NIST SP 800-53 **SC-7**; CMMC **AC.L2-3.1.3** |
| Restrict model directory permissions | NIST SP 800-53 **AC-3**, **AC-6**; CMMC **AC.L2-3.1.3** |
| Require API authentication | NIST SP 800-53 **IA-2**, **IA-3** |
| Audit log all LLM activity | NIST SP 800-53 **AU-2**, **AU-12** |
| Prohibit foreign-origin models | NIST AI 600-1 **§2.5**; FBI Advisory; HOUSE-DEEPSEEK |
| Review model provenance | NIST AI 600-1 **§2.5**; NIST SP 800-53 **SA-12** |
| Disable unused features (CORS, remote serving) | NIST SP 800-53 **CM-7**; CMMC **CM.L2-3.4.6** |
| MCP server review & approval | NIST AI 100-2; NSA-AI-SECURITY; NIST SP 800-53 **SI-3** |
| No agent access to CUI/credentials | NIST SP 800-171 **§3.1–3.14**; DFARS **252.204-7012** |
| Inventory all tools and models | NIST SP 800-53 **CM-8**; CMMC **CM.L2-3.4.1** |
| Encrypt data in transit | NIST SP 800-53 **SC-8** |
| Encrypt models at rest | NIST SP 800-53 **SC-28** |
| Incident reporting for violations | DFARS **252.204-7012(c)**; FISMA |

---

## Using the Hardening Scripts in This Repo

This repository contains scripts to help you audit and harden systems running local LLM tools. The scripts are organized by operating system:

```
Secure-Local-LLM/
├── README.md                      ← This file (federal guidance + full reference)
├── llm-hardening-menu.sh          ← Main menu launcher (macOS/Linux)
├── llm-hardening-menu.ps1         ← Main menu launcher (Windows)
│
├── common/                        ← Shared patterns — edit once, applies everywhere
│   ├── patterns.sh                ← All tool/agent/port/model patterns (bash)
│   ├── patterns.ps1               ← All tool/agent/port/model patterns (PowerShell)
│   ├── references.sh              ← Federal citations + print_federal_references()
│   └── references.ps1             ← Federal citations + Show-FederalReferences
│
├── macos/
│   ├── identify.sh                ← Identify LLMs, agents, models, MCP on macOS
│   ├── harden.sh                  ← Firewall (pf), localhost binding, quarantine
│   ├── audit.sh                   ← PASS/WARN/FAIL compliance checklist
│   └── mcp-audit.sh               ← Deep MCP/agent config + credential audit
│
├── linux/
│   ├── identify.sh                ← Identify LLMs, agents, Docker, systemd
│   ├── harden.sh                  ← ufw/firewalld/iptables + systemd overrides
│   ├── audit.sh                   ← PASS/WARN/FAIL compliance checklist
│   └── mcp-audit.sh               ← MCP/agent audit for Linux
│
└── windows/
    ├── identify.ps1               ← Registry, processes, files, network detection
    ├── harden.ps1                 ← Windows Firewall rules, env vars, ACLs
    ├── audit.ps1                  ← PASS/WARN/FAIL compliance checklist
    └── mcp-audit.ps1              ← MCP config analysis + outbound connections
```

### Covered Tools

The scripts detect and audit **all** of the following:

**Inference Servers:** Ollama · LM Studio · LocalAI · GPT4All · Jan.ai · text-generation-webui · KoboldCPP · TabbyML · vLLM · Xinference · PrivateGPT · AnythingLLM · Msty · LlamaFile · LM Deploy · SGLang · FastChat · Nitro/Cortex · Open WebUI · LibreChat · SillyTavern

**AI Agent Frameworks:** AutoGPT · AgentGPT · BabyAGI · SuperAGI · CrewAI · AutoGen · OpenDevin/OpenHands · GPT-Engineer · Open Interpreter · Aider · Goose · Plandex · Mentat · OpenClaw · SWE-agent · Devika · Sweep · GPT-Pilot · LangChain/LangGraph · Haystack · Flowise · Dify · n8n · MemGPT/Letta · mem0 · TaskWeaver · Phidata/Agno · Hermes Agent · PraisonAI · ActivePieces

**Vector Databases:** Qdrant · ChromaDB · Weaviate · Milvus · pgvector · Redis Stack

**Coding Agents / AI IDEs:** Cursor · Windsurf · Continue.dev · Cody (Sourcegraph) · GitHub Copilot (via MCP)

### Quick Start

**macOS / Linux:**
```bash
chmod +x llm-hardening-menu.sh
./llm-hardening-menu.sh
```

**Windows (PowerShell as Administrator):**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
.\llm-hardening-menu.ps1
```

The main menu will automatically detect your operating system and present the appropriate options.

---

*Document based on internal security guidance for federal contractors and regulated organizations deploying local LLM tooling.*
