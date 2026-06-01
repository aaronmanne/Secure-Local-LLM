#!/usr/bin/env bash
# =============================================================================
# macOS LLM & AI Agent Installation Identifier
# Identifies inference servers, agent frameworks, model files, and related
# software using the shared patterns catalogue in common/patterns.sh
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../common/patterns.sh
source "$SCRIPT_DIR/common/patterns.sh"

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
echo "║     macOS LLM & AI Agent Installation Identifier        ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo "Date: $(date) | Host: $(hostname) | User: $(whoami)"
echo ""

# ─── 1. RUNNING INFERENCE SERVER PROCESSES ────────────────────────────────────
print_header "1. Running Inference Server Processes"
FOUND_PROCS=0
while IFS= read -r line; do
    print_found "Process: $line"
    FOUND_PROCS=$((FOUND_PROCS+1))
done < <(pgrep -fla . 2>/dev/null | grep -iE "$LLM_PROCESS_PATTERN" | grep -v "grep\|$$" || true)
[ "$FOUND_PROCS" -eq 0 ] && print_info "No inference server processes detected."

# ─── 2. RUNNING AI AGENT PROCESSES ───────────────────────────────────────────
print_header "2. Running AI Agent / Framework Processes"
FOUND_AGENTS=0
while IFS= read -r line; do
    print_warn "Agent process: $line"
    FOUND_AGENTS=$((FOUND_AGENTS+1))
done < <(pgrep -fla . 2>/dev/null | grep -iE "$AGENT_PROCESS_PATTERN" | grep -v "grep\|$$" || true)
[ "$FOUND_AGENTS" -eq 0 ] && print_info "No AI agent processes detected."

# ─── 3. VECTOR DATABASE PROCESSES ─────────────────────────────────────────────
print_header "3. Vector Database Processes"
while IFS= read -r line; do
    print_warn "Vector DB: $line"
done < <(pgrep -fla . 2>/dev/null | grep -iE "$VECTORDB_PROCESS_PATTERN" | grep -v "grep\|$$" || true) || print_info "None detected."

# ─── 4. INSTALLED APPLICATIONS ────────────────────────────────────────────────
print_header "4. Installed LLM / Agent Applications"
FOUND_APPS=0
for app in \
    "Ollama" "LM Studio" "LM_Studio" "GPT4All" "Jan" "LocalAI" \
    "AnythingLLM" "Anything LLM" "Msty" "Tabby" "LMDeploy" \
    "Open WebUI" "OpenWebUI" "SillyTavern" "Oobabooga" \
    "Cursor" "Windsurf" "Continue" "Cody" \
    "AutoGPT" "CrewAI" "OpenDevin" "OpenHands"; do
    for base in "/Applications" "$HOME/Applications"; do
        [ -d "$base/${app}.app" ] && { print_found "App: ${app}.app ($base)"; FOUND_APPS=$((FOUND_APPS+1)); }
    done
done

# CLI tools
for cmd in "${LLM_CLI_TOOLS[@]}" "${AGENT_CLI_TOOLS[@]}"; do
    if command -v "$cmd" &>/dev/null; then
        print_found "CLI: $cmd → $(command -v $cmd)"
        FOUND_APPS=$((FOUND_APPS+1))
    fi
done

# pip-installed packages
if command -v pip3 &>/dev/null || command -v pip &>/dev/null; then
    PIP_CMD=$(command -v pip3 || command -v pip)
    while IFS= read -r pkg; do
        print_warn "Python package: $pkg"
        FOUND_APPS=$((FOUND_APPS+1))
    done < <("$PIP_CMD" list 2>/dev/null | grep -iE "ollama|llama.?cpp|llama-cpp-python|transformers|langchain|langgraph|autogen|crewai|openai|anthropic|cohere|huggingface|text.?generation|vllm|sglang|lmstudio|kobold|tabby|open-interpreter|aider|plandex|mentat|goose-ai|memgpt|mem0|letta|phidata|agno|dspy|haystack|flowise|xinference|privategpt|localai" || true)
fi

# Homebrew formulae
if command -v brew &>/dev/null; then
    while IFS= read -r pkg; do
        print_found "Homebrew: $pkg"
        FOUND_APPS=$((FOUND_APPS+1))
    done < <(brew list 2>/dev/null | grep -iE "ollama|llama|localai|llm|tabby|llamafile" || true)
fi

[ "$FOUND_APPS" -eq 0 ] && print_info "No LLM/agent applications found via standard checks."

# ─── 5. AGENT CONFIG / WORKSPACE FILES ────────────────────────────────────────
print_header "5. Agent Configuration & Workspace Files"
AGENT_DIRS=(
    "$HOME/.autogpt" "$HOME/Auto-GPT" "$HOME/AutoGPT"
    "$HOME/.crewai" "$HOME/.autogen"
    "$HOME/.opendevin" "$HOME/.openhands"
    "$HOME/.aider" "$HOME/.goose" "$HOME/.plandex" "$HOME/.mentat"
    "$HOME/.continue" "$HOME/.cody"
    "$HOME/flowise" "$HOME/.flowise"
    "$HOME/dify" "$HOME/.dify"
    "$HOME/n8n" "$HOME/.n8n"
    "$HOME/.memgpt" "$HOME/.letta" "$HOME/.mem0"
    "$HOME/.langchain"
    "$HOME/privategpt" "$HOME/anythingllm"
)
for d in "${AGENT_DIRS[@]}"; do
    [ -d "$d" ] && print_warn "Agent config dir: $d"
done

# aider config files
for f in "$HOME/.aider.conf.yml" "$HOME/.aider.model.metadata.json"; do
    [ -f "$f" ] && print_warn "Aider config: $f"
done

# ─── 6. MODEL DIRECTORIES ─────────────────────────────────────────────────────
print_header "6. Model Directories"
for dir in "${MODEL_DIRS_MACOS[@]}"; do
    if [ -d "$dir" ]; then
        COUNT=$(find "$dir" -type f \( -name "*.gguf" -o -name "*.safetensors" -o -name "*.ggml" -o -name "*.onnx" -o -name "*.llamafile" \) 2>/dev/null | wc -l | tr -d ' ')
        SIZE=$(du -sh "$dir" 2>/dev/null | cut -f1 || echo "?")
        print_found "Dir: $dir ($COUNT model files, ~$SIZE)"
    fi
done

# ─── 7. OLLAMA REGISTERED MODELS ──────────────────────────────────────────────
print_header "7. Ollama Registered Models"
if command -v ollama &>/dev/null; then
    ollama list 2>/dev/null || print_info "Ollama not responding."
else
    print_info "Ollama not installed."
fi

# ─── 8. SPLIT & BLOB-BASED MODEL STORAGE ─────────────────────────────────────
print_header "8. Split & Blob-Based Model Storage"
print_info "Scanning tools that store models as content-addressed blobs or shards..."
SPLIT_FOUND=0

# ── Ollama: content-addressed blob store (~/.ollama/models/blobs/sha256-*)  ──
# Ollama does NOT use .gguf filenames — it splits models into sha256-named blobs.
OLLAMA_BLOB_DIR="$HOME/.ollama/models/blobs"
OLLAMA_MANIFEST_DIR="$HOME/.ollama/models/manifests"
if [ -d "$OLLAMA_BLOB_DIR" ]; then
    BLOB_COUNT=$(find "$OLLAMA_BLOB_DIR" -type f 2>/dev/null | wc -l | tr -d ' ')
    BLOB_TOTAL=$(du -sh "$OLLAMA_BLOB_DIR" 2>/dev/null | cut -f1 || echo "?")
    print_found "Ollama blob store: $BLOB_COUNT content-addressed file(s), ~$BLOB_TOTAL  [$OLLAMA_BLOB_DIR]"
    SPLIT_FOUND=$((SPLIT_FOUND+1))
    if [ -d "$OLLAMA_MANIFEST_DIR" ]; then
        while IFS= read -r MFILE; do
            MODEL_ID="${MFILE#$OLLAMA_MANIFEST_DIR/}"
            MODEL_ID="${MODEL_ID#registry.ollama.ai/}"
            # Use python3 for reliable JSON parsing; grep fallback if unavailable
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
            digest   = layer['digest'].replace('sha256:', 'sha256-')
            size_gb  = round(layer.get('size', 0) / 1073741824, 2)
            blob     = os.path.join(blob_dir, digest)
            status   = 'ok' if os.path.exists(blob) else 'missing'
            print(f'{size_gb}|{blob}|{status}')
except Exception:
    pass
" 2>/dev/null)
            else
                # grep fallback: model layer digest follows the mediaType line
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

        # Report orphaned blobs — large blobs with no matching manifest entry
        find "$OLLAMA_BLOB_DIR" -type f -size +50M 2>/dev/null | while read -r BLOB; do
            BNAME=$(basename "$BLOB")
            REF=$(grep -rl "${BNAME/sha256-/sha256:}" "$OLLAMA_MANIFEST_DIR" 2>/dev/null | head -1)
            if [ -z "$REF" ]; then
                FSIZE=$(du -sh "$BLOB" 2>/dev/null | cut -f1 || echo "?")
                print_warn "  [$FSIZE] Orphaned blob (no manifest — leftover from deleted model): $BLOB"
            fi
        done
    fi
else
    print_info "Ollama blob store not found (Ollama not installed or no models pulled)."
fi

# ── HuggingFace Hub: content-addressed blob cache + sharded safetensors ──────
# HF Hub stores model shards as model-00001-of-NNNNN.safetensors and blobs/
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
        BLOB_COUNT=$(find "$MDIR/blobs" -type f -size +50M 2>/dev/null 2>/dev/null | wc -l | tr -d ' ')
        if [ "$SHARD_COUNT" -gt 0 ]; then
            print_found "  [~$MODEL_SIZE] HuggingFace: $MODEL_NAME  ($SHARD_COUNT weight shards)"
        elif [ "$BLOB_COUNT" -gt 0 ]; then
            print_found "  [~$MODEL_SIZE] HuggingFace: $MODEL_NAME  ($BLOB_COUNT large blob(s))"
        else
            print_found "  [~$MODEL_SIZE] HuggingFace: $MODEL_NAME"
        fi
    done
fi

# ── LM Studio: detect partial / incomplete downloads (.part, .download) ───────
for LMS_DIR in \
    "$HOME/.lmstudio" \
    "$HOME/.cache/lm-studio" \
    "$HOME/Library/Application Support/LM Studio"; do
    if [ -d "$LMS_DIR" ]; then
        while IFS= read -r PFILE; do
            FSIZE=$(du -sh "$PFILE" 2>/dev/null | cut -f1 || echo "?")
            print_warn "LM Studio partial download [~$FSIZE]: $PFILE"
            SPLIT_FOUND=$((SPLIT_FOUND+1))
        done < <(find "$LMS_DIR" \( -name "*.part" -o -name "*.download" -o -name "*.incomplete" \) 2>/dev/null)
    fi
done

# ── GPT4All / Jan: multi-part model checks ────────────────────────────────────
# GPT4All and Jan use standard .gguf but verify each model dir is complete
for TOOL_DIR in \
    "$HOME/Library/Application Support/nomic.ai/GPT4All" \
    "$HOME/jan/models"; do
    if [ -d "$TOOL_DIR" ]; then
        # Flag any zero-byte or very small .gguf (likely a stub / incomplete download)
        find "$TOOL_DIR" -name "*.gguf" -size -1M 2>/dev/null | while read -r f; do
            FSIZE=$(du -sh "$f" 2>/dev/null | cut -f1 || echo "?")
            print_warn "Possibly incomplete model file [$FSIZE]: $f"
        done
    fi
done

[ "$SPLIT_FOUND" -eq 0 ] && print_info "No split/blob model stores detected."

# ─── 9. ALL STANDARD MODEL FILES ──────────────────────────────────────────────
print_header "9. All Standard Model Files Found on System"
print_info "(searching $HOME and /usr — may take a moment...)"
find "$HOME" /usr /opt 2>/dev/null \
    -type f \( -name "*.gguf" -o -name "*.safetensors" -o -name "*.ggml" -o -name "*.onnx" -o -name "*.llamafile" \) \
    2>/dev/null | while read -r f; do
    SIZE=$(du -sh "$f" 2>/dev/null | cut -f1 || echo "?")
    print_info "[$SIZE] $f"
done

# ─── 10. PROHIBITED MODEL SCAN ────────────────────────────────────────────────
print_header "10. Prohibited / Foreign-Origin Model Scan"
print_info "Scanning for Chinese / Russian / UAE-origin models..."

find "$HOME" -type f \( -name "*.gguf" -o -name "*.bin" -o -name "*.safetensors" -o -name "*.ggml" \) 2>/dev/null | \
    grep -iE "$PROHIBITED_PATTERN" | while read -r f; do
        print_prohibited "PROHIBITED: $f"
    done

if command -v ollama &>/dev/null; then
    ollama list 2>/dev/null | grep -iE "$PROHIBITED_PATTERN" | while read -r line; do
        print_prohibited "PROHIBITED OLLAMA MODEL: $line"
    done
fi

# Also check HuggingFace Hub model names against prohibited list
if [ -d "$HOME/.cache/huggingface/hub" ]; then
    find "$HOME/.cache/huggingface/hub" -maxdepth 1 -type d -name "models--*" 2>/dev/null | while read -r d; do
        MODEL_NAME=$(basename "$d" | sed 's/^models--//;s/--/\//g')
        echo "$MODEL_NAME" | grep -iE "$PROHIBITED_PATTERN" && \
            print_prohibited "PROHIBITED HuggingFace model: $MODEL_NAME" || true
    done
fi

# Review-warranted (fine-tunes that need provenance check)
find "$HOME" -type f \( -name "*.gguf" -o -name "*.safetensors" \) 2>/dev/null | \
    grep -iE "$REVIEW_PATTERN" | while read -r f; do
        print_review "VERIFY ORIGIN: $f"
    done

print_info "Prohibited scan complete."

# ─── 11. NETWORK EXPOSURE ─────────────────────────────────────────────────────
print_header "11. Network Exposure Check"
for entry in "${LLM_PORTS[@]}"; do
    PORT="${entry%%:*}"; TOOL="${entry#*:}"
    BINDING=$(lsof -i TCP:"$PORT" -sTCP:LISTEN -n -P 2>/dev/null || true)
    if [ -n "$BINDING" ]; then
        if echo "$BINDING" | grep -qE "\*:|0\.0\.0\.0"; then
            print_warn "Port $PORT ($TOOL) EXPOSED on all interfaces!"
            echo "$BINDING" | while read -r b; do print_info "$b"; done
        else
            print_found "Port $PORT ($TOOL) — localhost-bound"
        fi
    fi
done

# ─── 12. OLLAMA CONFIG ────────────────────────────────────────────────────────
print_header "12. Ollama Configuration"
OH="${OLLAMA_HOST:-}"
if [ -n "$OH" ]; then
    echo "$OH" | grep -qE "0\.0\.0\.0|^:" && \
        print_warn "OLLAMA_HOST=$OH — EXPOSED!" || \
        print_found "OLLAMA_HOST=$OH"
else
    print_info "OLLAMA_HOST not set (defaults to 127.0.0.1:11434)"
fi

# ─── 13. MCP CONFIG SCAN ──────────────────────────────────────────────────────
print_header "13. MCP (Model Context Protocol) Config Files"
for f in "${MCP_CONFIG_PATHS_MACOS[@]}"; do
    if [ -f "$f" ] && grep -q "mcpServers" "$f" 2>/dev/null; then
        print_warn "MCP config: $f"
        grep -q '"url"' "$f" 2>/dev/null && print_warn "  >> Contains REMOTE server (url key)"
    fi
done
find "$HOME" -name "mcp.json" 2>/dev/null | while read -r f; do
    print_warn "mcp.json: $f"
done

# ─── SUMMARY ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}=== Scan Complete ===${NC}"
echo "Run audit.sh for full compliance checklist or harden.sh to apply controls."
echo ""
