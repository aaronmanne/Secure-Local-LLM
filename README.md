# Securing Local LLM Software
### Best Practices and Federal Contractor Considerations

> **Regulatory Coverage:**
> NIST AI 100-1 · NIST AI 600-1 · NIST SP 800-53 Rev 5 · NIST SP 800-171 Rev 3 · EO 14110 · OMB M-24-10 · CISA AI Guidance · NSA-AI-SECURITY · FBI DeepSeek Advisory · DFARS 252.204-7012 · CMMC 2.0 · FISMA

---

## Table of Contents

1. [Quick Start — Download, Install & Run the Scripts](#quick-start--download-install--run-the-scripts)
2. [Repository Structure](#repository-structure)
3. [Executive Summary](#executive-summary)
4. [Key Risks & Mitigations](#key-risks--mitigations)
5. [Hardening Guidelines Summary](#hardening-guidelines-summary)
6. [Approved Model Sources](#approved-model-sources)
7. [Quick Audit Checklist for IT Staff](#quick-audit-checklist-for-it-staff)
8. [What to Do When You Find a Violation](#what-to-do-when-you-find-a-violation)
9. [U.S. Federal Guidance & Regulatory Citations](#us-federal-guidance--regulatory-citations)
   - [NIST AI & Cybersecurity Frameworks](#nist-ai--cybersecurity-frameworks)
   - [Key NIST SP 800-53 Controls for LLM Deployments](#key-nist-sp-800-53-controls-for-llm-deployments)
   - [Executive Orders & OMB Policy](#executive-orders--omb-policy)
   - [CISA, NSA & Intelligence Community](#cisa-nsa--intelligence-community)
   - [DoD / CMMC / DFARS / FedRAMP](#dod--cmmc--dfars--fedramp)
   - [Applicable CMMC 2.0 Practices for LLM Deployments](#applicable-cmmc-20-practices-for-llm-deployments)
   - [Control-to-Hardening Mapping](#control-to-hardening-mapping)
10. [Detailed Technical Reference — Wiki](#detailed-technical-reference--wiki)

---

## Quick Start — Download, Install & Run the Scripts

### 1. Clone the Repository

```bash
git clone https://github.com/aaronmanne/Secure-Local-LLM.git
cd Secure-Local-LLM
```

### 2. Run the Main Menu

**macOS / Linux:**
```bash
chmod +x llm-hardening-menu.sh
./llm-hardening-menu.sh
```

**Windows — Recommended (handles signing automatically, prompts for UAC elevation):**
```bat
llm-hardening-menu.bat
```

**Windows — PowerShell direct:**
```powershell
# Option A: bypass signing for this session only (no permanent change)
powershell.exe -ExecutionPolicy Bypass -File .\llm-hardening-menu.ps1

# Option B: allow local scripts permanently for your user account
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
.\llm-hardening-menu.ps1
```

> **Why the signing warning?** Windows PowerShell's default `ExecutionPolicy` on many machines is `AllSigned` or `Restricted`, which blocks unsigned `.ps1` files. The `.bat` launcher handles this automatically — no permanent system policy changes are made. The scripts do not install anything or phone home.

### 3. What the Menu Offers

The main menu detects your OS and presents:
- **Identify** — Scans for installed LLM tools, agent frameworks, models, and MCP configs
- **Harden** — Applies firewall rules, restricts network binding, locks model file permissions
- **Audit** — Runs a PASS/WARN/FAIL compliance checklist aligned to NIST/CMMC controls
- **MCP Audit** — Deep inspection of Model Context Protocol server configurations and credentials

---

## Repository Structure

```
Secure-Local-LLM/
├── README.md                      ← This file (executive summary + quick start)
├── llm-hardening-menu.sh          ← Main menu launcher (macOS/Linux)
├── llm-hardening-menu.ps1         ← Main menu launcher (Windows PowerShell)
├── llm-hardening-menu.bat         ← Main menu launcher (Windows batch — recommended)
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

**The scripts detect and audit:** Ollama · LM Studio · LocalAI · GPT4All · Jan.ai · text-generation-webui · KoboldCPP · TabbyML · vLLM · Xinference · PrivateGPT · AnythingLLM · Msty · LlamaFile · LM Deploy · SGLang · FastChat · Nitro/Cortex · Open WebUI · LibreChat · SillyTavern · AutoGPT · CrewAI · AutoGen · OpenDevin/OpenHands · Open Interpreter · Aider · Goose · LangChain/LangGraph · Flowise · Dify · n8n · MemGPT/Letta · Qdrant · ChromaDB · Weaviate · Milvus · Cursor · Windsurf · Continue.dev · and more.

---

## Executive Summary

Local LLM tools such as **Ollama**, **LM Studio**, and AI agent frameworks provide valuable capabilities for development, testing, and isolated workflows — but they introduce **significant security and compliance risk** when deployed without proper safeguards.

These tools were designed for developer use on a single machine. They typically have **no authentication by default**, bind to network interfaces that may be reachable by other systems, download models from arbitrary public sources, and — in the case of agent frameworks — can autonomously execute code, read and write files, and call external APIs using the developer's own credentials.

For **federal contractors and regulated organizations**, these risks extend beyond technical hardening to include governance, contractual compliance (DFARS, CMMC), and data handling obligations (CUI, PII, PHI).

**The core requirement is simple:** before any local LLM tool or AI agent framework is used on a system that touches federal work, covered defense information, or regulated data, it must be inventoried, reviewed, and brought into compliance with the controls in this repository.

---

## Key Risks & Mitigations

| Risk | Description | Mitigation | Regulatory Basis |
|---|---|---|---|
| **Network Exposure** | Local inference services (Ollama `:11434`, LM Studio `:1234`, LocalAI `:8080`) may bind to all interfaces (`0.0.0.0`), making them reachable on the network without authentication | Restrict bind address to `127.0.0.1`; block LLM ports via host firewall and network segmentation | NIST SP 800-53 **SC-7** |
| **No Authentication** | Most local LLM servers expose unauthenticated APIs by default; any process or user on the machine — or network — can invoke inference | Require API tokens where supported; use reverse proxy with auth for any non-localhost access | NIST SP 800-53 **IA-2, IA-3** |
| **Uncontrolled Model Downloads** | Models can be downloaded from public registries (Hugging Face, Ollama Hub) without provenance review, including models from prohibited foreign origins | Enforce model approval workflow; block access to public model registries from work devices; run the identification scripts in this repo | NIST AI 600-1 **§2.5**; NIST SP 800-53 **SA-12** |
| **Prohibited / Foreign-Origin Models** | Models from Chinese- and Russian-origin organizations (DeepSeek, Qwen, Yi, ChatGLM, Baichuan, Falcon UAE, etc.) are prohibited for federal contractor use per FBI/IC advisories | Scan for and remove prohibited model names; see full list in the [wiki](../../wiki) | FBI DeepSeek Advisory; NIST AI 600-1 **§2.5**; NSA-AI-SECURITY |
| **AI Agent Framework Autonomy** | Agent frameworks (AutoGPT, CrewAI, Open Interpreter, Aider, etc.) can autonomously execute shell commands, commit code, and call external APIs — often with no per-action confirmation | No agent framework should access CUI, PII, PHI, credentials, or production systems without a formal security review | NIST AI 600-1 **§2.6**; DFARS **252.204-7012** |
| **MCP Server Attack Surface** | Model Context Protocol (MCP) servers extend AI tools with file access, database queries, shell execution, and external API calls; remote MCP servers may exfiltrate data to foreign infrastructure | Audit all MCP configurations; prohibit remote MCP servers without security review; restrict filesystem MCP servers to project directories only | NSA CSI: MCP Security; NIST SP 800-53 **SI-3** |
| **Prompt Injection / Data Disclosure** | Downstream applications feeding documents, web content, or database records into an LLM pipeline can be exploited to inject malicious instructions or disclose sensitive data | Treat all LLM inputs and outputs as untrusted; sandbox document processing pipelines; log and monitor for anomalous outputs | NIST AI 100-2; NIST SP 800-53 **SI-4** |
| **Unencrypted Traffic** | LLM API requests sent over plaintext HTTP expose inference content and any data in prompts | Use TLS for all non-localhost traffic; avoid exposing LLM endpoints to networks where plaintext is a risk | NIST SP 800-53 **SC-8** |
| **Sensitive Data in Model Context** | CUI, PII, PHI, source code, and credentials can be inadvertently included in prompts, logged by inference servers, or transmitted to cloud-based APIs | Classify data before submitting to any LLM; prohibit CUI/PII in prompts to cloud APIs; review logging configurations | NIST SP 800-171 **§3.1–3.14**; DFARS **252.204-7012** |
| **Resource Exhaustion** | Unrestricted inference requests can exhaust GPU, CPU, RAM, and storage, degrading other system services | Apply rate limiting; monitor resource usage; restrict who can submit inference requests | NIST SP 800-53 **SC-5** |
| **Unaudited Plugins and Integrations** | CORS enabled, open WebUI ports, and third-party plugins/extensions extend the attack surface of local LLM tools | Disable CORS, network serving, and all plugins/integrations unless explicitly reviewed and authorized | NIST SP 800-53 **CM-7**; CMMC **CM.L2-3.4.6** |
| **No Audit Trail** | Default configurations for local LLM tools typically do not log inference requests, model loads, or configuration changes | Enable inference logging; integrate with centralized SIEM; log model inventory changes | NIST SP 800-53 **AU-2, AU-12**; CMMC **AU.L2-3.3.1** |

---

## Hardening Guidelines Summary

Any local LLM tool should be treated as a **developer-oriented component**, not an internet-facing production service. Apply these controls before using local LLM tools on systems that handle federal work or regulated data:

| Control Area | Requirement |
|---|---|
| **Network Binding** | Bind all local inference services to `127.0.0.1` (localhost only) |
| **Firewall** | Block LLM ports (11434, 1234, 8080, etc.) via host firewall, cloud security groups, and network ACLs |
| **Remote Access** | If remote access is required, route through a hardened reverse proxy with authentication, TLS, rate limiting, and access logging |
| **Authentication** | Require API tokens for all LLM API access; never expose unauthenticated inference endpoints |
| **Model Provenance** | Download models only from approved sources; review and approve each model before use |
| **Prohibited Models** | Immediately remove models matching foreign/prohibited origin patterns (see [Prohibited Model List](../../wiki/Prohibited-Models)) |
| **Agent Frameworks** | No agent framework may access CUI, PII, PHI, credentials, or production systems without a written security review |
| **MCP Servers** | Audit all MCP configurations; prohibit remote MCP servers and unapproved local MCP servers |
| **File Permissions** | Restrict model file and configuration directory permissions to the owning user account |
| **Logging** | Enable inference request logging; forward to centralized audit log |
| **Encryption** | Use TLS for all non-localhost traffic; encrypt model files and sensitive config at rest |
| **Inventory** | Maintain a current inventory of all installed LLM tools, models, agent frameworks, and MCP servers |
| **Updates** | Keep all LLM software and dependencies patched and current |
| **Optional Features** | Enable tool use, plugins, MCP, CORS, or network serving **only** after documented security review |

---

## Approved Model Sources

> All models must go through your organization's **model approval workflow** before use on federal work.

| Model Family | Origin | Status |
|---|---|---|
| Meta Llama | Meta AI (USA) | ✅ OK with approval |
| Mistral | Mistral AI (France/EU) | ✅ OK – verify contract |
| Microsoft Phi series | Microsoft (USA) | ✅ OK – check license |
| Google Gemma | Google (USA) | ✅ OK – check license |
| OpenAI (via API) | OpenAI (USA) | ✅ OK – authorized environments only |
| Anthropic Claude (via API) | Anthropic (USA) | ✅ OK – managed API access |
| Cohere | Canada/USA | ✅ OK – verify contract |
| IBM Granite | IBM (USA) | ✅ OK – check license |
| Amazon Titan (Bedrock) | AWS (USA) | ✅ OK – FedRAMP options available |

> 🚨 **Chinese-origin and Russian-origin models are PROHIBITED.** See the [Prohibited Model List](../../wiki/Prohibited-Models) for the full list of banned model families and search patterns.

---

## Quick Audit Checklist for IT Staff

- [ ] Identify whether LLM software is installed — check for processes: `ollama`, `lmstudio`, `localai`, `gpt4all`, `jan`
- [ ] List all models present — run `ollama list` and inspect model directories
- [ ] Search for prohibited/foreign-origin model names (see [wiki: Prohibited Models](../../wiki/Prohibited-Models))
- [ ] Confirm network bindings — all services should bind to `127.0.0.1`, NOT `0.0.0.0`
- [ ] Verify firewall rules are blocking external access to LLM ports
- [ ] Confirm API endpoints require authentication
- [ ] Audit all MCP server configurations (run `mcp-audit` script)
- [ ] Verify no agent frameworks have access to CUI, credentials, or production systems
- [ ] Document findings and escalate any violations as HIGH severity

---

## What to Do When You Find a Violation

> **Escalation:** Category: `LLM Unauthorized Installation / Prohibited Model Found` | Severity: **HIGH**
> Include: Host, username, model filename(s), evidence bundle

1. **Isolate / Quarantine** — stop the service immediately
2. **Collect evidence** — save directory listings, model filenames, checksums, process output
3. **Document & Escalate** — create a HIGH severity ticket with evidence attached
4. **Remove or quarantine model files** — move to a secured quarantine location with `chmod 000`
5. **Reinforce controls** — add firewall rules, remove auto-restart service units
6. **Credential Exposure** — if API keys or credentials were exposed via MCP or config files, escalate immediately for rotation
7. **Follow up with InfoSec / Compliance** for deeper forensic analysis

See [wiki: Incident Response](../../wiki/Incident-Response) for detailed commands and evidence collection procedures.

---

## U.S. Federal Guidance & Regulatory Citations

The controls in this repository are grounded in the following frameworks. Federal contractors handling CUI, operating under DFARS clauses, or pursuing CMMC certification **must** comply with the applicable standards before deploying local LLM tooling in covered environments.

### NIST AI & Cybersecurity Frameworks

| Citation | Title | Link |
|---|---|---|
| **NIST AI 100-1** | AI Risk Management Framework (AI RMF 1.0) | [doi.org/10.6028/NIST.AI.100-1](https://doi.org/10.6028/NIST.AI.100-1) |
| **NIST AI 100-2** | Adversarial Machine Learning: Taxonomy and Terminology | [csrc.nist.gov](https://csrc.nist.gov/pubs/ai/100/2/e2025/final) |
| **NIST AI 600-1** | AI RMF for Generative AI *(directly covers LLMs)* | [doi.org/10.6028/NIST.AI.600-1](https://doi.org/10.6028/NIST.AI.600-1) |
| **NIST SP 800-53 Rev 5** | Security & Privacy Controls for Information Systems | [doi.org/10.6028/NIST.SP.800-53r5](https://doi.org/10.6028/NIST.SP.800-53r5) |
| **NIST SP 800-171 Rev 3** | Protecting CUI in Nonfederal Systems | [doi.org/10.6028/NIST.SP.800-171r3](https://doi.org/10.6028/NIST.SP.800-171r3) |
| **NIST SP 800-218** | Secure Software Development Framework (SSDF) | [doi.org/10.6028/NIST.SP.800-218](https://doi.org/10.6028/NIST.SP.800-218) |

### Key NIST SP 800-53 Controls for LLM Deployments

| Control | ID | LLM Application |
|---|---|---|
| Boundary Protection | SC-7 | Bind services to `127.0.0.1`; firewall LLM ports |
| Least Privilege | AC-6 | Restrict model file permissions to owner only |
| Identification & Authentication | IA-2, IA-3 | Require API tokens; never expose unauthenticated endpoints |
| Cryptographic Protection | SC-8, SC-28 | Encrypt traffic and model files at rest |
| Audit Events | AU-2, AU-12 | Log all inference requests, model loads, and config changes |
| Least Functionality | CM-7 | Disable unused LLM features: CORS, network serving, plugins |
| Component Inventory | CM-8 | Maintain inventory of all models, tools, and agent frameworks |
| Supply Chain Protection | SA-12 | Verify model provenance; prohibit foreign-origin models |
| Malicious Code Protection | SI-3 | Scan agent plugins and MCP servers for malicious behavior |
| Information System Monitoring | SI-4 | Monitor for unauthorized LLM processes and outbound connections |

### Executive Orders & OMB Policy

| Citation | Title | Link |
|---|---|---|
| **EO 14110** *(Oct 2023)* | Safe, Secure, and Trustworthy Development and Use of AI | [federalregister.gov](https://www.federalregister.gov/documents/2023/11/01/2023-24283/safe-secure-and-trustworthy-development-and-use-of-artificial-intelligence) |
| **EO 14179** *(Jan 2025)* | Removing Barriers to American Leadership in AI | [whitehouse.gov](https://www.whitehouse.gov/presidential-actions/2025/01/removing-barriers-to-american-leadership-in-artificial-intelligence/) |
| **OMB M-24-10** | Advancing Governance, Innovation, and Risk Management for Agency Use of AI | [whitehouse.gov (PDF)](https://www.whitehouse.gov/wp-content/uploads/2024/03/M-24-10-Advancing-Governance-Innovation-and-Risk-Management-for-Agency-Use-of-Artificial-Intelligence.pdf) |
| **OMB M-24-18** | Driving Efficient Acquisition of AI in Government | [whitehouse.gov (PDF)](https://www.whitehouse.gov/wp-content/uploads/2025/02/M-25-22-Driving-Efficient-Acquisition-of-Artificial-Intelligence-in-Government.pdf) |

### CISA, NSA & Intelligence Community

| Citation | Title | Link |
|---|---|---|
| **CISA AI Roadmap** | CISA Roadmap for Artificial Intelligence 2023–2024 | [cisa.gov](https://www.cisa.gov/resources-tools/resources/roadmap-ai) |
| **CISA/NCSC Secure AI Dev** | Guidelines for Secure AI System Development *(joint UK/US/AU/CA/DE)* | [ncsc.gov.uk (PDF)](https://www.ncsc.gov.uk/files/Guidelines-for-secure-AI-system-development.pdf) |
| **NSA CSI: Deploying AI Securely** *(Apr 2024)* | Best Practices for Deploying AI Systems | [media.defense.gov (PDF)](https://media.defense.gov/2024/Apr/15/2003439257/-1/-1/0/CSI-DEPLOYING-AI-SYSTEMS-SECURELY.PDF) |
| **NSA MCP Security** | Model Context Protocol: Security Design Considerations | [nsa.gov (PDF)](https://www.nsa.gov/Portals/75/documents/Cybersecurity/CSI_MCP_SECURITY.pdf) |
| **DOJ** *(Dec 2025)* | U.S. Authorities Shut Down China-Linked AI Tech Smuggling Network | [justice.gov](https://www.justice.gov/opa/pr/us-authorities-shut-down-major-china-linked-ai-tech-smuggling-network) |
| **FBI/CISA Foreign AI Advisory** | Foreign State-Sponsored AI Tool Threats to U.S. Organizations | [fbi.gov](https://www.fbi.gov/investigate/counterintelligence/the-china-threat) |

> 🚨 The FBI and IC advisories directly inform the [Prohibited Model List](../../wiki/Prohibited-Models). Agencies and organizations that have formally banned or restricted DeepSeek and Chinese-origin AI models include: U.S. Navy, NASA, U.S. Congress, Pentagon/DoD, multiple state governments (Texas, Virginia, and others), and several allied foreign governments.

### DoD / CMMC / DFARS / FedRAMP

| Citation | Title | Link |
|---|---|---|
| **CMMC 2.0** | DoD Cybersecurity Maturity Model Certification | [dodcio.defense.gov/CMMC](https://dodcio.defense.gov/CMMC/) |
| **DFARS 252.204-7012** | Safeguarding Covered Defense Information and Cyber Incident Reporting | [acquisition.gov](https://www.acquisition.gov/dfars/252.204-7012-safeguarding-covered-defense-information-and-cyber-incident-reporting.) |
| **DoD AI Ethics Principles** | DoD Adopted Ethical Principles for AI *(Feb 2020)* | [defense.gov](https://www.defense.gov/News/Releases/Release/Article/2091996/dod-adopts-ethical-principles-for-artificial-intelligence/) |
| **DISA STIGs** | Application Security & Development STIG *(applies to AI/ML components)* | [public.cyber.mil/stigs](https://public.cyber.mil/stigs/) |
| **NDAA FY2024 §1553** | National Defense Authorization Act AI Security Provisions | [congress.gov](https://www.congress.gov/bill/118th-congress/house-bill/2670) |
| **FedRAMP AI Guidance** | FedRAMP Guidance on AI/ML Services Authorization | [fedramp.gov/ai](https://www.fedramp.gov/ai/) |
| **FISMA 2014** | Federal Information Security Modernization Act | [cisa.gov](https://www.cisa.gov/topics/cyber-threats-and-advisories/federal-information-security-modernization-act) |

> Cloud-based LLM APIs (OpenAI, Anthropic, Cohere, AWS Bedrock, etc.) used in federal contractor environments **must** be FedRAMP authorized or operate under an equivalent authorization framework.

### Applicable CMMC 2.0 Practices for LLM Deployments

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

### Control-to-Hardening Mapping

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
| MCP server review & approval | NSA-AI-SECURITY; NIST SP 800-53 **SI-3** |
| No agent access to CUI/credentials | NIST SP 800-171 **§3.1–3.14**; DFARS **252.204-7012** |
| Inventory all tools and models | NIST SP 800-53 **CM-8**; CMMC **CM.L2-3.4.1** |
| Encrypt data in transit | NIST SP 800-53 **SC-8** |
| Encrypt models at rest | NIST SP 800-53 **SC-28** |
| Incident reporting for violations | DFARS **252.204-7012(c)**; FISMA |

---

## Detailed Technical Reference — Wiki

For detailed technical guidance, see the [project wiki](../../wiki):

- **[LLM Tools Reference](../../wiki/LLM-Tools-Reference)** — Default ports, model directories, and security notes for all supported inference servers
- **[AI Agent Frameworks](../../wiki/AI-Agent-Frameworks)** — Risk profiles and approval requirements for all supported agent frameworks
- **[Vector Databases](../../wiki/Vector-Databases)** — RAG backend security configurations
- **[Prohibited Models](../../wiki/Prohibited-Models)** — Full list of prohibited foreign-origin model names with search patterns
- **[Model File Types](../../wiki/Model-File-Types)** — GGUF, safetensors, bin, and other model file formats
- **[Network Exposure Checks](../../wiki/Network-Exposure-Checks)** — Commands to identify exposed LLM services
- **[MCP Security](../../wiki/MCP-Security)** — Model Context Protocol attack surface, audit commands, and best practices
- **[Incident Response](../../wiki/Incident-Response)** — Evidence collection and escalation procedures for LLM violations

---

*Guidance for federal contractors and regulated organizations deploying local LLM tooling.*
