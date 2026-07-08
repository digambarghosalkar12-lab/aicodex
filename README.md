# AI Codex Local

AI Codex Local is a local coding assistant workflow for macOS. It combines Ollama, Open WebUI, Aider, a smart local router, project memory, and safe tooling so you can work on code projects in a Codex-like way without sending your repo to a cloud model.

## What changed in v3.1

This version is optimized for performance.

Older versions tried to use several heavy models at once:

```text
qwen3:30b
qwen3-coder:30b
deepseek-r1:32b
```

That caused high RAM/CPU usage and Open WebUI timeouts on local machines.

v3.1 changes the design:

```text
One main coding-agent model
One fast fallback model
One vision model
One embedding model
```

## Recommended model setup

### Fast mode

Best for low RAM/CPU and stable GUI use.

```text
qwen2.5-coder:14b
```

### Balanced mode

Best daily Codex-like mode.

```text
hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q2_K_XL
```

### Full mode

Best quality, but heavier.

```text
hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q4_K_M
```

### Vision model

Used only when an image or screenshot is attached.

```text
qwen2.5vl:7b
```

### Embedding model

Used for local memory/RAG-style workflows.

```text
nomic-embed-text
```

## Why Qwen3-Coder-Next?

Qwen3-Coder-Next is designed for coding agents and local development. It is an 80B total parameter MoE model with only 3B active parameters during inference, which makes it more efficient than running normal dense 30B/32B models for every task.

It is better aligned with this project because AI Codex needs:

- repo understanding
- code generation
- command/tool workflows
- recovery from execution failures
- long-context project work

## Main architecture

```text
User
 ↓
Open WebUI smart-auto
 ↓
AI Codex Router
 ↓
Ollama local models
```

For actual file editing:

```text
User
 ↓
aicodex aider
 ↓
Aider reads/edits repo
 ↓
Git diff / review
```

## Install

```bash
chmod +x ~/Downloads/aicodex-install-brew-v3.1-qwen-next.sh
~/Downloads/aicodex-install-brew-v3.1-qwen-next.sh
source ~/.zshrc
```

## First run

Start in fast mode first:

```bash
aicodex mode fast
aicodex pull-models fast
aicodex run
```

After everything is stable, use balanced mode:

```bash
aicodex kill
aicodex mode balanced
aicodex pull-models balanced
aicodex run
```

Use full mode only when you need highest local quality:

```bash
aicodex kill
aicodex mode full
aicodex pull-models full
aicodex run
```

## Commands

```bash
aicodex run
aicodex gui
aicodex project
aicodex context
aicodex analyze
aicodex aider
aicodex kill
aicodex status
aicodex tune
aicodex models
aicodex mode fast
aicodex mode balanced
aicodex mode full
aicodex pull-models fast
aicodex pull-models balanced
aicodex pull-models full
```

## Which command should I use?

Use Open WebUI for:

```text
planning
explanation
documentation
reviewing generated project context
quick Q&A
```

Use Aider for:

```text
reading files
editing files
showing diffs
working like Codex on a repo
```

The most important command for Codex-like repo editing is:

```bash
aicodex aider
```

## Project understanding

When you select a project, AI Codex generates:

```text
.ai-memory/project-context.md
.ai-memory/project-tree.md
.ai-memory/how-to-use-project-context.md
```

Regenerate anytime:

```bash
aicodex context
```

The router loads this project snapshot so Open WebUI can understand the selected project. For live edits, use Aider.

## Performance tuning

If Open WebUI freezes or times out:

```bash
aicodex kill
aicodex mode fast
aicodex run
```

Check mode:

```bash
aicodex status
```

See recommendation:

```bash
aicodex tune
```

## Troubleshooting

### smart-auto not visible

Check router:

```bash
curl http://127.0.0.1:5050/v1/models
```

Expected:

```json
{"object":"list","data":[{"id":"smart-auto","object":"model"}]}
```

Restart:

```bash
aicodex kill
aicodex run
```

### Port 5050 already in use

```bash
lsof -tiTCP:5050 -sTCP:LISTEN | xargs kill -9 2>/dev/null
```

Or:

```bash
aicodex kill
```

### Port 8080 already in use

```bash
lsof -tiTCP:8080 -sTCP:LISTEN | xargs kill -9 2>/dev/null
```

### Aider warning: OLLAMA_API_BASE not set

v3.1 sets this automatically. For current terminal:

```bash
export OLLAMA_API_BASE=http://127.0.0.1:11434
export OLLAMA_HOST=http://127.0.0.1:11434
aicodex aider
```

### High RAM or CPU

Use fast mode:

```bash
aicodex kill
aicodex mode fast
aicodex run
```

Avoid running multiple heavy models at the same time.

### Project changed but AI gives old answer

Regenerate context:

```bash
aicodex context
```

### Aider is not editing files

Run:

```bash
aicodex project
aicodex context
aicodex aider
```

Make sure you are inside a Git repo or allow AI Codex to initialize one.

## Recommended daily workflow

```bash
aicodex mode balanced
aicodex run
```

For repo changes:

```bash
aicodex aider
```

For cleanup:

```bash
aicodex kill
```

## Notes

- Open WebUI chat is not the file editor.
- Aider is the file-editing agent.
- smart-auto is the model router.
- Qwen3-Coder-Next is the main optimized coding model.
- Fast mode is safest when testing.
- Balanced mode is the best daily mode.
- Full mode is heavy.
