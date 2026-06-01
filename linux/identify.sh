#!/usr/bin/env bash
# =============================================================================
# Linux LLM Identification Script
# Identifies locally installed LLM tools, models, and related software
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

PROHIBITED_PATTERN="deepseek|qwen|qwq|yi-[0-9]|baichuan|chatglm|internlm|minimax|ernie|hunyuan|tigerbot|aquila|moss|belle|rugpt|saiga|fred-t5|falcon"

print_header() { echo -e "\n${BOLD}${CYAN}=== $1 ===${NC}"; }
print_found()  { echo -e "${GREEN}[FOUND]${NC} $1"; }
print_warn()   { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_prohibited() { echo -e "${RED}[PROHIBITED]${NC} $1"; }
print_info()   { echo -e "  $1"; }

echo -e "${BOLD}${CYAN}"
echo "╔══════════════════════════════════════════════════════════╗"
echo "║         Linux LLM Installation Identifier               ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo "Date: $(date)"
echo "Host: $(hostname)"
echo "User: $(whoami)"
echo "Distro: $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d= -f2 | tr -d '"' || echo 'Unknown')"
echo ""

# ─── 1. RUNNING PROCESSES ─────────────────────────────────────────────────────
print_header "Running LLM Processes"
FOUND_PROCS=0
for proc in ollama lmstudio localai gpt4all jan llamafile llm; do
    if pgrep -fi "$proc" > /dev/null 2>&1; then
        print_found "Process running: $proc"
        pgrep -fla "$proc" 2>/dev/null | while read -r line; do print_info "$line"; done
        FOUND_PROCS=$((FOUND_PROCS+1))
    fi
done
[ "$FOUND_PROCS" -eq 0 ] && echo "  No LLM processes currently running."

# ─── 2. SYSTEMD SERVICES ──────────────────────────────────────────────────────
print_header "Systemd LLM Services"
for svc in ollama localai gpt4all jan llamafile; do
    if systemctl list-units --full --all 2>/dev/null | grep -qi "$svc"; then
        STATUS=$(systemctl is-active "$svc" 2>/dev/null || echo "unknown")
        print_found "Systemd service: $svc ($STATUS)"
    fi
done

# ─── 3. INSTALLED PACKAGES / CLI TOOLS ────────────────────────────────────────
print_header "Installed LLM CLI Tools"
for cmd in ollama localai llamafile llm lm-studio; do
    if command -v "$cmd" &>/dev/null; then
        print_found "CLI: $cmd ($(command -v $cmd))"
    fi
done

# Docker containers
if command -v docker &>/dev/null; then
    print_header "Docker Containers (LLM-related)"
    docker ps -a 2>/dev/null | grep -iE "ollama|localai|llama|gpt|tgi|vllm|lmstudio|jan" || echo "  No LLM-related Docker containers found."
fi

# ─── 4. MODEL DIRECTORIES ─────────────────────────────────────────────────────
print_header "Model Directories"
MODEL_DIRS=(
    "$HOME/.ollama/models"
    "/usr/share/ollama/.ollama/models"
    "$HOME/.lmstudio/models"
    "$HOME/jan/models"
    "/usr/share/local-ai/models"
    "$HOME/.local/share/nomic.ai/GPT4All"
    "$HOME/.cache/lm-studio"
    "/opt/ollama"
    "/var/lib/ollama"
)

for dir in "${MODEL_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        COUNT=$(find "$dir" -type f \( -name "*.gguf" -o -name "*.bin" -o -name "*.safetensors" -o -name "*.ggml" \) 2>/dev/null | wc -l)
        SIZE=$(du -sh "$dir" 2>/dev/null | cut -f1 || echo "unknown")
        print_found "Dir: $dir ($COUNT model files, ~$SIZE)"
    fi
done

# ─── 5. LIST OLLAMA MODELS ────────────────────────────────────────────────────
print_header "Ollama Registered Models"
if command -v ollama &>/dev/null; then
    ollama list 2>/dev/null || echo "  Ollama installed but not responding."
else
    echo "  Ollama CLI not found."
fi

# ─── 6. ALL MODEL FILES ───────────────────────────────────────────────────────
print_header "All Model Files Found on System"
echo "  (searching $HOME and common system paths...)"
find "$HOME" /usr /opt /var 2>/dev/null \
    -type f \( -name "*.gguf" -o -name "*.safetensors" -o -name "*.ggml" \) 2>/dev/null | \
    while read -r f; do
        SIZE=$(du -sh "$f" 2>/dev/null | cut -f1 || echo "?")
        echo "  [$SIZE] $f"
    done

# ─── 7. PROHIBITED MODEL SCAN ─────────────────────────────────────────────────
print_header "Prohibited / Foreign-Origin Model Scan"
find "$HOME" /usr /opt -type f \( -name "*.gguf" -o -name "*.bin" -o -name "*.safetensors" -o -name "*.ggml" \) 2>/dev/null | \
    grep -iE "$PROHIBITED_PATTERN" | while read -r f; do
        print_prohibited "PROHIBITED MODEL: $f"
    done

if command -v ollama &>/dev/null; then
    ollama list 2>/dev/null | grep -iE "$PROHIBITED_PATTERN" | while read -r line; do
        print_prohibited "PROHIBITED OLLAMA MODEL: $line"
    done
fi
echo "  Prohibited model scan complete."

# ─── 8. NETWORK EXPOSURE ──────────────────────────────────────────────────────
print_header "Network Exposure Check"
for PORT in 11434 1234 8080 3000 8000 5000; do
    if command -v ss &>/dev/null; then
        BINDING=$(ss -tlnp 2>/dev/null | grep ":$PORT " || true)
    else
        BINDING=$(netstat -tlnp 2>/dev/null | grep ":$PORT " || true)
    fi

    if [ -n "$BINDING" ]; then
        if echo "$BINDING" | grep -qE "0\.0\.0\.0|\*:|\[::\]"; then
            print_warn "Port $PORT is EXPOSED on all interfaces!"
            echo "  $BINDING"
        else
            print_found "Port $PORT listening (appears local): $BINDING"
        fi
    fi
done

# ─── 9. OLLAMA ENV / CONFIG ────────────────────────────────────────────────────
print_header "Ollama Configuration"
if [ -n "${OLLAMA_HOST:-}" ]; then
    echo "$OLLAMA_HOST" | grep -qE "0\.0\.0\.0|^:" && \
        print_warn "OLLAMA_HOST=$OLLAMA_HOST — EXPOSED TO NETWORK!" || \
        print_found "OLLAMA_HOST=$OLLAMA_HOST"
else
    echo "  OLLAMA_HOST not set (defaults to localhost:11434)"
fi

# Check systemd environment override
for unit_env in /etc/systemd/system/ollama.service.d/*.conf /lib/systemd/system/ollama.service; do
    if [ -f "$unit_env" ] && grep -q "OLLAMA_HOST" "$unit_env" 2>/dev/null; then
        print_warn "OLLAMA_HOST found in systemd unit: $unit_env"
        grep "OLLAMA_HOST" "$unit_env"
    fi
done

# ─── 10. MCP CONFIG SCAN ──────────────────────────────────────────────────────
print_header "MCP Config Files"
for f in \
    "$HOME/.config/Claude/claude_desktop_config.json" \
    "$HOME/.cursor/mcp.json" \
    "$HOME/.continue/config.json" \
    "$HOME/.config/Code/User/settings.json"; do
    if [ -f "$f" ] && grep -q "mcpServers" "$f" 2>/dev/null; then
        print_warn "MCP config: $f"
    fi
done
find "$HOME" -name "mcp.json" 2>/dev/null | while read -r f; do
    print_warn "mcp.json: $f"
done

# ─── SUMMARY ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}=== Scan Complete ===${NC}"
echo "Run audit.sh for full checklist or harden.sh to apply controls."
echo ""
