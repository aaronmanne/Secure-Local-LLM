# Prohibited Models

> 🚨 **WARNING:** Models of Chinese and Russian origin are **HIGH RISK** — flag immediately for security review per federal guidance, FBI advisory, and IC warnings.

These prohibitions are informed by:
- [FBI/CISA Foreign AI Tool Advisory](https://www.fbi.gov/investigate/counterintelligence/the-china-threat)
- [House Select Committee on CCP: DeepSeek Letter (Jan 2025)](https://chinaselectcommittee.house.gov/sites/evo-subsites/selectcommitteeontheccp.house.gov/files/evo-media-document/letter-to-doc-nvidia-deepseek-pla-use_final.pdf)
- [DOJ: U.S. Authorities Shut Down China-Linked AI Tech Smuggling Network (Dec 2025)](https://www.justice.gov/opa/pr/us-authorities-shut-down-major-china-linked-ai-tech-smuggling-network)
- [NIST AI 600-1 §2.5](https://doi.org/10.6028/NIST.AI.600-1)
- [NSA CSI: Deploying AI Systems Securely](https://media.defense.gov/2024/Apr/15/2003439257/-1/-1/0/CSI-DEPLOYING-AI-SYSTEMS-SECURELY.PDF)

---

## Prohibited Model List

| Pattern / Name | Typical Origin | Action |
|---|---|---|
| `deepseek`, `deepseek-r1`, `deepseek-v2`, `deepseek-coder` | DeepSeek AI (China) | 🔴 **PROHIBITED** – Flag/Remove immediately |
| `qwen`, `qwen2`, `qwen2.5`, `qwq` | Alibaba Cloud (China) | 🔴 **PROHIBITED** – Flag/Remove immediately |
| `yi`, `yi-34b`, `yi-6b` | 01.AI (China) | 🔴 **PROHIBITED** – Flag/Remove immediately |
| `baichuan`, `baichuan2` | Baichuan AI (China) | 🔴 **PROHIBITED** – Flag/Remove immediately |
| `chatglm`, `glm-4`, `codegeex` | Zhipu AI / Tsinghua (China) | 🔴 **PROHIBITED** – Flag/Remove immediately |
| `internlm`, `internlm2` | Shanghai AI Lab (China) | 🔴 **PROHIBITED** – Flag/Remove immediately |
| `minimax` | MiniMax (China) | 🔴 **PROHIBITED** – Flag/Remove immediately |
| `ernie`, `ernie-bot` | Baidu (China) | 🔴 **PROHIBITED** – Flag/Remove immediately |
| `hunyuan` | Tencent (China) | 🔴 **PROHIBITED** – Flag/Remove immediately |
| `tigerbot` | TigerBot (China) | 🔴 **PROHIBITED** – Flag/Remove immediately |
| `aquila` | BAAI – Beijing Academy of AI (China) | 🔴 **PROHIBITED** – Flag/Remove immediately |
| `moss` | Fudan University (China) | 🔴 **PROHIBITED** – Flag/Remove immediately |
| `belle` | BELLE Group (China) | 🔴 **PROHIBITED** – Flag/Remove immediately |
| `chinese-alpaca`, `chinese-llama` | Chinese community fine-tunes | 🔴 **PROHIBITED** – Flag/Remove immediately |
| `falcon` (TII, UAE) | Technology Innovation Institute, UAE | 🔴 **PROHIBITED** – Flag/Remove immediately |
| `rugpt`, `rugpt3` | Sber AI (Russia) | 🔴 **PROHIBITED** – Flag/Remove immediately |
| `saiga` | Russian fine-tunes | 🔴 **PROHIBITED** – Flag/Remove immediately |
| `fred-t5` | Sber AI (Russia) | 🔴 **PROHIBITED** – Flag/Remove immediately |

---

## How to Search for Prohibited Models on a System

**Windows PowerShell:**
```powershell
Get-ChildItem -Path "$env:USERPROFILE\.ollama\models" -Recurse -File |
  Where-Object { $_.Name -match "deepseek|qwen|qwq|yi-|baichuan|chatglm|internlm|minimax|ernie|hunyuan|tigerbot|aquila|moss|belle|rugpt|saiga" }
```

**macOS / Linux:**
```bash
find ~/.ollama/models -type f | grep -iE "deepseek|qwen|qwq|yi-[0-9]|baichuan|chatglm|internlm|minimax|ernie|hunyuan|tigerbot|aquila|moss|belle|rugpt|saiga"

find ~/.lmstudio -type f -name "*.gguf" | grep -iE "deepseek|qwen|qwq|yi-[0-9]|baichuan|chatglm|internlm|minimax|ernie|hunyuan|tigerbot|aquila|moss|belle|rugpt|saiga"
```

**Check registered Ollama models:**
```bash
ollama list
```

**Broad search across all model files:**
```bash
sudo find / -type f \( -name "*.gguf" -o -name "*.bin" -o -name "*.safetensors" \) 2>/dev/null \
  | grep -iE "deepseek|qwen|qwq|yi-[0-9]|baichuan|chatglm|internlm|minimax|ernie|hunyuan|tigerbot|aquila|moss|belle|rugpt|saiga"
```

---

## How to Identify Model Origin

- **Model card / Hugging Face:** Check `huggingface.co/[org]/[model]` — look at the organization profile and country of registration.
- **Organization name:** Names like `deepseek-ai`, `qwen`, `baichuan`, `THUDM`, `internlm` are strong indicators of Chinese origin.
- **Ollama manifests / FROM lines:**
  ```bash
  grep -R "FROM\|source\|url" ~/.ollama -n || true
  ```
- **Inspect `.gguf` metadata:**
  ```bash
  gguf-dump metadata path/to/model.gguf
  strings path/to/model.gguf | head -n 200
  ```

**🚩 Red flags:**
- Model card/README primarily in Chinese or Russian
- Organization or repo registered in China, Russia, or UAE
- `FROM` lines pointing to Chinese registries
- Filenames matching prohibited patterns above

---

## Agencies That Have Formally Banned or Restricted DeepSeek and Chinese-Origin AI Models (as of 2025)

- U.S. Navy
- NASA
- U.S. Congress (House and Senate IT systems)
- Pentagon / DoD components
- Multiple U.S. state governments (Texas, Virginia, and others)
- Several allied foreign governments

---

← [Back to Wiki Home](Home)
