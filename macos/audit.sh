#!/usr/bin/env bash
# =============================================================================
# macOS LLM Audit Script
# Runs the full IT Staff audit checklist from the security guidance document
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

PASS=0; WARN=0; FAIL=0
PROHIBITED_PATTERN="deepseek|qwen|qwq|yi-[0-9]|baichuan|chatglm|internlm|minimax|ernie|hunyuan|tigerbot|aquila|moss|belle|rugpt|saiga|fred-t5|falcon"

check_pass() { echo -e "${GREEN}[PASS]${NC} $1"; PASS=$((PASS+1)); }
check_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; WARN=$((WARN+1)); }
check_fail() { echo -e "${RED}[FAIL]${NC} $1"; FAIL=$((FAIL+1)); }
print_header() { echo -e "\n${BOLD}${CYAN}=== $1 ===${NC}"; }

echo -e "${BOLD}${CYAN}"
echo "╔══════════════════════════════════════════════════════════╗"
echo "║         macOS LLM Security Audit Checklist              ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo "Date: $(date)"
echo "Host: $(hostname)"
echo "User: $(whoami)"

# ─── CHECK 1: LLM SOFTWARE INSTALLED ─────────────────────────────────────────
print_header "Check 1: LLM Software Detection"
FOUND=0
for proc in ollama lmstudio localai gpt4all jan; do
    if pgrep -fi "$proc" &>/dev/null || command -v "$proc" &>/dev/null; then
        check_warn "LLM software detected: $proc"
        FOUND=$((FOUND+1))
    fi
done
for app in "Ollama" "LM Studio" "GPT4All" "Jan" "LocalAI" "AnythingLLM"; do
    [ -d "/Applications/${app}.app" ] && { check_warn "App installed: ${app}.app"; FOUND=$((FOUND+1)); }
done
[ "$FOUND" -eq 0 ] && check_pass "No LLM software detected."

# ─── CHECK 2: MODELS PRESENT ─────────────────────────────────────────────────
print_header "Check 2: Models Present"
MODEL_COUNT=0
for dir in "$HOME/.ollama/models" "$HOME/.lmstudio/models" "$HOME/jan/models" \
           "$HOME/Library/Application Support/LM Studio" \
           "$HOME/Library/Application Support/nomic.ai/GPT4All"; do
    if [ -d "$dir" ]; then
        COUNT=$(find "$dir" -type f \( -name "*.gguf" -o -name "*.bin" -o -name "*.safetensors" \) 2>/dev/null | wc -l | tr -d ' ')
        check_warn "Model directory $dir — $COUNT model files found"
        MODEL_COUNT=$((MODEL_COUNT+COUNT))
    fi
done
if command -v ollama &>/dev/null; then
    OLLAMA_MODELS=$(ollama list 2>/dev/null | tail -n +2 | wc -l | tr -d ' ')
    [ "$OLLAMA_MODELS" -gt 0 ] && check_warn "Ollama has $OLLAMA_MODELS registered model(s)" || check_pass "No Ollama models registered."
fi
[ "$MODEL_COUNT" -eq 0 ] && check_pass "No model files found in default locations."

# ─── CHECK 3: PROHIBITED MODELS ───────────────────────────────────────────────
print_header "Check 3: Prohibited / Foreign-Origin Models"
PROHIBITED_COUNT=0
while IFS= read -r f; do
    if echo "$f" | grep -iEq "$PROHIBITED_PATTERN"; then
        check_fail "PROHIBITED MODEL FOUND: $f"
        PROHIBITED_COUNT=$((PROHIBITED_COUNT+1))
    fi
done < <(find "$HOME" -type f \( -name "*.gguf" -o -name "*.bin" -o -name "*.safetensors" \) 2>/dev/null)

if command -v ollama &>/dev/null; then
    while IFS= read -r line; do
        MODEL=$(echo "$line" | awk '{print $1}')
        if echo "$MODEL" | grep -iEq "$PROHIBITED_PATTERN"; then
            check_fail "PROHIBITED OLLAMA MODEL: $MODEL"
            PROHIBITED_COUNT=$((PROHIBITED_COUNT+1))
        fi
    done < <(ollama list 2>/dev/null | tail -n +2 || true)
fi
[ "$PROHIBITED_COUNT" -eq 0 ] && check_pass "No prohibited models detected."

# ─── CHECK 4: NETWORK BINDING ─────────────────────────────────────────────────
print_header "Check 4: Network Binding (Localhost Only?)"
for PORT in 11434 1234 8080; do
    BINDING=$(lsof -i TCP:"$PORT" -sTCP:LISTEN -n -P 2>/dev/null || true)
    if [ -n "$BINDING" ]; then
        if echo "$BINDING" | grep -qE "\*:|0\.0\.0\.0"; then
            check_fail "Port $PORT is EXPOSED on all interfaces (0.0.0.0 or *)"
        else
            check_warn "Port $PORT is listening — appears localhost-bound (verify below)"
            echo "$BINDING"
        fi
    else
        check_pass "Port $PORT — not listening."
    fi
done

# ─── CHECK 5: OLLAMA HOST ENV ─────────────────────────────────────────────────
print_header "Check 5: OLLAMA_HOST Environment Variable"
if [ -n "${OLLAMA_HOST:-}" ]; then
    if echo "$OLLAMA_HOST" | grep -qE "0\.0\.0\.0|^:"; then
        check_fail "OLLAMA_HOST=$OLLAMA_HOST — EXPOSES OLLAMA TO NETWORK"
    else
        check_warn "OLLAMA_HOST is set: $OLLAMA_HOST (verify this is intentional)"
    fi
else
    check_pass "OLLAMA_HOST not set — defaults to localhost."
fi

# ─── CHECK 6: FIREWALL STATUS ─────────────────────────────────────────────────
print_header "Check 6: macOS Firewall"
FW_STATE=$(defaults read /Library/Preferences/com.apple.alf globalstate 2>/dev/null || echo "0")
if [ "$FW_STATE" -ge 1 ]; then
    check_pass "macOS Application Firewall is enabled (state=$FW_STATE)."
else
    check_fail "macOS Application Firewall is DISABLED."
fi

# ─── CHECK 7: API AUTHENTICATION ──────────────────────────────────────────────
print_header "Check 7: API Authentication (Unauthenticated Access?)"
if lsof -i TCP:11434 -sTCP:LISTEN &>/dev/null 2>&1; then
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:11434/api/tags 2>/dev/null || echo "000")
    if [ "$RESPONSE" = "200" ]; then
        check_warn "Ollama API responds without authentication (HTTP 200) — expected for local-only; FAIL if network-exposed."
    else
        check_pass "Ollama API not reachable or requires auth (HTTP $RESPONSE)."
    fi
fi

if lsof -i TCP:1234 -sTCP:LISTEN &>/dev/null 2>&1; then
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:1234/v1/models 2>/dev/null || echo "000")
    if [ "$RESPONSE" = "200" ]; then
        check_warn "LM Studio API responds without authentication — FAIL if network-exposed."
    fi
fi

# ─── CHECK 8: MCP CONFIGS ─────────────────────────────────────────────────────
print_header "Check 8: MCP (Model Context Protocol) Configuration"
MCP_FOUND=0
for f in \
    "$HOME/Library/Application Support/Claude/claude_desktop_config.json" \
    "$HOME/.cursor/mcp.json" \
    "$HOME/.continue/config.json" \
    "$HOME/Library/Application Support/Code/User/settings.json" \
    "$HOME/Library/Application Support/Cursor/User/settings.json"; do
    if [ -f "$f" ] && grep -q "mcpServers" "$f" 2>/dev/null; then
        check_warn "MCP config found: $f"
        # Check for remote (url) servers
        if grep -q '"url"' "$f" 2>/dev/null; then
            check_fail "REMOTE MCP SERVER detected in: $f — requires immediate review!"
        fi
        # Check for npx -y (supply chain risk)
        if grep -q '"npx"' "$f" 2>/dev/null && grep -q '"-y"' "$f" 2>/dev/null; then
            check_warn "npx -y pattern found in $f (supply chain risk)"
        fi
        MCP_FOUND=$((MCP_FOUND+1))
    fi
done
while IFS= read -r f; do
    check_warn "mcp.json found: $f"
    MCP_FOUND=$((MCP_FOUND+1))
done < <(find "$HOME" -name "mcp.json" 2>/dev/null)
[ "$MCP_FOUND" -eq 0 ] && check_pass "No MCP server configurations found."

# ─── CHECK 9: AUTO-START ──────────────────────────────────────────────────────
print_header "Check 9: Auto-Start / Launch Agents"
for plist in \
    "$HOME/Library/LaunchAgents/com.ollama.ollama.plist" \
    "/Library/LaunchDaemons/com.ollama.ollama.plist"; do
    if [ -f "$plist" ]; then
        ENABLED=$(launchctl list 2>/dev/null | grep ollama || true)
        [ -n "$ENABLED" ] && check_warn "Ollama launch agent is active: $plist" || check_warn "Ollama launch agent file exists (may be disabled): $plist"
    fi
done

# ─── SUMMARY ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║                  AUDIT SUMMARY                          ║${NC}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo -e "  ${GREEN}PASS: $PASS${NC}   ${YELLOW}WARN: $WARN${NC}   ${RED}FAIL: $FAIL${NC}"
echo ""
if [ "$FAIL" -gt 0 ]; then
    echo -e "${RED}ACTION REQUIRED: $FAIL critical issue(s) found. Run harden.sh or escalate immediately.${NC}"
elif [ "$WARN" -gt 0 ]; then
    echo -e "${YELLOW}REVIEW RECOMMENDED: $WARN warning(s) found. Review and apply controls as needed.${NC}"
else
    echo -e "${GREEN}System appears compliant based on automated checks.${NC}"
fi
echo ""
