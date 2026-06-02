# Model File Types

Understanding model file formats helps IT staff identify and audit LLM models on systems.

---

## File Type Reference

| Extension | Description | Notes |
|---|---|---|
| `.gguf` | Most common modern single-file format; includes metadata | Used by Ollama, LM Studio, llama.cpp, KoboldCPP, LlamaFile |
| `.bin` | Older binary weight files | Common generic extension — hard to isolate without inspecting content; also used by PyTorch |
| `.safetensors` | Hugging Face-compatible safe tensor format | Safer than `.pkl` — does not allow arbitrary code execution on load |
| `.ggml` | Older GGML formats | Superseded by `.gguf`; may still appear in older installations |
| `.pt` / `.pth` | PyTorch weight files | Can execute arbitrary code on load — treat as untrusted |
| `.q4_0`, `.q4_k_m`, `.q8_0` | Quantized version suffixes | Appear as part of filenames, not standalone extensions (e.g., `llama-3-8b.q4_k_m.gguf`) |
| `.pkl` / `.pickle` | Pickle serialization format | **HIGH RISK** — arbitrary code execution on load; should never be used for model weights |
| `.npz` | NumPy archive | Used by some older models; generally lower risk than pickle |
| `.h5` / `.hdf5` | Keras/TensorFlow format | Less common in local LLM contexts |

---

## Key Security Considerations

- **`.gguf`** files are the safest single-file format because they include metadata (model name, architecture, tokenizer) that can be inspected with `gguf-dump` or `strings` to verify origin.
- **`.pt` / `.pth` / `.pkl`** files can execute arbitrary Python code when loaded — never load these from untrusted sources.
- **`.safetensors`** was designed specifically to prevent arbitrary code execution on load and is preferred over `.pt` for sharing weights.
- Quantization suffixes (`.q4_k_m`, `.q8_0`, etc.) indicate the compression level and do not affect security classification — the underlying model origin still governs whether it is approved.

---

## How to Inspect `.gguf` Metadata

```bash
# Install gguf-tools (if available)
pip install gguf

# Dump metadata
gguf-dump metadata path/to/model.gguf

# Quick check with strings
strings path/to/model.gguf | head -n 200
```

Look for:
- `general.name` — the model's declared name
- `general.organization` — the originating organization
- `tokenizer.ggml.model` — tokenizer type
- Any Chinese, Russian, or other foreign-language strings in the first 200 lines may indicate prohibited origin

---

← [Back to Wiki Home](Home)
