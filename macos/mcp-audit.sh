#!/usr/bin/env bash
# =============================================================================
# macOS MCP (Model Context Protocol) Security Audit
# Deep scan for MCP server configurations, running processes, and risky patterns
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

PASS=0; WARN=0; FAIL=0

check_pass() { echo -e "${GREEN}[PASS]${NC} $1"; PASS=$((PASS+1)); }
check_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; WARN=$((WARN+1)); }
check_fail() { echo -e "${RED}[FAIL]${NC} $1"; FAIL=$((FAIL+1)); }
print_header() { echo -e "\n${BOLD}${CYAN}=== $1 ===${NC}"; }

echo -e "${BOLD}${CYAN}"
echo "╔══════════════════════════════════════════════════════════╗"
echo "║          macOS MCP Security Audit                       ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo "Date: $(date)"
echo "Host: $(hostname)"
echo ""

# ─── 1. FIND ALL MCP CONFIG FILES ─────────────────────────────────────────────
print_header "1. MCP Config File Discovery"

declare -a KNOWN_MCP_PATHS=(
    "$HOME/Library/Application Support/Claude/claude_desktop_config.json"
    "$HOME/.cursor/mcp.json"
    "$HOME/.continue/config.json"
    "$HOME/Library/Application Support/Code/User/settings.json"
    "$HOME/Library/Application Support/Cursor/User/settings.json"
)

ALL_MCP_FILES=()

for f in "${KNOWN_MCP_PATHS[@]}"; do
    if [ -f "$f" ] && grep -q "mcpServers" "$f" 2>/dev/null; then
        check_warn "MCP config: $f"
        ALL_MCP_FILES+=("$f")
    fi
done

# Search for any mcp.json in home dir
while IFS= read -r f; do
    check_warn "Found mcp.json: $f"
    ALL_MCP_FILES+=("$f")
done < <(find "$HOME" -name "mcp.json" 2>/dev/null)

# Search for any JSON with mcpServers key
while IFS= read -r f; do
    # Avoid duplicates
    ALREADY=0
    for existing in "${ALL_MCP_FILES[@]:-}"; do [ "$f" = "$existing" ] && ALREADY=1; done
    if [ "$ALREADY" -eq 0 ]; then
        check_warn "JSON with mcpServers key: $f"
        ALL_MCP_FILES+=("$f")
    fi
done < <(grep -rl "mcpServers" "$HOME" --include="*.json" 2>/dev/null | grep -v ".git" || true)

[ "${#ALL_MCP_FILES[@]}" -eq 0 ] && check_pass "No MCP config files found."

# ─── 2. ANALYZE EACH CONFIG FILE ──────────────────────────────────────────────
print_header "2. MCP Config Analysis"

for f in "${ALL_MCP_FILES[@]:-}"; do
    echo ""
    echo -e "  ${BOLD}File: $f${NC}"

    # Remote servers (url key)
    if grep -q '"url"' "$f" 2>/dev/null; then
        URLS=$(grep -oE '"url"\s*:\s*"[^"]+"' "$f" 2>/dev/null || true)
        check_fail "REMOTE MCP SERVER(S) in $f:"
        echo "$URLS" | while read -r u; do echo "    $u"; done
    fi

    # npx -y (supply chain risk)
    if python3 -c "
import json, sys
try:
    d = json.load(open('$f'))
    servers = d.get('mcpServers', {}) or {}
    if isinstance(servers, list): servers = {}
    for name, cfg in servers.items():
        if isinstance(cfg, dict):
            cmd = cfg.get('command','')
            args = cfg.get('args', [])
            if cmd == 'npx' and '-y' in args:
                print(f'npx -y server: {name}')
except: pass
" 2>/dev/null | while read -r line; do
        check_warn "Supply-chain risk: $line in $f"
    done

    # Credentials embedded
    if grep -qiE '"(api_key|apikey|api-key|token|password|secret|Authorization)"\s*:' "$f" 2>/dev/null; then
        check_fail "CREDENTIALS possibly embedded in MCP config: $f"
    fi

    # Broad filesystem paths
    if grep -qE '"(/|~|C:\\\\|/home|/Users)"\s*[,\]]' "$f" 2>/dev/null; then
        check_warn "Broad filesystem path in MCP config: $f (check scope)"
    fi

    # Scripts from /tmp or Downloads
    if grep -qE '"/tmp/|/Downloads/|\\\\Temp\\\\' "$f" 2>/dev/null; then
        check_fail "MCP server running from temp/download path in: $f"
    fi
done

# ─── 3. RUNNING MCP PROCESSES ─────────────────────────────────────────────────
print_header "3. Running MCP-Related Processes"

MCP_PROCS=$(ps aux | grep -iE "mcp|modelcontext" | grep -v grep || true)
if [ -n "$MCP_PROCS" ]; then
    check_warn "MCP-related processes running:"
    echo "$MCP_PROCS" | while read -r line; do echo "  $line"; done
else
    check_pass "No MCP-specific processes detected."
fi

NODE_PROCS=$(ps aux | grep -iE "node" | grep -v grep || true)
if [ -n "$NODE_PROCS" ]; then
    check_warn "Node.js processes running (common MCP runtime):"
    echo "$NODE_PROCS" | while read -r line; do echo "  $line"; done
fi

# ─── 4. OUTBOUND CONNECTIONS FROM NODE/PYTHON ─────────────────────────────────
print_header "4. Outbound Network Connections from MCP Runtimes"

OUTBOUND=$(lsof -i -P -n 2>/dev/null | grep -iE "node|python|npx" | grep ESTABLISHED || true)
if [ -n "$OUTBOUND" ]; then
    check_warn "Active outbound connections from MCP runtimes:"
    echo "$OUTBOUND" | while read -r line; do echo "  $line"; done
else
    check_pass "No active outbound connections from node/python detected."
fi

# ─── 5. CREDENTIAL PATH EXPOSURE ──────────────────────────────────────────────
print_header "5. Sensitive Path Exposure in MCP Configs"
SENSITIVE_PATHS=(".ssh" ".aws" ".env" ".gnupg" "credentials" "id_rsa" "id_ed25519")

for f in "${ALL_MCP_FILES[@]:-}"; do
    for path in "${SENSITIVE_PATHS[@]}"; do
        if grep -q "$path" "$f" 2>/dev/null; then
            check_fail "Sensitive path '$path' referenced in MCP config: $f"
        fi
    done
done

# ─── SUMMARY ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║              MCP AUDIT SUMMARY                          ║${NC}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo -e "  ${GREEN}PASS: $PASS${NC}   ${YELLOW}WARN: $WARN${NC}   ${RED}FAIL: $FAIL${NC}"
echo ""
[ "$FAIL" -gt 0 ] && echo -e "${RED}CRITICAL: $FAIL issue(s) require immediate action. Escalate to InfoSec.${NC}"
[ "$WARN" -gt 0 ] && echo -e "${YELLOW}REVIEW: $WARN item(s) need manual review.${NC}"
[ "$FAIL" -eq 0 ] && [ "$WARN" -eq 0 ] && echo -e "${GREEN}No MCP issues detected.${NC}"
echo ""
