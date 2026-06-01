#!/usr/bin/env bash
# =============================================================================
# Linux LLM Hardening Script
# Applies security controls for local LLM tools on Linux systems
# Requires sudo for firewall/systemd operations
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
echo "║            Linux LLM Hardening Script                   ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo "This script applies hardening controls for local LLM tools."
echo "Many steps require sudo privileges."
echo ""
read -rp "Continue? [y/N] " CONFIRM
[[ "$CONFIRM" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

PROHIBITED_PATTERN="deepseek|qwen|qwq|yi-[0-9]|baichuan|chatglm|internlm|minimax|ernie|hunyuan|tigerbot|aquila|moss|belle|rugpt|saiga|fred-t5|falcon"

# ─── 1. STOP OLLAMA SERVICE ───────────────────────────────────────────────────
print_header "1. Stop LLM Services"

if systemctl is-active --quiet ollama 2>/dev/null; then
    print_action "Stopping Ollama systemd service..."
    sudo systemctl stop ollama
    print_ok "Ollama service stopped."
elif pgrep -x ollama &>/dev/null; then
    print_action "Killing Ollama process..."
    sudo pkill -x ollama || true
    print_ok "Ollama process killed."
else
    print_skip "Ollama not running."
fi

for svc in localai; do
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
        print_action "Stopping $svc..."
        sudo systemctl stop "$svc"
        print_ok "$svc stopped."
    fi
done

# ─── 2. RESTRICT OLLAMA TO LOCALHOST VIA SYSTEMD OVERRIDE ─────────────────────
print_header "2. Restrict Ollama to Localhost"

OVERRIDE_DIR="/etc/systemd/system/ollama.service.d"
OVERRIDE_FILE="$OVERRIDE_DIR/localhost.conf"

if systemctl list-unit-files ollama.service &>/dev/null 2>&1 | grep -q ollama; then
    print_action "Creating systemd override to bind Ollama to localhost..."
    sudo mkdir -p "$OVERRIDE_DIR"
    sudo tee "$OVERRIDE_FILE" > /dev/null <<'EOF'
[Service]
Environment="OLLAMA_HOST=127.0.0.1"
EOF
    sudo systemctl daemon-reload
    print_ok "Ollama override created: $OVERRIDE_FILE"
fi

# Also set in shell profiles
for PROFILE in "$HOME/.bashrc" "$HOME/.profile" "$HOME/.bash_profile" "$HOME/.zshrc"; do
    if [ -f "$PROFILE" ] && ! grep -q "OLLAMA_HOST" "$PROFILE"; then
        echo '# LLM Hardening: restrict Ollama to localhost' >> "$PROFILE"
        echo 'export OLLAMA_HOST=127.0.0.1' >> "$PROFILE"
        print_ok "Added OLLAMA_HOST=127.0.0.1 to $PROFILE"
    fi
done

# ─── 3. FIREWALL RULES ────────────────────────────────────────────────────────
print_header "3. Firewall Rules – Block External LLM Port Access"

if command -v ufw &>/dev/null; then
    print_action "Applying UFW rules for LLM ports..."
    for PORT in 11434 1234 8080; do
        sudo ufw deny in from any to any port "$PORT" comment "LLM port hardening" 2>/dev/null && \
            print_ok "UFW: blocked port $PORT from external access" || \
            print_warn "UFW rule for port $PORT may already exist or failed."
    done
    sudo ufw allow from 127.0.0.1 to any port 11434 comment "Allow Ollama localhost" 2>/dev/null || true
    sudo ufw --force enable
    print_ok "UFW enabled."

elif command -v firewall-cmd &>/dev/null; then
    print_action "Applying firewalld rules..."
    for PORT in 11434 1234 8080; do
        sudo firewall-cmd --permanent --add-rich-rule="rule family='ipv4' port port='$PORT' protocol='tcp' source address='127.0.0.1' accept" 2>/dev/null || true
        sudo firewall-cmd --permanent --add-rich-rule="rule family='ipv4' port port='$PORT' protocol='tcp' reject" 2>/dev/null || true
    done
    sudo firewall-cmd --reload
    print_ok "firewalld rules applied."

elif command -v iptables &>/dev/null; then
    print_action "Applying iptables rules..."
    for PORT in 11434 1234 8080; do
        sudo iptables -I INPUT -p tcp --dport "$PORT" ! -s 127.0.0.1 -j DROP
        print_ok "iptables: blocked port $PORT from non-localhost"
    done
    # Persist if iptables-save is available
    if command -v iptables-save &>/dev/null; then
        sudo iptables-save > /etc/iptables/rules.v4 2>/dev/null || \
        sudo iptables-save > /etc/iptables.rules 2>/dev/null || true
        print_ok "iptables rules saved."
    fi
else
    print_warn "No supported firewall tool found (ufw/firewalld/iptables). Apply rules manually."
fi

# ─── 4. FILE PERMISSIONS ──────────────────────────────────────────────────────
print_header "4. Restrict Model Directory Permissions"

for dir in \
    "$HOME/.ollama" \
    "/usr/share/ollama" \
    "$HOME/.lmstudio" \
    "$HOME/jan" \
    "$HOME/.local/share/nomic.ai/GPT4All"; do
    if [ -d "$dir" ]; then
        print_action "Restricting permissions: $dir"
        chmod -R o-rwx "$dir"
        print_ok "Others-access removed: $dir"
    fi
done

# ─── 5. REMOVE PROHIBITED MODELS ──────────────────────────────────────────────
print_header "5. Prohibited Model Removal"

QUARANTINE_DIR="/var/quarantine/llm-removed-$(date +%Y%m%d_%H%M%S)"
FOUND_PROHIBITED=0

while IFS= read -r f; do
    if echo "$f" | grep -iEq "$PROHIBITED_PATTERN"; then
        if [ "$FOUND_PROHIBITED" -eq 0 ]; then
            sudo mkdir -p "$QUARANTINE_DIR"
            print_warn "Prohibited models found. Will quarantine to: $QUARANTINE_DIR"
        fi
        read -rp "  Quarantine: $f ? [y/N] " CONFIRM
        if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
            sudo mv "$f" "$QUARANTINE_DIR/"
            sudo chmod 000 "$QUARANTINE_DIR/$(basename $f)"
            print_ok "Quarantined: $(basename $f)"
        fi
        FOUND_PROHIBITED=$((FOUND_PROHIBITED+1))
    fi
done < <(find "$HOME" /usr/share/ollama 2>/dev/null -type f \( -name "*.gguf" -o -name "*.bin" -o -name "*.safetensors" \) 2>/dev/null)

if command -v ollama &>/dev/null; then
    while IFS= read -r line; do
        MODEL=$(echo "$line" | awk '{print $1}')
        if echo "$MODEL" | grep -iEq "$PROHIBITED_PATTERN"; then
            read -rp "  Remove Ollama model: $MODEL ? [y/N] " RM_CONFIRM
            if [[ "$RM_CONFIRM" =~ ^[Yy]$ ]]; then
                ollama rm "$MODEL" && print_ok "Removed: $MODEL"
            fi
        fi
    done < <(ollama list 2>/dev/null | tail -n +2 || true)
fi

[ "$FOUND_PROHIBITED" -eq 0 ] && print_ok "No prohibited models found."

# ─── 6. DISABLE AUTO-START ────────────────────────────────────────────────────
print_header "6. Disable LLM Service Auto-Start"

for svc in ollama localai; do
    if systemctl is-enabled "$svc" &>/dev/null 2>&1; then
        read -rp "  Disable $svc from auto-starting? [y/N] " D_CONFIRM
        if [[ "$D_CONFIRM" =~ ^[Yy]$ ]]; then
            sudo systemctl disable "$svc"
            print_ok "Disabled auto-start: $svc"
        fi
    fi
done

# ─── 7. AUDIT LOG ─────────────────────────────────────────────────────────────
print_header "7. Hardening Log"

LOG_FILE="$HOME/llm-hardening-$(date +%Y%m%d_%H%M%S).log"
{
    echo "LLM Hardening Report – Linux"
    echo "Date: $(date)"
    echo "Host: $(hostname)"
    echo "User: $(whoami)"
    echo "Distro: $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d= -f2 | tr -d '"')"
    echo ""
    echo "--- Ollama Models ---"
    ollama list 2>/dev/null || echo "Ollama not available"
    echo ""
    echo "--- Network Ports ---"
    ss -tlnp 2>/dev/null | grep -E "11434|1234|8080" || echo "None found"
    echo ""
    echo "--- OLLAMA_HOST ---"
    echo "${OLLAMA_HOST:-not set}"
    echo ""
    echo "--- Systemd Ollama Status ---"
    systemctl status ollama 2>/dev/null || echo "Ollama service not found"
} > "$LOG_FILE"

print_ok "Log saved: $LOG_FILE"

echo ""
echo -e "${BOLD}${GREEN}=== Hardening Complete ===${NC}"
echo "Run audit.sh to verify posture."
echo ""
