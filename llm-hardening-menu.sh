#!/usr/bin/env bash
# =============================================================================
# LLM Security Hardening – Main Menu
# Detects OS and routes to the appropriate platform scripts
# Compatible with: macOS, Linux
# For Windows: run llm-hardening-menu.ps1 instead
# =============================================================================

set -euo pipefail

# ─── COLORS ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# ─── DETECT OS AND SCRIPT DIR ─────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

detect_os() {
    case "$(uname -s)" in
        Darwin) echo "macos" ;;
        Linux)  echo "linux" ;;
        MINGW*|CYGWIN*|MSYS*) echo "windows" ;;
        *) echo "unknown" ;;
    esac
}

OS=$(detect_os)
OS_DIR="$SCRIPT_DIR/$OS"

# ─── BANNER ───────────────────────────────────────────────────────────────────
print_banner() {
    clear
    echo -e "${BOLD}${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║          Local LLM Security Hardening Suite                  ║"
    echo "║          Federal Contractor Security Guidance                 ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "  Platform: ${BOLD}$(uname -s) $(uname -m)${NC}"
    echo -e "  Host:     ${BOLD}$(hostname)${NC}"
    echo -e "  User:     ${BOLD}$(whoami)${NC}"
    echo -e "  Date:     ${BOLD}$(date)${NC}"
    echo ""

    case "$OS" in
        macos) echo -e "  OS Profile: ${GREEN}macOS${NC} — using scripts in: macos/" ;;
        linux) echo -e "  OS Profile: ${GREEN}Linux${NC} — using scripts in: linux/" ;;
        windows) echo -e "  OS Profile: ${YELLOW}Windows (Git Bash/WSL)${NC} — consider running llm-hardening-menu.ps1" ;;
        *) echo -e "  OS Profile: ${RED}Unknown${NC} — manual script selection required" ;;
    esac
    echo ""
}

# ─── CHECK SCRIPTS EXIST ──────────────────────────────────────────────────────
ensure_scripts() {
    if [ ! -d "$OS_DIR" ]; then
        echo -e "${RED}[ERROR]${NC} Script directory not found: $OS_DIR"
        echo "  Please ensure you are running from the repo root."
        exit 1
    fi
    for script in identify.sh audit.sh harden.sh mcp-audit.sh; do
        if [ ! -f "$OS_DIR/$script" ]; then
            echo -e "${YELLOW}[WARN]${NC} Missing script: $OS_DIR/$script"
        else
            chmod +x "$OS_DIR/$script" 2>/dev/null || true
        fi
    done
}

# ─── RUN SCRIPT ───────────────────────────────────────────────────────────────
run_script() {
    local script="$OS_DIR/$1"
    if [ ! -f "$script" ]; then
        echo -e "${RED}[ERROR]${NC} Script not found: $script"
        read -rp "Press Enter to continue..."
        return 1
    fi
    chmod +x "$script" 2>/dev/null || true
    echo ""
    echo -e "${CYAN}─── Running: $script ───${NC}"
    echo ""
    bash "$script"
    echo ""
    read -rp "Press Enter to return to menu..."
}

# ─── IDENTIFY: full identify + MCP audit + evidence collection ───────────────
run_identify() {
    local EVIDENCE_DIR="$HOME/llm-audit-evidence-$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$EVIDENCE_DIR"

    echo -e "${CYAN}─── Identify: LLM Discovery + MCP Audit + Evidence Collection ───${NC}"
    echo "Evidence will be saved to: $EVIDENCE_DIR"
    echo ""

    # ── Live output ──────────────────────────────────────────────────────────
    echo -e "${CYAN}─── Step 1/2: Identifying LLM installations... ───${NC}"
    echo ""
    bash "$OS_DIR/identify.sh" 2>/dev/null | tee "$EVIDENCE_DIR/identify.txt" || true

    echo ""
    echo -e "${CYAN}─── Step 2/2: MCP (Model Context Protocol) audit... ───${NC}"
    echo ""
    bash "$OS_DIR/mcp-audit.sh" 2>/dev/null | tee "$EVIDENCE_DIR/mcp-audit.txt" || true

    # ── Collect supplemental system evidence ─────────────────────────────────
    {
        echo "=== LLM Audit Evidence ==="
        echo "Date: $(date)"
        echo "Host: $(hostname)"
        echo "User: $(whoami)"
        echo ""

        if command -v ollama &>/dev/null; then
            echo "=== Ollama Models ==="
            ollama list 2>/dev/null || echo "Ollama not responding"
        fi

        echo ""
        echo "=== Model Files Found ==="
        find "$HOME" -type f \( -name "*.gguf" -o -name "*.safetensors" -o -name "*.ggml" \) 2>/dev/null || true

        echo ""
        echo "=== Network Ports ==="
        if command -v ss &>/dev/null; then
            ss -tlnp 2>/dev/null | grep -E "11434|1234|8080" || echo "None found"
        else
            netstat -an 2>/dev/null | grep -E "11434|1234|8080" || echo "None found"
        fi

        echo ""
        echo "=== OLLAMA_HOST ==="
        echo "${OLLAMA_HOST:-not set}"

        echo ""
        echo "=== MCP Configs ==="
        find "$HOME" -name "claude_desktop_config.json" -o -name "mcp.json" 2>/dev/null | while read -r f; do
            echo "--- $f ---"
            cat "$f" 2>/dev/null || true
        done

    } > "$EVIDENCE_DIR/evidence.txt" 2>/dev/null

    echo ""
    echo -e "${GREEN}Evidence bundle saved to: $EVIDENCE_DIR${NC}"
    echo "Contents:"
    ls -la "$EVIDENCE_DIR"
    echo ""
    read -rp "Press Enter to return to menu..."
}

# ─── OS SELECTION OVERRIDE ────────────────────────────────────────────────────
select_platform() {
    echo ""
    echo "Select platform scripts to use:"
    echo "  1) macOS"
    echo "  2) Linux"
    echo "  3) Back"
    echo ""
    read -rp "Choice: " PLAT_CHOICE
    case "$PLAT_CHOICE" in
        1) OS="macos"; OS_DIR="$SCRIPT_DIR/macos" ;;
        2) OS="linux"; OS_DIR="$SCRIPT_DIR/linux" ;;
        *) return ;;
    esac
    echo -e "${GREEN}Platform set to: $OS${NC}"
    sleep 1
}

# ─── MAIN MENU ────────────────────────────────────────────────────────────────
main_menu() {
    ensure_scripts

    while true; do
        print_banner
        echo -e "${BOLD}  Main Menu${NC}"
        echo "  ─────────────────────────────────────────────"
        echo "  1) 🔍  Identify LLM installations on this system"
        echo "  2) ✅  Run security audit checklist"
        echo "  3) 🔒  Apply hardening controls"
        echo "  ─────────────────────────────────────────────"
        echo "  7) 🖥️   Switch platform (current: $OS)"
        echo "  8) 📖  View README / documentation"
        echo "  q) Quit"
        echo ""
        read -rp "  Select option: " CHOICE

        case "$CHOICE" in
            1) run_identify ;;
            2) run_script "audit.sh" ;;
            3) run_script "harden.sh" ;;
            7) select_platform; ensure_scripts ;;
            8)
                if command -v less &>/dev/null; then
                    less "$SCRIPT_DIR/README.md"
                else
                    cat "$SCRIPT_DIR/README.md" | head -100
                    read -rp "Press Enter to continue..."
                fi
                ;;
            q|Q|quit|exit) echo -e "\n${GREEN}Goodbye.${NC}\n"; exit 0 ;;
            *) echo -e "${YELLOW}Invalid option.${NC}"; sleep 1 ;;
        esac
    done
}

# ─── ENTRY POINT ──────────────────────────────────────────────────────────────

# Handle command-line arguments for non-interactive use
if [ "${1:-}" = "--identify" ]; then bash "$OS_DIR/identify.sh"; exit 0; fi
if [ "${1:-}" = "--audit" ];    then bash "$OS_DIR/audit.sh";    exit 0; fi
if [ "${1:-}" = "--harden" ];   then bash "$OS_DIR/harden.sh";   exit 0; fi
if [ "${1:-}" = "--mcp" ];      then bash "$OS_DIR/mcp-audit.sh"; exit 0; fi
if [ "${1:-}" = "--help" ]; then
    echo "Usage: $0 [--identify|--audit|--harden|--mcp|--help]"
    echo "  Without arguments: launches interactive menu"
    exit 0
fi

main_menu
