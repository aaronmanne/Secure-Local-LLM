# =============================================================================
# common/patterns.ps1
# Single source of truth for all LLM tool, agent, model, and port patterns.
# Dot-sourced by windows/ scripts.  Edit here — changes apply everywhere.
# =============================================================================

# ─── INFERENCE SERVERS / RUNTIMES ─────────────────────────────────────────────
$LLM_ProcessPattern = 'ollama|lmstudio|lm.?studio|localai|local.?ai|gpt4all|llamafile|llama.?cpp|llama.?server|text.?generation.?webui|oobabooga|koboldcpp|koboldai|tabby|tabbyml|vllm|xinference|privategpt|anythingllm|msty|lmdeploy|dalai|serge|librechat|fastchat|fschat|sglang|nitro|cortex|moshi|open.?webui'

$LLM_CLITools = @(
    'ollama', 'localai', 'llamafile', 'llm', 'koboldcpp', 'tabby',
    'vllm', 'xinference', 'privategpt', 'anythingllm', 'dalai',
    'fastchat', 'sglang', 'nitro', 'cortex'
)

# ─── AI AGENT FRAMEWORKS & CODING AGENTS ──────────────────────────────────────
$Agent_ProcessPattern = 'autogpt|auto.?gpt|agentgpt|babyagi|superagi|crewai|autogen|opendevin|openhands|gpt.?engineer|open.?interpreter|aider|goose|plandex|mentat|openclaw|hermes.?agent|devon|sweep|swe.?agent|gptpilot|devika|langchain|langgraph|haystack|flowise|dify|n8n|taskweaver|memgpt|mem0|letta|praison|agno|phidata|activepieces'

$Agent_CLITools = @(
    'aider', 'interpreter', 'goose', 'plandex', 'mentat', 'crewai', 'autogen', 'autogpt'
)

# ─── PORTS TO CHECK ───────────────────────────────────────────────────────────
$LLM_Ports = [ordered]@{
    11434 = 'Ollama'
    1234  = 'LM Studio'
    8080  = 'LocalAI / llama.cpp server'
    8000  = 'vLLM / FastChat / Open Interpreter'
    8001  = 'PrivateGPT'
    7860  = 'text-generation-webui / Gradio'
    5001  = 'KoboldAI / KoboldCPP'
    9997  = 'Xinference'
    3000  = 'AnythingLLM / LibreChat / Open WebUI'
    3001  = 'AnythingLLM / LibreChat'
    4891  = 'GPT4All server'
    5000  = 'LocalAI alt / Tabby'
    5005  = 'Tabby / various'
    6333  = 'Qdrant vector DB'
    6334  = 'Qdrant gRPC'
    8265  = 'Ray dashboard (vLLM cluster)'
    9000  = 'various agent APIs'
    9200  = 'Elasticsearch (RAG backend)'
    19530 = 'Milvus vector DB'
}

$LLM_PortArray = $LLM_Ports.Keys

# ─── MODEL FILE EXTENSIONS ────────────────────────────────────────────────────
$ModelExtensions = @('*.gguf', '*.ggml', '*.safetensors', '*.ot', '*.onnx', '*.llamafile')
# .bin / .pt / .pth omitted from broad searches (too many false positives on Windows)

# ─── MODEL DIRECTORIES ────────────────────────────────────────────────────────
# Note: Ollama stores models as content-addressed blobs (sha256-* files, no extension)
# in the blobs\ subdirectory — NOT as .gguf files. The identify script handles these
# specially via manifest JSON parsing. HuggingFace Hub stores shards + blobs under
# .cache\huggingface\hub\models--<org>--<model>\.
$ModelDirs = @(
    "$env:USERPROFILE\.ollama\models",                        # Ollama (blob store)
    "$env:USERPROFILE\.ollama\models\blobs",                  # Ollama raw blobs
    "$env:USERPROFILE\.lmstudio\models",                      # LM Studio
    "$env:USERPROFILE\.cache\lm-studio\models",               # LM Studio cache
    "$env:APPDATA\LM Studio",                                 # LM Studio AppData
    "$env:LOCALAPPDATA\nomic.ai\GPT4All",                     # GPT4All
    "$env:USERPROFILE\jan\models",                            # Jan
    "$env:USERPROFILE\.localai\models",                       # LocalAI
    "$env:USERPROFILE\.tabby\models",                         # Tabby
    "$env:USERPROFILE\.cache\koboldcpp",                      # KoboldCPP
    "$env:USERPROFILE\text-generation-webui\models",          # text-gen-webui
    "$env:USERPROFILE\.cache\xinference\models",              # Xinference
    "$env:USERPROFILE\.cache\huggingface\hub",                # HuggingFace Hub (shards + blobs)
    "$env:LOCALAPPDATA\Programs\Msty",                        # Msty
    "$env:USERPROFILE\privategpt\models",                     # PrivateGPT
    "$env:USERPROFILE\anythingllm\models",                    # AnythingLLM
    "$env:USERPROFILE\.cortex\models",                        # Cortex
    "$env:USERPROFILE\.nitro\models",                         # Nitro
    "$env:APPDATA\Jan"                                        # Jan AppData
)

# ─── INSTALLED APP PATHS ──────────────────────────────────────────────────────
$AppPaths = @(
    "$env:LOCALAPPDATA\Programs\Ollama",
    "$env:LOCALAPPDATA\Programs\LM-Studio",
    "$env:LOCALAPPDATA\Programs\LM Studio",
    "$env:LOCALAPPDATA\Jan",
    "$env:LOCALAPPDATA\Programs\Msty",
    "$env:LOCALAPPDATA\Programs\AnythingLLM",
    "$env:LOCALAPPDATA\Programs\Tabby",
    "$env:LOCALAPPDATA\Programs\Cursor",
    "$env:LOCALAPPDATA\Programs\Windsurf",
    "$env:PROGRAMFILES\Ollama",
    "$env:PROGRAMFILES\LM Studio",
    "$env:PROGRAMFILES\text-generation-webui",
    "$env:USERPROFILE\text-generation-webui",
    "$env:USERPROFILE\koboldcpp",
    "$env:USERPROFILE\KoboldAI",
    "$env:USERPROFILE\SillyTavern",
    "$env:USERPROFILE\oobabooga_windows",
    "$env:USERPROFILE\privategpt",
    "$env:USERPROFILE\anythingllm",
    "$env:USERPROFILE\AutoGPT",
    "$env:USERPROFILE\auto-gpt",
    "$env:USERPROFILE\crewai",
    "$env:USERPROFILE\opendevin",
    "$env:USERPROFILE\OpenHands"
)

# ─── PROHIBITED / FLAGGED MODEL PATTERNS ──────────────────────────────────────
# Chinese-origin — HIGH RISK per federal guidance
$ProhibitedChina = 'deepseek|deepseek-r1|deepseek-v\d|deepseek-coder|deepseek-prover|deepseek-vl|qwen[\d\-]|qwen2|qwen2\.5|qwq|qvq|qwen-vl|qwen-audio|yi-\d|yi-vl|baichuan[\d\-]|chatglm|glm-\d|glm4|codegeex|internlm[\d\-]|internvl|minimax|ernie[\d\-]|ernie-bot|hunyuan|tigerbot|aquila[\d\-]|moss\b|belle[\d\-]|chinese-alpaca|chinese-llama|megrez|yuan[\d\-]|skywork|telechat|xuanyuan|orion-\d|index-\d|reader-lm'
# Russian-origin — HIGH RISK
$ProhibitedRussia = 'rugpt|rugpt3|saiga[\d\-]|fred-t5|vikhr|sber-|sberchat|gigachat|rudall'
# UAE / Other flagged
$ProhibitedOther  = 'falcon\b|falcon-\d|tiiuae'

$ProhibitedPattern = "$ProhibitedChina|$ProhibitedRussia|$ProhibitedOther"

# ─── REVIEW-WARRANTED MODELS (verify provenance before use) ───────────────────
$ReviewPattern = 'hermes[\d\-]|openhermes|nous-hermes|capybara|dolphin[\d\-]|airoboros|wizard.*lm|wizardcoder|neural-chat|openchat|openorca|orca-\d|zephyr.*\d|solar-\d|starling|speechless|manticore|pygmalion'

# ─── MCP CONFIG LOCATIONS ─────────────────────────────────────────────────────
$McpConfigPaths = @(
    "$env:APPDATA\Claude\claude_desktop_config.json",
    "$env:USERPROFILE\.cursor\mcp.json",
    "$env:USERPROFILE\.continue\config.json",
    "$env:APPDATA\Code\User\settings.json",
    "$env:APPDATA\Cursor\User\settings.json",
    "$env:APPDATA\Windsurf\User\settings.json",
    "$env:USERPROFILE\.cody\config.json",
    "$env:USERPROFILE\.aider.conf.yml",
    "$env:USERPROFILE\.goose\config.yaml",
    "$env:USERPROFILE\.plandex\config.json"
)

# ─── SENSITIVE CREDENTIAL PATHS ───────────────────────────────────────────────
$SensitivePaths = @('.ssh', '.aws', '.gnupg', '.env', 'credentials', 'id_rsa', 'id_ed25519', '.kube', '.azure', 'gcloud', 'tokens.json', 'service-account')

# ─── VECTOR DATABASE INDICATORS ───────────────────────────────────────────────
$VectorDBPattern = 'qdrant|chroma|chromadb|weaviate|milvus|pgvector|redis-stack|opensearch'
