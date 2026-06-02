# AI Agent Frameworks

AI agent frameworks present a **distinct and elevated risk profile** from inference servers. They can autonomously execute code, read/write files, browse the web, call external APIs, and chain multi-step actions — often with the developer's own credentials and without per-action confirmation.

**Each framework below must be inventoried and its external integrations reviewed before use on federal or sensitive systems.**

> **Regulatory basis:** [NIST AI 600-1 §2.6](https://doi.org/10.6028/NIST.AI.600-1) (Third-Party Integrations); [NIST SP 800-53 SA-4](https://csrc.nist.gov/publications/detail/sp/800-53/rev-5/final) (Acquisition Process); [NSA CSI: Deploying AI Systems Securely](https://media.defense.gov/2024/Apr/15/2003439257/-1/-1/0/CSI-DEPLOYING-AI-SYSTEMS-SECURELY.PDF)

> 🔴 **No AI agent framework should be granted access to CUI, PII, PHI, credentials, or production systems without a formal security review aligned to [NIST AI 600-1](https://doi.org/10.6028/NIST.AI.600-1) and [DFARS 252.204-7012](https://www.acquisition.gov/dfars/252.204-7012-safeguarding-covered-defense-information-and-cyber-incident-reporting.).**

---

## Framework Reference Table

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

---

## Coding Agents / AI IDEs

The following AI-integrated development environments and coding agents also require security review before use on systems handling federal work:

| Tool | Key Risk |
|---|---|
| **Cursor** | MCP server support; workspace-wide file access |
| **Windsurf** | MCP server support; autonomous code edits |
| **Continue.dev** | MCP server support; local model or cloud API |
| **Cody** (Sourcegraph) | Repository-wide indexing; cloud telemetry |
| **GitHub Copilot** (via MCP) | Code completion; potential secret exposure in context |

---

## Approval Classification

- **✅ Yes** — Requires formal written security review before any use on systems touching federal data, CUI, or covered defense information
- **✅ Review** — Requires security review before use with external integrations, CUI, or production system access. May be used in isolated sandbox environments with prior IT approval

---

← [Back to Wiki Home](Home)
