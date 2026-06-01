#!/usr/bin/env bash
# =============================================================================
# Linux LLM Hardening Script
# Regulatory basis: NIST SP 800-53 SC-7, AC-6, AU-2, CM-7;
#                   NIST AI 600-1; DFARS 252.204-7012; CMMC 2.0
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
echo "║            Linux LLM Hardening Script                   ║"
echo "║  Ref: NIST SP 800-53 SC-7 · AC-6 · AU-2 · CM-7         ║"
echo "║       NIST AI 600-1 · DFARS 252.204-7012 · CMMC 2.0    ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo "Date: $(date) | Host: $(hostname) | User: $(whoami)"
echo ""
read -rp "Continue with hardening? [y/N] " CONFIRM
[[ "$CONFIRM" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

# ─── 1. STOP SERVICES ─────────────────────────────────────────────────────────
print_header "1. Stop LLM / Agent Services  [NIST SP 800-53 CM-7: Least Functionality]"

for PROC in ollama localai tabby koboldcpp text-generation-webui vllm xinference; do
    if systemctl is-active --quiet "$PROC" 2>/dev/null; then
        print_action "Stopping systemd service: $PROC"
        sudo systemctl stop "$PROC" && print_ok "Stopped: $PROC"
    elif pgrep -fi "$PROC" &>/dev/null; then
        read -rp "  Kill process '$PROC'? [y/N] " PC
        [[ "$PC" =~ ^[Yy]$ ]] && sudo pkill -fi "$PROC" && print_ok "Killed: $PROC" || print_skip "$PROC"
    fi
done

# ─── 2. RESTRICT OLLAMA TO LOCALHOST ──────────────────────────────────────────
print_header "2. Restrict Ollama to Localhost  [NIST SP 800-53 SC-7, IA-3]"

OVERRIDE_DIR="/etc/systemd/system/ollama.service.d"
if systemctl list-unit-files ollama.service &>/dev/null 2>&1 | grep -q ollama; then
    print_action "Creating systemd override: OLLAMA_HOST=127.0.0.1"
    sudo mkdir -p "$OVERRIDE_DIR"
    sudo tee "$OVERRIDE_DIR/localhost.conf" > /dev/null <<'EOF'
# LLM Hardening — NIST SP 800-53 SC-7 Boundary Protection
[Service]
Environment="OLLAMA_HOST=127.0.0.1"
EOF
    sudo systemctl daemon-reload
    print_ok "Systemd override created: $OVERRIDE_DIR/localhost.conf"
fi

for PROFILE in "$HOME/.bashrc" "$HOME/.profile" "$HOME/.bash_profile" "$HOME/.zshrc"; do
    if [ -f "$PROFILE" ] && ! grep -q "OLLAMA_HOST" "$PROFILE"; then
        printf '\n# LLM Hardening — NIST SP 800-53 SC-7\nexport OLLAMA_HOST=127.0.0.1\n' >> "$PROFILE"
        print_ok "OLLAMA_HOST=127.0.0.1 added to $PROFILE"
    fi
done
cite "NIST SP 800-53 SC-7 (Boundary Protection)"

# ─── 3. FIREWALL ──────────────────────────────────────────────────────────────
print_header "3. Firewall Rules  [NIST SP 800-53 SC-7; CMMC AC.L2-3.1.3]"

if command -v ufw &>/dev/null; then
    print_action "Applying UFW rules for all LLM/agent ports..."
    for entry in "${LLM_PORTS[@]}"; do
        PORT="${entry%%:*}"; TOOL="${entry#*:}"
        sudo ufw deny in from any to any port "$PORT" proto tcp comment "LLM-Harden: $TOOL" 2>/dev/null || true
        sudo ufw allow from 127.0.0.1 to any port "$PORT" proto tcp comment "LLM-Harden: allow localhost $TOOL" 2>/dev/null || true
        print_ok "UFW: $PORT ($TOOL) — blocked external, allowed localhost"
    done
    sudo ufw --force enable
    print_ok "UFW enabled."

elif command -v firewall-cmd &>/dev/null; then
    print_action "Applying firewalld rules..."
    for entry in "${LLM_PORTS[@]}"; do
        PORT="${entry%%:*}"; TOOL="${entry#*:}"
        sudo firewall-cmd --permanent --add-rich-rule="rule family='ipv4' port port='$PORT' protocol='tcp' source address='127.0.0.1' accept" 2>/dev/null || true
        sudo firewall-cmd --permanent --add-rich-rule="rule family='ipv4' port port='$PORT' protocol='tcp' reject" 2>/dev/null || true
        print_ok "firewalld: $PORT ($TOOL) restricted to localhost"
    done
    sudo firewall-cmd --reload
    print_ok "firewalld reloaded."

elif command -v iptables &>/dev/null; then
    print_action "Applying iptables rules..."
    for entry in "${LLM_PORTS[@]}"; do
        PORT="${entry%%:*}"; TOOL="${entry#*:}"
        sudo iptables -I INPUT -p tcp --dport "$PORT" ! -s 127.0.0.1 -j DROP 2>/dev/null || true
        print_ok "iptables: blocked port $PORT ($TOOL) from non-localhost"
    done
    # Persist
    sudo iptables-save > /etc/iptables/rules.v4 2>/dev/null || \
    sudo iptables-save > /etc/iptables.rules 2>/dev/null || true
    print_ok "iptables rules saved."
else
    print_warn "No firewall tool found. Apply rules manually."
fi
cite "NIST SP 800-53 SC-7 / CMMC AC.L2-3.1.3"

# ─── 4. FILE PERMISSIONS ──────────────────────────────────────────────────────
print_header "4. File Permissions  [NIST SP 800-53 AC-3, AC-6: Least Privilege]"

for dir in "${MODEL_DIRS_LINUX[@]}"; do
    if [ -d "$dir" ]; then
        chmod -R o-rwx "$dir" 2>/dev/null || true
        print_ok "Others-access removed: $dir"
    fi
done
cite "NIST SP 800-53 AC-6 (Least Privilege)"

# ─── 5. PROHIBITED MODEL REMOVAL ──────────────────────────────────────────────
print_header "5. Prohibited Model Removal  [FBI-DEEPSEEK; HOUSE-DEEPSEEK; NIST AI 600-1 §2.5]"

QUARANTINE_DIR="/var/quarantine/llm-removed-$(date +%Y%m%d_%H%M%S)"
FOUND_PROHIBITED=0

while IFS= read -r f; do
    if echo "$f" | grep -iEq "$PROHIBITED_PATTERN"; then
        [ "$FOUND_PROHIBITED" -eq 0 ] && sudo mkdir -p "$QUARANTINE_DIR" && \
            print_warn "Quarantine directory: $QUARANTINE_DIR"
        read -rp "  Quarantine: $f ? [y/N] " QC
        if [[ "$QC" =~ ^[Yy]$ ]]; then
            sudo mv "$f" "$QUARANTINE_DIR/"
            sudo chmod 000 "$QUARANTINE_DIR/$(basename "$f")"
            print_ok "Quarantined: $(basename "$f")"
        fi
        FOUND_PROHIBITED=$((FOUND_PROHIBITED+1))
    fi
done < <(find "$HOME" /usr/share/ollama 2>/dev/null -type f \( -name "*.gguf" -o -name "*.bin" -o -name "*.safetensors" \) 2>/dev/null)

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
cite "FBI-DEEPSEEK / HOUSE-DEEPSEEK / NIST AI 600-1 §2.5"

# ─── 6. DISABLE AUTO-START ────────────────────────────────────────────────────
print_header "6. Disable Auto-Start  [NIST SP 800-53 CM-7: Least Functionality]"

for svc in ollama localai tabby koboldcpp text-generation-webui vllm xinference; do
    if systemctl is-enabled "$svc" &>/dev/null 2>&1; then
        read -rp "  Disable auto-start for '$svc'? [y/N] " DC
        if [[ "$DC" =~ ^[Yy]$ ]]; then
            sudo systemctl disable "$svc"
            print_ok "Disabled: $svc"
        fi
    fi
done

# ─── 7. AUDIT LOG ─────────────────────────────────────────────────────────────
print_header "7. Hardening Audit Log  [NIST SP 800-53 AU-2, AU-12]"

LOG_FILE="$HOME/llm-hardening-$(date +%Y%m%d_%H%M%S).log"
{
    echo "LLM Hardening Report — Linux"
    echo "Date: $(date)"
    echo "Host: $(hostname)"
    echo "User: $(whoami)"
    echo "Distro: $(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')"
    echo "Regulatory basis: NIST SP 800-53, NIST AI 600-1, DFARS 252.204-7012, CMMC 2.0"
    echo ""
    echo "--- Ollama Models ---"
    ollama list 2>/dev/null || echo "Ollama not available"
    echo ""
    echo "--- Listening Ports ---"
    ss -tlnp 2>/dev/null | grep -E "$LLM_PORT_NUMS" || echo "None found"
    echo ""
    echo "--- OLLAMA_HOST ---"
    echo "${OLLAMA_HOST:-not set}"
    echo ""
    echo "--- Systemd Ollama ---"
    systemctl status ollama 2>/dev/null || echo "Not found"
} > "$LOG_FILE"
print_ok "Log saved: $LOG_FILE"

# ─── REFERENCES ───────────────────────────────────────────────────────────────
print_federal_references

echo -e "${BOLD}${GREEN}=== Hardening Complete ===${NC}"
echo "Run audit.sh to verify posture."
echo ""
