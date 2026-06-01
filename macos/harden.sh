#!/usr/bin/env bash
# =============================================================================
# macOS LLM Hardening Script
# Applies security controls to restrict local LLM/agent tool exposure.
# Regulatory basis: NIST SP 800-53 SC-7, IA-2, AU-2; NIST AI 600-1;
#                   DFARS 252.204-7012; CMMC 2.0 AC.L2-3.1.3, CM.L2-3.4.6
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/common/patterns.sh"
source "$SCRIPT_DIR/common/references.sh"

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

print_header() { echo -e "\n${BOLD}${CYAN}=== $1 ===${NC}"; }
print_ok()     { echo -e "${GREEN}[OK]${NC} $1"; }
print_warn()   { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_action() { echo -e "${CYAN}[ACTION]${NC} $1"; }
print_skip()   { echo -e "  [SKIP] $1"; }

echo -e "${BOLD}${CYAN}"
echo "╔══════════════════════════════════════════════════════════╗"
echo "║            macOS LLM Hardening Script                    ║"
echo "║  Ref: NIST SP 800-53 SC-7 · IA-2 · AU-2                  ║"
echo "║       NIST AI 600-1 · DFARS 252.204-7012 · CMMC 2.0      ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo "Date: $(date) | Host: $(hostname) | User: $(whoami)"
echo ""
read -rp "Continue with hardening? [y/N] " CONFIRM
[[ "$CONFIRM" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

# ─── 1. STOP INFERENCE SERVERS & AGENTS ───────────────────────────────────────
print_header "1. Stop Running LLM / Agent Processes  [NIST SP 800-53 CM-7: Least Functionality]"

for PROC_PATTERN in ollama lmstudio "text-generation-webui" koboldcpp tabby localai; do
    if pgrep -fi "$PROC_PATTERN" &>/dev/null; then
        read -rp "  Stop process '$PROC_PATTERN'? [y/N] " PC
        if [[ "$PC" =~ ^[Yy]$ ]]; then
            pkill -fi "$PROC_PATTERN" 2>/dev/null || true
            sleep 1
            pgrep -fi "$PROC_PATTERN" &>/dev/null && print_warn "'$PROC_PATTERN' still running." || print_ok "Stopped: $PROC_PATTERN"
        fi
    fi
done

# Disable Ollama launch agent
LAUNCH_AGENT="$HOME/Library/LaunchAgents/com.ollama.ollama.plist"
if [ -f "$LAUNCH_AGENT" ]; then
    print_action "Disabling Ollama launch agent (NIST SP 800-53 CM-7)..."
    launchctl unload "$LAUNCH_AGENT" 2>/dev/null || true
    print_ok "Ollama launch agent disabled."
fi

# ─── 2. FIREWALL — BLOCK EXTERNAL LLM PORTS ───────────────────────────────────
print_header "2. Firewall: Block External LLM Ports  [NIST SP 800-53 SC-7: Boundary Protection]"

# Enable macOS Application Firewall
FW_STATE=$(defaults read /Library/Preferences/com.apple.alf globalstate 2>/dev/null || echo "0")
if [ "$FW_STATE" -lt 1 ]; then
    print_action "Enabling macOS Application Firewall..."
    sudo defaults write /Library/Preferences/com.apple.alf globalstate -int 1
    print_ok "Firewall enabled."
else
    print_ok "Application Firewall already enabled."
fi

# pf anchor — block all LLM ports on external interfaces
PF_ANCHOR="/etc/pf.anchors/llm-harden"
{
    echo "# LLM/Agent Hardening — NIST SP 800-53 SC-7 Boundary Protection"
    echo "# Generated: $(date)"
    for entry in "${LLM_PORTS[@]}"; do
        PORT="${entry%%:*}"; TOOL="${entry#*:}"
        echo "# $TOOL"
        echo "block in quick on { en0 en1 en2 en3 utun0 } proto tcp to any port $PORT"
    done
} > /tmp/llm-harden.pf

print_action "Installing PF anchor rules for all LLM/agent ports..."
sudo cp /tmp/llm-harden.pf "$PF_ANCHOR"
sudo chmod 644 "$PF_ANCHOR"
if ! sudo grep -q 'llm-harden' /etc/pf.conf 2>/dev/null; then
    printf '\nanchor "llm-harden"\nload anchor "llm-harden" from "/etc/pf.anchors/llm-harden"\n' | sudo tee -a /etc/pf.conf > /dev/null
fi
sudo pfctl -f /etc/pf.conf 2>/dev/null || true
sudo pfctl -e 2>/dev/null || true
print_ok "PF rules applied — all LLM/agent ports blocked on external interfaces."
cite "NIST SP 800-53 SC-7 (Boundary Protection)"

# ─── 3. RESTRICT OLLAMA TO LOCALHOST ──────────────────────────────────────────
print_header "3. Restrict Ollama to Localhost  [NIST SP 800-53 SC-7, IA-3]"

mkdir -p "$HOME/.ollama"
OLLAMA_CFG="$HOME/.ollama/config"
if grep -q "OLLAMA_HOST" "$OLLAMA_CFG" 2>/dev/null; then
    sed -i '' 's/OLLAMA_HOST=.*/OLLAMA_HOST=127.0.0.1/' "$OLLAMA_CFG"
else
    echo 'OLLAMA_HOST=127.0.0.1' >> "$OLLAMA_CFG"
fi
print_ok "OLLAMA_HOST=127.0.0.1 set in $OLLAMA_CFG"

for PROFILE in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile"; do
    if [ -f "$PROFILE" ] && ! grep -q "OLLAMA_HOST" "$PROFILE"; then
        printf '\n# LLM Hardening — NIST SP 800-53 SC-7\nexport OLLAMA_HOST=127.0.0.1\n' >> "$PROFILE"
        print_ok "OLLAMA_HOST added to $PROFILE"
    fi
done

# ─── 4. FILE PERMISSIONS ──────────────────────────────────────────────────────
print_header "4. Restrict Model Directory Permissions  [NIST SP 800-53 AC-3, AC-6: Least Privilege]"

for dir in "${MODEL_DIRS_MACOS[@]}"; do
    if [ -d "$dir" ]; then
        chmod -R go-rwx "$dir" 2>/dev/null || true
        print_ok "Permissions restricted (owner-only): $dir"
    fi
done
cite "NIST SP 800-53 AC-6 (Least Privilege)"

# ─── 5. REMOVE PROHIBITED MODELS ──────────────────────────────────────────────
print_header "5. Prohibited Model Removal  [FBI Advisory Feb 2025; HOUSE-DEEPSEEK; NIST AI 600-1 §2.5]"

QUARANTINE_DIR="$HOME/llm-quarantine-$(date +%Y%m%d_%H%M%S)"
FOUND_PROHIBITED=0

while IFS= read -r f; do
    if echo "$f" | grep -iEq "$PROHIBITED_PATTERN"; then
        [ "$FOUND_PROHIBITED" -eq 0 ] && mkdir -p "$QUARANTINE_DIR" && \
            print_warn "Prohibited models found. Quarantine: $QUARANTINE_DIR"
        read -rp "  Quarantine: $f ? [y/N] " MC
        if [[ "$MC" =~ ^[Yy]$ ]]; then
            mv "$f" "$QUARANTINE_DIR/" && print_ok "Quarantined: $(basename "$f")"
        fi
        FOUND_PROHIBITED=$((FOUND_PROHIBITED+1))
    fi
done < <(find "$HOME" -type f \( -name "*.gguf" -o -name "*.bin" -o -name "*.safetensors" -o -name "*.ggml" \) 2>/dev/null)

if command -v ollama &>/dev/null; then
    while IFS= read -r line; do
        MODEL=$(echo "$line" | awk '{print $1}')
        if echo "$MODEL" | grep -iEq "$PROHIBITED_PATTERN"; then
            read -rp "  Remove Ollama model '$MODEL'? [y/N] " RC
            [[ "$RC" =~ ^[Yy]$ ]] && ollama rm "$MODEL" && print_ok "Removed: $MODEL"
        fi
    done < <(ollama list 2>/dev/null | tail -n +2 || true)
fi
[ "$FOUND_PROHIBITED" -eq 0 ] && print_ok "No prohibited models found."
cite "FBI-DEEPSEEK / HOUSE-DEEPSEEK / NIST AI 600-1 §2.5 (Supply Chain)"

# ─── 6. DISABLE AUTO-START ────────────────────────────────────────────────────
print_header "6. Disable LLM Auto-Start  [NIST SP 800-53 CM-7: Least Functionality]"

for plist in \
    "$HOME/Library/LaunchAgents/com.ollama.ollama.plist" \
    "/Library/LaunchDaemons/com.ollama.ollama.plist"; do
    if [ -f "$plist" ]; then
        launchctl unload "$plist" 2>/dev/null || true
        chmod 000 "$plist"
        print_ok "Disabled launch item: $plist"
    fi
done

# ─── 7. AUDIT LOGGING ─────────────────────────────────────────────────────────
print_header "7. Hardening Audit Log  [NIST SP 800-53 AU-2, AU-12: Audit Events]"

LOG_FILE="$HOME/llm-hardening-$(date +%Y%m%d_%H%M%S).log"
{
    echo "LLM Hardening Report — macOS"
    echo "Date: $(date)"
    echo "Host: $(hostname)"
    echo "User: $(whoami)"
    echo "Regulatory basis: NIST SP 800-53, NIST AI 600-1, DFARS 252.204-7012, CMMC 2.0"
    echo ""
    echo "--- Ollama Models ---"
    ollama list 2>/dev/null || echo "Ollama not available"
    echo ""
    echo "--- Listening Ports ---"
    lsof -i TCP -sTCP:LISTEN -n -P 2>/dev/null | grep -E "${LLM_PORT_NUMS}" || echo "None found"
    echo ""
    echo "--- OLLAMA_HOST ---"
    echo "${OLLAMA_HOST:-not set}"
} > "$LOG_FILE"
print_ok "Log saved: $LOG_FILE"

# ─── REFERENCES ───────────────────────────────────────────────────────────────
print_federal_references

echo -e "${BOLD}${GREEN}=== Hardening Complete ===${NC}"
echo "Run audit.sh to verify posture."
echo ""
