#!/usr/bin/env bash
# =============================================================================
# Linux LLM & AI Agent Installation Identifier
# Regulatory basis: NIST SP 800-53 CM-8; NIST AI 600-1; CMMC 2.0 CM.L2-3.4.1
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/common/patterns.sh"
source "$SCRIPT_DIR/common/references.sh"

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; BOLD='\033[1m'; NC='\033[0m'

print_header()     { echo -e "\n${BOLD}${CYAN}=== $1 ===${NC}"; }
print_found()      { echo -e "${GREEN}[FOUND]${NC} $1"; }
print_warn()       { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_prohibited() { echo -e "${RED}[PROHIBITED]${NC} $1"; }
print_review()     { echo -e "${MAGENTA}[REVIEW]${NC} $1"; }
print_info()       { echo -e "  $1"; }

echo -e "${BOLD}${CYAN}"
echo "╔══════════════════════════════════════════════════════════╗"
echo "║     Linux LLM & AI Agent Installation Identifier         ║"
echo "║  Ref: NIST SP 800-53 CM-8 · NIST AI 600-1                ║"
echo "║       CMMC 2.0 CM.L2-3.4.1 · DFARS 252.204-7012          ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo "Date: $(date) | Host: $(hostname) | User: $(whoami)"
DISTRO=$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"' || echo "Unknown")
echo "Distro: $DISTRO"
echo ""

# ─── 1. RUNNING INFERENCE SERVER PROCESSES ────────────────────────────────────
print_header "1. Running Inference Server Processes"
FOUND_PROCS=0
while IFS= read -r line; do
    print_found "Process: $line"; FOUND_PROCS=$((FOUND_PROCS+1))
done < <(pgrep -fla . 2>/dev/null | grep -iE "$LLM_PROCESS_PATTERN" | grep -v "grep\|$$\|identify" || true)
[ "$FOUND_PROCS" -eq 0 ] && print_info "No inference server processes detected."

# ─── 2. RUNNING AI AGENT PROCESSES ───────────────────────────────────────────
print_header "2. Running AI Agent / Framework Processes"
FOUND_AGENTS=0
while IFS= read -r line; do
    print_warn "Agent process: $line"; FOUND_AGENTS=$((FOUND_AGENTS+1))
done < <(pgrep -fla . 2>/dev/null | grep -iE "$AGENT_PROCESS_PATTERN" | grep -v "grep\|$$\|identify" || true)
[ "$FOUND_AGENTS" -eq 0 ] && print_info "No AI agent processes detected."

# ─── 3. SYSTEMD SERVICES ──────────────────────────────────────────────────────
print_header "3. Systemd LLM / Agent Services"
FOUND_SVCS=0
for svc in ollama localai gpt4all jan tabby koboldcpp text-generation-webui vllm xinference qdrant weaviate milvus; do
    if systemctl list-units --full --all 2>/dev/null | grep -qi "^$svc"; then
        STATUS=$(systemctl is-active "$svc" 2>/dev/null || echo "unknown")
        ENABLED=$(systemctl is-enabled "$svc" 2>/dev/null || echo "unknown")
        print_found "Service: $svc (active=$STATUS, enabled=$ENABLED)"
        FOUND_SVCS=$((FOUND_SVCS+1))
    fi
done
[ "$FOUND_SVCS" -eq 0 ] && print_info "No LLM/agent systemd services found."

# ─── 4. DOCKER CONTAINERS ─────────────────────────────────────────────────────
print_header "4. Docker / Container Workloads"
if command -v docker &>/dev/null; then
    while IFS= read -r line; do
        print_warn "Container: $line"
    done < <(docker ps -a 2>/dev/null | grep -iE "ollama|localai|llama|vllm|tgi|lmstudio|jan|kobold|tabby|oobabooga|xinference|qdrant|weaviate|milvus|anythingllm|privategpt|flowise|dify|n8n|autogpt|crewai|opendevin|openhands|langchain|mem0|memgpt|letta" || true)
    docker ps -a 2>/dev/null | grep -iE "ollama|localai|llama|vllm|tgi" | grep -qi "" || print_info "No LLM-related containers found."
else
    print_info "Docker not installed."
fi
if command -v podman &>/dev/null; then
    while IFS= read -r line; do
        print_warn "Podman container: $line"
    done < <(podman ps -a 2>/dev/null | grep -iE "ollama|llama|vllm|tgi|localai" || true)
fi

# ─── 5. INSTALLED CLI TOOLS ───────────────────────────────────────────────────
print_header "5. Installed LLM / Agent CLI Tools"
for cmd in "${LLM_CLI_TOOLS[@]}" "${AGENT_CLI_TOOLS[@]}"; do
    command -v "$cmd" &>/dev/null && print_found "CLI: $cmd → $(command -v $cmd)"
done

# pip packages
if command -v pip3 &>/dev/null || command -v pip &>/dev/null; then
    PIP_CMD=$(command -v pip3 2>/dev/null || command -v pip)
    while IFS= read -r pkg; do
        print_warn "Python package: $pkg"
    done < <("$PIP_CMD" list 2>/dev/null | grep -iE "ollama|llama.?cpp|transformers|langchain|langgraph|autogen|crewai|openai|anthropic|huggingface|text.?generation|vllm|sglang|open-interpreter|aider|plandex|mentat|goose-ai|memgpt|mem0|letta|phidata|dspy|haystack|xinference|privategpt|localai" || true)
fi

# ─── 6. AGENT CONFIG DIRECTORIES ──────────────────────────────────────────────
print_header "6. Agent Config / Workspace Directories"
AGENT_DIRS=(
    "$HOME/.autogpt" "$HOME/AutoGPT" "$HOME/.crewai" "$HOME/.autogen"
    "$HOME/.opendevin" "$HOME/.openhands" "$HOME/.aider" "$HOME/.goose"
    "$HOME/.plandex" "$HOME/.mentat" "$HOME/.continue" "$HOME/.cody"
    "$HOME/flowise" "$HOME/.flowise" "$HOME/dify" "$HOME/.n8n"
    "$HOME/.memgpt" "$HOME/.letta" "$HOME/.mem0" "$HOME/.langchain"
    "$HOME/privategpt" "$HOME/anythingllm"
)
for d in "${AGENT_DIRS[@]}"; do [ -d "$d" ] && print_warn "Agent config dir: $d"; done

# ─── 7. MODEL DIRECTORIES ─────────────────────────────────────────────────────
print_header "7. Model Directories"
for dir in "${MODEL_DIRS_LINUX[@]}"; do
    if [ -d "$dir" ]; then
        COUNT=$(find "$dir" -type f \( -name "*.gguf" -o -name "*.safetensors" -o -name "*.ggml" -o -name "*.onnx" \) 2>/dev/null | wc -l)
        SIZE=$(du -sh "$dir" 2>/dev/null | cut -f1 || echo "?")
        print_found "$dir ($COUNT model files, ~$SIZE)"
    fi
done

# ─── 8. OLLAMA REGISTERED MODELS ──────────────────────────────────────────────
print_header "8. Ollama Registered Models"
if command -v ollama &>/dev/null; then
    ollama list 2>/dev/null || print_info "Ollama not responding."
else
    print_info "Ollama not installed."
fi

# ─── 9. SPLIT & BLOB-BASED MODEL STORAGE ─────────────────────────────────────
print_header "9. Split & Blob-Based Model Storage"
print_info "Scanning tools that store models as content-addressed blobs or shards..."
SPLIT_FOUND=0

# ── Ollama: content-addressed blob store (sha256-* files, no extension) ───────
for OLLAMA_BLOB_DIR in \
    "$HOME/.ollama/models/blobs" \
    "/usr/share/ollama/.ollama/models/blobs" \
    "/var/lib/ollama/models/blobs"; do
    if [ -d "$OLLAMA_BLOB_DIR" ]; then
        OLLAMA_MANIFEST_DIR="${OLLAMA_BLOB_DIR%/blobs}/manifests"
        BLOB_COUNT=$(find "$OLLAMA_BLOB_DIR" -type f 2>/dev/null | wc -l | tr -d ' ')
        BLOB_TOTAL=$(du -sh "$OLLAMA_BLOB_DIR" 2>/dev/null | cut -f1 || echo "?")
        print_found "Ollama blob store: $BLOB_COUNT content-addressed file(s), ~$BLOB_TOTAL  [$OLLAMA_BLOB_DIR]"
        SPLIT_FOUND=$((SPLIT_FOUND+1))
        if [ -d "$OLLAMA_MANIFEST_DIR" ]; then
            while IFS= read -r MFILE; do
                MODEL_ID="${MFILE#$OLLAMA_MANIFEST_DIR/}"
                MODEL_ID="${MODEL_ID#registry.ollama.ai/}"
                if command -v python3 &>/dev/null; then
                    while IFS='|' read -r SIZE_GB BLOB_PATH STATUS; do
                        if [ "$STATUS" = "ok" ]; then
                            print_found "  [${SIZE_GB} GB] ollama://$MODEL_ID  →  $BLOB_PATH"
                        else
                            print_warn  "  [${SIZE_GB} GB] ollama://$MODEL_ID  →  BLOB MISSING: $BLOB_PATH"
                        fi
                    done < <(MFILE="$MFILE" BDIR="$OLLAMA_BLOB_DIR" python3 -c "
import os, json
mfile    = os.environ['MFILE']
blob_dir = os.environ['BDIR']
try:
    with open(mfile) as f:
        m = json.load(f)
    for layer in m.get('layers', []):
        mt = layer.get('mediaType', '')
        if 'model' in mt or 'weights' in mt:
            digest  = layer['digest'].replace('sha256:', 'sha256-')
            size_gb = round(layer.get('size', 0) / 1073741824, 2)
            blob    = os.path.join(blob_dir, digest)
            status  = 'ok' if os.path.exists(blob) else 'missing'
            print(f'{size_gb}|{blob}|{status}')
except Exception:
    pass
" 2>/dev/null)
                else
                    LAYER_DIGEST=$(grep -A5 'vnd.ollama.image.model' "$MFILE" 2>/dev/null | \
                        grep -o '"sha256:[a-f0-9]*"' | head -1 | tr -d '"' | \
                        sed 's/sha256:/sha256-/')
                    if [ -n "$LAYER_DIGEST" ]; then
                        BLOB_FILE="$OLLAMA_BLOB_DIR/$LAYER_DIGEST"
                        if [ -f "$BLOB_FILE" ]; then
                            FSIZE=$(du -sh "$BLOB_FILE" 2>/dev/null | cut -f1 || echo "?")
                            print_found "  [$FSIZE] ollama://$MODEL_ID  →  $BLOB_FILE"
                        else
                            print_warn "  ollama://$MODEL_ID  →  BLOB MISSING: $BLOB_FILE"
                        fi
                    fi
                fi
            done < <(find "$OLLAMA_MANIFEST_DIR" -type f 2>/dev/null)

            # Report orphaned blobs — large blobs with no matching manifest
            find "$OLLAMA_BLOB_DIR" -type f -size +50M 2>/dev/null | while read -r BLOB; do
                BNAME=$(basename "$BLOB")
                REF=$(grep -rl "${BNAME/sha256-/sha256:}" "$OLLAMA_MANIFEST_DIR" 2>/dev/null | head -1)
                if [ -z "$REF" ]; then
                    FSIZE=$(du -sh "$BLOB" 2>/dev/null | cut -f1 || echo "?")
                    print_warn "  [$FSIZE] Orphaned blob (no manifest — leftover from deleted model): $BLOB"
                fi
            done
        fi
    fi
done

# ── HuggingFace Hub: blob cache + sharded safetensors ─────────────────────────
HF_DIR="$HOME/.cache/huggingface/hub"
if [ -d "$HF_DIR" ]; then
    HF_TOTAL=$(du -sh "$HF_DIR" 2>/dev/null | cut -f1 || echo "?")
    HF_COUNT=$(find "$HF_DIR" -maxdepth 1 -type d -name "models--*" 2>/dev/null | wc -l | tr -d ' ')
    print_found "HuggingFace Hub cache: $HF_COUNT model(s), ~$HF_TOTAL  [$HF_DIR]"
    SPLIT_FOUND=$((SPLIT_FOUND+1))
    find "$HF_DIR" -maxdepth 1 -type d -name "models--*" 2>/dev/null | sort | while read -r MDIR; do
        MODEL_NAME=$(basename "$MDIR" | sed 's/^models--//;s/--/\//g')
        MODEL_SIZE=$(du -sh "$MDIR" 2>/dev/null | cut -f1 || echo "?")
        SHARD_COUNT=$(find "$MDIR" \( -name "model-*-of-*.safetensors" -o -name "pytorch_model-*-of-*.bin" \) 2>/dev/null | wc -l | tr -d ' ')
        BLOB_COUNT=$(find "$MDIR/blobs" -type f -size +50M 2>/dev/null | wc -l | tr -d ' ')
        if [ "$SHARD_COUNT" -gt 0 ]; then
            print_found "  [~$MODEL_SIZE] HuggingFace: $MODEL_NAME  ($SHARD_COUNT weight shards)"
        elif [ "$BLOB_COUNT" -gt 0 ]; then
            print_found "  [~$MODEL_SIZE] HuggingFace: $MODEL_NAME  ($BLOB_COUNT large blob(s))"
        else
            print_found "  [~$MODEL_SIZE] HuggingFace: $MODEL_NAME"
        fi
    done
fi

# ── LM Studio: partial / incomplete downloads ─────────────────────────────────
for LMS_DIR in "$HOME/.lmstudio" "$HOME/.cache/lm-studio"; do
    if [ -d "$LMS_DIR" ]; then
        while IFS= read -r PFILE; do
            FSIZE=$(du -sh "$PFILE" 2>/dev/null | cut -f1 || echo "?")
            print_warn "LM Studio partial download [~$FSIZE]: $PFILE"
            SPLIT_FOUND=$((SPLIT_FOUND+1))
        done < <(find "$LMS_DIR" \( -name "*.part" -o -name "*.download" -o -name "*.incomplete" \) 2>/dev/null)
    fi
done

# ── GPT4All / Jan: flag suspiciously small .gguf (stub / incomplete) ──────────
for TOOL_DIR in \
    "$HOME/.local/share/nomic.ai/GPT4All" \
    "$HOME/jan/models"; do
    if [ -d "$TOOL_DIR" ]; then
        find "$TOOL_DIR" -name "*.gguf" -size -1M 2>/dev/null | while read -r f; do
            FSIZE=$(du -sh "$f" 2>/dev/null | cut -f1 || echo "?")
            print_warn "Possibly incomplete model file [$FSIZE]: $f"
        done
    fi
done

[ "$SPLIT_FOUND" -eq 0 ] && print_info "No split/blob model stores detected."

# ─── 10. ALL STANDARD MODEL FILES ─────────────────────────────────────────────
print_header "10. All Standard Model Files Found"
print_info "(searching $HOME, /usr, /opt...)"
find "$HOME" /usr /opt /var 2>/dev/null \
    -type f \( -name "*.gguf" -o -name "*.safetensors" -o -name "*.ggml" -o -name "*.onnx" -o -name "*.llamafile" \) \
    2>/dev/null | while read -r f; do
    SIZE=$(du -sh "$f" 2>/dev/null | cut -f1 || echo "?"); print_info "[$SIZE] $f"
done

# ─── 11. PROHIBITED MODEL SCAN ────────────────────────────────────────────────
print_header "11. Prohibited / Foreign-Origin Model Scan  [FBI-DEEPSEEK; HOUSE-DEEPSEEK]"
find "$HOME" /usr/share/ollama 2>/dev/null \
    -type f \( -name "*.gguf" -o -name "*.bin" -o -name "*.safetensors" -o -name "*.ggml" \) \
    2>/dev/null | grep -iE "$PROHIBITED_PATTERN" | while read -r f; do
        print_prohibited "PROHIBITED: $f"
    done
if command -v ollama &>/dev/null; then
    ollama list 2>/dev/null | grep -iE "$PROHIBITED_PATTERN" | while read -r line; do
        print_prohibited "PROHIBITED OLLAMA MODEL: $line"
    done
fi
# Also scan HuggingFace Hub model names
if [ -d "$HOME/.cache/huggingface/hub" ]; then
    find "$HOME/.cache/huggingface/hub" -maxdepth 1 -type d -name "models--*" 2>/dev/null | while read -r d; do
        MN=$(basename "$d" | sed 's/^models--//;s/--/\//g')
        echo "$MN" | grep -qiE "$PROHIBITED_PATTERN" && \
            print_prohibited "PROHIBITED HuggingFace model: $MN" || true
    done
fi
find "$HOME" -type f \( -name "*.gguf" -o -name "*.safetensors" \) 2>/dev/null | \
    grep -iE "$REVIEW_PATTERN" | while read -r f; do
        print_review "VERIFY ORIGIN: $f"
    done
print_info "Prohibited scan complete."

# ─── 12. NETWORK EXPOSURE ─────────────────────────────────────────────────────
print_header "12. Network Exposure Check  [NIST SP 800-53 SC-7]"
for entry in "${LLM_PORTS[@]}"; do
    PORT="${entry%%:*}"; TOOL="${entry#*:}"
    if command -v ss &>/dev/null; then
        BIND=$(ss -tlnp 2>/dev/null | grep ":$PORT " || true)
    else
        BIND=$(netstat -tlnp 2>/dev/null | grep ":$PORT " || true)
    fi
    if [ -n "$BIND" ]; then
        echo "$BIND" | grep -qE "0\.0\.0\.0|\*:|\[::\]" && \
            print_warn "Port $PORT ($TOOL) EXPOSED on all interfaces!" || \
            print_found "Port $PORT ($TOOL) — localhost-bound"
        print_info "$BIND"
    fi
done

# ─── 13. OLLAMA CONFIG / SYSTEMD ENV ──────────────────────────────────────────
print_header "13. Ollama Configuration"
OH="${OLLAMA_HOST:-}"
[ -n "$OH" ] && {
    echo "$OH" | grep -qE "0\.0\.0\.0|^:" && \
        print_warn "OLLAMA_HOST=$OH — NETWORK EXPOSED" || print_found "OLLAMA_HOST=$OH"
} || print_info "OLLAMA_HOST not set (defaults to localhost)."

for f in /etc/systemd/system/ollama.service.d/*.conf /lib/systemd/system/ollama.service; do
    [ -f "$f" ] && grep -q "OLLAMA_HOST" "$f" 2>/dev/null && \
        print_warn "OLLAMA_HOST in systemd unit: $f → $(grep OLLAMA_HOST $f)"
done

# ─── 14. MCP CONFIG SCAN ──────────────────────────────────────────────────────
print_header "14. MCP Config Files  [NIST AI 100-2; NSA-AI-SECURITY]"
for f in "${MCP_CONFIG_PATHS_LINUX[@]}"; do
    if [ -f "$f" ] && grep -q "mcpServers" "$f" 2>/dev/null; then
        print_warn "MCP config: $f"
        grep -q '"url"' "$f" 2>/dev/null && print_warn "  >> Contains REMOTE server!"
    fi
done
find "$HOME" -name "mcp.json" 2>/dev/null | while read -r f; do print_warn "mcp.json: $f"; done

# ─── SUMMARY ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}=== Scan Complete ===${NC}"
echo "Run audit.sh for full compliance checklist or harden.sh to apply controls."
print_federal_references
echo ""
