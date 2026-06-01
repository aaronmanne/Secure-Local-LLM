#!/usr/bin/env bash
# =============================================================================
# macOS LLM Security Audit Checklist
# Full PASS/WARN/FAIL checklist — sources shared patterns from common/
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../common/patterns.sh
source "$SCRIPT_DIR/common/patterns.sh"

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; BOLD='\033[1m'; NC='\033[0m'
PASS=0; WARN=0; FAIL=0

check_pass() { echo -e "${GREEN}[PASS]${NC} $1"; PASS=$((PASS+1)); }
check_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; WARN=$((WARN+1)); }
check_fail() { echo -e "${RED}[FAIL]${NC} $1"; FAIL=$((FAIL+1)); }
check_review(){ echo -e "${MAGENTA}[REVIEW]${NC} $1"; WARN=$((WARN+1)); }
print_header() { echo -e "\n${BOLD}${CYAN}=== $1 ===${NC}"; }

echo -e "${BOLD}${CYAN}"
echo "╔══════════════════════════════════════════════════════════╗"
echo "║       macOS LLM & Agent Security Audit Checklist         ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo "Date: $(date) | Host: $(hostname) | User: $(whoami)"

# ─── Check 1: Inference Servers ───────────────────────────────────────────────
print_header "Check 1: Inference Server Software"
F=0
while IFS= read -r line; do
    check_warn "Inference server running: $line"; F=$((F+1))
done < <(pgrep -fla . 2>/dev/null | grep -iE "$LLM_PROCESS_PATTERN" | grep -v "grep\|$$\|audit" || true)
for cmd in "${LLM_CLI_TOOLS[@]}"; do
    command -v "$cmd" &>/dev/null && { check_warn "CLI installed: $cmd"; F=$((F+1)); }
done
[ "$F" -eq 0 ] && check_pass "No inference server software detected."

# ─── Check 2: AI Agent Frameworks ────────────────────────────────────────────
print_header "Check 2: AI Agent Frameworks / Coding Agents"
F=0
while IFS= read -r line; do
    check_warn "Agent process: $line"; F=$((F+1))
done < <(pgrep -fla . 2>/dev/null | grep -iE "$AGENT_PROCESS_PATTERN" | grep -v "grep\|$$\|audit" || true)
for cmd in "${AGENT_CLI_TOOLS[@]}"; do
    command -v "$cmd" &>/dev/null && { check_warn "Agent CLI: $cmd"; F=$((F+1)); }
done
AGENT_DIRS=("$HOME/.autogpt" "$HOME/AutoGPT" "$HOME/.crewai" "$HOME/.autogen" "$HOME/.opendevin" "$HOME/.openhands" "$HOME/.goose" "$HOME/.plandex" "$HOME/.aider" "$HOME/flowise" "$HOME/.n8n" "$HOME/.memgpt" "$HOME/.letta" "$HOME/dify")
for d in "${AGENT_DIRS[@]}"; do [ -d "$d" ] && { check_warn "Agent config dir: $d"; F=$((F+1)); }; done
[ "$F" -eq 0 ] && check_pass "No AI agent frameworks detected."

# ─── Check 3: Vector Databases ───────────────────────────────────────────────
print_header "Check 3: Vector Databases (RAG backends)"
F=0
while IFS= read -r line; do
    check_warn "Vector DB process: $line"; F=$((F+1))
done < <(pgrep -fla . 2>/dev/null | grep -iE "$VECTORDB_PROCESS_PATTERN" | grep -v "grep\|$$" || true)
[ "$F" -eq 0 ] && check_pass "No vector database processes detected."

# ─── Check 4: Models Present ──────────────────────────────────────────────────
print_header "Check 4: Model Files Present"
MC=0
for dir in "${MODEL_DIRS_MACOS[@]}"; do
    if [ -d "$dir" ]; then
        CNT=$(find "$dir" -type f \( -name "*.gguf" -o -name "*.safetensors" -o -name "*.ggml" \) 2>/dev/null | wc -l | tr -d ' ')
        check_warn "Model dir: $dir ($CNT files)"; MC=$((MC+CNT))
    fi
done
if command -v ollama &>/dev/null; then
    OM=$(ollama list 2>/dev/null | tail -n +2 | wc -l | tr -d ' ')
    [ "$OM" -gt 0 ] && check_warn "Ollama: $OM registered model(s)" || check_pass "No Ollama models registered."
fi
[ "$MC" -eq 0 ] && check_pass "No model files in default locations."

# ─── Check 5: Prohibited Models ───────────────────────────────────────────────
print_header "Check 5: Prohibited / Foreign-Origin Models"
PC=0
while IFS= read -r f; do
    echo "$f" | grep -iEq "$PROHIBITED_PATTERN" && { check_fail "PROHIBITED MODEL: $f"; PC=$((PC+1)); }
done < <(find "$HOME" -type f \( -name "*.gguf" -o -name "*.bin" -o -name "*.safetensors" -o -name "*.ggml" \) 2>/dev/null)
if command -v ollama &>/dev/null; then
    ollama list 2>/dev/null | tail -n +2 | while read -r line; do
        M=$(echo "$line" | awk '{print $1}')
        echo "$M" | grep -iEq "$PROHIBITED_PATTERN" && { check_fail "PROHIBITED OLLAMA MODEL: $M"; PC=$((PC+1)); }
    done
fi
[ "$PC" -eq 0 ] && check_pass "No prohibited models detected."

# ─── Check 6: Review-Warranted Models ────────────────────────────────────────
print_header "Check 6: Models Requiring Provenance Review"
RC=0
find "$HOME" -type f \( -name "*.gguf" -o -name "*.safetensors" \) 2>/dev/null | \
    grep -iE "$REVIEW_PATTERN" | while read -r f; do
        check_review "Verify origin: $f"; RC=$((RC+1))
    done
[ "$RC" -eq 0 ] && check_pass "No review-warranted models detected."

# ─── Check 7: Network Binding ─────────────────────────────────────────────────
print_header "Check 7: Network Port Binding"
for entry in "${LLM_PORTS[@]}"; do
    PORT="${entry%%:*}"; TOOL="${entry#*:}"
    B=$(lsof -i TCP:"$PORT" -sTCP:LISTEN -n -P 2>/dev/null || true)
    if [ -n "$B" ]; then
        echo "$B" | grep -qE "\*:|0\.0\.0\.0" && \
            check_fail "Port $PORT ($TOOL) EXPOSED on all interfaces!" || \
            check_warn "Port $PORT ($TOOL) listening — verify localhost-only"
    else
        check_pass "Port $PORT ($TOOL) — not listening."
    fi
done

# ─── Check 8: OLLAMA_HOST ─────────────────────────────────────────────────────
print_header "Check 8: OLLAMA_HOST Environment"
OH="${OLLAMA_HOST:-}"
if [ -n "$OH" ]; then
    echo "$OH" | grep -qE "0\.0\.0\.0|^:" && \
        check_fail "OLLAMA_HOST=$OH — NETWORK EXPOSED" || \
        check_warn "OLLAMA_HOST=$OH (verify)"
else
    check_pass "OLLAMA_HOST not set (defaults to localhost)."
fi

# ─── Check 9: macOS Firewall ──────────────────────────────────────────────────
print_header "Check 9: macOS Application Firewall"
FW=$(defaults read /Library/Preferences/com.apple.alf globalstate 2>/dev/null || echo "0")
[ "$FW" -ge 1 ] && check_pass "Firewall enabled (state=$FW)." || check_fail "Firewall DISABLED."

# ─── Check 10: API Auth ───────────────────────────────────────────────────────
print_header "Check 10: API Authentication"
for PORT in 11434 1234 8080 7860 8000 8001 5001; do
    if lsof -i TCP:"$PORT" -sTCP:LISTEN -n -P &>/dev/null 2>&1; then
        RESP=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:$PORT" --max-time 2 2>/dev/null || echo "000")
        [ "$RESP" = "200" ] && check_warn "Port $PORT responds unauthenticated (HTTP 200) — FAIL if network-exposed."
    fi
done

# ─── Check 11: MCP ────────────────────────────────────────────────────────────
print_header "Check 11: MCP Server Configurations"
MC=0
for f in "${MCP_CONFIG_PATHS_MACOS[@]}"; do
    if [ -f "$f" ] && grep -q "mcpServers" "$f" 2>/dev/null; then
        check_warn "MCP config: $f"; MC=$((MC+1))
        grep -q '"url"' "$f" 2>/dev/null && check_fail "REMOTE MCP server in $f!"
        grep -q '"npx"' "$f" 2>/dev/null && grep -q '"-y"' "$f" 2>/dev/null && \
            check_warn "npx -y (supply chain risk) in $f"
    fi
done
find "$HOME" -name "mcp.json" 2>/dev/null | while read -r f; do
    check_warn "mcp.json: $f"; MC=$((MC+1))
done
[ "$MC" -eq 0 ] && check_pass "No MCP configurations found."

# ─── Check 12: Auto-Start ─────────────────────────────────────────────────────
print_header "Check 12: Auto-Start / Launch Agents"
for plist in "$HOME/Library/LaunchAgents/com.ollama.ollama.plist" "/Library/LaunchDaemons/com.ollama.ollama.plist"; do
    [ -f "$plist" ] && { check_warn "Ollama launch item: $plist"; }
done
# Check for other LLM launch agents
find "$HOME/Library/LaunchAgents" /Library/LaunchAgents /Library/LaunchDaemons 2>/dev/null \
    -name "*.plist" | xargs grep -lE "ollama|lmstudio|localai|kobold|tabby|oobabooga|anythingllm" 2>/dev/null | \
    while read -r f; do check_warn "LLM launch plist: $f"; done || true

# ─── SUMMARY ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║                  AUDIT SUMMARY                           ║${NC}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo -e "  ${GREEN}PASS: $PASS${NC}   ${YELLOW}WARN: $WARN${NC}   ${RED}FAIL: $FAIL${NC}"
echo ""
[ "$FAIL" -gt 0 ] && echo -e "${RED}ACTION REQUIRED: $FAIL critical issue(s). Run harden.sh or escalate.${NC}"
[ "$WARN" -gt 0 ] && [ "$FAIL" -eq 0 ] && echo -e "${YELLOW}REVIEW: $WARN warning(s) found.${NC}"
[ "$FAIL" -eq 0 ] && [ "$WARN" -eq 0 ] && echo -e "${GREEN}System appears compliant.${NC}"
echo ""
