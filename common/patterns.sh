#!/usr/bin/env bash
# =============================================================================
# common/patterns.sh
# Single source of truth for all LLM tool, agent, model, and port patterns.
# Sourced by macos/ and linux/ scripts.  Edit here — changes apply everywhere.
# =============================================================================

# ─── INFERENCE SERVERS / RUNTIMES ─────────────────────────────────────────────
# Process names and CLI binaries to look for
LLM_PROCESS_PATTERN="ollama|lmstudio|lm-studio|lm_studio|localai|local-ai|gpt4all|jan\b|llamafile|llama\.cpp|llama-server|llama-cpp|text-generation-webui|webui\.py|oobabooga|koboldcpp|koboldai|kobold-cpp|tabby\b|tabbyml|vllm|vllm\.entrypoints|tgi\b|text_generation_inference|xinference|privategpt|private-gpt|anythingllm|anything-llm|msty\b|lmdeploy|lm-deploy|dalai\b|serge\b|librechat|fastchat|fschat|sglang\b|llamacpp|nitro\b|cortex\b|moshi\b|open-webui|openwebui"

# CLI binaries to probe with `command -v`
LLM_CLI_TOOLS=(
    ollama
    localai
    llamafile
    llm
    lm-studio
    koboldcpp
    tabby
    vllm
    tgi
    xinference
    privategpt
    anythingllm
    dalai
    fastchat
    sglang
    nitro
    cortex
)

# ─── AI AGENT FRAMEWORKS & CODING AGENTS ──────────────────────────────────────
AGENT_PROCESS_PATTERN="autogpt|auto-gpt|agentgpt|babyagi|baby-agi|superagi|super-agi|crewai|crew-ai|autogen|auto-gen|opendevin|open-devin|openhands|open-hands|gpt-engineer|gptengineer|open-interpreter|openinterpreter\b|aider\b|goose\b|plandex\b|mentat\b|openclaw|open-claw|hermes-agent|devon\b|sweep\b|swe-agent|swe_agent|gptpilot|gpt-pilot|devika\b|agenta\b|fixie\b|langchain|langgraph|haystack\b|flowise\b|dify\b|n8n\b|activepieces|taskweaver|memgpt|mem0\b|letta\b|praison|agno\b|phidata"

AGENT_CLI_TOOLS=(
    aider
    interpreter
    goose
    plandex
    mentat
    crewai
    autogen
    autogpt
)

# ─── ALL TOOL NAMES (combined, for directory/file searching) ──────────────────
ALL_TOOL_PATTERN="${LLM_PROCESS_PATTERN}|${AGENT_PROCESS_PATTERN}"

# ─── PORTS TO CHECK ───────────────────────────────────────────────────────────
# Format: "PORT:TOOL_NAME"
declare -a LLM_PORTS=(
    "11434:Ollama"
    "1234:LM Studio"
    "8080:LocalAI / llama.cpp server"
    "8000:vLLM / FastChat / Open Interpreter"
    "8001:PrivateGPT"
    "7860:text-generation-webui / Gradio"
    "5001:KoboldAI / KoboldCPP"
    "9997:Xinference"
    "3000:AnythingLLM / LibreChat / Open WebUI"
    "3001:AnythingLLM / LibreChat"
    "4891:GPT4All server"
    "5000:various (LocalAI alt / Tabby)"
    "5005:Tabby / various"
    "6333:Qdrant vector DB"
    "6334:Qdrant gRPC"
    "8265:Ray dashboard (vLLM cluster)"
    "9000:various agent APIs"
    "9200:Elasticsearch (RAG backend)"
    "19530:Milvus vector DB"
)

# Just the port numbers for grep/netstat
LLM_PORT_NUMS="11434|1234|8080|8000|8001|7860|5001|9997|3000|3001|4891|5000|5005|6333|6334|8265|9000|9200|19530"

# ─── MODEL FILE EXTENSIONS ────────────────────────────────────────────────────
MODEL_EXTENSIONS=("*.gguf" "*.ggml" "*.bin" "*.safetensors" "*.pt" "*.pth" "*.ot" "*.onnx" "*.llamafile")
MODEL_EXT_FIND='( -name "*.gguf" -o -name "*.ggml" -o -name "*.safetensors" -o -name "*.ot" -o -name "*.onnx" -o -name "*.llamafile" )'
# Note: .bin and .pt/.pth intentionally omitted from broad filesystem searches (too many false positives)

# ─── MODEL DIRECTORIES ────────────────────────────────────────────────────────
# Note: Ollama stores models as content-addressed blobs (sha256-*) in the blobs/
# subdirectory — NOT as .gguf files. The identify scripts handle these specially.
# HuggingFace Hub stores sharded safetensors and blobs in ~/.cache/huggingface/hub.
declare -a MODEL_DIRS_MACOS=(
    "$HOME/.ollama/models"                                   # Ollama (blob store)
    "$HOME/.ollama/models/blobs"                             # Ollama raw blobs
    "$HOME/.lmstudio/models"                                 # LM Studio
    "$HOME/Library/Application Support/LM Studio"           # LM Studio alt
    "$HOME/Library/Application Support/nomic.ai/GPT4All"    # GPT4All
    "$HOME/jan/models"                                       # Jan
    "$HOME/.localai/models"                                  # LocalAI
    "$HOME/.cache/lm-studio"                                 # LM Studio cache
    "$HOME/.tabby/models"                                    # Tabby
    "$HOME/.cache/koboldcpp"                                 # KoboldCPP
    "$HOME/text-generation-webui/models"                     # text-gen-webui
    "$HOME/.cache/xinference/models"                         # Xinference
    "$HOME/.cache/huggingface/hub"                           # HuggingFace Hub (shards + blobs)
    "$HOME/Library/Application Support/Msty"                # Msty
    "$HOME/.continue/models"                                 # Continue
    "$HOME/.cache/lm_studio"                                 # LM Studio cache alt
    "$HOME/privategpt/models"                                # PrivateGPT
    "$HOME/anythingllm/models"                               # AnythingLLM
    "$HOME/.cortex/models"                                   # Cortex
    "$HOME/.nitro/models"                                    # Nitro
)

declare -a MODEL_DIRS_LINUX=(
    "$HOME/.ollama/models"                                   # Ollama (blob store)
    "$HOME/.ollama/models/blobs"                             # Ollama raw blobs
    "/usr/share/ollama/.ollama/models"                       # Ollama system-wide
    "/usr/share/ollama/.ollama/models/blobs"                 # Ollama system blobs
    "/var/lib/ollama/models"                                 # Ollama service data
    "/var/lib/ollama/models/blobs"                           # Ollama service blobs
    "$HOME/.lmstudio/models"                                 # LM Studio
    "$HOME/jan/models"                                       # Jan
    "/usr/share/local-ai/models"                             # LocalAI system
    "$HOME/.local/share/nomic.ai/GPT4All"                   # GPT4All
    "$HOME/.cache/lm-studio"                                 # LM Studio cache
    "$HOME/.tabby/models"                                    # Tabby
    "$HOME/.cache/koboldcpp"                                 # KoboldCPP
    "$HOME/text-generation-webui/models"                     # text-gen-webui
    "$HOME/.cache/xinference/models"                         # Xinference
    "$HOME/.cache/huggingface/hub"                           # HuggingFace Hub (shards + blobs)
    "/usr/share/text-generation-inference/data"              # TGI
    "$HOME/privategpt/models"                                # PrivateGPT
    "$HOME/anythingllm/models"                               # AnythingLLM
    "$HOME/.cortex/models"                                   # Cortex
    "$HOME/.nitro/models"                                    # Nitro
    "/opt/models"                                            # Generic opt
    "/var/lib/ollama"                                        # Ollama service root
)

# ─── PROHIBITED / FLAGGED MODEL PATTERNS ──────────────────────────────────────
# Chinese-origin models (HIGH RISK per federal guidance)
PROHIBITED_CHINA="deepseek|deepseek-r1|deepseek-v[0-9]|deepseek-coder|deepseek-prover|deepseek-vl|qwen[0-9\-]|qwen2|qwen2\.5|qwq|qvq|qwen-vl|qwen-audio|yi-[0-9]|yi-vl|baichuan[0-9\-]|chatglm|glm-[0-9]|glm4|codegeex|internlm[0-9\-]|internvl|minimax|ernie[0-9\-]|ernie-bot|hunyuan|tigerbot|aquila[0-9\-]|moss\b|belle[0-9\-]|chinese-alpaca|chinese-llama|abacusai.*chinese|megrez|yuan[0-9\-]|skywork|telechat|xuanyuan|seagull-[0-9]|orion-[0-9]|mplug|idefics.*cn|reader-lm|jamba.*cn|phi.*cn|index-[0-9]|aya-cn|c4ai-cn"

# Russian-origin models (HIGH RISK)
PROHIBITED_RUSSIA="rugpt|rugpt3|saiga[0-9\-]|fred-t5|vikhr|rubert|sber-|sberchat|gigachat|ruclip|rudall"

# UAE/Other flagged
PROHIBITED_OTHER="falcon\b|falcon-[0-9]|tiiuae"

# North Korean / Iranian / other state-actor concerns (emerging)
PROHIBITED_EMERGING="polyglot-ko.*dprk|solar.*[Kk][Pp][Rr]"

# Combined prohibited pattern
PROHIBITED_PATTERN="${PROHIBITED_CHINA}|${PROHIBITED_RUSSIA}|${PROHIBITED_OTHER}|${PROHIBITED_EMERGING}"

# ─── SUSPICIOUS MODEL NAMES (warrant review, not auto-prohibited) ─────────────
# Models that need provenance verification before use
REVIEW_PATTERN="hermes[0-9\-]|openhermes|nous-hermes|capybara|dolphin[0-9\-]|airoboros|wizard.*lm|wizardcoder|wizardmath|codebooga|mythomist|mythomax|cinematika|samantha|zephyr.*[0-9]|neural-chat|mistral.*[0-9]|solar-[0-9]|starling|openchat|openorca|orca-[0-9]|speechless|manticore|lazarus|pygmalion|eve-[0-9]|lzlv|goliath|bagel|tulu|tigerbot|alma-[0-9]|bling-[0-9]"
# Note: Hermes (Nous Research, USA) is generally OK but verify; Dolphin is a fine-tune - verify origin

# ─── MCP CONFIG LOCATIONS ─────────────────────────────────────────────────────
declare -a MCP_CONFIG_PATHS_MACOS=(
    "$HOME/Library/Application Support/Claude/claude_desktop_config.json"
    "$HOME/.cursor/mcp.json"
    "$HOME/.continue/config.json"
    "$HOME/Library/Application Support/Code/User/settings.json"
    "$HOME/Library/Application Support/Cursor/User/settings.json"
    "$HOME/Library/Application Support/Windsurf/User/settings.json"
    "$HOME/.cody/config.json"
    "$HOME/.config/aider/config.yml"
    "$HOME/.aider.conf.yml"
    "$HOME/.goose/config.yaml"
    "$HOME/.plandex/config.json"
)

declare -a MCP_CONFIG_PATHS_LINUX=(
    "$HOME/.config/Claude/claude_desktop_config.json"
    "$HOME/.cursor/mcp.json"
    "$HOME/.continue/config.json"
    "$HOME/.config/Code/User/settings.json"
    "$HOME/.config/Cursor/User/settings.json"
    "$HOME/.config/Windsurf/User/settings.json"
    "$HOME/.cody/config.json"
    "$HOME/.config/aider/config.yml"
    "$HOME/.aider.conf.yml"
    "$HOME/.goose/config.yaml"
    "$HOME/.plandex/config.json"
)

# ─── AGENT CONFIG / WORKFLOW FILES ────────────────────────────────────────────
# Files that indicate an agent framework is configured
AGENT_CONFIG_PATTERN=".autogpt|AUTO-GPT|agentops|crewai|crew\.yaml|agents\.yaml|\.autogen|autogen_config|opendevin|\.openhands|openhands\.toml|\.aider|aider\.conf|\.goose|\.plandex|\.mentat|openclaw\.conf|hermes\.yaml|taskweaver|flowise|dify\.yaml|n8n-data|langchain|langgraph|memgpt|mem0\.db|letta\.db"

# ─── VECTOR DATABASE INDICATORS ───────────────────────────────────────────────
VECTORDB_PROCESS_PATTERN="qdrant|chroma\b|chromadb|weaviate|milvus|pinecone-local|pgvector|redis-stack|opensearch"

# ─── SENSITIVE CREDENTIAL PATHS (for MCP scope checks) ───────────────────────
SENSITIVE_PATHS=(".ssh" ".aws" ".gnupg" ".env" "credentials" "id_rsa" "id_ed25519" "id_ecdsa" ".netrc" ".pgpass" "\.kube" "\.azure" "gcloud" "tokens.json" "service-account")
