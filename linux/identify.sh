#!/usr/bin/env bash
# =============================================================================
# Linux LLM & AI Agent Installation Identifier
# Regulatory basis: NIST SP 800-53 CM-8; NIST AI 600-1; CMMC 2.0 CM.L2-3.4.1
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/common/patterns.sh"
source "$SCRIPT_DIR/common/references.sh"

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
echo "║     Linux LLM & AI Agent Installation Identifier        ║"
echo "║  Ref: NIST SP 800-53 CM-8 · NIST AI 600-1              ║"
echo "║       CMMC 2.0 CM.L2-3.4.1 · DFARS 252.204-7012        ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo "Date: $(date) | Host: $(hostname) | User: $(whoami)"
DISTRO=$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"' || echo "Unknown")
echo "Distro: $DISTRO"
echo ""

# ─── 1. RUNNING INFERENCE SERVER PROCESSES ────────────────────────────────────
print_header "1. Running Inference Server Processes"
FOUND_PROCS=0
while IFS= read -r line; do
    print_found "Process: $line"; FOUND_PROCS=$((FOUND_PROCS+1))
done < <(pgrep -fla . 2>/dev/null | grep -iE "$LLM_PROCESS_PATTERN" | grep -v "grep\|$$\|identify" || true)
[ "$FOUND_PROCS" -eq 0 ] && print_info "No inference server processes detected."

# ─── 2. RUNNING AI AGENT PROCESSES ───────────────────────────────────────────
print_header "2. Running AI Agent / Framework Processes"
FOUND_AGENTS=0
while IFS= read -r line; do
    print_warn "Agent process: $line"; FOUND_AGENTS=$((FOUND_AGENTS+1))
done < <(pgrep -fla . 2>/dev/null | grep -iE "$AGENT_PROCESS_PATTERN" | grep -v "grep\|$$\|identify" || true)
[ "$FOUND_AGENTS" -eq 0 ] && print_info "No AI agent processes detected."

# ─── 3. SYSTEMD SERVICES ──────────────────────────────────────────────────────
print_header "3. Systemd LLM / Agent Services"
FOUND_SVCS=0
for svc in ollama localai gpt4all jan tabby koboldcpp text-generation-webui vllm xinference qdrant weaviate milvus; do
    if systemctl list-units --full --all 2>/dev/null | grep -qi "^$svc"; then
        STATUS=$(systemctl is-active "$svc" 2>/dev/null || echo "unknown")
        ENABLED=$(systemctl is-enabled "$svc" 2>/dev/null || echo "unknown")
        print_found "Service: $svc (active=$STATUS, enabled=$ENABLED)"
        FOUND_SVCS=$((FOUND_SVCS+1))
    fi
done
[ "$FOUND_SVCS" -eq 0 ] && print_info "No LLM/agent systemd services found."

# ─── 4. DOCKER CONTAINERS ─────────────────────────────────────────────────────
print_header "4. Docker / Container Workloads"
if command -v docker &>/dev/null; then
    while IFS= read -r line; do
        print_warn "Container: $line"
    done < <(docker ps -a 2>/dev/null | grep -iE "ollama|localai|llama|vllm|tgi|lmstudio|jan|kobold|tabby|oobabooga|xinference|qdrant|weaviate|milvus|anythingllm|privategpt|flowise|dify|n8n|autogpt|crewai|opendevin|openhands|langchain|mem0|memgpt|letta" || true)
    docker ps -a 2>/dev/null | grep -iE "ollama|localai|llama|vllm|tgi" | grep -qi "" || print_info "No LLM-related containers found."
else
    print_info "Docker not installed."
fi
if command -v podman &>/dev/null; then
    while IFS= read -r line; do
        print_warn "Podman container: $line"
    done < <(podman ps -a 2>/dev/null | grep -iE "ollama|llama|vllm|tgi|localai" || true)
fi

# ─── 5. INSTALLED CLI TOOLS ───────────────────────────────────────────────────
print_header "5. Installed LLM / Agent CLI Tools"
for cmd in "${LLM_CLI_TOOLS[@]}" "${AGENT_CLI_TOOLS[@]}"; do
    command -v "$cmd" &>/dev/null && print_found "CLI: $cmd → $(command -v $cmd)"
done

# pip packages
if command -v pip3 &>/dev/null || command -v pip &>/dev/null; then
    PIP_CMD=$(command -v pip3 2>/dev/null || command -v pip)
    while IFS= read -r pkg; do
        print_warn "Python package: $pkg"
    done < <("$PIP_CMD" list 2>/dev/null | grep -iE "ollama|llama.?cpp|transformers|langchain|langgraph|autogen|crewai|openai|anthropic|huggingface|text.?generation|vllm|sglang|open-interpreter|aider|plandex|mentat|goose-ai|memgpt|mem0|letta|phidata|dspy|haystack|xinference|privategpt|localai" || true)
fi

# ─── 6. AGENT CONFIG DIRECTORIES ──────────────────────────────────────────────
print_header "6. Agent Config / Workspace Directories"
AGENT_DIRS=(
    "$HOME/.autogpt" "$HOME/AutoGPT" "$HOME/.crewai" "$HOME/.autogen"
    "$HOME/.opendevin" "$HOME/.openhands" "$HOME/.aider" "$HOME/.goose"
    "$HOME/.plandex" "$HOME/.mentat" "$HOME/.continue" "$HOME/.cody"
    "$HOME/flowise" "$HOME/.flowise" "$HOME/dify" "$HOME/.n8n"
    "$HOME/.memgpt" "$HOME/.letta" "$HOME/.mem0" "$HOME/.langchain"
    "$HOME/privategpt" "$HOME/anythingllm"
)
for d in "${AGENT_DIRS[@]}"; do [ -d "$d" ] && print_warn "Agent config dir: $d"; done

# ─── 7. MODEL DIRECTORIES ─────────────────────────────────────────────────────
print_header "7. Model Directories"
for dir in "${MODEL_DIRS_LINUX[@]}"; do
    if [ -d "$dir" ]; then
        COUNT=$(find "$dir" -type f \( -name "*.gguf" -o -name "*.safetensors" -o -name "*.ggml" -o -name "*.onnx" \) 2>/dev/null | wc -l)
        SIZE=$(du -sh "$dir" 2>/dev/null | cut -f1 || echo "?")
        print_found "$dir ($COUNT model files, ~$SIZE)"
    fi
done

# ─── 8. OLLAMA REGISTERED MODELS ──────────────────────────────────────────────
print_header "8. Ollama Registered Models"
if command -v ollama &>/dev/null; then
    ollama list 2>/dev/null || print_info "Ollama not responding."
else
    print_info "Ollama not installed."
fi

# ─── 9. ALL MODEL FILES ───────────────────────────────────────────────────────
print_header "9. All Model Files Found"
print_info "(searching $HOME, /usr, /opt...)"
find "$HOME" /usr /opt /var 2>/dev/null \
    -type f \( -name "*.gguf" -o -name "*.safetensors" -o -name "*.ggml" -o -name "*.onnx" -o -name "*.llamafile" \) \
    2>/dev/null | while read -r f; do
    SIZE=$(du -sh "$f" 2>/dev/null | cut -f1 || echo "?"); print_info "[$SIZE] $f"
done

# ─── 10. PROHIBITED MODEL SCAN ────────────────────────────────────────────────
print_header "10. Prohibited / Foreign-Origin Model Scan  [FBI-DEEPSEEK; HOUSE-DEEPSEEK]"
find "$HOME" /usr/share/ollama 2>/dev/null \
    -type f \( -name "*.gguf" -o -name "*.bin" -o -name "*.safetensors" -o -name "*.ggml" \) \
    2>/dev/null | grep -iE "$PROHIBITED_PATTERN" | while read -r f; do
        print_prohibited "PROHIBITED: $f"
    done
if command -v ollama &>/dev/null; then
    ollama list 2>/dev/null | grep -iE "$PROHIBITED_PATTERN" | while read -r line; do
        print_prohibited "PROHIBITED OLLAMA MODEL: $line"
    done
fi
find "$HOME" -type f \( -name "*.gguf" -o -name "*.safetensors" \) 2>/dev/null | \
    grep -iE "$REVIEW_PATTERN" | while read -r f; do
        print_review "VERIFY ORIGIN: $f"
    done
print_info "Prohibited scan complete."

# ─── 11. NETWORK EXPOSURE ─────────────────────────────────────────────────────
print_header "11. Network Exposure Check  [NIST SP 800-53 SC-7]"
for entry in "${LLM_PORTS[@]}"; do
    PORT="${entry%%:*}"; TOOL="${entry#*:}"
    if command -v ss &>/dev/null; then
        BIND=$(ss -tlnp 2>/dev/null | grep ":$PORT " || true)
    else
        BIND=$(netstat -tlnp 2>/dev/null | grep ":$PORT " || true)
    fi
    if [ -n "$BIND" ]; then
        echo "$BIND" | grep -qE "0\.0\.0\.0|\*:|\[::\]" && \
            print_warn "Port $PORT ($TOOL) EXPOSED on all interfaces!" || \
            print_found "Port $PORT ($TOOL) — localhost-bound"
        print_info "$BIND"
    fi
done

# ─── 12. OLLAMA CONFIG / SYSTEMD ENV ──────────────────────────────────────────
print_header "12. Ollama Configuration"
OH="${OLLAMA_HOST:-}"
[ -n "$OH" ] && {
    echo "$OH" | grep -qE "0\.0\.0\.0|^:" && \
        print_warn "OLLAMA_HOST=$OH — NETWORK EXPOSED" || print_found "OLLAMA_HOST=$OH"
} || print_info "OLLAMA_HOST not set (defaults to localhost)."

for f in /etc/systemd/system/ollama.service.d/*.conf /lib/systemd/system/ollama.service; do
    [ -f "$f" ] && grep -q "OLLAMA_HOST" "$f" 2>/dev/null && \
        print_warn "OLLAMA_HOST in systemd unit: $f → $(grep OLLAMA_HOST $f)"
done

# ─── 13. MCP CONFIG SCAN ──────────────────────────────────────────────────────
print_header "13. MCP Config Files  [NIST AI 100-2; NSA-AI-SECURITY]"
for f in "${MCP_CONFIG_PATHS_LINUX[@]}"; do
    if [ -f "$f" ] && grep -q "mcpServers" "$f" 2>/dev/null; then
        print_warn "MCP config: $f"
        grep -q '"url"' "$f" 2>/dev/null && print_warn "  >> Contains REMOTE server!"
    fi
done
find "$HOME" -name "mcp.json" 2>/dev/null | while read -r f; do print_warn "mcp.json: $f"; done

# ─── SUMMARY ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}=== Scan Complete ===${NC}"
echo "Run audit.sh for full compliance checklist or harden.sh to apply controls."
print_federal_references
echo ""
