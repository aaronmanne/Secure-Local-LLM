#!/usr/bin/env bash
# =============================================================================
# macOS LLM Identification Script
# Identifies locally installed LLM tools, models, and related software
# =============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

PROHIBITED_PATTERN="deepseek|qwen|qwq|yi-[0-9]|baichuan|chatglm|internlm|minimax|ernie|hunyuan|tigerbot|aquila|moss|belle|rugpt|saiga|fred-t5|falcon"

print_header() {
    echo -e "\n${BOLD}${CYAN}=== $1 ===${NC}"
}

print_found() {
    echo -e "${GREEN}[FOUND]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_prohibited() {
    echo -e "${RED}[PROHIBITED]${NC} $1"
}

print_info() {
    echo -e "  $1"
}

echo -e "${BOLD}${CYAN}"
echo "╔══════════════════════════════════════════════════════════╗"
echo "║         macOS LLM Installation Identifier               ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo "Scanning system for local LLM tools and models..."
echo "Date: $(date)"
echo "Host: $(hostname)"
echo "User: $(whoami)"
echo ""

# ─── 1. RUNNING PROCESSES ─────────────────────────────────────────────────────
print_header "Running LLM Processes"
FOUND_PROCS=0
for proc in ollama lmstudio "lm studio" localai gpt4all jan llamafile llm; do
    if pgrep -fi "$proc" > /dev/null 2>&1; then
        print_found "Process running: $proc"
        pgrep -fla "$proc" 2>/dev/null | while read -r line; do print_info "$line"; done
        FOUND_PROCS=$((FOUND_PROCS+1))
    fi
done
[ "$FOUND_PROCS" -eq 0 ] && echo "  No LLM processes currently running."

# ─── 2. INSTALLED APPLICATIONS ────────────────────────────────────────────────
print_header "Installed LLM Applications"
FOUND_APPS=0
for app in "Ollama" "LM Studio" "LM_Studio" "GPT4All" "Jan" "LocalAI" "Open WebUI" "AnythingLLM"; do
    if [ -d "/Applications/${app}.app" ] || [ -d "$HOME/Applications/${app}.app" ]; then
        print_found "App: ${app}.app"
        FOUND_APPS=$((FOUND_APPS+1))
    fi
done

# Check brew-installed CLI tools
for cmd in ollama localai llamafile llm; do
    if command -v "$cmd" &>/dev/null; then
        print_found "CLI tool: $cmd ($(command -v $cmd))"
        FOUND_APPS=$((FOUND_APPS+1))
    fi
done
[ "$FOUND_APPS" -eq 0 ] && echo "  No LLM applications found."

# ─── 3. MODEL DIRECTORIES ─────────────────────────────────────────────────────
print_header "Model Directories"

declare -a MODEL_DIRS=(
    "$HOME/.ollama/models"
    "$HOME/.lmstudio/models"
    "$HOME/Library/Application Support/LM Studio"
    "$HOME/Library/Application Support/nomic.ai/GPT4All"
    "$HOME/jan/models"
    "$HOME/.localai/models"
    "$HOME/.cache/lm-studio"
)

for dir in "${MODEL_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        COUNT=$(find "$dir" -type f \( -name "*.gguf" -o -name "*.bin" -o -name "*.safetensors" -o -name "*.ggml" -o -name "*.pt" -o -name "*.pth" \) 2>/dev/null | wc -l | tr -d ' ')
        SIZE=$(du -sh "$dir" 2>/dev/null | cut -f1 || echo "unknown")
        print_found "Dir: $dir ($COUNT model files, ~$SIZE)"
    fi
done

# ─── 4. LIST OLLAMA MODELS ────────────────────────────────────────────────────
print_header "Ollama Registered Models"
if command -v ollama &>/dev/null; then
    ollama list 2>/dev/null || echo "  Ollama installed but not responding."
else
    echo "  Ollama CLI not found."
fi

# ─── 5. SEARCH FOR MODEL FILES ────────────────────────────────────────────────
print_header "All Model Files Found on System"
echo "  (searching common locations — may take a moment...)"
find "$HOME" /usr /opt -type f \( -name "*.gguf" -o -name "*.safetensors" -o -name "*.ggml" \) 2>/dev/null | while read -r f; do
    SIZE=$(du -sh "$f" 2>/dev/null | cut -f1 || echo "?")
    echo "  [$SIZE] $f"
done

# ─── 6. PROHIBITED MODEL SCAN ─────────────────────────────────────────────────
print_header "Prohibited / Foreign-Origin Model Scan"
echo "  Scanning for Chinese/Russian/UAE-origin model names..."
PROHIBITED_FOUND=0

find "$HOME" -type f \( -name "*.gguf" -o -name "*.bin" -o -name "*.safetensors" -o -name "*.ggml" \) 2>/dev/null | \
    grep -iE "$PROHIBITED_PATTERN" | while read -r f; do
        print_prohibited "PROHIBITED MODEL: $f"
        PROHIBITED_FOUND=$((PROHIBITED_FOUND+1))
    done

if command -v ollama &>/dev/null; then
    ollama list 2>/dev/null | grep -iE "$PROHIBITED_PATTERN" | while read -r line; do
        print_prohibited "PROHIBITED OLLAMA MODEL: $line"
    done
fi

echo "  Prohibited model scan complete."

# ─── 7. NETWORK EXPOSURE CHECK ────────────────────────────────────────────────
print_header "Network Exposure Check"
for PORT in 11434 1234 8080 3000 8000 5000; do
    BINDING=$(lsof -i TCP:"$PORT" -sTCP:LISTEN -n -P 2>/dev/null | grep -v COMMAND || true)
    if [ -n "$BINDING" ]; then
        if echo "$BINDING" | grep -q "0.0.0.0\|\*:"; then
            print_warn "Port $PORT is EXPOSED on all interfaces!"
            echo "$BINDING" | while read -r line; do print_info "$line"; done
        else
            print_found "Port $PORT is listening (localhost only)"
            echo "$BINDING" | while read -r line; do print_info "$line"; done
        fi
    fi
done

# ─── 8. OLLAMA ENV / CONFIG ────────────────────────────────────────────────────
print_header "Ollama Configuration"
if [ -n "${OLLAMA_HOST:-}" ]; then
    if echo "$OLLAMA_HOST" | grep -qE "0\.0\.0\.0|^:"; then
        print_warn "OLLAMA_HOST=$OLLAMA_HOST — EXPOSED TO NETWORK!"
    else
        print_found "OLLAMA_HOST=$OLLAMA_HOST"
    fi
else
    echo "  OLLAMA_HOST not set (defaults to localhost:11434)"
fi

if [ -d "$HOME/.ollama" ]; then
    print_found ".ollama directory exists: $HOME/.ollama"
    ls -la "$HOME/.ollama/" 2>/dev/null || true
fi

# ─── 9. MCP CONFIG SCAN ───────────────────────────────────────────────────────
print_header "MCP (Model Context Protocol) Config Files"
MCP_LOCATIONS=(
    "$HOME/Library/Application Support/Claude/claude_desktop_config.json"
    "$HOME/.cursor/mcp.json"
    "$HOME/.continue/config.json"
    "$HOME/Library/Application Support/Code/User/settings.json"
    "$HOME/Library/Application Support/Cursor/User/settings.json"
)

for f in "${MCP_LOCATIONS[@]}"; do
    if [ -f "$f" ]; then
        if grep -q "mcpServers" "$f" 2>/dev/null; then
            print_warn "MCP config found: $f"
            grep -A 3 "mcpServers" "$f" | head -20 || true
        fi
    fi
done

find "$HOME" -name "mcp.json" 2>/dev/null | while read -r f; do
    print_warn "MCP config file: $f"
done

# ─── SUMMARY ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}=== Scan Complete ===${NC}"
echo "Review any ${RED}[PROHIBITED]${NC} or ${YELLOW}[WARN]${NC} items above."
echo "Run audit.sh for full compliance checklist or harden.sh to apply controls."
echo ""
