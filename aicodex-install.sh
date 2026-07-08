#!/bin/zsh
# ==============================================================================
# aicodex-install-brew.sh
# AI Codex Level 1 - Brew-first installer/repair
#
# This version avoids manual Python/Node downloads.
# It uses user-writable Homebrew for Python, Node, uv, Git, ffmpeg, shellcheck,
# Ollama, and VS Code, while keeping all aicodex tool files inside:
#   ~/.aicodex-level1
#
# No sudo is used by this script.
# ==============================================================================

set -e

AICODEX_HOME="$HOME/.aicodex-level1"
AICODEX_BIN="$AICODEX_HOME/bin"
AICODEX_APP="$AICODEX_HOME/app"
AICODEX_ROUTER="$AICODEX_HOME/router"
AICODEX_MCP="$AICODEX_HOME/mcp"
AICODEX_CONFIG="$AICODEX_HOME/config"
AICODEX_LOGS="$AICODEX_HOME/logs"
AICODEX_STATE="$AICODEX_HOME/state"
AICODEX_ARCHIVES="$AICODEX_HOME/archives"
AICODEX_PROJECTS="$AICODEX_HOME/projects"
AICODEX_DOWNLOADS="$AICODEX_HOME/downloads"
AICODEX_VENVS="$AICODEX_HOME/venvs"
AICODEX_NPM="$AICODEX_HOME/npm-global"
USER_BIN="$HOME/.local/bin"

BREW_PYTHON_BIN=""
BREW_NODE_BIN=""
BREW_NPM_BIN=""
BREW_UV_BIN=""

say() {
  echo ""
  echo "==> $1"
}

warn() {
  echo "⚠ $1"
}

die() {
  echo "ERROR: $1"
  exit 1
}

prompt() {
  local message="$1"
  local result

  # Print prompt directly to terminal, not stdout.
  # This keeps command substitution clean:
  # choice="$(prompt "Select option: ")" captures only "1", not "Select option: 1".
  printf "%s" "$message" >/dev/tty
  IFS= read -r result </dev/tty

  echo "$result"
}

write_file() {
  local path="$1"
  mkdir -p "$(dirname "$path")"
  cat > "$path"
}

create_dirs() {
  say "Creating/repairing user-owned AI Codex directory"

  mkdir -p \
    "$AICODEX_BIN" \
    "$AICODEX_APP" \
    "$AICODEX_ROUTER" \
    "$AICODEX_MCP" \
    "$AICODEX_CONFIG" \
    "$AICODEX_LOGS" \
    "$AICODEX_STATE" \
    "$AICODEX_ARCHIVES" \
    "$AICODEX_PROJECTS" \
    "$AICODEX_DOWNLOADS" \
    "$AICODEX_VENVS" \
    "$AICODEX_NPM" \
    "$USER_BIN"

  [ -f "$AICODEX_STATE/performance_mode" ] || echo "fast" > "$AICODEX_STATE/performance_mode"

  chmod -R u+rwX "$AICODEX_HOME" 2>/dev/null || true
}

setup_shell_path() {
  say "Configuring shell PATH"

  local path_line='export AICODEX_HOME="$HOME/.aicodex-level1"; export PATH="$AICODEX_HOME/bin:$AICODEX_HOME/npm-global/bin:$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"'

  if [ ! -f "$HOME/.zshrc" ]; then
    touch "$HOME/.zshrc"
  fi

  if ! grep -q "AICODEX_HOME" "$HOME/.zshrc"; then
    {
      echo ""
      echo "# AI Codex Level 1"
      echo "$path_line"
    } >> "$HOME/.zshrc"
  fi

  export AICODEX_HOME="$AICODEX_HOME"
  export PATH="$AICODEX_BIN:$AICODEX_NPM/bin:$USER_BIN:/opt/homebrew/bin:/usr/local/bin:$PATH"
  export NPM_CONFIG_PREFIX="$AICODEX_NPM"
}

check_brew_exists() {
  if command -v brew >/dev/null 2>&1; then
    return 0
  fi

  echo ""
  echo "Homebrew is not installed."
  echo ""
  echo "Options:"
  echo "1) Try installing Homebrew"
  echo "2) Exit"
  local choice
  choice="$(prompt "Enter option number: ")"

  if [ "$choice" = "1" ]; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || true
    eval "$(/usr/local/bin/brew shellenv)" 2>/dev/null || true
  else
    die "Homebrew is required for this Brew-first installer."
  fi

  command -v brew >/dev/null 2>&1 || die "Homebrew install failed or not in PATH."
}

check_brew_writable() {
  local prefix
  prefix="$(brew --prefix 2>/dev/null || true)"

  if [ -z "$prefix" ]; then
    die "Could not detect Homebrew prefix."
  fi

  if [ -w "$prefix" ]; then
    echo "✓ Homebrew writable: $prefix"
    return 0
  fi

  echo ""
  echo "Homebrew exists but current user cannot write to:"
  echo "$prefix"
  echo ""
  echo "Ask admin to run once:"
  echo "sudo chown -R $USER:admin \"$prefix\""
  echo "chmod -R u+w \"$prefix\""
  echo ""
  die "Homebrew is not writable by current user."
}

install_brew_tools() {
  say "Installing/repairing required tools using Brew"

  check_brew_exists
  check_brew_writable

  brew update || true

  brew install git || true
  brew install python@3.12 || true
  brew install node || true
  brew install uv || true
  brew install ffmpeg || true
  brew install shellcheck || true

  mkdir -p "$HOME/Applications"

  echo ""
  echo "Install/repair GUI apps using Brew cask?"
  echo "1) Yes, install Ollama and VS Code into ~/Applications"
  echo "2) Skip GUI casks"
  local cask_choice
  cask_choice="$(prompt "Enter option number: ")"

  if [ "$cask_choice" = "1" ]; then
    brew install --cask --appdir="$HOME/Applications" ollama || true
    brew install --cask --appdir="$HOME/Applications" visual-studio-code || true
  fi

  BREW_PYTHON_BIN="$(brew --prefix python@3.12)/bin/python3.12"
  BREW_NODE_BIN="$(brew --prefix node)/bin/node"
  BREW_NPM_BIN="$(brew --prefix node)/bin/npm"
  BREW_UV_BIN="$(brew --prefix uv)/bin/uv"

  [ -x "$BREW_PYTHON_BIN" ] || BREW_PYTHON_BIN="$(command -v python3)"
  [ -x "$BREW_NODE_BIN" ] || BREW_NODE_BIN="$(command -v node)"
  [ -x "$BREW_NPM_BIN" ] || BREW_NPM_BIN="$(command -v npm)"
  [ -x "$BREW_UV_BIN" ] || BREW_UV_BIN="$(command -v uv)"

  [ -x "$BREW_PYTHON_BIN" ] || die "Python was not installed correctly."
  [ -x "$BREW_NODE_BIN" ] || die "Node was not installed correctly."
  [ -x "$BREW_NPM_BIN" ] || die "npm was not installed correctly."
  [ -x "$BREW_UV_BIN" ] || die "uv was not installed correctly."

  echo "$BREW_PYTHON_BIN" > "$AICODEX_STATE/tool_python"
  echo "$BREW_NODE_BIN" > "$AICODEX_STATE/tool_node"
  echo "$BREW_NPM_BIN" > "$AICODEX_STATE/tool_npm"
  echo "$BREW_UV_BIN" > "$AICODEX_STATE/tool_uv"

  "$BREW_PYTHON_BIN" --version
  "$BREW_NODE_BIN" --version
  "$BREW_NPM_BIN" --version
  "$BREW_UV_BIN" --version

  "$BREW_NPM_BIN" config set prefix "$AICODEX_NPM"
}

write_default_configs() {
  say "Writing/repairing default configs"

  write_file "$AICODEX_CONFIG/default-aider.conf.yml" <<'EOF'
# Optimized for local Codex-like coding on Apple Silicon.
# Use one main coding-agent model instead of loading several 30B/32B models.
model: ollama_chat/hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q2_K_XL
editor-model: ollama_chat/hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q2_K_XL
architect: false

auto-commits: false
dirty-commits: false
show-diffs: true
show-model-warnings: false

map-tokens: 4096
max-chat-history-tokens: 8192

read:
  - CONVENTIONS.md
  - .ai-memory/project-memory.md
  - .ai-memory/project-analysis.md
  - .ai-memory/project-context.md
  - .ai-memory/decisions.md
  - .ai-memory/commands.md

auto-accept-architect: false
EOF

  write_file "$AICODEX_CONFIG/default-conventions.md" <<'EOF'
# AI Coding Rules

## Working Style
- Understand project structure before editing.
- Do not modify unrelated files.
- Prefer small focused changes.
- Explain the plan before major changes.
- Show diff after changes.
- Do not auto-commit unless explicitly asked.

## Security
- Do not hardcode secrets, passwords, tokens, API keys, private keys, or client secrets.
- Do not print secrets in logs.
- Do not delete files unless explicitly asked.
- Avoid destructive commands.

## Code Quality
- Keep code simple and readable.
- Add error handling for risky operations.
- Avoid unnecessary dependencies.
- Prefer maintainable code over clever code.

## macOS / Shell
- Prefer zsh/bash compatible scripts.
- Use variables at the top.
- Add logging functions.
- Use proper exit codes.
- Validate required commands before use.
- Avoid jq unless explicitly approved.
- Prefer plutil, xmllint, python3, or native shell where practical.

## API Scripts
- Prefer OAuth/client credentials.
- Never use basic auth unless explicitly requested.
- Keep secrets in environment variables or external config.
- Add retry and error handling.

## Testing
- Run available tests or explain manual test steps.
- If tests fail, explain root cause before fixing.
EOF

  write_file "$AICODEX_CONFIG/default-gitignore" <<'EOF'
# AI Codex local memory
.ai-memory/session-history.md

# Secrets
.env
.env.*
*.pem
*.key
*.p12
*.mobileconfig
id_rsa
id_ed25519
*.secret
secrets.*
credentials.*
token.*
private_key.*
client_secret.*

# Local tooling
node_modules/
.venv/
venv/
__pycache__/
EOF

  write_file "$AICODEX_CONFIG/openwebui-requirements.txt" <<'EOF'
open-webui
EOF

  write_file "$AICODEX_CONFIG/aider-requirements.txt" <<'EOF'
aider-chat
EOF
}

write_router() {
  say "Writing/repairing smart router"

  write_file "$AICODEX_ROUTER/requirements.txt" <<'EOF'
fastapi
uvicorn
requests
EOF

  write_file "$AICODEX_ROUTER/router.py" <<'PYEOF'
from fastapi import FastAPI, Request
from pathlib import Path
import requests
import json
import re

OLLAMA_URL = "http://127.0.0.1:11434"
CONTROLLER_MODEL = "qwen2.5-coder:14b"

AICODEX_HOME = Path.home() / ".aicodex-level1"
LAST_PROJECT_FILE = AICODEX_HOME / "state" / "last_project"
PERFORMANCE_MODE_FILE = AICODEX_HOME / "state" / "performance_mode"

# Context is powerful but expensive. Keep it smaller by default.
MAX_PROJECT_CONTEXT_CHARS_BY_MODE = {
    "fast": 35000,
    "balanced": 70000,
    "full": 120000,
}

FAST_CODER_MODEL = "qwen2.5-coder:14b"
BALANCED_CODER_MODEL = "hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q2_K_XL"
FULL_CODER_MODEL = "hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q4_K_M"
VISION_MODEL = "qwen2.5vl:7b"
EMBED_MODEL = "nomic-embed-text"

ALLOWED_TARGETS = {
    FAST_CODER_MODEL,
    BALANCED_CODER_MODEL,
    FULL_CODER_MODEL,
    VISION_MODEL,
}

FAILOVER_MAP = {
    FULL_CODER_MODEL: [BALANCED_CODER_MODEL, FAST_CODER_MODEL],
    BALANCED_CODER_MODEL: [FAST_CODER_MODEL],
    FAST_CODER_MODEL: [BALANCED_CODER_MODEL],
    VISION_MODEL: [FAST_CODER_MODEL],
}

app = FastAPI(title="AI Codex Smart Local Router")


def get_performance_mode():
    try:
        if PERFORMANCE_MODE_FILE.exists():
            mode = PERFORMANCE_MODE_FILE.read_text().strip().lower()
            if mode in {"fast", "balanced", "full"}:
                return mode
    except Exception:
        pass
    return "fast"


def max_project_context_chars():
    return MAX_PROJECT_CONTEXT_CHARS_BY_MODE.get(get_performance_mode(), 35000)


def model_profile():
    """
    fast     = lowest RAM/CPU, uses qwen2.5-coder:14b
    balanced = optimized local Codex-like mode, uses Qwen3-Coder-Next Q2
    full     = best local quality, uses Qwen3-Coder-Next Q4
    """
    mode = get_performance_mode()

    if mode == "full":
        return {
            "general": FULL_CODER_MODEL,
            "code": FULL_CODER_MODEL,
            "architect": FULL_CODER_MODEL,
            "vision": VISION_MODEL,
            "quick": FAST_CODER_MODEL,
        }

    if mode == "balanced":
        return {
            "general": BALANCED_CODER_MODEL,
            "code": BALANCED_CODER_MODEL,
            "architect": BALANCED_CODER_MODEL,
            "vision": VISION_MODEL,
            "quick": FAST_CODER_MODEL,
        }

    return {
        "general": FAST_CODER_MODEL,
        "code": FAST_CODER_MODEL,
        "architect": FAST_CODER_MODEL,
        "vision": VISION_MODEL,
        "quick": FAST_CODER_MODEL,
    }


def get_last_project_dir():
    try:
        if LAST_PROJECT_FILE.exists():
            project = Path(LAST_PROJECT_FILE.read_text().strip()).expanduser()
            if project.exists() and project.is_dir():
                return project
    except Exception:
        return None
    return None


def load_project_context():
    """
    Load generated project context so Open WebUI smart-auto can answer about
    the selected project without the user pasting files manually.

    This is read-only context. Real file editing still belongs to Aider.
    """
    project = get_last_project_dir()
    if not project:
        return None, ""

    context_file = project / ".ai-memory" / "project-context.md"
    tree_file = project / ".ai-memory" / "project-tree.md"

    parts = []
    if context_file.exists():
        try:
            parts.append(context_file.read_text(errors="ignore"))
        except Exception:
            pass
    elif tree_file.exists():
        try:
            parts.append(tree_file.read_text(errors="ignore"))
        except Exception:
            pass

    context = "\n\n".join(parts).strip()
    max_chars = max_project_context_chars()
    if len(context) > max_chars:
        context = context[:max_chars] + "\n\n[Project context truncated for performance mode. Run `aicodex mode full` for larger context or ask about a specific file.]"

    return str(project), context


def inject_project_context(messages):
    project_dir, context = load_project_context()
    if not context:
        return messages

    system_context = f"""You are AI Codex running locally.

You have read-only access to a generated snapshot of the selected project folder.

Selected project:
{project_dir}

Use this project snapshot to answer questions about files, folder structure, code, HTML/CSS/JS, scripts, README, and project behavior.

Important limits:
- You can understand and discuss the generated snapshot.
- You cannot see the live browser screen unless the user uploads a screenshot.
- You cannot directly edit files from Open WebUI chat.
- For real file edits, tell the user to run: aicodex aider
- If the snapshot may be outdated, tell the user to run: aicodex context

Project snapshot:
{context}
"""

    return [{"role": "system", "content": system_context}] + messages


def _image_url_to_base64(value):
    """
    Accept OpenAI/Open WebUI image_url values and return raw base64 for Ollama.
    Supports:
    - {"url": "data:image/png;base64,...."}
    - "data:image/png;base64,...."
    Remote http(s) image URLs are intentionally ignored for local/offline safety.
    """
    if isinstance(value, dict):
        value = value.get("url", "")
    if not isinstance(value, str):
        return None
    if value.startswith("data:image") and "base64," in value:
        return value.split("base64,", 1)[1]
    return None


def normalize_messages_for_ollama(messages, vision=False):
    """
    Open WebUI/OpenAI messages can contain content as a list:
      [{"type":"text","text":"..."}, {"type":"image_url","image_url": {...}}]

    Ollama /api/chat expects:
      {"role":"user","content":"text","images":["base64..."]}

    Without this conversion Ollama returns:
      400 Client Error: Bad Request for /api/chat
    """
    normalized = []

    for msg in messages:
        role = msg.get("role", "user")
        if role not in {"system", "user", "assistant", "tool"}:
            role = "user"

        content = msg.get("content", "")
        text_parts = []
        images = []

        if isinstance(content, list):
            for item in content:
                if not isinstance(item, dict):
                    continue

                item_type = item.get("type")
                if item_type == "text":
                    text_parts.append(str(item.get("text", "")))

                elif item_type == "image_url":
                    image_b64 = _image_url_to_base64(item.get("image_url"))
                    if image_b64:
                        images.append(image_b64)

                elif item_type == "image":
                    image_b64 = _image_url_to_base64(item.get("image_url") or item.get("source") or item.get("data"))
                    if image_b64:
                        images.append(image_b64)

                else:
                    # Keep unknown content as readable text instead of passing invalid JSON to Ollama.
                    if "text" in item:
                        text_parts.append(str(item.get("text", "")))
        else:
            text_parts.append(str(content or ""))

        new_msg = {
            "role": role,
            "content": "\n".join(part for part in text_parts if part).strip(),
        }

        if vision and images:
            new_msg["images"] = images

        # Ollama can reject completely empty messages.
        if new_msg["content"] or new_msg.get("images"):
            normalized.append(new_msg)

    return normalized or [{"role": "user", "content": ""}]


def has_image_payload(messages):
    """
    Detect image attachments before asking the controller.
    This avoids the controller accidentally selecting a text-only model.
    """
    for msg in messages:
        content = msg.get("content", "")
        if isinstance(content, list):
            for item in content:
                if not isinstance(item, dict):
                    continue
                item_type = item.get("type", "")
                if item_type in {"image_url", "image"}:
                    return True
                if item.get("image_url") or item.get("source") or item.get("data"):
                    return True
    return False


def messages_to_text(messages):
    output = []
    for msg in messages:
        role = msg.get("role", "user")
        content = msg.get("content", "")
        text_parts = []
        image_found = False

        if isinstance(content, list):
            for item in content:
                if not isinstance(item, dict):
                    continue
                if item.get("type") == "text":
                    text_parts.append(str(item.get("text", "")))
                elif item.get("type") in {"image_url", "image"} or item.get("image_url") or item.get("source") or item.get("data"):
                    image_found = True
        else:
            text_parts.append(str(content or ""))

        image_note = " [image attached]" if image_found else ""
        output.append(f"{role.upper()}: {' '.join(text_parts).strip()}{image_note}")

    return "\n\n".join(output)


def extract_json(text):
    try:
        return json.loads(text)
    except Exception:
        pass
    match = re.search(r"\{.*\}", text, re.DOTALL)
    if match:
        try:
            return json.loads(match.group(0))
        except Exception:
            pass
    return None


def installed_models():
    try:
        response = requests.get(f"{OLLAMA_URL}/api/tags", timeout=10)
        response.raise_for_status()
        return {m["name"] for m in response.json().get("models", [])}
    except Exception:
        return set()


def call_ollama(model, messages, temperature=0.2, timeout=420, use_project_context=True):
    is_vision = (model == VISION_MODEL)

    if use_project_context:
        messages = inject_project_context(messages)

    ollama_messages = normalize_messages_for_ollama(messages, vision=is_vision)

    payload = {
        "model": model,
        "messages": ollama_messages,
        "stream": False,
        "options": {"temperature": temperature},
    }

    response = requests.post(
        f"{OLLAMA_URL}/api/chat",
        json=payload,
        timeout=timeout,
    )

    if response.status_code >= 400:
        detail = response.text[:800]
        raise RuntimeError(f"{response.status_code} from Ollama /api/chat: {detail}")

    return response.json().get("message", {}).get("content", "")


def ask_controller(user_text):
    prompt = f"""
You are a local AI model router.

Decide whether to answer by yourself or forward to a specialist model.

Available models:
- qwen2.5-coder:14b = fast local coding/general fallback; lowest RAM/CPU
- hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q2_K_XL = balanced Codex-like coding agent; repo understanding, scripts, docs, web projects
- hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q4_K_M = full quality Codex-like coding agent; heavier RAM/CPU
- qwen2.5vl:7b = image, screenshot, OCR, diagram, UI error, video frame

Return ONLY valid JSON:
{{
  "action": "answer_self" or "forward",
  "target": "model-name",
  "reason": "short reason"
}}

Rules:
- For code/script/repo/project tasks, prefer the current mode code model from model_profile().
- For planning/review/architecture, prefer the current mode architect model from model_profile().
- For image/screenshot/video frame or messages with attached images, prefer qwen2.5vl:7b.
- For small code snippets, use the fast model.
- For normal explanation, use the current mode general model from model_profile().
- For questions about selected project files, website source code, folder structure, HTML/CSS/JS, or README, prefer qwen3-coder:30b.
- Do not invent model names.

User request:
{user_text}
"""
    try:
        content = call_ollama(
            CONTROLLER_MODEL,
            [{"role": "user", "content": prompt}],
            temperature=0,
            timeout=180,
            use_project_context=False,
        )
        decision = extract_json(content)
        if not decision:
            raise ValueError("Controller did not return valid JSON")
        target = decision.get("target", model_profile()["general"])
        if target not in ALLOWED_TARGETS:
            target = model_profile()["general"]

        # Performance-mode remap. This prevents the GUI from loading heavy models
        # unless the user has explicitly selected full mode.
        profile = model_profile()
        if target in {"deepseek-r1:32b"}:
            target = profile["architect"]
        elif target in {"qwen3-coder:30b", BALANCED_CODER_MODEL, FULL_CODER_MODEL}:
            target = profile["code"]
        elif target in {"qwen3:30b", FAST_CODER_MODEL}:
            target = profile["general"]

        return {"target": target, "reason": decision.get("reason", "No reason provided") + f" | mode={get_performance_mode()}"}
    except Exception as error:
        return {"target": model_profile()["general"], "reason": f"Controller failed, using general model in {get_performance_mode()} mode: {error}"}


def failover_chain(primary):
    available = installed_models()
    chain = [primary] + FAILOVER_MAP.get(primary, [])
    filtered = [model for model in chain if model in available]
    return filtered or ["qwen3:30b"]


@app.get("/health")
def health():
    return {"status": "ok", "controller": CONTROLLER_MODEL, "ollama": OLLAMA_URL, "performance_mode": get_performance_mode()}


@app.get("/project")
def project():
    project_dir, context = load_project_context()
    return {
        "project": project_dir,
        "context_loaded": bool(context),
        "context_chars": len(context or ""),
        "performance_mode": get_performance_mode(),
        "max_project_context_chars": max_project_context_chars(),
        "model_profile": model_profile(),
    }


@app.get("/v1/models")
def models():
    # Expose only smart-auto to GUI users.
    # Internal specialist models are selected by the router, not manually by users.
    return {
        "object": "list",
        "data": [
            {
                "id": "smart-auto",
                "object": "model"
            }
        ],
    }


@app.post("/v1/chat/completions")
async def chat_completions(request: Request):
    body = await request.json()
    messages = body.get("messages", [])
    requested_model = body.get("model", "smart-auto")
    temperature = body.get("temperature", 0.2)

    if requested_model == "smart-auto":
        # Hard rule: if any image is attached, do not ask a text-only controller to decide.
        # Send directly to the vision model.
        if has_image_payload(messages):
            primary = model_profile()["vision"]
            reason = f"Image attachment detected; using vision model | mode={get_performance_mode()}"
        else:
            decision = ask_controller(messages_to_text(messages))
            primary = decision["target"]
            reason = decision["reason"]
    else:
        primary = requested_model
        reason = "Manual model selected"

    if primary not in ALLOWED_TARGETS:
        primary = model_profile()["general"]

    chain = failover_chain(primary)
    errors = []
    selected_model = None
    answer = None

    for model in chain:
        try:
            answer = call_ollama(model, messages, temperature=temperature)
            selected_model = model
            break
        except Exception as error:
            errors.append(f"{model}: {error}")

    if answer is None:
        return {
            "id": "aicodex-router",
            "object": "chat.completion",
            "model": "none",
            "choices": [{
                "index": 0,
                "message": {"role": "assistant", "content": "Router failed.\n" + "\n".join(errors)},
                "finish_reason": "error",
            }],
        }

    note = f"[Router selected: {selected_model} | Reason: {reason}]\n\n"

    return {
        "id": "aicodex-router",
        "object": "chat.completion",
        "model": selected_model,
        "choices": [{
            "index": 0,
            "message": {"role": "assistant", "content": note + answer},
            "finish_reason": "stop",
        }],
    }
PYEOF
}

write_mcp() {
  say "Writing/repairing safe MCP tools"

  write_file "$AICODEX_MCP/requirements.txt" <<'EOF'
fastmcp
EOF

  write_file "$AICODEX_MCP/safe_tools.py" <<'PYEOF'
from fastmcp import FastMCP
from pathlib import Path
import subprocess
import os

mcp = FastMCP("AI Codex Safe Tools")

AICODEX_HOME = Path.home() / ".aicodex-level1"
STATE_FILE = AICODEX_HOME / "state" / "last_project"

BLOCKED_PATTERNS = [
    "sudo",
    "rm -rf",
    "curl | bash",
    "curl -fsSL",
    "chmod -R 777",
    "diskutil",
    "profiles remove",
    "security dump-keychain",
    "mkfs",
    "dd if=",
    ":(){",
    "> /dev/",
]

ALLOWED_COMMANDS = [
    "ls",
    "pwd",
    "cat",
    "grep",
    "find",
    "git status",
    "git diff",
    "git log",
    "git branch",
    "npm test",
    "npm run test",
    "python -m pytest",
    "python3 -m pytest",
    "plutil -lint",
    "shellcheck",
]


def get_project_dir() -> Path:
    if not STATE_FILE.exists():
        raise ValueError("No active project selected. Run: aicodex project")
    project = Path(STATE_FILE.read_text().strip()).expanduser().resolve()
    if not project.exists():
        raise ValueError(f"Project does not exist: {project}")
    return project


def safe_path(relative_path: str) -> Path:
    project = get_project_dir()
    target = (project / relative_path).resolve()
    if not str(target).startswith(str(project)):
        raise ValueError("Blocked: path escapes project directory")
    return target


def is_command_safe(command: str) -> bool:
    lowered = command.lower().strip()
    for pattern in BLOCKED_PATTERNS:
        if pattern in lowered:
            return False
    return any(lowered.startswith(cmd) for cmd in ALLOWED_COMMANDS)


@mcp.tool()
def project_tree(max_depth: int = 3) -> str:
    """Show safe project tree."""
    project = get_project_dir()
    output = []
    base_depth = len(project.parts)

    for root, dirs, files in os.walk(project):
        root_path = Path(root)
        if ".git" in root_path.parts:
            continue
        depth = len(root_path.parts) - base_depth
        if depth > max_depth:
            dirs[:] = []
            continue
        indent = "  " * depth
        output.append(f"{indent}{root_path.name}/")
        for file in files[:30]:
            output.append(f"{indent}  {file}")

    return "\n".join(output)


@mcp.tool()
def read_file(relative_path: str, max_chars: int = 12000) -> str:
    """Read a file inside active project only."""
    target = safe_path(relative_path)
    if not target.is_file():
        raise ValueError("File not found or not a file")
    return target.read_text(errors="replace")[:max_chars]


@mcp.tool()
def git_status() -> str:
    """Run git status in active project."""
    project = get_project_dir()
    result = subprocess.run(["git", "status", "--short"], cwd=project, text=True, capture_output=True, timeout=30)
    return result.stdout or "Git working tree clean"


@mcp.tool()
def git_diff(max_chars: int = 20000) -> str:
    """Show git diff in active project."""
    project = get_project_dir()
    result = subprocess.run(["git", "diff"], cwd=project, text=True, capture_output=True, timeout=60)
    return (result.stdout or "No diff")[:max_chars]


@mcp.tool()
def run_safe_command(command: str, timeout: int = 120) -> str:
    """Run allowlisted safe command in active project only."""
    project = get_project_dir()

    if not is_command_safe(command):
        raise ValueError(f"Blocked unsafe command: {command}")

    result = subprocess.run(command, cwd=project, shell=True, text=True, capture_output=True, timeout=timeout)

    return f"Exit code: {result.returncode}\n\nSTDOUT:\n{result.stdout}\n\nSTDERR:\n{result.stderr}"


if __name__ == "__main__":
    mcp.run()
PYEOF
}

write_launcher() {
  say "Writing/repairing main launcher"

  write_file "$AICODEX_APP/launcher.zsh" <<'LAUNCHEREOF'
#!/bin/zsh

AICODEX_HOME="$HOME/.aicodex-level1"
AICODEX_BIN="$AICODEX_HOME/bin"
AICODEX_ROUTER="$AICODEX_HOME/router"
AICODEX_MCP="$AICODEX_HOME/mcp"
AICODEX_CONFIG="$AICODEX_HOME/config"
AICODEX_LOGS="$AICODEX_HOME/logs"
AICODEX_STATE="$AICODEX_HOME/state"
AICODEX_ARCHIVES="$AICODEX_HOME/archives"
AICODEX_PROJECTS="$AICODEX_HOME/projects"
AICODEX_VENVS="$AICODEX_HOME/venvs"
AICODEX_NPM="$AICODEX_HOME/npm-global"
LAST_PROJECT_FILE="$AICODEX_STATE/last_project"

export PATH="$AICODEX_BIN:$AICODEX_NPM/bin:$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
export NPM_CONFIG_PREFIX="$AICODEX_NPM"

# Optimized model set.
# Do not pull several 30B/32B models by default; it causes RAM pressure and GUI timeouts.
FAST_MODEL="qwen2.5-coder:14b"
BALANCED_MODEL="hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q2_K_XL"
FULL_MODEL="hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q4_K_M"
VISION_MODEL="qwen2.5vl:7b"
EMBED_MODEL="nomic-embed-text"

MODELS=(
  "$FAST_MODEL"
  "$BALANCED_MODEL"
  "$VISION_MODEL"
  "$EMBED_MODEL"
)

OPTIONAL_FULL_MODELS=(
  "$FULL_MODEL"
)

say() {
  echo ""
  echo "==> $1"
}

prompt() {
  local message="$1"
  local result

  # Print prompt directly to terminal, not stdout.
  # This keeps command substitution clean:
  # choice="$(prompt "Select option: ")" captures only "1", not "Select option: 1".
  printf "%s" "$message" >/dev/tty
  IFS= read -r result </dev/tty

  echo "$result"
}

pause() {
  echo ""
  printf "Press Enter to continue..."
  IFS= read -r _
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

tool_python() {
  cat "$AICODEX_STATE/tool_python" 2>/dev/null || command -v python3 || true
}

tool_node() {
  cat "$AICODEX_STATE/tool_node" 2>/dev/null || command -v node || true
}

tool_npm() {
  cat "$AICODEX_STATE/tool_npm" 2>/dev/null || command -v npm || true
}

tool_issue_menu() {
  echo ""
  echo "AI Codex tool issue found."
  echo ""
  echo "1) Repair AI Codex tool"
  echo "2) Reset AI Codex tool config"
  echo "3) Exit"

  local choice
  choice="$(prompt "Enter option number: ")"

  case "$choice" in
    1) repair_tool ;;
    2) reset_tool ;;
    *) exit 1 ;;
  esac
}

check_brew_writable() {
  command_exists brew || return 1
  local prefix
  prefix="$(brew --prefix 2>/dev/null || true)"
  [ -n "$prefix" ] || return 1
  [ -w "$prefix" ]
}

repair_tool() {
  say "Repairing AI Codex tool only"

  mkdir -p "$AICODEX_VENVS" "$AICODEX_NPM" "$AICODEX_LOGS" "$AICODEX_STATE"

  if ! command_exists brew; then
    echo "Homebrew missing. Install Homebrew first, then run aicodex repair."
    return 1
  fi

  if ! check_brew_writable; then
    local prefix
    prefix="$(brew --prefix 2>/dev/null || true)"
    echo "Homebrew is not writable by current user: $prefix"
    echo "Ask admin to run:"
    echo "sudo chown -R $USER:admin \"$prefix\""
    echo "chmod -R u+w \"$prefix\""
    return 1
  fi

  brew update || true
  brew install git python@3.12 node uv ffmpeg shellcheck || true

  local py
  py="$(brew --prefix python@3.12)/bin/python3.12"
  [ -x "$py" ] || py="$(command -v python3)"

  local node
  node="$(brew --prefix node)/bin/node"
  [ -x "$node" ] || node="$(command -v node)"

  local npm_bin
  npm_bin="$(brew --prefix node)/bin/npm"
  [ -x "$npm_bin" ] || npm_bin="$(command -v npm)"

  local uv_bin
  uv_bin="$(brew --prefix uv)/bin/uv"
  [ -x "$uv_bin" ] || uv_bin="$(command -v uv)"

  echo "$py" > "$AICODEX_STATE/tool_python"
  echo "$node" > "$AICODEX_STATE/tool_node"
  echo "$npm_bin" > "$AICODEX_STATE/tool_npm"
  echo "$uv_bin" > "$AICODEX_STATE/tool_uv"

  "$npm_bin" config set prefix "$AICODEX_NPM" >/dev/null 2>&1 || true

  ensure_python_packages || true

  echo ""
  echo "Install/repair Cline CLI locally?"
  echo "1) Yes"
  echo "2) Skip"
  local npm_choice
  npm_choice="$(prompt "Enter option number: ")"

  if [ "$npm_choice" = "1" ]; then
    "$npm_bin" install -g cline || true
  fi

  start_ollama || true

  echo ""
  echo "Pull/update models now?"
  echo "1) Yes"
  echo "2) Skip"
  local model_choice
  model_choice="$(prompt "Enter option number: ")"

  if [ "$model_choice" = "1" ]; then
    pull_optimized_models "$(cat "$AICODEX_STATE/performance_mode" 2>/dev/null || echo fast)" || true
  fi

  start_router || true

  echo "Repair completed."
}

create_venv_if_missing() {
  local name="$1"
  local requirements="$2"
  local venv_path="$AICODEX_VENVS/$name"

  local py
  py="$(tool_python)"

  if [ -z "$py" ] || [ ! -x "$py" ]; then
    echo "Python missing. Run: aicodex repair"
    return 1
  fi

  if [ ! -x "$venv_path/bin/python" ]; then
    "$py" -m venv "$venv_path" || return 1
  fi

  "$venv_path/bin/python" -m pip install --upgrade pip >/dev/null 2>&1 || return 1
  "$venv_path/bin/python" -m pip install -r "$requirements" || return 1
}

ensure_python_packages() {
  say "Validating local Python venvs"

  create_venv_if_missing "router" "$AICODEX_ROUTER/requirements.txt" || return 1
  create_venv_if_missing "mcp" "$AICODEX_MCP/requirements.txt" || return 1
  create_venv_if_missing "openwebui" "$AICODEX_CONFIG/openwebui-requirements.txt" || return 1
  create_venv_if_missing "aider" "$AICODEX_CONFIG/aider-requirements.txt" || return 1
}

start_ollama() {
  if curl -s http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
    echo "✓ Ollama running"
    return 0
  fi

  if command_exists ollama; then
    say "Starting Ollama"
    nohup ollama serve > "$AICODEX_LOGS/ollama.log" 2>&1 &
    sleep 6

    if curl -s http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
      echo "✓ Ollama started"
      return 0
    fi
  fi

  echo "Ollama is not running or not installed."
  return 1
}

start_router() {
  if curl -s http://127.0.0.1:5050/health >/dev/null 2>&1; then
    echo "✓ Smart router running"
    return 0
  fi

  if [ ! -x "$AICODEX_VENVS/router/bin/python" ]; then
    echo "Router venv missing."
    return 1
  fi

  say "Starting smart router"

  nohup "$AICODEX_VENVS/router/bin/python" -m uvicorn router:app \
    --host 127.0.0.1 \
    --port 5050 \
    --app-dir "$AICODEX_ROUTER" \
    > "$AICODEX_LOGS/router.log" 2>&1 &

  sleep 5

  if curl -s http://127.0.0.1:5050/health >/dev/null 2>&1; then
    echo "✓ Smart router started"
    return 0
  fi

  echo "Smart router failed to start. Check: $AICODEX_LOGS/router.log"
  return 1
}

start_openwebui() {
  if curl -s http://127.0.0.1:8080 >/dev/null 2>&1; then
    echo "✓ Open WebUI running"
    return 0
  fi

  if [ ! -x "$AICODEX_VENVS/openwebui/bin/open-webui" ]; then
    echo "Open WebUI local venv missing."
    return 1
  fi

  say "Starting Open WebUI in AI Codex auto-router mode"

  # Force Open WebUI to use only the AI Codex OpenAI-compatible router.
  # This hides/bypasses direct Ollama model selection and keeps users on smart-auto.
  # ENABLE_PERSISTENT_CONFIG=false makes env config win over old saved UI settings.
  env \
    ENABLE_PERSISTENT_CONFIG=false \
    RESET_CONFIG_ON_START=true \
    ENABLE_OLLAMA_API=false \
    ENABLE_OPENAI_API=true \
    OPENAI_API_BASE_URL="http://127.0.0.1:5050/v1" \
    OPENAI_API_BASE_URLS="http://127.0.0.1:5050/v1" \
    OPENAI_API_KEY="local" \
    OPENAI_API_KEYS="local" \
    DEFAULT_MODELS="smart-auto" \
    DEFAULT_PINNED_MODELS="smart-auto" \
    TASK_MODEL_EXTERNAL="smart-auto" \
    WEBUI_NAME="AI Codex" \
    "$AICODEX_VENVS/openwebui/bin/open-webui" serve \
    > "$AICODEX_LOGS/open-webui.log" 2>&1 &

  sleep 12

  if curl -s http://127.0.0.1:8080 >/dev/null 2>&1; then
    echo "✓ Open WebUI started in smart-auto mode"
    return 0
  fi

  echo "Open WebUI failed to start. Check: $AICODEX_LOGS/open-webui.log"
  return 1
}

validate_tool() {
  say "Validating AI Codex tool"

  local failed=0

  local py
  py="$(tool_python)"
  if [ -x "$py" ]; then
    echo "✓ Python: $("$py" --version 2>&1)"
  else
    echo "✗ Python missing"
    failed=1
  fi

  local node
  node="$(tool_node)"
  if [ -x "$node" ]; then
    echo "✓ Node: $("$node" --version 2>&1)"
  else
    echo "✗ Node missing"
    failed=1
  fi

  local npm_bin
  npm_bin="$(tool_npm)"
  if [ -x "$npm_bin" ]; then
    echo "✓ npm: $("$npm_bin" --version 2>&1)"
  else
    echo "✗ npm missing"
    failed=1
  fi

  [ -f "$AICODEX_ROUTER/router.py" ] && echo "✓ router.py" || { echo "✗ router.py missing"; failed=1; }
  [ -f "$AICODEX_MCP/safe_tools.py" ] && echo "✓ MCP safe tools" || { echo "✗ MCP safe tools missing"; failed=1; }
  [ -f "$AICODEX_CONFIG/default-aider.conf.yml" ] && echo "✓ default aider config" || { echo "✗ default aider config missing"; failed=1; }

  ensure_python_packages || failed=1
  start_ollama || failed=1

  if [ "$failed" -ne 0 ]; then
    return 1
  fi

  say "Checking required models"
  for model in "${MODELS[@]}"; do
    if ollama list | awk '{print $1}' | grep -q "^${model}$"; then
      echo "✓ $model"
    else
      echo "⚠ missing model: $model"
    fi
  done

  start_router || return 1

  local router_models
  router_models="$(curl -s http://127.0.0.1:5050/v1/models 2>/dev/null || true)"
  echo "$router_models" | grep -q "smart-auto" || {
    echo "Router is not exposing smart-auto correctly."
    return 1
  }

  echo "✓ Tool validation completed"
}

reset_tool() {
  echo ""
  echo "Reset AI Codex tool config only."
  echo "Models and user projects will not be deleted."
  echo ""
  echo "1) Reset logs"
  echo "2) Reset router venv"
  echo "3) Reset MCP venv"
  echo "4) Reset Open WebUI venv"
  echo "5) Reset Aider venv"
  echo "6) Reset all local venvs and logs"
  echo "7) Reset last project pointer"
  echo "8) Cancel"

  local choice
  choice="$(prompt "Enter option number: ")"

  case "$choice" in
    1) rm -f "$AICODEX_LOGS"/*.log 2>/dev/null || true ;;
    2) rm -rf "$AICODEX_VENVS/router" ;;
    3) rm -rf "$AICODEX_VENVS/mcp" ;;
    4) rm -rf "$AICODEX_VENVS/openwebui" ;;
    5) rm -rf "$AICODEX_VENVS/aider" ;;
    6) rm -rf "$AICODEX_VENVS"; mkdir -p "$AICODEX_VENVS"; rm -f "$AICODEX_LOGS"/*.log 2>/dev/null || true ;;
    7) rm -f "$LAST_PROJECT_FILE" ;;
    *) echo "Cancelled."; return 0 ;;
  esac

  echo "Reset completed. Run: aicodex repair"
}

update_prompt() {
  echo ""
  echo "Check for updates before launch?"
  echo "1) Brew update + update packages/models"
  echo "2) Skip update"

  local choice
  choice="$(prompt "Enter option number: ")"

  if [ "$choice" != "1" ]; then
    return 0
  fi

  repair_tool
}

ensure_gitignore() {
  if [ ! -f ".gitignore" ]; then
    cp "$AICODEX_CONFIG/default-gitignore" .gitignore
  else
    if ! grep -q ".ai-memory/session-history.md" .gitignore; then
      echo "" >> .gitignore
      cat "$AICODEX_CONFIG/default-gitignore" >> .gitignore
    fi
  fi
}

prepare_project_files() {
  [ -f ".aider.conf.yml" ] || cp "$AICODEX_CONFIG/default-aider.conf.yml" .aider.conf.yml
  [ -f "CONVENTIONS.md" ] || cp "$AICODEX_CONFIG/default-conventions.md" CONVENTIONS.md

  mkdir -p .ai-memory

  if [ ! -f ".ai-memory/project-memory.md" ]; then
    cat > .ai-memory/project-memory.md <<MEMORY
# Project Memory

Project path: $(pwd)
Created: $(date)

## Purpose
TBD

## Run Command
TBD

## Test Command
TBD

## Important Files
TBD

## Notes
TBD
MEMORY
  fi

  if [ ! -f ".ai-memory/project-analysis.md" ]; then
    {
      echo "# Project Analysis"
      echo ""
      echo "Generated: $(date)"
      echo ""
      echo "## Top-level files"
      find . -maxdepth 2 -not -path "./.git/*" -print | sed 's#^\./##' | head -200
      echo ""
      echo "## Detected hints"
      [ -f "package.json" ] && echo "- Node/JavaScript project detected because package.json exists."
      [ -f "pyproject.toml" ] && echo "- Python project detected because pyproject.toml exists."
      [ -f "requirements.txt" ] && echo "- Python requirements.txt detected."
      [ -f "index.html" ] && echo "- Static web project detected."
      echo ""
      echo "## Next AI action"
      echo "Ask Aider: Analyze this project structure. Do not edit files yet."
    } > .ai-memory/project-analysis.md
  fi

  touch .ai-memory/session-history.md
  touch .ai-memory/decisions.md
  touch .ai-memory/commands.md
}

secret_scan() {
  say "Project hygiene: scanning for obvious secret files"

  local findings
  findings="$(find . \
    \( -name ".env" -o -name ".env.*" -o -name "*.pem" -o -name "*.key" -o -name "*.p12" -o -name "id_rsa" -o -name "id_ed25519" \) \
    -not -path "./.git/*" \
    -maxdepth 5 \
    2>/dev/null | head -20)"

  if [ -n "$findings" ]; then
    echo "⚠ Possible secret files found:"
    echo "$findings"
    echo ""
    echo "Project issue, not tool issue."
    echo "1) Continue"
    echo "2) Exit and fix project"
    local choice
    choice="$(prompt "Enter option number: ")"
    [ "$choice" = "2" ] && exit 1
  else
    echo "✓ No obvious secret files found"
  fi
}

git_hygiene() {
  say "Project hygiene: checking Git"

  if ! command_exists git; then
    echo "git command missing. Project Git hygiene skipped."
    return 0
  fi

  if [ ! -d ".git" ]; then
    echo "No Git repo found."
    echo "1) Initialize Git"
    echo "2) Continue without Git"
    echo "3) Exit"
    local choice
    choice="$(prompt "Enter option number: ")"
    case "$choice" in
      1) git init ;;
      2) return 0 ;;
      *) exit 0 ;;
    esac
  fi

  if ! git rev-parse --verify HEAD >/dev/null 2>&1; then
    echo "No baseline commit found."
    echo "1) Create baseline commit"
    echo "2) Continue without baseline"
    echo "3) Exit"
    local choice
    choice="$(prompt "Enter option number: ")"
    case "$choice" in
      1) git add .; git commit -m "Initial baseline before AI-assisted work" || true ;;
      2) echo "Continuing without baseline." ;;
      *) exit 0 ;;
    esac
    return 0
  fi

  if [ -n "$(git status --porcelain)" ]; then
    echo "⚠ Project has uncommitted changes."
    echo "1) Create baseline commit"
    echo "2) Continue without commit"
    echo "3) Show git diff"
    echo "4) Exit"
    local choice
    choice="$(prompt "Enter option number: ")"
    case "$choice" in
      1) git add .; git commit -m "Baseline before AI-assisted work" || true ;;
      2) echo "Continuing without baseline commit." ;;
      3) git diff; pause ;;
      *) exit 0 ;;
    esac
  else
    echo "✓ Git working tree clean"
  fi
}

restore_archive_if_needed() {
  if [ -d ".ai-memory" ]; then
    return 0
  fi

  local project_name
  project_name="$(basename "$(pwd)")"
  local archive_dir="$AICODEX_ARCHIVES/$project_name"

  [ -d "$archive_dir" ] || return 0

  local latest
  latest="$(ls -t "$archive_dir"/*.tar.gz 2>/dev/null | head -1)"
  [ -n "$latest" ] || return 0

  echo "Previous AI memory archive found:"
  echo "$latest"
  echo "1) Restore archive"
  echo "2) Generate fresh memory"
  local choice
  choice="$(prompt "Enter option number: ")"

  [ "$choice" = "1" ] && tar -xzf "$latest" -C .
}

archive_project_memory() {
  if [ ! -f "$LAST_PROJECT_FILE" ]; then
    return 0
  fi

  local project_dir
  project_dir="$(cat "$LAST_PROJECT_FILE")"

  [ -d "$project_dir" ] || return 0

  local project_name
  project_name="$(basename "$project_dir")"

  local archive_dir="$AICODEX_ARCHIVES/$project_name"
  local stamp
  stamp="$(date +%Y%m%d_%H%M%S)"

  mkdir -p "$archive_dir"

  tar -czf "$archive_dir/${project_name}_memory_${stamp}.tar.gz" \
    -C "$project_dir" \
    .ai-memory .aider.conf.yml CONVENTIONS.md .gitignore 2>/dev/null || true

  echo "✓ Project memory archived:"
  echo "$archive_dir/${project_name}_memory_${stamp}.tar.gz"
}

select_project() {
  echo ""
  echo "Project selection:"
  echo "1) Start new project"
  echo "2) Select ongoing project"
  echo "3) Reopen last project"

  local choice
  choice="$(prompt "Enter option number: ")"

  local project_dir=""

  case "$choice" in
    1)
      local name
      name="$(prompt "New project name: ")"
      project_dir="$AICODEX_PROJECTS/$name"
      mkdir -p "$project_dir"
      ;;
    2)
      project_dir="$(prompt "Enter full project path: ")"
      project_dir="${project_dir/#\~/$HOME}"
      ;;
    3)
      if [ -f "$LAST_PROJECT_FILE" ]; then
        project_dir="$(cat "$LAST_PROJECT_FILE")"
      else
        echo "No last project found."
        exit 1
      fi
      ;;
    *)
      echo "Invalid option."
      exit 1
      ;;
  esac

  [ -d "$project_dir" ] || { echo "Project folder not found: $project_dir"; exit 1; }

  cd "$project_dir" || exit 1

  restore_archive_if_needed
  ensure_gitignore
  prepare_project_files
  secret_scan
  git_hygiene

  echo "$project_dir" > "$LAST_PROJECT_FILE"
  echo "✓ Project ready: $project_dir"
}

launch_vscode_or_folder() {
  [ -f "$LAST_PROJECT_FILE" ] || return 0
  local project_dir
  project_dir="$(cat "$LAST_PROJECT_FILE")"
  [ -d "$project_dir" ] || return 0

  if command_exists code; then
    code "$project_dir" >/dev/null 2>&1 || open "$project_dir"
  else
    open "$project_dir"
  fi
}

launch_gui() {
  say "Launching Codex-like GUI"

  start_ollama || tool_issue_menu
  start_router || tool_issue_menu
  start_openwebui || tool_issue_menu

  open "http://127.0.0.1:8080" || tool_issue_menu
  launch_vscode_or_folder

  sleep 2

  if ! curl -s http://127.0.0.1:8080 >/dev/null 2>&1; then
    tool_issue_menu
  fi

  echo "✓ GUI launched"
  echo "Open WebUI: http://127.0.0.1:8080"
  echo "Router API: http://127.0.0.1:5050/v1"
  echo "Open WebUI is launched in auto-router mode."
  echo "Only model users should use: smart-auto"
  echo "Router API: http://127.0.0.1:5050/v1"
}


project_context() {
  local project_dir="${1:-}"

  if [ -z "$project_dir" ]; then
    if [ -f "$LAST_PROJECT_FILE" ]; then
      project_dir="$(cat "$LAST_PROJECT_FILE")"
    fi
  fi

  if [ -z "$project_dir" ] || [ ! -d "$project_dir" ]; then
    echo "No project selected."
    echo "Run: aicodex project"
    return 1
  fi

  local memory_dir="$project_dir/.ai-memory"
  mkdir -p "$memory_dir"

  local context_file="$memory_dir/project-context.md"
  local tree_file="$memory_dir/project-tree.md"

  echo "Building project context for:"
  echo "$project_dir"
  echo ""

  {
    echo "# Project Context"
    echo ""
    echo "Generated: $(date)"
    echo "Project: $project_dir"
    echo ""
    echo "This file is generated by AI Codex so local AI tools can understand the project folder."
    echo ""
    echo "## Project Tree"
    echo ""
    echo '```text'
    find "$project_dir" \
      -path "*/.git" -prune -o \
      -path "*/node_modules" -prune -o \
      -path "*/vendor" -prune -o \
      -path "*/dist" -prune -o \
      -path "*/build" -prune -o \
      -path "*/.next" -prune -o \
      -path "*/.venv" -prune -o \
      -path "*/venv" -prune -o \
      -path "*/__pycache__" -prune -o \
      -path "*/.aicodex-cache" -prune -o \
      -type f -print | sed "s#^$project_dir/##" | sort | head -500
    echo '```'
    echo ""

    echo "## Important Files Preview"
    echo ""

    local count=0
    while IFS= read -r file; do
      rel="${file#$project_dir/}"

      case "$rel" in
        *.png|*.jpg|*.jpeg|*.gif|*.webp|*.ico|*.icns|*.zip|*.tar|*.gz|*.dmg|*.pkg|*.mp4|*.mov|*.mp3|*.pdf)
          continue
          ;;
      esac

      case "$rel" in
        */.git/*|*/node_modules/*|*/vendor/*|*/dist/*|*/build/*|*/.next/*|*/.venv/*|*/venv/*|*/__pycache__/*)
          continue
          ;;
      esac

      if [ "$count" -ge 80 ]; then
        break
      fi

      if [ -f "$file" ]; then
        size="$(wc -c < "$file" 2>/dev/null | tr -d ' ')"
        if [ "${size:-0}" -gt 30000 ]; then
          echo "### $rel"
          echo ""
          echo "Skipped preview because file is large: ${size} bytes"
          echo ""
          continue
        fi

        echo "### $rel"
        echo ""
        echo '```'
        sed -n '1,160p' "$file" 2>/dev/null
        echo '```'
        echo ""

        count=$((count + 1))
      fi
    done < <(find "$project_dir" \
      -path "*/.git" -prune -o \
      -path "*/node_modules" -prune -o \
      -path "*/vendor" -prune -o \
      -path "*/dist" -prune -o \
      -path "*/build" -prune -o \
      -path "*/.next" -prune -o \
      -path "*/.venv" -prune -o \
      -path "*/venv" -prune -o \
      -path "*/__pycache__" -prune -o \
      -type f -print | sort)

  } > "$context_file"

  {
    echo "# Project Tree"
    echo ""
    echo '```text'
    find "$project_dir" \
      -path "*/.git" -prune -o \
      -path "*/node_modules" -prune -o \
      -path "*/vendor" -prune -o \
      -path "*/dist" -prune -o \
      -path "*/build" -prune -o \
      -path "*/.next" -prune -o \
      -path "*/.venv" -prune -o \
      -path "*/venv" -prune -o \
      -path "*/__pycache__" -prune -o \
      -type f -print | sed "s#^$project_dir/##" | sort
    echo '```'
  } > "$tree_file"

  cat > "$memory_dir/how-to-use-project-context.md" <<EOF
# How AI Codex Uses This Project

AI Codex has generated these files:

- .ai-memory/project-context.md
- .ai-memory/project-tree.md

For best Codex-like behavior:

1. Use \`aicodex aider\` for real repo editing.
   Aider runs inside the selected project folder and can read/edit files.

2. Use Open WebUI \`smart-auto\` for planning, explanation, and quick help.

3. When asking GUI to work with the project, paste or attach:
   \`.ai-memory/project-context.md\`

4. Regenerate context after major project changes:
   \`aicodex context\`

EOF

  echo "✓ Project context generated:"
  echo "$context_file"
  echo "$tree_file"
  echo ""
  echo "For real Codex-like file editing, run:"
  echo "aicodex aider"
}

run_full() {
  trap archive_project_memory EXIT

  update_prompt

  if ! validate_tool; then
    tool_issue_menu
  fi

  select_project
  launch_gui

  echo ""
  echo "Launch Aider terminal agent now?"
  echo "1) Yes"
  echo "2) No"
  local choice
  choice="$(prompt "Enter option number: ")"

  if [ "$choice" = "1" ]; then
    start_aider
  else
    echo "Use later: aicodex aider"
  fi
}

start_mcp() {
  [ -x "$AICODEX_VENVS/mcp/bin/python" ] || { echo "MCP venv missing. Run: aicodex repair"; exit 1; }
  cd "$AICODEX_MCP" || exit 1
  "$AICODEX_VENVS/mcp/bin/python" safe_tools.py
}

start_aider() {
  [ -f "$LAST_PROJECT_FILE" ] || select_project
  local project_dir
  project_dir="$(cat "$LAST_PROJECT_FILE")"

  cd "$project_dir" || exit 1
  [ -x "$AICODEX_VENVS/aider/bin/aider" ] || { echo "Aider venv missing. Run: aicodex repair"; exit 1; }

  prepare_project_files
  project_context "$project_dir" >/dev/null 2>&1 || true

  # Aider's ollama_chat provider expects this env var.
  # Without it, Aider shows OLLAMA_API_BASE warnings.
  export OLLAMA_API_BASE="http://127.0.0.1:11434"
  export OLLAMA_HOST="http://127.0.0.1:11434"

  local mode
  mode="$(cat "$AICODEX_STATE/performance_mode" 2>/dev/null || echo fast)"

  local aider_model="qwen2.5-coder:14b"
  case "$mode" in
    balanced) aider_model="hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q2_K_XL" ;;
    full) aider_model="hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q4_K_M" ;;
    *) aider_model="qwen2.5-coder:14b" ;;
  esac

  "$AICODEX_VENVS/aider/bin/aider" \
    --config "$project_dir/.aider.conf.yml" \
    --model "ollama_chat/$aider_model" \
    --editor-model "ollama_chat/$aider_model" \
    --no-show-model-warnings
}


kill_aicodex() {
  echo "Stopping AI Codex processes..."

  # Stop AI Codex web UI, router, MCP, and any process launched from the tool folder.
  pkill -f "open-webui" 2>/dev/null || true
  pkill -f "uvicorn router:app" 2>/dev/null || true
  pkill -f "safe_tools.py" 2>/dev/null || true
  pkill -f ".aicodex-level1" 2>/dev/null || true

  # Free known AI Codex ports.
  lsof -tiTCP:5050 -sTCP:LISTEN 2>/dev/null | xargs kill -9 2>/dev/null || true
  lsof -tiTCP:8080 -sTCP:LISTEN 2>/dev/null | xargs kill -9 2>/dev/null || true

  echo ""
  echo "AI Codex user-space processes cleaned."
  echo ""
  echo "Ollama model engine was not stopped."
  echo "To stop Ollama also, run:"
  echo "pkill -f 'ollama serve' 2>/dev/null"
}



set_performance_mode() {
  local mode="${1:-}"

  if [ -z "$mode" ]; then
    echo "Current mode: $(cat "$AICODEX_STATE/performance_mode" 2>/dev/null || echo fast)"
    echo ""
    echo "Usage:"
    echo "  aicodex mode fast"
    echo "  aicodex mode balanced"
    echo "  aicodex mode full"
    echo ""
    echo "fast     = lowest RAM/CPU, best for GUI and fewer timeouts"
    echo "balanced = better coding quality, medium load"
    echo "full     = heavy 30B/32B models, best quality but high RAM/CPU"
    return 0
  fi

  case "$mode" in
    fast|balanced|full)
      echo "$mode" > "$AICODEX_STATE/performance_mode"
      echo "AI Codex performance mode set to: $mode"
      echo ""
      echo "Restart AI Codex to apply:"
      echo "  aicodex kill"
    echo "  aicodex mode fast|balanced|full"
    echo "  aicodex models"
    echo "  aicodex pull-models [fast|balanced|full]"
    echo "  aicodex tune"
      echo "  aicodex run"
      ;;
    *)
      echo "Invalid mode: $mode"
      echo "Use: fast, balanced, or full"
      return 1
      ;;
  esac
}

tune_aicodex() {
  echo "AI Codex tuning recommendation"
  echo ""
  echo "For your current issue: high CPU/RAM and timeout"
  echo "Recommended:"
  echo "  aicodex mode fast"
  echo "  aicodex kill"
  echo "  aicodex run"
  echo ""
  echo "This reduces GUI routing to lighter models and smaller project context."
  echo "Use Aider only when you need real file edits."
}


show_models() {
  echo "AI Codex optimized model plan"
  echo ""
  echo "fast:"
  echo "  qwen2.5-coder:14b"
  echo ""
  echo "balanced:"
  echo "  hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q2_K_XL"
  echo ""
  echo "full:"
  echo "  hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q4_K_M"
  echo ""
  echo "vision:"
  echo "  qwen2.5vl:7b"
  echo ""
  echo "embedding:"
  echo "  nomic-embed-text"
  echo ""
  echo "Current mode: $(cat "$AICODEX_STATE/performance_mode" 2>/dev/null || echo fast)"
}

pull_optimized_models() {
  local mode="${1:-$(cat "$AICODEX_STATE/performance_mode" 2>/dev/null || echo fast)}"

  start_ollama || return 1

  echo "Pulling optimized AI Codex models for mode: $mode"
  echo ""

  case "$mode" in
    fast)
      ollama pull "qwen2.5-coder:14b" || return 1
      ollama pull "qwen2.5vl:7b" || true
      ollama pull "nomic-embed-text" || true
      ;;
    balanced)
      ollama pull "qwen2.5-coder:14b" || return 1
      ollama pull "hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q2_K_XL" || return 1
      ollama pull "qwen2.5vl:7b" || true
      ollama pull "nomic-embed-text" || true
      ;;
    full)
      ollama pull "qwen2.5-coder:14b" || return 1
      ollama pull "hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q4_K_M" || return 1
      ollama pull "qwen2.5vl:7b" || true
      ollama pull "nomic-embed-text" || true
      ;;
    *)
      echo "Invalid mode: $mode"
      echo "Use: fast, balanced, or full"
      return 1
      ;;
  esac
}

show_env_help() {
  echo "AI Codex environment:"
  echo "OLLAMA_API_BASE=${OLLAMA_API_BASE:-not set}"
  echo "OLLAMA_HOST=${OLLAMA_HOST:-not set}"
  echo ""
  echo "For current terminal, run:"
  echo "export OLLAMA_API_BASE=http://127.0.0.1:11434"
  echo "export OLLAMA_HOST=http://127.0.0.1:11434"
}

status_tool() {
  echo "AI Codex Status"
  echo ""
  echo "Performance mode: $(cat "$AICODEX_STATE/performance_mode" 2>/dev/null || echo fast)"
  echo ""

  local py
  py="$(tool_python)"
  [ -x "$py" ] && echo "✓ Python: $("$py" --version 2>&1)" || echo "✗ Python missing"

  local node
  node="$(tool_node)"
  [ -x "$node" ] && echo "✓ Node: $("$node" --version 2>&1)" || echo "✗ Node missing"

  curl -s http://127.0.0.1:11434/api/tags >/dev/null 2>&1 && echo "✓ Ollama running" || echo "✗ Ollama not running"
  curl -s http://127.0.0.1:5050/health >/dev/null 2>&1 && echo "✓ Router running" || echo "✗ Router not running"
  curl -s http://127.0.0.1:8080 >/dev/null 2>&1 && echo "✓ Open WebUI running" || echo "✗ Open WebUI not running"

  echo ""
  echo "Loaded models:"
  ollama ps 2>/dev/null || true

  echo ""
  [ -f "$LAST_PROJECT_FILE" ] && echo "Last project: $(cat "$LAST_PROJECT_FILE")" || echo "Last project: none"
}

case "$1" in
  run) run_full ;;
  gui) launch_gui ;;
  validate) validate_tool ;;
  repair) repair_tool ;;
  reset) reset_tool ;;
  project) select_project ;;
  context) project_context ;;
  analyze) project_context ;;
  aider) start_aider ;;
  mcp) start_mcp ;;
  archive) archive_project_memory ;;
  kill) kill_aicodex ;;
  mode) set_performance_mode "$2" ;;
  tune) tune_aicodex ;;
  models) show_models ;;
  pull-models) pull_optimized_models "$2" ;;
  env) show_env_help ;;
  status) status_tool ;;
  *)
    echo "Usage:"
    echo "  aicodex run"
    echo "  aicodex gui"
    echo "  aicodex validate"
    echo "  aicodex repair"
    echo "  aicodex reset"
    echo "  aicodex project"
    echo "  aicodex context"
    echo "  aicodex analyze"
    echo "  aicodex aider"
    echo "  aicodex mcp"
    echo "  aicodex archive"
    echo "  aicodex kill"
    echo "  aicodex env"
    echo "  aicodex status"
    ;;
esac
LAUNCHEREOF

  chmod +x "$AICODEX_APP/launcher.zsh"

  write_file "$AICODEX_BIN/aicodex" <<EOF
#!/bin/zsh
exec "$AICODEX_APP/launcher.zsh" "\$@"
EOF

  chmod +x "$AICODEX_BIN/aicodex"
}

link_cli() {
  say "Linking aicodex command"

  ln -sf "$AICODEX_BIN/aicodex" "$USER_BIN/aicodex"

  echo "Linked:"
  echo "$USER_BIN/aicodex"
}

repair_previous_install() {
  say "Repairing previous aicodex install if present"

  chmod -R u+rwX "$AICODEX_HOME" 2>/dev/null || true

  # This preserves projects, archives, state, logs, downloads, and Ollama models.
  # It overwrites launcher/router/mcp/default configs with the Brew-first version.
}

final_message() {
  echo ""
  echo "AI Codex Level 1 Brew-first installer completed."
  echo ""
  echo "Run:"
  echo "source ~/.zshrc"
  echo ""
  echo "Then:"
  echo "aicodex repair"
  echo "aicodex run"
  echo ""
  echo "Installed under:"
  echo "$AICODEX_HOME"
  echo ""
  echo "No sudo was used by this installer."
}

main() {
  create_dirs
  setup_shell_path
  repair_previous_install
  write_default_configs
  write_router
  write_mcp
  write_launcher
  link_cli

  echo ""
  echo "Install/repair Python, Node, uv and tools using Brew now?"
  echo "1) Yes"
  echo "2) Skip, run aicodex repair later"
  local choice
  choice="$(prompt "Enter option number: ")"

  if [ "$choice" = "1" ]; then
    install_brew_tools
  fi

  final_message
}

main
