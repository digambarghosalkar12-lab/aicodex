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
model: ollama_chat/deepseek-r1:32b
editor-model: ollama_chat/qwen3-coder:30b
architect: true

auto-commits: false
dirty-commits: false
show-diffs: true

map-tokens: 4096
max-chat-history-tokens: 8192

read:
  - CONVENTIONS.md
  - .ai-memory/project-memory.md
  - .ai-memory/project-analysis.md
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
import requests
import json
import re

OLLAMA_URL = "http://127.0.0.1:11434"
CONTROLLER_MODEL = "qwen3:30b"

ALLOWED_TARGETS = {
    "qwen3:30b",
    "qwen3-coder:30b",
    "deepseek-r1:32b",
    "qwen2.5vl:7b",
    "qwen2.5-coder:14b",
}

FAILOVER_MAP = {
    "qwen3-coder:30b": ["qwen2.5-coder:14b", "qwen3:30b"],
    "deepseek-r1:32b": ["qwen3:30b", "qwen3-coder:30b"],
    "qwen2.5vl:7b": ["qwen3:30b"],
    "qwen2.5-coder:14b": ["qwen3-coder:30b", "qwen3:30b"],
    "qwen3:30b": ["deepseek-r1:32b"],
}

app = FastAPI(title="AI Codex Smart Local Router")


def messages_to_text(messages):
    output = []
    for msg in messages:
        role = msg.get("role", "user")
        content = msg.get("content", "")
        if isinstance(content, list):
            content = "\n".join(
                item.get("text", "")
                for item in content
                if item.get("type") == "text"
            )
        output.append(f"{role.upper()}: {content}")
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


def call_ollama(model, messages, temperature=0.2, timeout=420):
    payload = {
        "model": model,
        "messages": messages,
        "stream": False,
        "options": {"temperature": temperature},
    }
    response = requests.post(
        f"{OLLAMA_URL}/api/chat",
        json=payload,
        timeout=timeout,
    )
    response.raise_for_status()
    return response.json().get("message", {}).get("content", "")


def ask_controller(user_text):
    prompt = f"""
You are a local AI model router.

Decide whether to answer by yourself or forward to a specialist model.

Available models:
- qwen3:30b = general chat, explanation, documentation, normal technical questions
- qwen3-coder:30b = code generation, repo changes, shell/zsh/bash/python/javascript/html/css, Jamf, Microsoft Graph API, macOS automation
- deepseek-r1:32b = architecture, planning, review, root cause analysis, risk analysis, complex troubleshooting
- qwen2.5vl:7b = image, screenshot, OCR, diagram, UI error, video frame
- qwen2.5-coder:14b = quick snippets, small coding help, simple syntax fixes

Return ONLY valid JSON:
{{
  "action": "answer_self" or "forward",
  "target": "model-name",
  "reason": "short reason"
}}

Rules:
- For code/script/repo tasks, prefer qwen3-coder:30b.
- For planning/review/architecture, prefer deepseek-r1:32b.
- For image/screenshot/video frame, prefer qwen2.5vl:7b.
- For small code snippets, use qwen2.5-coder:14b.
- For normal explanation, use qwen3:30b.
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
        )
        decision = extract_json(content)
        if not decision:
            raise ValueError("Controller did not return valid JSON")
        target = decision.get("target", "qwen3:30b")
        if target not in ALLOWED_TARGETS:
            target = "qwen3:30b"
        return {"target": target, "reason": decision.get("reason", "No reason provided")}
    except Exception as error:
        return {"target": "qwen3:30b", "reason": f"Controller failed, using general model: {error}"}


def failover_chain(primary):
    available = installed_models()
    chain = [primary] + FAILOVER_MAP.get(primary, [])
    filtered = [model for model in chain if model in available]
    return filtered or ["qwen3:30b"]


@app.get("/health")
def health():
    return {"status": "ok", "controller": CONTROLLER_MODEL, "ollama": OLLAMA_URL}


@app.get("/v1/models")
def models():
    return {
        "object": "list",
        "data": [{"id": "smart-auto", "object": "model"}]
        + [{"id": model, "object": "model"} for model in sorted(ALLOWED_TARGETS)],
    }


@app.post("/v1/chat/completions")
async def chat_completions(request: Request):
    body = await request.json()
    messages = body.get("messages", [])
    requested_model = body.get("model", "smart-auto")
    temperature = body.get("temperature", 0.2)

    if requested_model == "smart-auto":
        decision = ask_controller(messages_to_text(messages))
        primary = decision["target"]
        reason = decision["reason"]
    else:
        primary = requested_model
        reason = "Manual model selected"

    if primary not in ALLOWED_TARGETS:
        primary = "qwen3:30b"

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

MODELS=(
  "qwen3:30b"
  "qwen3-coder:30b"
  "deepseek-r1:32b"
  "qwen2.5vl:7b"
  "nomic-embed-text"
  "qwen2.5-coder:14b"
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
    for model in "${MODELS[@]}"; do
      ollama pull "$model" || true
    done
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

  say "Starting Open WebUI"

  nohup "$AICODEX_VENVS/openwebui/bin/open-webui" serve \
    > "$AICODEX_LOGS/open-webui.log" 2>&1 &

  sleep 12

  if curl -s http://127.0.0.1:8080 >/dev/null 2>&1; then
    echo "✓ Open WebUI started"
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
  echo "Open WebUI connection:"
  echo "Base URL: http://127.0.0.1:5050/v1"
  echo "API Key: local"
  echo "Model: smart-auto"
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
    cd "$(cat "$LAST_PROJECT_FILE")" || exit 1
    "$AICODEX_VENVS/aider/bin/aider"
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
  cd "$(cat "$LAST_PROJECT_FILE")" || exit 1
  [ -x "$AICODEX_VENVS/aider/bin/aider" ] || { echo "Aider venv missing. Run: aicodex repair"; exit 1; }
  "$AICODEX_VENVS/aider/bin/aider"
}

status_tool() {
  echo "AI Codex Status"
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
  aider) start_aider ;;
  mcp) start_mcp ;;
  archive) archive_project_memory ;;
  status) status_tool ;;
  *)
    echo "Usage:"
    echo "  aicodex run"
    echo "  aicodex gui"
    echo "  aicodex validate"
    echo "  aicodex repair"
    echo "  aicodex reset"
    echo "  aicodex project"
    echo "  aicodex aider"
    echo "  aicodex mcp"
    echo "  aicodex archive"
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
