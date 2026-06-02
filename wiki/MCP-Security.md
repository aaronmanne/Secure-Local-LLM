# MCP Security

## What Is MCP and Why It Matters for Security

**MCP (Model Context Protocol)** is an open protocol that allows AI coding tools — such as Claude Desktop, VS Code Copilot, Cursor, Continue.dev, and Ollama frontends — to connect to external "MCP servers" that provide executable tools, data resources, and prompt templates to the AI. MCP servers can run:

- **Locally** as subprocesses on the developer's machine (`stdio` transport)
- **Remotely** over HTTP/SSE on third-party infrastructure

Because MCP servers can execute code, read files, query databases, and call external APIs **on behalf of the AI** — often with the developer's own credentials — they represent a **significant and rapidly growing attack surface**.

> **References:**
> - [NSA CSI: Model Context Protocol Security Design Considerations](https://www.nsa.gov/Portals/75/documents/Cybersecurity/CSI_MCP_SECURITY.pdf)
> - [NIST SP 800-53 SI-3](https://csrc.nist.gov/publications/detail/sp/800-53/rev-5/final) (Malicious Code Protection)
> - [NIST AI 100-2](https://csrc.nist.gov/pubs/ai/100/2/e2025/final) (Adversarial ML)

---

## MCP Attack Surface Overview

| Component | Description | Risk Level | Example Threat |
|---|---|---|---|
| Local MCP Server (stdio) | Runs as subprocess on developer machine | **HIGH** | Reads local files, `.env` vars, SSH keys, AWS credentials |
| Remote MCP Server (HTTP/SSE) | Runs on third-party infrastructure | **CRITICAL** | Data exfiltration to unknown/foreign party; no data sovereignty |
| MCP Tools | Executable functions the AI can call | **HIGH** | Shell execution, file read/write, database queries, API calls |
| MCP Resources | Data sources the AI can read | **MEDIUM-HIGH** | Indirect prompt injection via malicious document or DB record content |
| MCP Prompts | Reusable system prompt templates | **MEDIUM** | Malicious system prompt injection into AI context |

---

## Prohibited MCP Server Categories

The following MCP server types are **PROHIBITED** without explicit security team review and approval:

- 🔴 Any **remote MCP server operated by a foreign entity** — data sent to these servers may be logged, stored, or used for training outside your jurisdiction
- 🔴 MCP servers installed from **unvetted sources** — random GitHub repos, blog posts, npm/PyPI packages without code review and provenance verification
- 🔴 MCP servers with **shell/command execution capabilities** — unless explicitly authorized in writing by the security team
- 🔴 MCP servers that **connect to external APIs** without a signed data handling agreement
- 🔴 MCP servers with access to **production databases, patient records, HR systems, or financial data** without formal security review
- 🔴 **Any MCP server that has not been reviewed and approved** by the security team — approval required before installation on any work device

---

## Where MCP Servers Are Configured

### Claude Desktop
- macOS: `~/Library/Application Support/Claude/claude_desktop_config.json`
- Windows: `%APPDATA%\Claude\claude_desktop_config.json`

### VS Code (GitHub Copilot / Continue.dev / other extensions)
- Workspace: `.vscode/mcp.json` or `.vscode/settings.json` (look for `mcp` or `mcpServers` keys)
- User-level (macOS): `~/Library/Application Support/Code/User/settings.json`
- User-level (Windows): `%APPDATA%\Code\User\settings.json`

### Cursor
- Global: `~/.cursor/mcp.json`
- Project-level: `.cursor/mcp.json` in any project directory
- macOS settings: `~/Library/Application Support/Cursor/User/settings.json`

### Continue.dev
- `~/.continue/config.json` — look for the `mcpServers` array

### OpenCode
- `~/.config/opencode/config.json` — look for `mcp` key

---

## How to Find All MCP Configs on a System

**macOS / Linux:**
```bash
# Find Claude Desktop config
find ~ -name "claude_desktop_config.json" 2>/dev/null

# Find any mcp.json files
find ~ -name "mcp.json" 2>/dev/null

# Search all JSON files for mcpServers key
grep -r "mcpServers" ~/.config ~/.cursor ~/Library/Application\ Support ~/.continue 2>/dev/null | grep -v ".git"
```

**Windows PowerShell:**
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

## How to Read an MCP Config File

MCP configurations follow a standard JSON structure. Example `claude_desktop_config.json`:

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

## MCP Audit Commands

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

## What to Do When You Find an Unauthorized MCP Server

1. **Document** the full contents of the config file; copy the JSON and note the file path, hostname, and username
2. **Classify** the server type: local (`command`/`args` keys) vs. remote (`url` key)
3. For **remote servers**: note the full URL; flag any unknown or foreign-operated domains immediately
4. For **local servers**: identify the command being run, its source path, and whether it was installed from a vetted package
5. **Check for embedded credentials**: scan the config for API keys, tokens, passwords, or connection strings — if found, treat as a **credential exposure incident**
6. If **unauthorized**: remove the server entry from the config file and kill any associated running processes
7. If **credentials were exposed**: escalate to InfoSec immediately for credential rotation — do not wait
8. Create a **HIGH severity ticket** with the config file contents, file path, hostname, username, and any credential exposure details

---

## MCP Security Best Practices for Developers

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

## Data Classification and MCP

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

← [Back to Wiki Home](Home)
