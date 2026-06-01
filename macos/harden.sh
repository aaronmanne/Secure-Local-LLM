#!/usr/bin/env bash
# =============================================================================
# macOS LLM Hardening Script
# Applies security controls to restrict local LLM tool exposure
# Run as the target user; some steps require sudo.
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

print_header() { echo -e "\n${BOLD}${CYAN}=== $1 ===${NC}"; }
print_ok()     { echo -e "${GREEN}[OK]${NC} $1"; }
print_warn()   { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_action() { echo -e "${CYAN}[ACTION]${NC} $1"; }
print_skip()   { echo -e "  [SKIP] $1"; }

echo -e "${BOLD}${CYAN}"
echo "╔══════════════════════════════════════════════════════════╗"
echo "║            macOS LLM Hardening Script                   ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo "This script applies hardening controls for local LLM tools."
echo "Some steps require sudo privileges."
echo ""
read -rp "Continue? [y/N] " CONFIRM
[[ "$CONFIRM" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

# ─── 1. STOP OLLAMA SERVICE ───────────────────────────────────────────────────
print_header "1. Stop Exposed LLM Services"

if pgrep -x "ollama" &>/dev/null; then
    print_action "Stopping Ollama process..."
    pkill -x ollama 2>/dev/null || true
    sleep 1
    pgrep -x "ollama" &>/dev/null && print_warn "Ollama still running!" || print_ok "Ollama stopped."
else
    print_skip "Ollama not running."
fi

# Disable Ollama launch agent if present
LAUNCH_AGENT="$HOME/Library/LaunchAgents/com.ollama.ollama.plist"
if [ -f "$LAUNCH_AGENT" ]; then
    print_action "Disabling Ollama launch agent..."
    launchctl unload "$LAUNCH_AGENT" 2>/dev/null || true
    print_ok "Ollama launch agent disabled. (File preserved for reference)"
fi

# ─── 2. FIREWALL RULES ────────────────────────────────────────────────────────
print_header "2. macOS Application Firewall"

FIREWALL_STATE=$(defaults read /Library/Preferences/com.apple.alf globalstate 2>/dev/null || echo "0")
if [ "$FIREWALL_STATE" -lt 1 ]; then
    print_action "Enabling macOS Application Firewall..."
    sudo defaults write /Library/Preferences/com.apple.alf globalstate -int 1
    sudo launchctl load /System/Library/LaunchDaemons/com.apple.alf.plist 2>/dev/null || true
    print_ok "Firewall enabled."
else
    print_ok "macOS Application Firewall is already enabled (state=$FIREWALL_STATE)."
fi

# Block LLM ports using pf (packet filter)
print_header "2b. PF Rules – Block External LLM Port Access"
PF_ANCHOR="/etc/pf.anchors/llm-harden"
PF_CONF_LINE='anchor "llm-harden"'

cat <<'EOF' > /tmp/llm-harden.pf
# LLM Hardening - block external access to local LLM ports
# Allow only loopback; block from any other interface
block in quick on { en0 en1 en2 en3 utun0 } proto tcp to any port { 11434 1234 8080 3000 8000 5000 }
EOF

print_action "Installing PF anchor rules for LLM ports..."
sudo cp /tmp/llm-harden.pf "$PF_ANCHOR"
sudo chmod 644 "$PF_ANCHOR"

if ! sudo grep -q 'llm-harden' /etc/pf.conf 2>/dev/null; then
    echo 'anchor "llm-harden"' | sudo tee -a /etc/pf.conf > /dev/null
    echo 'load anchor "llm-harden" from "/etc/pf.anchors/llm-harden"' | sudo tee -a /etc/pf.conf > /dev/null
fi

sudo pfctl -f /etc/pf.conf 2>/dev/null || true
sudo pfctl -e 2>/dev/null || true
print_ok "PF rules applied. LLM ports blocked on external interfaces."

# ─── 3. RESTRICT OLLAMA TO LOCALHOST ──────────────────────────────────────────
print_header "3. Restrict Ollama to Localhost"

OLLAMA_ENV_FILE="$HOME/.ollama/config"
mkdir -p "$HOME/.ollama"

if [ -f "$OLLAMA_ENV_FILE" ]; then
    if grep -q "OLLAMA_HOST" "$OLLAMA_ENV_FILE"; then
        sed -i '' 's/OLLAMA_HOST=.*/OLLAMA_HOST=127.0.0.1/' "$OLLAMA_ENV_FILE"
        print_ok "Updated OLLAMA_HOST to 127.0.0.1 in $OLLAMA_ENV_FILE"
    else
        echo 'OLLAMA_HOST=127.0.0.1' >> "$OLLAMA_ENV_FILE"
        print_ok "Added OLLAMA_HOST=127.0.0.1 to $OLLAMA_ENV_FILE"
    fi
else
    echo 'OLLAMA_HOST=127.0.0.1' > "$OLLAMA_ENV_FILE"
    print_ok "Created $OLLAMA_ENV_FILE with OLLAMA_HOST=127.0.0.1"
fi

# Also set in current shell profile if zsh
for PROFILE in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile"; do
    if [ -f "$PROFILE" ]; then
        if ! grep -q "OLLAMA_HOST" "$PROFILE"; then
            echo '# LLM Hardening: restrict Ollama to localhost' >> "$PROFILE"
            echo 'export OLLAMA_HOST=127.0.0.1' >> "$PROFILE"
            print_ok "Added OLLAMA_HOST export to $PROFILE"
        fi
    fi
done

# ─── 4. FILE PERMISSIONS ──────────────────────────────────────────────────────
print_header "4. Restrict Model Directory Permissions"

MODEL_DIRS=(
    "$HOME/.ollama"
    "$HOME/.lmstudio"
    "$HOME/jan"
)

for dir in "${MODEL_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        print_action "Restricting permissions on $dir"
        chmod -R go-rwx "$dir"
        print_ok "Permissions set to owner-only: $dir"
    fi
done

# ─── 5. REMOVE PROHIBITED MODELS ──────────────────────────────────────────────
print_header "5. Prohibited Model Removal"

PROHIBITED_PATTERN="deepseek|qwen|qwq|yi-[0-9]|baichuan|chatglm|internlm|minimax|ernie|hunyuan|tigerbot|aquila|moss|belle|rugpt|saiga|fred-t5|falcon"

QUARANTINE_DIR="$HOME/llm-quarantine-$(date +%Y%m%d_%H%M%S)"
FOUND_PROHIBITED=0

while IFS= read -r f; do
    if echo "$f" | grep -iEq "$PROHIBITED_PATTERN"; then
        if [ "$FOUND_PROHIBITED" -eq 0 ]; then
            mkdir -p "$QUARANTINE_DIR"
            echo ""
            print_warn "Prohibited models found. They will be moved to: $QUARANTINE_DIR"
            echo ""
        fi
        read -rp "  Move to quarantine: $f ? [y/N] " MOVE_CONFIRM
        if [[ "$MOVE_CONFIRM" =~ ^[Yy]$ ]]; then
            mv "$f" "$QUARANTINE_DIR/"
            print_ok "Quarantined: $(basename "$f")"
        fi
        FOUND_PROHIBITED=$((FOUND_PROHIBITED+1))
    fi
done < <(find "$HOME" -type f \( -name "*.gguf" -o -name "*.bin" -o -name "*.safetensors" \) 2>/dev/null)

# Check Ollama registered models
if command -v ollama &>/dev/null; then
    while IFS= read -r line; do
        MODEL_NAME=$(echo "$line" | awk '{print $1}')
        if echo "$MODEL_NAME" | grep -iEq "$PROHIBITED_PATTERN"; then
            read -rp "  Remove Ollama model: $MODEL_NAME ? [y/N] " RM_CONFIRM
            if [[ "$RM_CONFIRM" =~ ^[Yy]$ ]]; then
                ollama rm "$MODEL_NAME" && print_ok "Removed Ollama model: $MODEL_NAME"
            fi
        fi
    done < <(ollama list 2>/dev/null | tail -n +2 || true)
fi

[ "$FOUND_PROHIBITED" -eq 0 ] && print_ok "No prohibited models found."

# ─── 6. DISABLE AUTO-START ────────────────────────────────────────────────────
print_header "6. Disable LLM Auto-Start"

for plist in \
    "$HOME/Library/LaunchAgents/com.ollama.ollama.plist" \
    "/Library/LaunchDaemons/com.ollama.ollama.plist"; do
    if [ -f "$plist" ]; then
        print_action "Disabling launch item: $plist"
        launchctl unload "$plist" 2>/dev/null || true
        chmod 000 "$plist"
        print_ok "Disabled: $plist"
    fi
done

# ─── 7. AUDIT LOG ─────────────────────────────────────────────────────────────
print_header "7. Hardening Audit Log"

LOG_FILE="$HOME/llm-hardening-$(date +%Y%m%d_%H%M%S).log"
{
    echo "LLM Hardening Report"
    echo "Date: $(date)"
    echo "Host: $(hostname)"
    echo "User: $(whoami)"
    echo ""
    echo "--- Ollama Models ---"
    ollama list 2>/dev/null || echo "Ollama not available"
    echo ""
    echo "--- Network Ports ---"
    lsof -i TCP:11434 -i TCP:1234 -i TCP:8080 -sTCP:LISTEN 2>/dev/null || echo "None found"
    echo ""
    echo "--- OLLAMA_HOST ---"
    echo "${OLLAMA_HOST:-not set}"
} > "$LOG_FILE"

print_ok "Hardening log saved: $LOG_FILE"

echo ""
echo -e "${BOLD}${GREEN}=== Hardening Complete ===${NC}"
echo "Review the log at: $LOG_FILE"
echo "Run audit.sh to verify posture."
echo ""
