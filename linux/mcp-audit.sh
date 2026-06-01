#!/usr/bin/env bash
# =============================================================================
# Linux MCP (Model Context Protocol) Security Audit
# Regulatory basis: NIST AI 100-2; NSA-AI-SECURITY; NIST SP 800-53 SI-3, CA-7
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/common/patterns.sh"
source "$SCRIPT_DIR/common/references.sh"

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
echo "║  Ref: NIST AI 100-2 · NSA-AI-SECURITY · NIST 800-53    ║"
echo "║       SI-3 · CA-7 · SA-12 · IA-5                       ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo "Date: $(date) | Host: $(hostname)"

# ─── 1. DISCOVER MCP CONFIGS ──────────────────────────────────────────────────
print_header "1. MCP Config Discovery  [NIST SP 800-53 CM-8]"
ALL_MCP_FILES=()
for f in "${MCP_CONFIG_PATHS_LINUX[@]}"; do
    if [ -f "$f" ] && grep -q "mcpServers" "$f" 2>/dev/null; then
        check_warn "MCP config: $f"; ALL_MCP_FILES+=("$f")
    fi
done
while IFS= read -r f; do
    check_warn "mcp.json: $f"; ALL_MCP_FILES+=("$f")
done < <(find "$HOME" -name "mcp.json" 2>/dev/null)
while IFS= read -r f; do
    ALREADY=0; for e in "${ALL_MCP_FILES[@]:-}"; do [ "$f" = "$e" ] && ALREADY=1; done
    [ "$ALREADY" -eq 0 ] && { check_warn "JSON with mcpServers: $f"; ALL_MCP_FILES+=("$f"); }
done < <(grep -rl "mcpServers" "$HOME" --include="*.json" 2>/dev/null | grep -v ".git" || true)
[ "${#ALL_MCP_FILES[@]}" -eq 0 ] && check_pass "No MCP config files found."

# ─── 2. ANALYZE CONFIGS ───────────────────────────────────────────────────────
print_header "2. MCP Config Analysis  [NIST AI 100-2; NSA-AI-SECURITY §4]"
for f in "${ALL_MCP_FILES[@]:-}"; do
    echo -e "\n  ${BOLD}$f${NC}"
    grep -q '"url"' "$f" 2>/dev/null && check_fail "REMOTE MCP SERVER in $f  [FBI-FOREIGN-AI; NIST AI 600-1 §2.5]"
    grep -qiE '"(api_key|apikey|token|password|secret|Authorization)"\s*:' "$f" 2>/dev/null && \
        check_fail "CREDENTIALS in $f  [NIST SP 800-53 IA-5]"
    grep -qE '"/tmp/|/Downloads/' "$f" 2>/dev/null && \
        check_fail "Temp/download path in $f  [NIST SP 800-53 SI-3]"
    if command -v python3 &>/dev/null; then
        python3 -c "
import json
try:
    d = json.load(open('$f'))
    for name, cfg in (d.get('mcpServers') or {}).items():
        if isinstance(cfg, dict) and cfg.get('command') == 'npx' and '-y' in (cfg.get('args') or []):
            print(name)
except: pass
" 2>/dev/null | while read -r sname; do
            check_warn "npx -y (supply chain): '$sname'  [NIST SP 800-218 §2.1]"
        done
    fi
    grep -qE '"(/|~)"\s*[,\]]' "$f" 2>/dev/null && \
        check_warn "Broad filesystem scope  [NIST SP 800-53 AC-6]"
    for sp in "${SENSITIVE_PATHS[@]}"; do
        grep -q "$sp" "$f" 2>/dev/null && \
            check_fail "Sensitive path '$sp' in $f  [DFARS 252.204-7012; NIST SP 800-171 §3.5]"
    done
done

# ─── 3. RUNNING MCP PROCESSES ─────────────────────────────────────────────────
print_header "3. Running MCP Processes  [NIST SP 800-53 CM-7]"
MCP=$(ps aux | grep -iE "mcp|modelcontext" | grep -v grep || true)
[ -n "$MCP" ] && { check_warn "MCP processes:"; echo "$MCP"; } || check_pass "No MCP processes."
NODE=$(ps aux | grep -E " node " | grep -v grep || true)
[ -n "$NODE" ] && check_warn "Node.js running (common MCP runtime) — verify expected."

# ─── 4. OUTBOUND CONNECTIONS ──────────────────────────────────────────────────
print_header "4. Outbound Connections  [NIST SP 800-53 SC-7, SI-4]"
for PID in $(pgrep -x node 2>/dev/null || true) $(pgrep -x python3 2>/dev/null || true); do
    CONNS=$(ss -tnp 2>/dev/null | grep "pid=$PID" | grep -v "127\.0\.0\.1\|::1" || true)
    [ -n "$CONNS" ] && check_warn "Non-localhost connections for PID $PID: $CONNS"
done
check_pass "Outbound check complete (also review: ss -tnp)"

# ─── 5. CREDENTIAL PATHS ──────────────────────────────────────────────────────
print_header "5. Credential Path Exposure  [NIST SP 800-53 IA-5; DFARS 252.204-7012]"
for f in "${ALL_MCP_FILES[@]:-}"; do
    for sp in "${SENSITIVE_PATHS[@]}"; do
        grep -q "$sp" "$f" 2>/dev/null && check_fail "Sensitive path '$sp' in: $f"
    done
done
[ "${#ALL_MCP_FILES[@]}" -eq 0 ] && check_pass "No MCP files to check."

# ─── 6. AGENT TOOL CONFIGS ────────────────────────────────────────────────────
print_header "6. AI Agent Tool Configs  [NIST AI 600-1 §2.6]"
for f in "$HOME/.aider.conf.yml" "$HOME/.aider.model.metadata.json" \
         "$HOME/.goose/config.yaml" "$HOME/.plandex/config.json" \
         "$HOME/.continue/config.json" "$HOME/.cody/config.json"; do
    if [ -f "$f" ]; then
        check_warn "Agent config: $f"
        grep -qiE "url|endpoint|host|api_key|token" "$f" 2>/dev/null && \
            check_warn "  >> External endpoint or credential reference — review!"
    fi
done

# ─── SUMMARY ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║              MCP AUDIT SUMMARY                          ║${NC}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo -e "  ${GREEN}PASS: $PASS${NC}   ${YELLOW}WARN: $WARN${NC}   ${RED}FAIL: $FAIL${NC}"
[ "$FAIL" -gt 0 ] && echo -e "${RED}CRITICAL: $FAIL issue(s) — escalate to InfoSec immediately.${NC}"
[ "$WARN" -gt 0 ] && [ "$FAIL" -eq 0 ] && echo -e "${YELLOW}REVIEW: $WARN item(s) need review.${NC}"
[ "$FAIL" -eq 0 ] && [ "$WARN" -eq 0 ] && echo -e "${GREEN}No MCP issues detected.${NC}"
print_federal_references
echo ""
