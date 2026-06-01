#!/usr/bin/env bash
# =============================================================================
# Linux MCP (Model Context Protocol) Security Audit
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
PASS=0; WARN=0; FAIL=0

check_pass() { echo -e "${GREEN}[PASS]${NC} $1"; PASS=$((PASS+1)); }
check_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; WARN=$((WARN+1)); }
check_fail() { echo -e "${RED}[FAIL]${NC} $1"; FAIL=$((FAIL+1)); }
print_header() { echo -e "\n${BOLD}${CYAN}=== $1 ===${NC}"; }

echo -e "${BOLD}${CYAN}"
echo "╔══════════════════════════════════════════════════════════╗"
echo "║          Linux MCP Security Audit                       ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo "Date: $(date)"; echo "Host: $(hostname)"

print_header "1. MCP Config Discovery"
ALL_MCP_FILES=()
for f in \
    "$HOME/.config/Claude/claude_desktop_config.json" \
    "$HOME/.cursor/mcp.json" \
    "$HOME/.continue/config.json" \
    "$HOME/.config/Code/User/settings.json" \
    "$HOME/.config/Cursor/User/settings.json"; do
    if [ -f "$f" ] && grep -q "mcpServers" "$f" 2>/dev/null; then
        check_warn "MCP config: $f"
        ALL_MCP_FILES+=("$f")
    fi
done
while IFS= read -r f; do
    check_warn "mcp.json: $f"; ALL_MCP_FILES+=("$f")
done < <(find "$HOME" -name "mcp.json" 2>/dev/null)
while IFS= read -r f; do
    ALREADY=0
    for e in "${ALL_MCP_FILES[@]:-}"; do [ "$f" = "$e" ] && ALREADY=1; done
    if [ "$ALREADY" -eq 0 ]; then check_warn "JSON with mcpServers: $f"; ALL_MCP_FILES+=("$f"); fi
done < <(grep -rl "mcpServers" "$HOME" --include="*.json" 2>/dev/null | grep -v ".git" || true)
[ "${#ALL_MCP_FILES[@]}" -eq 0 ] && check_pass "No MCP config files found."

print_header "2. MCP Config Analysis"
for f in "${ALL_MCP_FILES[@]:-}"; do
    echo -e "\n  ${BOLD}$f${NC}"
    grep -q '"url"' "$f" 2>/dev/null && check_fail "REMOTE MCP server in: $f"
    grep -qiE '"(api_key|token|password|secret|Authorization)"\s*:' "$f" 2>/dev/null && \
        check_fail "CREDENTIALS embedded in: $f"
    grep -qE '"/tmp/|/Downloads/' "$f" 2>/dev/null && \
        check_fail "Script from temp path in: $f"
    if command -v python3 &>/dev/null; then
        python3 -c "
import json
try:
    d = json.load(open('$f'))
    for name, cfg in (d.get('mcpServers', {}) or {}).items():
        if isinstance(cfg, dict) and cfg.get('command') == 'npx' and '-y' in (cfg.get('args') or []):
            print(name)
except: pass
" 2>/dev/null | while read -r sname; do
            check_warn "npx -y risk (supply chain): server '$sname' in $f"
        done
    fi
done

print_header "3. Running MCP Processes"
MCP=$(ps aux | grep -iE "mcp|modelcontext" | grep -v grep || true)
[ -n "$MCP" ] && { check_warn "MCP processes running:"; echo "$MCP"; } || check_pass "No MCP processes."

NODE=$(ps aux | grep node | grep -v grep || true)
[ -n "$NODE" ] && check_warn "Node.js processes running (common MCP runtime)."

print_header "4. Outbound Connections from MCP Runtimes"
if command -v ss &>/dev/null; then
    for pid in $(pgrep -x node 2>/dev/null || true) $(pgrep -x python3 2>/dev/null || true); do
        CONNS=$(ss -tlnp 2>/dev/null | grep "pid=$pid" || true)
        [ -n "$CONNS" ] && check_warn "Connections for PID $pid: $CONNS"
    done
fi
check_pass "Outbound connection check complete (review manually with: ss -tlnp)."

print_header "5. Sensitive Path Exposure"
SENSITIVE=(".ssh" ".aws" ".env" ".gnupg" "credentials" "id_rsa" "id_ed25519")
for f in "${ALL_MCP_FILES[@]:-}"; do
    for p in "${SENSITIVE[@]}"; do
        grep -q "$p" "$f" 2>/dev/null && check_fail "Sensitive path '$p' in MCP config: $f"
    done
done

echo ""
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║              MCP AUDIT SUMMARY                          ║${NC}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo -e "  ${GREEN}PASS: $PASS${NC}   ${YELLOW}WARN: $WARN${NC}   ${RED}FAIL: $FAIL${NC}"
[ "$FAIL" -gt 0 ] && echo -e "${RED}CRITICAL: $FAIL issue(s). Escalate to InfoSec.${NC}"
[ "$WARN" -gt 0 ] && [ "$FAIL" -eq 0 ] && echo -e "${YELLOW}REVIEW: $WARN warning(s).${NC}"
[ "$FAIL" -eq 0 ] && [ "$WARN" -eq 0 ] && echo -e "${GREEN}No MCP issues detected.${NC}"
echo ""
