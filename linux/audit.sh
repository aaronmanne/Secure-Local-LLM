#!/usr/bin/env bash
# =============================================================================
# Linux LLM Security Audit Checklist
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
PASS=0; WARN=0; FAIL=0
PROHIBITED_PATTERN="deepseek|qwen|qwq|yi-[0-9]|baichuan|chatglm|internlm|minimax|ernie|hunyuan|tigerbot|aquila|moss|belle|rugpt|saiga|fred-t5|falcon"

check_pass() { echo -e "${GREEN}[PASS]${NC} $1"; PASS=$((PASS+1)); }
check_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; WARN=$((WARN+1)); }
check_fail() { echo -e "${RED}[FAIL]${NC} $1"; FAIL=$((FAIL+1)); }
print_header() { echo -e "\n${BOLD}${CYAN}=== $1 ===${NC}"; }

echo -e "${BOLD}${CYAN}"
echo "╔══════════════════════════════════════════════════════════╗"
echo "║         Linux LLM Security Audit Checklist              ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo "Date: $(date)"; echo "Host: $(hostname)"; echo "User: $(whoami)"

print_header "Check 1: LLM Software Detection"
FOUND=0
for cmd in ollama localai llamafile llm; do
    command -v "$cmd" &>/dev/null && { check_warn "Installed: $cmd"; FOUND=$((FOUND+1)); }
done
for svc in ollama localai; do
    systemctl list-units --full --all 2>/dev/null | grep -qi "$svc" && { check_warn "Systemd unit exists: $svc"; FOUND=$((FOUND+1)); }
done
if command -v docker &>/dev/null; then
    CONTAINERS=$(docker ps -a 2>/dev/null | grep -iE "ollama|localai|llama|vllm|tgi" || true)
    [ -n "$CONTAINERS" ] && { check_warn "LLM-related Docker containers found"; echo "$CONTAINERS"; }
fi
[ "$FOUND" -eq 0 ] && check_pass "No LLM software detected."

print_header "Check 2: Models Present"
MC=0
for dir in "$HOME/.ollama/models" "/usr/share/ollama/.ollama/models" "$HOME/.lmstudio/models" \
           "$HOME/jan/models" "/usr/share/local-ai/models" "$HOME/.local/share/nomic.ai/GPT4All"; do
    if [ -d "$dir" ]; then
        CNT=$(find "$dir" -type f \( -name "*.gguf" -o -name "*.bin" -o -name "*.safetensors" \) 2>/dev/null | wc -l)
        check_warn "Model dir: $dir ($CNT files)"
        MC=$((MC+CNT))
    fi
done
[ "$MC" -eq 0 ] && check_pass "No model files found in default locations."

print_header "Check 3: Prohibited Models"
PC=0
while IFS= read -r f; do
    echo "$f" | grep -iEq "$PROHIBITED_PATTERN" && { check_fail "PROHIBITED: $f"; PC=$((PC+1)); }
done < <(find "$HOME" /usr/share/ollama 2>/dev/null -type f \( -name "*.gguf" -o -name "*.safetensors" \) 2>/dev/null)
if command -v ollama &>/dev/null; then
    ollama list 2>/dev/null | tail -n +2 | while read -r line; do
        MODEL=$(echo "$line" | awk '{print $1}')
        echo "$MODEL" | grep -iEq "$PROHIBITED_PATTERN" && check_fail "PROHIBITED OLLAMA MODEL: $MODEL"
    done
fi
[ "$PC" -eq 0 ] && check_pass "No prohibited models detected."

print_header "Check 4: Network Binding"
for PORT in 11434 1234 8080; do
    if command -v ss &>/dev/null; then
        BIND=$(ss -tlnp 2>/dev/null | grep ":$PORT " || true)
    else
        BIND=$(netstat -tlnp 2>/dev/null | grep ":$PORT " || true)
    fi
    if [ -n "$BIND" ]; then
        echo "$BIND" | grep -qE "0\.0\.0\.0|\*:|\[::\]" && \
            check_fail "Port $PORT EXPOSED on all interfaces: $BIND" || \
            check_warn "Port $PORT listening (verify localhost-only): $BIND"
    else
        check_pass "Port $PORT not listening."
    fi
done

print_header "Check 5: OLLAMA_HOST"
if [ -n "${OLLAMA_HOST:-}" ]; then
    echo "$OLLAMA_HOST" | grep -qE "0\.0\.0\.0|^:" && \
        check_fail "OLLAMA_HOST=$OLLAMA_HOST — NETWORK EXPOSED" || \
        check_warn "OLLAMA_HOST=$OLLAMA_HOST (verify)"
else
    check_pass "OLLAMA_HOST not set (defaults to localhost)."
fi

# Check systemd unit for OLLAMA_HOST override
for f in /etc/systemd/system/ollama.service.d/*.conf /lib/systemd/system/ollama.service; do
    [ -f "$f" ] && grep -q "OLLAMA_HOST" "$f" 2>/dev/null && \
        check_warn "OLLAMA_HOST in systemd unit $f: $(grep OLLAMA_HOST $f)"
done

print_header "Check 6: Firewall Status"
if command -v ufw &>/dev/null; then
    UFW_STATUS=$(sudo ufw status 2>/dev/null | head -1 || echo "Status: inactive")
    echo "$UFW_STATUS" | grep -qi "active" && check_pass "UFW is active." || check_fail "UFW is inactive."
elif command -v firewall-cmd &>/dev/null; then
    firewall-cmd --state 2>/dev/null | grep -qi "running" && check_pass "firewalld is running." || check_fail "firewalld not running."
elif command -v iptables &>/dev/null; then
    RULES=$(sudo iptables -L INPUT -n 2>/dev/null | grep -E "11434|1234|8080" || true)
    [ -n "$RULES" ] && check_pass "iptables rules found for LLM ports." || check_warn "No iptables rules found for LLM ports."
else
    check_warn "No firewall tool detected."
fi

print_header "Check 7: API Authentication"
for PORT in 11434 1234 8080; do
    if ss -tlnp 2>/dev/null | grep -q ":$PORT "; then
        RESP=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:$PORT" 2>/dev/null || echo "000")
        [ "$RESP" = "200" ] && check_warn "Port $PORT responds unauthenticated (HTTP 200)"
    fi
done

print_header "Check 8: MCP Configurations"
MC=0
for f in "$HOME/.config/Claude/claude_desktop_config.json" "$HOME/.cursor/mcp.json" \
         "$HOME/.continue/config.json" "$HOME/.config/Code/User/settings.json"; do
    if [ -f "$f" ] && grep -q "mcpServers" "$f" 2>/dev/null; then
        check_warn "MCP config: $f"
        grep -q '"url"' "$f" 2>/dev/null && check_fail "REMOTE MCP server in $f!"
        MC=$((MC+1))
    fi
done
while IFS= read -r f; do check_warn "mcp.json: $f"; MC=$((MC+1)); done < <(find "$HOME" -name "mcp.json" 2>/dev/null)
[ "$MC" -eq 0 ] && check_pass "No MCP configurations found."

print_header "Check 9: Auto-Start"
for svc in ollama localai; do
    if systemctl is-enabled "$svc" &>/dev/null 2>&1; then
        check_warn "Service is enabled to auto-start: $svc"
    fi
done

echo ""
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║                  AUDIT SUMMARY                          ║${NC}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo -e "  ${GREEN}PASS: $PASS${NC}   ${YELLOW}WARN: $WARN${NC}   ${RED}FAIL: $FAIL${NC}"
echo ""
[ "$FAIL" -gt 0 ] && echo -e "${RED}ACTION REQUIRED: $FAIL critical issue(s). Run harden.sh or escalate.${NC}"
[ "$WARN" -gt 0 ] && [ "$FAIL" -eq 0 ] && echo -e "${YELLOW}REVIEW: $WARN warning(s) found.${NC}"
[ "$FAIL" -eq 0 ] && [ "$WARN" -eq 0 ] && echo -e "${GREEN}System appears compliant.${NC}"
echo ""
