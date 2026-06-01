#!/usr/bin/env bash
# =============================================================================
# Linux LLM Security Audit Checklist
# Regulatory basis: NIST SP 800-53; NIST AI 600-1; CMMC 2.0;
#                   DFARS 252.204-7012; EO 14110; FBI-DEEPSEEK
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/common/patterns.sh"
source "$SCRIPT_DIR/common/references.sh"

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; BOLD='\033[1m'; NC='\033[0m'
PASS=0; WARN=0; FAIL=0

check_pass()   { echo -e "${GREEN}[PASS]${NC} $1";    PASS=$((PASS+1)); }
check_warn()   { echo -e "${YELLOW}[WARN]${NC} $1";   WARN=$((WARN+1)); }
check_fail()   { echo -e "${RED}[FAIL]${NC} $1";      FAIL=$((FAIL+1)); }
check_review() { echo -e "${MAGENTA}[REVIEW]${NC} $1"; WARN=$((WARN+1)); }
print_header() { echo -e "\n${BOLD}${CYAN}=== $1 ===${NC}"; }

echo -e "${BOLD}${CYAN}"
echo "╔══════════════════════════════════════════════════════════╗"
echo "║       Linux LLM & Agent Security Audit Checklist         ║"
echo "║  Ref: NIST SP 800-53 · NIST AI 600-1 · CMMC 2.0          ║"
echo "║       DFARS 252.204-7012 · EO 14110 · FBI-DEEPSEEK       ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo "Date: $(date) | Host: $(hostname) | User: $(whoami)"

# ─── Check 1: Inference Servers ───────────────────────────────────────────────
print_header "Check 1: Inference Server Software  [NIST SP 800-53 CM-7]"
F=0
while IFS= read -r line; do
    check_warn "Inference server running: $line"; F=$((F+1))
done < <(pgrep -fla . 2>/dev/null | grep -iE "$LLM_PROCESS_PATTERN" | grep -v "grep\|$$\|audit" || true)
for cmd in "${LLM_CLI_TOOLS[@]}"; do command -v "$cmd" &>/dev/null && { check_warn "CLI: $cmd"; F=$((F+1)); }; done
for svc in ollama localai tabby koboldcpp text-generation-webui vllm xinference; do
    systemctl list-units --full --all 2>/dev/null | grep -qi "^$svc" && { check_warn "Systemd: $svc ($(systemctl is-active $svc 2>/dev/null))"; F=$((F+1)); }
done
[ "$F" -eq 0 ] && check_pass "No inference server software detected."

# ─── Check 2: AI Agents ───────────────────────────────────────────────────────
print_header "Check 2: AI Agent Frameworks  [NIST AI 600-1 §2.6; NIST SP 800-53 SA-4]"
F=0
while IFS= read -r line; do
    check_warn "Agent process: $line"; F=$((F+1))
done < <(pgrep -fla . 2>/dev/null | grep -iE "$AGENT_PROCESS_PATTERN" | grep -v "grep\|$$\|audit" || true)
for cmd in "${AGENT_CLI_TOOLS[@]}"; do command -v "$cmd" &>/dev/null && { check_warn "Agent CLI: $cmd"; F=$((F+1)); }; done
AGENT_DIRS=("$HOME/.autogpt" "$HOME/AutoGPT" "$HOME/.crewai" "$HOME/.autogen" "$HOME/.opendevin" "$HOME/.openhands" "$HOME/.goose" "$HOME/.plandex" "$HOME/.aider" "$HOME/flowise" "$HOME/.n8n" "$HOME/.memgpt" "$HOME/.letta" "$HOME/dify")
for d in "${AGENT_DIRS[@]}"; do [ -d "$d" ] && { check_warn "Agent config dir: $d"; F=$((F+1)); }; done
[ "$F" -eq 0 ] && check_pass "No AI agent frameworks detected."

# ─── Check 3: Vector Databases ────────────────────────────────────────────────
print_header "Check 3: Vector Databases  [NIST SP 800-53 SC-28: Protection at Rest]"
F=0
while IFS= read -r line; do
    check_warn "Vector DB: $line"; F=$((F+1))
done < <(pgrep -fla . 2>/dev/null | grep -iE "$VECTORDB_PROCESS_PATTERN" | grep -v "grep\|$$" || true)
for svc in qdrant weaviate milvus chromadb; do
    systemctl list-units --full --all 2>/dev/null | grep -qi "$svc" && { check_warn "Vector DB service: $svc"; F=$((F+1)); }
done
[ "$F" -eq 0 ] && check_pass "No vector database processes detected."

# ─── Check 4: Docker Containers ───────────────────────────────────────────────
print_header "Check 4: Docker / Container Workloads  [NIST SP 800-53 CM-8]"
if command -v docker &>/dev/null; then
    CONTAINERS=$(docker ps -a 2>/dev/null | grep -iE "ollama|localai|llama|vllm|tgi|kobold|tabby|anythingllm|privategpt|flowise|autogpt|crewai|opendevin|langchain|memgpt" || true)
    [ -n "$CONTAINERS" ] && { check_warn "LLM/agent containers found:"; echo "$CONTAINERS"; } || check_pass "No LLM-related Docker containers."
fi

# ─── Check 5: Models Present ──────────────────────────────────────────────────
print_header "Check 5: Model Files Present  [NIST AI 600-1 §2.5: Model Provenance]"
MC=0
for dir in "${MODEL_DIRS_LINUX[@]}"; do
    if [ -d "$dir" ]; then
        CNT=$(find "$dir" -type f \( -name "*.gguf" -o -name "*.safetensors" -o -name "*.ggml" \) 2>/dev/null | wc -l)
        check_warn "Model dir: $dir ($CNT files)"; MC=$((MC+CNT))
    fi
done
[ "$MC" -eq 0 ] && check_pass "No model files in default locations."

# ─── Check 6: Prohibited Models ───────────────────────────────────────────────
print_header "Check 6: Prohibited / Foreign-Origin Models  [FBI-DEEPSEEK; HOUSE-DEEPSEEK; NIST AI 600-1 §2.5]"
PC=0
while IFS= read -r f; do
    echo "$f" | grep -iEq "$PROHIBITED_PATTERN" && { check_fail "PROHIBITED: $f"; PC=$((PC+1)); }
done < <(find "$HOME" /usr/share/ollama 2>/dev/null -type f \( -name "*.gguf" -o -name "*.safetensors" -o -name "*.ggml" \) 2>/dev/null)
if command -v ollama &>/dev/null; then
    ollama list 2>/dev/null | tail -n +2 | while read -r line; do
        M=$(echo "$line" | awk '{print $1}')
        echo "$M" | grep -iEq "$PROHIBITED_PATTERN" && { check_fail "PROHIBITED OLLAMA MODEL: $M"; PC=$((PC+1)); }
    done
fi
[ "$PC" -eq 0 ] && check_pass "No prohibited models detected."

# ─── Check 7: Review-Warranted Models ────────────────────────────────────────
print_header "Check 7: Models Requiring Provenance Review  [NIST AI 600-1 §2.5]"
RC=0
find "$HOME" -type f \( -name "*.gguf" -o -name "*.safetensors" \) 2>/dev/null | \
    grep -iE "$REVIEW_PATTERN" | while read -r f; do check_review "Verify origin: $f"; RC=$((RC+1)); done
[ "$RC" -eq 0 ] && check_pass "No review-warranted models detected."

# ─── Check 8: Network Binding ─────────────────────────────────────────────────
print_header "Check 8: Network Port Binding  [NIST SP 800-53 SC-7: Boundary Protection]"
for entry in "${LLM_PORTS[@]}"; do
    PORT="${entry%%:*}"; TOOL="${entry#*:}"
    BIND=$(ss -tlnp 2>/dev/null | grep ":$PORT " || netstat -tlnp 2>/dev/null | grep ":$PORT " || true)
    if [ -n "$BIND" ]; then
        echo "$BIND" | grep -qE "0\.0\.0\.0|\*:|\[::\]" && \
            check_fail "Port $PORT ($TOOL) EXPOSED!  [Ref: NIST SP 800-53 SC-7]" || \
            check_warn "Port $PORT ($TOOL) listening — verify localhost-only"
    else
        check_pass "Port $PORT ($TOOL) — not listening."
    fi
done

# ─── Check 9: OLLAMA_HOST ─────────────────────────────────────────────────────
print_header "Check 9: OLLAMA_HOST  [NIST SP 800-53 SC-7, IA-3]"
OH="${OLLAMA_HOST:-}"
if [ -n "$OH" ]; then
    echo "$OH" | grep -qE "0\.0\.0\.0|^:" && \
        check_fail "OLLAMA_HOST=$OH — NETWORK EXPOSED  [Ref: NIST SP 800-53 SC-7]" || \
        check_warn "OLLAMA_HOST=$OH (verify)"
else
    check_pass "OLLAMA_HOST not set (defaults to localhost)."
fi
for f in /etc/systemd/system/ollama.service.d/*.conf /lib/systemd/system/ollama.service; do
    [ -f "$f" ] && grep -q "OLLAMA_HOST" "$f" 2>/dev/null && \
        check_warn "OLLAMA_HOST in systemd unit: $f → $(grep OLLAMA_HOST $f)"
done

# ─── Check 10: Firewall ───────────────────────────────────────────────────────
print_header "Check 10: Firewall Status  [NIST SP 800-53 SC-7; CMMC AC.L2-3.1.3]"
if command -v ufw &>/dev/null; then
    STATUS=$(sudo ufw status 2>/dev/null | head -1 || echo "inactive")
    echo "$STATUS" | grep -qi "active" && check_pass "UFW active." || check_fail "UFW inactive.  [Ref: NIST SP 800-53 SC-7]"
    for entry in "${LLM_PORTS[@]}"; do
        PORT="${entry%%:*}"; TOOL="${entry#*:}"
        sudo ufw status 2>/dev/null | grep -q "$PORT" && check_pass "UFW rule for $PORT ($TOOL)." || check_warn "No UFW rule for $PORT ($TOOL)."
    done
elif command -v firewall-cmd &>/dev/null; then
    firewall-cmd --state 2>/dev/null | grep -qi "running" && check_pass "firewalld running." || check_fail "firewalld not running."
elif command -v iptables &>/dev/null; then
    RULES=$(sudo iptables -L INPUT -n 2>/dev/null | grep -E "${LLM_PORT_NUMS}" || true)
    [ -n "$RULES" ] && check_pass "iptables rules found for LLM ports." || check_warn "No iptables LLM rules found."
else
    check_warn "No firewall tool found."
fi

# ─── Check 11: API Authentication ────────────────────────────────────────────
print_header "Check 11: API Authentication  [NIST SP 800-53 IA-2, IA-3]"
for PORT in 11434 1234 8080 7860 8000 8001 5001; do
    BIND=$(ss -tlnp 2>/dev/null | grep ":$PORT " || true)
    if [ -n "$BIND" ]; then
        RESP=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:$PORT" --max-time 2 2>/dev/null || echo "000")
        [ "$RESP" = "200" ] && check_warn "Port $PORT unauthenticated (HTTP 200)  [Ref: NIST SP 800-53 IA-2]"
    fi
done

# ─── Check 12: MCP ────────────────────────────────────────────────────────────
print_header "Check 12: MCP Configurations  [NIST AI 100-2; NSA-AI-SECURITY]"
MC=0
for f in "${MCP_CONFIG_PATHS_LINUX[@]}"; do
    if [ -f "$f" ] && grep -q "mcpServers" "$f" 2>/dev/null; then
        check_warn "MCP config: $f"; MC=$((MC+1))
        grep -q '"url"' "$f" 2>/dev/null && check_fail "REMOTE MCP server in $f!  [Ref: FBI-FOREIGN-AI]"
        grep -qiE '"(api_key|token|password)"\s*:' "$f" 2>/dev/null && check_fail "Credentials in $f  [Ref: NIST SP 800-53 IA-5]"
    fi
done
find "$HOME" -name "mcp.json" 2>/dev/null | while read -r f; do check_warn "mcp.json: $f"; MC=$((MC+1)); done
[ "$MC" -eq 0 ] && check_pass "No MCP configurations found."

# ─── Check 13: Auto-Start ────────────────────────────────────────────────────
print_header "Check 13: Auto-Start  [NIST SP 800-53 CM-7: Least Functionality]"
for svc in ollama localai tabby koboldcpp text-generation-webui vllm xinference; do
    systemctl is-enabled "$svc" &>/dev/null 2>&1 && check_warn "Auto-start enabled: $svc"
done

# ─── SUMMARY ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║                  AUDIT SUMMARY                           ║${NC}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo -e "  ${GREEN}PASS: $PASS${NC}   ${YELLOW}WARN: $WARN${NC}   ${RED}FAIL: $FAIL${NC}"
[ "$FAIL" -gt 0 ] && echo -e "${RED}ACTION REQUIRED: $FAIL critical issue(s). Run harden.sh or escalate.${NC}"
[ "$WARN" -gt 0 ] && [ "$FAIL" -eq 0 ] && echo -e "${YELLOW}REVIEW: $WARN warning(s).${NC}"
[ "$FAIL" -eq 0 ] && [ "$WARN" -eq 0 ] && echo -e "${GREEN}System appears compliant.${NC}"

print_federal_references
echo ""
