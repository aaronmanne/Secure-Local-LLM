#!/usr/bin/env bash
# =============================================================================
# macOS LLM & AI Agent Installation Identifier
# Identifies inference servers, agent frameworks, model files, and related
# software using the shared patterns catalogue in common/patterns.sh
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../common/patterns.sh
source "$SCRIPT_DIR/common/patterns.sh"

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; BOLD='\033[1m'; NC='\033[0m'

print_header()     { echo -e "\n${BOLD}${CYAN}=== $1 ===${NC}"; }
print_found()      { echo -e "${GREEN}[FOUND]${NC} $1"; }
print_warn()       { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_prohibited() { echo -e "${RED}[PROHIBITED]${NC} $1"; }
print_review()     { echo -e "${MAGENTA}[REVIEW]${NC} $1"; }
print_info()       { echo -e "  $1"; }

echo -e "${BOLD}${CYAN}"
echo "╔══════════════════════════════════════════════════════════╗"
echo "║     macOS LLM & AI Agent Installation Identifier        ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo "Date: $(date) | Host: $(hostname) | User: $(whoami)"
echo ""

# ─── 1. RUNNING INFERENCE SERVER PROCESSES ────────────────────────────────────
print_header "1. Running Inference Server Processes"
FOUND_PROCS=0
while IFS= read -r line; do
    print_found "Process: $line"
    FOUND_PROCS=$((FOUND_PROCS+1))
done < <(pgrep -fla . 2>/dev/null | grep -iE "$LLM_PROCESS_PATTERN" | grep -v "grep\|$$" || true)
[ "$FOUND_PROCS" -eq 0 ] && print_info "No inference server processes detected."

# ─── 2. RUNNING AI AGENT PROCESSES ───────────────────────────────────────────
print_header "2. Running AI Agent / Framework Processes"
FOUND_AGENTS=0
while IFS= read -r line; do
    print_warn "Agent process: $line"
    FOUND_AGENTS=$((FOUND_AGENTS+1))
done < <(pgrep -fla . 2>/dev/null | grep -iE "$AGENT_PROCESS_PATTERN" | grep -v "grep\|$$" || true)
[ "$FOUND_AGENTS" -eq 0 ] && print_info "No AI agent processes detected."

# ─── 3. VECTOR DATABASE PROCESSES ─────────────────────────────────────────────
print_header "3. Vector Database Processes"
while IFS= read -r line; do
    print_warn "Vector DB: $line"
done < <(pgrep -fla . 2>/dev/null | grep -iE "$VECTORDB_PROCESS_PATTERN" | grep -v "grep\|$$" || true) || print_info "None detected."

# ─── 4. INSTALLED APPLICATIONS ────────────────────────────────────────────────
print_header "4. Installed LLM / Agent Applications"
FOUND_APPS=0
for app in \
    "Ollama" "LM Studio" "LM_Studio" "GPT4All" "Jan" "LocalAI" \
    "AnythingLLM" "Anything LLM" "Msty" "Tabby" "LMDeploy" \
    "Open WebUI" "OpenWebUI" "SillyTavern" "Oobabooga" \
    "Cursor" "Windsurf" "Continue" "Cody" \
    "AutoGPT" "CrewAI" "OpenDevin" "OpenHands"; do
    for base in "/Applications" "$HOME/Applications"; do
        [ -d "$base/${app}.app" ] && { print_found "App: ${app}.app ($base)"; FOUND_APPS=$((FOUND_APPS+1)); }
    done
done

# CLI tools
for cmd in "${LLM_CLI_TOOLS[@]}" "${AGENT_CLI_TOOLS[@]}"; do
    if command -v "$cmd" &>/dev/null; then
        print_found "CLI: $cmd → $(command -v $cmd)"
        FOUND_APPS=$((FOUND_APPS+1))
    fi
done

# pip-installed packages
if command -v pip3 &>/dev/null || command -v pip &>/dev/null; then
    PIP_CMD=$(command -v pip3 || command -v pip)
    while IFS= read -r pkg; do
        print_warn "Python package: $pkg"
        FOUND_APPS=$((FOUND_APPS+1))
    done < <("$PIP_CMD" list 2>/dev/null | grep -iE "ollama|llama.?cpp|llama-cpp-python|transformers|langchain|langgraph|autogen|crewai|openai|anthropic|cohere|huggingface|text.?generation|vllm|sglang|lmstudio|kobold|tabby|open-interpreter|aider|plandex|mentat|goose-ai|memgpt|mem0|letta|phidata|agno|dspy|haystack|flowise|xinference|privategpt|localai" || true)
fi

# Homebrew formulae
if command -v brew &>/dev/null; then
    while IFS= read -r pkg; do
        print_found "Homebrew: $pkg"
        FOUND_APPS=$((FOUND_APPS+1))
    done < <(brew list 2>/dev/null | grep -iE "ollama|llama|localai|llm|tabby|llamafile" || true)
fi

[ "$FOUND_APPS" -eq 0 ] && print_info "No LLM/agent applications found via standard checks."

# ─── 5. AGENT CONFIG / WORKSPACE FILES ────────────────────────────────────────
print_header "5. Agent Configuration & Workspace Files"
AGENT_DIRS=(
    "$HOME/.autogpt" "$HOME/Auto-GPT" "$HOME/AutoGPT"
    "$HOME/.crewai" "$HOME/.autogen"
    "$HOME/.opendevin" "$HOME/.openhands"
    "$HOME/.aider" "$HOME/.goose" "$HOME/.plandex" "$HOME/.mentat"
    "$HOME/.continue" "$HOME/.cody"
    "$HOME/flowise" "$HOME/.flowise"
    "$HOME/dify" "$HOME/.dify"
    "$HOME/n8n" "$HOME/.n8n"
    "$HOME/.memgpt" "$HOME/.letta" "$HOME/.mem0"
    "$HOME/.langchain"
    "$HOME/privategpt" "$HOME/anythingllm"
)
for d in "${AGENT_DIRS[@]}"; do
    [ -d "$d" ] && print_warn "Agent config dir: $d"
done

# aider config files
for f in "$HOME/.aider.conf.yml" "$HOME/.aider.model.metadata.json"; do
    [ -f "$f" ] && print_warn "Aider config: $f"
done

# ─── 6. MODEL DIRECTORIES ─────────────────────────────────────────────────────
print_header "6. Model Directories"
for dir in "${MODEL_DIRS_MACOS[@]}"; do
    if [ -d "$dir" ]; then
        COUNT=$(find "$dir" -type f \( -name "*.gguf" -o -name "*.safetensors" -o -name "*.ggml" -o -name "*.onnx" -o -name "*.llamafile" \) 2>/dev/null | wc -l | tr -d ' ')
        SIZE=$(du -sh "$dir" 2>/dev/null | cut -f1 || echo "?")
        print_found "Dir: $dir ($COUNT model files, ~$SIZE)"
    fi
done

# ─── 7. OLLAMA REGISTERED MODELS ──────────────────────────────────────────────
print_header "7. Ollama Registered Models"
if command -v ollama &>/dev/null; then
    ollama list 2>/dev/null || print_info "Ollama not responding."
else
    print_info "Ollama not installed."
fi

# ─── 8. ALL MODEL FILES ───────────────────────────────────────────────────────
print_header "8. All Model Files Found on System"
print_info "(searching $HOME and /usr — may take a moment...)"
find "$HOME" /usr /opt 2>/dev/null \
    -type f \( -name "*.gguf" -o -name "*.safetensors" -o -name "*.ggml" -o -name "*.onnx" -o -name "*.llamafile" \) \
    2>/dev/null | while read -r f; do
    SIZE=$(du -sh "$f" 2>/dev/null | cut -f1 || echo "?")
    print_info "[$SIZE] $f"
done

# ─── 9. PROHIBITED MODEL SCAN ─────────────────────────────────────────────────
print_header "9. Prohibited / Foreign-Origin Model Scan"
print_info "Scanning for Chinese / Russian / UAE-origin models..."
PHITS=0

find "$HOME" -type f \( -name "*.gguf" -o -name "*.bin" -o -name "*.safetensors" -o -name "*.ggml" \) 2>/dev/null | \
    grep -iE "$PROHIBITED_PATTERN" | while read -r f; do
        print_prohibited "PROHIBITED: $f"
        PHITS=$((PHITS+1))
    done

if command -v ollama &>/dev/null; then
    ollama list 2>/dev/null | grep -iE "$PROHIBITED_PATTERN" | while read -r line; do
        print_prohibited "PROHIBITED OLLAMA MODEL: $line"
    done
fi

# Review-warranted (fine-tunes that need provenance check)
find "$HOME" -type f \( -name "*.gguf" -o -name "*.safetensors" \) 2>/dev/null | \
    grep -iE "$REVIEW_PATTERN" | while read -r f; do
        print_review "VERIFY ORIGIN: $f"
    done

print_info "Prohibited scan complete."

# ─── 10. NETWORK EXPOSURE ─────────────────────────────────────────────────────
print_header "10. Network Exposure Check"
for entry in "${LLM_PORTS[@]}"; do
    PORT="${entry%%:*}"; TOOL="${entry#*:}"
    BINDING=$(lsof -i TCP:"$PORT" -sTCP:LISTEN -n -P 2>/dev/null || true)
    if [ -n "$BINDING" ]; then
        if echo "$BINDING" | grep -qE "\*:|0\.0\.0\.0"; then
            print_warn "Port $PORT ($TOOL) EXPOSED on all interfaces!"
            echo "$BINDING" | while read -r b; do print_info "$b"; done
        else
            print_found "Port $PORT ($TOOL) — localhost-bound"
        fi
    fi
done

# ─── 11. OLLAMA CONFIG ────────────────────────────────────────────────────────
print_header "11. Ollama Configuration"
OH="${OLLAMA_HOST:-}"
if [ -n "$OH" ]; then
    echo "$OH" | grep -qE "0\.0\.0\.0|^:" && \
        print_warn "OLLAMA_HOST=$OH — EXPOSED!" || \
        print_found "OLLAMA_HOST=$OH"
else
    print_info "OLLAMA_HOST not set (defaults to 127.0.0.1:11434)"
fi

# ─── 12. MCP CONFIG SCAN ──────────────────────────────────────────────────────
print_header "12. MCP (Model Context Protocol) Config Files"
for f in "${MCP_CONFIG_PATHS_MACOS[@]}"; do
    if [ -f "$f" ] && grep -q "mcpServers" "$f" 2>/dev/null; then
        print_warn "MCP config: $f"
        grep -q '"url"' "$f" 2>/dev/null && print_warn "  >> Contains REMOTE server (url key)"
    fi
done
find "$HOME" -name "mcp.json" 2>/dev/null | while read -r f; do
    print_warn "mcp.json: $f"
done

# ─── SUMMARY ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}=== Scan Complete ===${NC}"
echo "Run audit.sh for full compliance checklist or harden.sh to apply controls."
echo ""
