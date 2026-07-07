# Building a Local Codex-Like AI Coding Tool on Mac: My `aicodex` Setup

Over the last few days, I explored one question:

**Can we build something close to Codex locally, using open-source/local models, without depending completely on a paid cloud coding agent?**

The honest answer is:

**Not 100% identical to Codex, but we can build a very practical local Codex-like workflow.**

My goal was not to copy Codex exactly. My goal was to create a **local AI coding command center** that can:

```text
Understand a project
Edit code
Use different models for different tasks
Open a GUI
Use safe tools
Maintain project memory
Protect project hygiene
Run without admin permission issues as much as possible
```

That is how the idea of **`aicodex`** started.

---

## What is `aicodex`?

`aicodex` is a local launcher/tooling setup that creates a Codex-like working environment on your Mac.

It combines:

```text
Ollama       = local model runtime
Aider        = repo editing / coding agent
Open WebUI   = browser-based ChatGPT-like GUI
Smart Router = auto-selects the right model
MCP Tools    = safe filesystem/git/shell tools
Git          = safety, diff, rollback
Project Memory = reusable context for each project
```

The main command is:

```bash
aicodex run
```

This launches the local AI coding environment.

---

## Why I Built This

Paid cloud coding tools are powerful, but they have some limitations:

```text
They may cost money
They may need internet
They may send code to cloud
They may not be suitable for private/local experiments
They may not give full control over model selection
```

I wanted something that works more like:

```text
My Mac
My models
My project
My rules
My Git history
My local memory
```

So the idea was to create a reusable local tool that can be launched again and again for different projects.

---

## Hardware Needed

This setup is model-heavy. Hardware matters.

### Recommended Mac

```text
Apple Silicon Mac
64 GB RAM or higher
1 TB storage recommended
Good internet for first model downloads
```

### Minimum practical setup

```text
Apple Silicon Mac
32 GB RAM
500 GB storage
Use smaller models like 7B / 14B
```

### Best experience

```text
64 GB RAM
1 TB SSD
Qwen3-Coder 30B
DeepSeek-R1 32B
Qwen2.5-VL 7B
nomic-embed-text
```

Why storage matters: local models are large. Once you start pulling multiple 7B, 14B, 30B, and 32B models, disk usage increases quickly.

---

## Models Used

The setup uses multiple models because one model should not do everything.

```text
Qwen3-Coder 30B
Main coding model. Used for code edits, shell scripts, APIs, and repo changes.

DeepSeek-R1 32B
Architect/reviewer model. Used for planning, reasoning, design, and root cause analysis.

Qwen3 30B
General reasoning and router/controller model.

Qwen2.5-VL 7B
Vision model. Used for screenshots, UI errors, images, and diagrams.

Qwen2.5-Coder 14B
Fast fallback model for smaller code tasks.

nomic-embed-text
Embedding model for local memory/RAG.
```

This gives the system a role-based design:

```text
DeepSeek = brain / architect
Qwen Coder = hands / code editor
Qwen VL = eyes
nomic = memory
Aider = repo editing body
Open WebUI = GUI
MCP = tools
```

---

## How `aicodex` is Installed

The installer creates one clean user-owned directory:

```bash
~/.aicodex-level1
```

Everything related to the tool goes inside that directory:

```text
~/.aicodex-level1
├── bin
├── app
├── router
├── mcp
├── config
├── logs
├── state
├── archives
├── projects
├── venvs
├── npm-global
└── downloads
```

This is important because the tool is designed to avoid permission issues.

The goal is:

```text
No sudo during daily use
No random system-level writes
No mixing tool files with project files
No global Python package mess
No global npm permission issue
```

Python dependencies are installed into local virtual environments.

Node packages use a local npm prefix:

```bash
~/.aicodex-level1/npm-global
```

The CLI command is linked as:

```bash
aicodex
```

---

## Why User-Owned Setup Matters

Many Mac setups fail because tools are installed globally and later the user gets permission errors.

This setup avoids that by using:

```text
User-owned directory
Local Python venvs
Local npm prefix
User Applications folder for GUI apps
No automatic sudo
```

If Homebrew is already installed but owned by admin/root, `aicodex` does not silently break. It informs the user and continues in local-only mode where possible.

If needed, an admin can make Homebrew writable once, but `aicodex` itself does not depend on sudo for daily use.

---

## How It Works Internally

When you run:

```bash
aicodex run
```

the tool follows this flow:

```text
1. Check for updates
2. Validate the AI Codex tool
3. Repair/reset only if tool components are broken
4. Ask user to select project
5. Apply project hygiene checks
6. Generate project AI files if missing
7. Restore memory archive if available
8. Start Ollama
9. Start smart router
10. Start Open WebUI
11. Open project folder / VS Code
12. Optionally launch Aider
13. Archive project memory on exit
```

---

## GUI-First Behavior

The tool is designed to always launch a GUI.

The GUI layer is:

```text
Open WebUI = ChatGPT-like local AI interface
VS Code / project folder = coding workspace
Aider = terminal coding agent
```

So when the setup is working, `aicodex run` opens:

```text
Open WebUI in browser
Selected project in VS Code or Finder
Optional Aider terminal session
```

If the GUI does not launch, that is treated as a **tool issue**, not a project issue.

Then the user gets:

```text
1. Repair AI Codex tool
2. Reset AI Codex tool config
3. Exit
```

---

## Smart Router

A key part of this setup is the smart router.

Instead of manually choosing a model every time, Open WebUI connects to:

```text
http://127.0.0.1:5050/v1
```

The model name is:

```text
smart-auto
```

The router asks the controller model what kind of task this is.

Example:

```text
User: Write a zsh script for Jamf API
Router selects: Qwen3-Coder 30B
```

```text
User: Review this architecture
Router selects: DeepSeek-R1 32B
```

```text
User: Explain this screenshot
Router selects: Qwen2.5-VL 7B
```

```text
User: Explain MCP in simple words
Router selects: Qwen3 30B
```

---

## Failover Design

The router also has failover.

If the selected model fails, it tries another model.

Example:

```text
Qwen3-Coder 30B fails
↓
Qwen2.5-Coder 14B
↓
Qwen3 30B
```

For planning:

```text
DeepSeek-R1 32B fails
↓
Qwen3 30B
↓
Qwen3-Coder 30B
```

This makes the system more stable.

---

## How Aider Works in This Setup

Aider is used for actual repository editing.

For Aider, we do not use the full smart router. Aider works better with fixed roles:

```yaml
model: ollama_chat/deepseek-r1:32b
editor-model: ollama_chat/qwen3-coder:30b
architect: true
```

This means:

```text
DeepSeek-R1 32B = architect/planner
Qwen3-Coder 30B = editor/code writer
```

Aider reads the Git repository, builds a repo map, understands the project structure, and edits files safely with visible diffs.

A normal Aider flow looks like:

```text
User gives coding task
↓
DeepSeek creates plan
↓
Qwen3-Coder edits files
↓
Aider shows diff
↓
User reviews
↓
User commits
```

---

## Project Hygiene

This was one of the most important parts of the design.

Before AI works on a project, `aicodex` checks:

```text
Is this a Git repo?
Is there a baseline commit?
Is the working tree dirty?
Are AI config files present?
Is project memory present?
Are obvious secret files present?
Is .gitignore configured?
```

If project files are missing, it generates them.

It creates:

```text
.aider.conf.yml
CONVENTIONS.md
.gitignore
.ai-memory/project-memory.md
.ai-memory/project-analysis.md
.ai-memory/session-history.md
.ai-memory/decisions.md
.ai-memory/commands.md
```

This keeps the AI workflow clean and repeatable.

---

## Tool Issue vs Project Issue

This distinction is important.

### Tool issues

These trigger repair/reset:

```text
Ollama missing
Open WebUI not starting
Router broken
MCP server broken
Python venv broken
Required config missing
GUI failed to launch
```

### Project issues

These do not reset the tool.

They trigger project hygiene prompts:

```text
No Git repo
Dirty Git status
Missing .ai-memory
Missing CONVENTIONS.md
Possible secrets found
No baseline commit
```

This prevents one bad project from breaking the whole local AI setup.

---

## Project Memory

Each project gets its own memory folder:

```text
.ai-memory
```

It contains:

```text
project-memory.md
project-analysis.md
session-history.md
decisions.md
commands.md
```

This gives the AI reusable context.

Example:

```text
How to run the project
How to test the project
Important files
Architecture decisions
Previous AI sessions
Known risks
```

When the user exits, `aicodex` archives this memory.

Archives are stored in:

```bash
~/.aicodex-level1/archives/<project-name>/
```

When reopening an old project, if `.ai-memory` is missing, the tool can restore it from the archive.

---

## Safe MCP Tools

MCP gives the AI controlled tool access.

But unrestricted shell access is dangerous.

So `aicodex` includes safe MCP tools only:

```text
project_tree
read_file
git_status
git_diff
run_safe_command
```

The MCP tools are limited to the selected project directory.

They block dangerous commands like:

```text
sudo
rm -rf
curl | bash
chmod -R 777
diskutil
profiles remove
security dump-keychain
dd if=
```

Only safe commands are allowed, such as:

```text
git status
git diff
git log
ls
cat
grep
find
npm test
python3 -m pytest
plutil -lint
shellcheck
```

This makes the system safer for real project work.

---

## Security Model

The security approach is simple:

```text
Local first
User-owned directory
No sudo by default
Project path restrictions
Safe MCP allowlist
Blocked destructive commands
Git baseline before AI changes
Secrets check before launch
Memory archived locally
No tool files mixed with project files
```

The main security benefits are:

```text
Code stays local unless user adds cloud tools
Models run locally through Ollama
AI tool files stay inside ~/.aicodex-level1
Project files stay inside the selected project
Memory archives stay local
Destructive commands are blocked in MCP
```

This is not a perfect security sandbox, but it is much safer than giving an AI unrestricted shell access.

---

## How to Use It

### Install

```bash
chmod +x ~/aicodex-install.sh
~/aicodex-install.sh
source ~/.zshrc
```

### Start

```bash
aicodex run
```

### Validate

```bash
aicodex validate
```

### Repair tool

```bash
aicodex repair
```

### Reset tool config

```bash
aicodex reset
```

### Select project

```bash
aicodex project
```

### Launch GUI

```bash
aicodex gui
```

### Launch Aider

```bash
aicodex aider
```

### Start MCP tools

```bash
aicodex mcp
```

### Check status

```bash
aicodex status
```

---

## How to Use It Like Codex

A typical workflow:

```bash
aicodex run
```

Select your project.

Open WebUI and use:

```text
Model: smart-auto
Base URL: http://127.0.0.1:5050/v1
API Key: local
```

Ask:

```text
Analyze this project structure. Do not edit anything yet.
```

Then launch Aider:

```bash
aicodex aider
```

Inside Aider:

```text
Improve this feature. Keep changes minimal. Show diff.
```

After changes:

```bash
git diff
git status
git add .
git commit -m "AI-assisted improvement"
```

This gives a Codex-like loop:

```text
Ask
Plan
Edit
Review diff
Test
Commit
Archive memory
```

---

## What Features We Get

```text
Local AI chat GUI
Local coding agent
Repo-aware code editing
Smart model routing
Model failover
Project memory
Project analysis
Safe MCP tools
Git hygiene
Secret hygiene
Repair/reset flow
GUI-first launch
Standard-user friendly setup
Reusable across multiple projects
```

---

## What It Still Cannot Fully Replace

This is not exactly the same as paid Codex.

Our local setup does not fully replace:

```text
Codex Cloud
OpenAI-hosted coding models
Managed cloud sandboxes
Remote mobile handoff
Official OpenAI app integration
Enterprise workspace controls
Polished multi-agent cloud orchestration
```

But it gives a strong local alternative for:

```text
Private coding
Learning
Local experiments
Script generation
Repo editing
Architecture review
Offline-ish workflows
Reusable project memory
```

---

## Final Thought

The goal of `aicodex` is not to say local open-source tools are better than Codex.

The goal is to understand the architecture behind a coding agent and build a practical local version:

```text
Model runtime
Coding agent
GUI
Router
Tool layer
Memory
Project hygiene
Security controls
```

Once you understand this, you stop seeing AI coding as just “one chatbot”.

You start seeing it as a system.

And that system can be built, controlled, repaired, reused, and improved locally.

That is the real value of this setup.
