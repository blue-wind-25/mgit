# mgit

A recursive multi-repo git wrapper that treats a git repository with submodules as a single unit. Run one command at the root and `mgit` does the right thing across every submodule, at every level of nesting, in the correct order.

## Why

Standard git does not understand that submodules need to be committed and pushed before the parent updates its ref pointers. It also does not enforce signing consistently across all repos in a tree, and it does not know to skip signing when an AI coding agent is doing the committing.

`mgit` handles all of this transparently. It is a single Python script with **zero pip dependencies** — nothing beyond the Python standard library and stock `git`.

## Requirements

- Python 3.6 or later
- git (any stock version)
- GPG configured if you want signed commits (see [Signing](#signing))
- Linux, macOS, or Windows — see [Windows](#windows)
- `gh` (GitHub CLI) — required only for `mgit detach` and `mgit attach`; see [GitHub CLI](#github-cli)

## Installation

### Linux / macOS

```bash
curl -O https://raw.githubusercontent.com/blue-wind-25/mgit/main/mgit
chmod +x mgit
sudo mv mgit /usr/local/bin/
```

Or clone the repo and symlink:

```bash
git clone https://github.com/blue-wind-25/mgit.git
sudo ln -s "$(pwd)/mgit/mgit" /usr/local/bin/mgit
```

### Windows

Download `mgit` and `mgit.cmd` from the repo, place both files in the same directory, and add that directory to your `PATH`. Open a new terminal and run `mgit` like any other command.

Requirements on Windows:
- [Python 3.6+](https://www.python.org/downloads/) — tick "Add Python to PATH" during install
- [Git for Windows](https://gitforwindows.org/) — includes git, GPG, and sets `core.editor` for you

## Usage

`mgit` is used exactly like `git`. Run it from anywhere inside your repo tree.

```
mgit <command> [args...]
```

### Commands

| Command | Behaviour |
|---|---|
| `mgit status` | Status of all repos, root first |
| `mgit add [paths]` | Stage in all repos |
| `mgit add -A` | Stage everything in all repos |
| `mgit commit -m "msg"` | Commit all repos, leaves first, same message everywhere |
| `mgit commit` | Commit all repos, opening an editor per repo for individual messages |
| `mgit push` | Push all submodules, update refs in parent, push root |
| `mgit pull` | Pull root, then sync and update all submodules |
| `mgit fetch` | Fetch all repos |
| `mgit diff` | Diff all repos |
| `mgit log` | Log all repos |
| `mgit detach <subdir>` | Extract a subdirectory into a new GitHub repo and re-add it as a submodule |
| `mgit attach <subdir> <submodule-path>` | Move a subdirectory's contents into an existing submodule |
| `mgit <anything>` | Any other git command is passed through to all repos |

All extra flags and arguments are forwarded to git unchanged.

### Typical workflow

```bash
# Make changes across your repo and its submodules
mgit add -A
mgit commit -m "feat: implement new feature"
mgit push
```

`mgit commit` commits submodules first (bottom-up), then the root. Submodule ref pointers in the root are **not** updated until `mgit push`, keeping `commit` a local-only operation.

`mgit push` then: pushes each submodule to its own remote, stages the updated ref pointers in the root, makes an automatic commit (`chore: update submodule refs`), and pushes the root.

### Per-repo commit messages

Running `mgit commit` without `-m` opens your configured editor once per repo that has staged changes. Each editor session shows a comment header identifying the repo being committed:

```
# Please enter the commit message for: libs/crypto
# Lines starting with '#' will be ignored.
# An empty message aborts the commit for this repo.
```

Save and exit to commit that repo, leave the message empty to skip it. This mirrors git's own behaviour and lets you write meaningful per-repo messages without running git separately in each directory.

The editor is resolved in this order: `GIT_EDITOR` → `core.editor` (git config) → `VISUAL` → `EDITOR` → `nano` (Linux/macOS) / `notepad` (Windows).

### Working from a subdirectory

`mgit` detects the root of the current repo and operates from there. Running `mgit` from inside a submodule only operates on that submodule and its own nested submodules — it does not walk up to parent repos.

## Submodule management

### `mgit detach <subdir>`

Extracts a subdirectory from the current repo, creates a new GitHub repository for it, and re-adds it as a submodule. The subdirectory's git history is not carried over — the new repo starts with a single clean initial commit.

```bash
mgit detach libs/crypto
```

`mgit` will interactively ask for:

- **New repo name** — defaults to the subdirectory basename
- **Description** — optional, passed to `gh repo create`
- **Visibility** — public or private
- **Initial commit message** — whether to include the parent repo name (a privacy warning is shown if the parent is private and the new repo is public)

The sequence performed:

1. Validates the subdir exists, is not already a submodule, and the working tree is clean
2. Creates a temporary git repo, copies the subdir contents in, and commits
3. Creates the GitHub repo via `gh` and pushes
4. Removes the subdir from the parent with `git rm -r`
5. Adds the new repo back as a submodule
6. Commits the change in the parent

After `mgit detach`, run `mgit push` to push both repos to their remotes.

#### Nested detach

If a submodule itself contains subdirectories that need further splitting, `mgit detach` can be run from inside the submodule. The parent will pick up the updated `.gitmodules` ref on the next `mgit push`.

### `mgit attach <subdir> <submodule-path>`

Moves the contents of a subdirectory into an existing submodule, then removes the subdirectory from the parent. This is the complement of `detach` — useful when you want to consolidate a directory into a repo that already exists as a submodule rather than creating a new one.

```bash
mgit attach libs/utils vendor/common
```

`mgit` will ask for the destination path inside the target submodule (defaults to the subdirectory's basename), and warn if that destination already exists.

The sequence performed:

1. Validates the subdir exists, the target is an existing submodule, and both repos have clean working trees
2. Copies the subdir contents into the specified path inside the submodule
3. Commits the addition inside the submodule
4. Removes the subdir from the parent and stages the updated submodule ref
5. Commits the change in the parent

After `mgit attach`, run `mgit push` to push both repos.

## Signing

GPG commit signing is driven entirely by your git config — `mgit` does not inject or force signing. Configure it once and it applies everywhere:

```bash
git config --global user.signingkey <YOUR_KEY_ID>
git config --global commit.gpgsign true
```

With `commit.gpgsign = true`, every `git commit` (and therefore every `mgit commit`) signs automatically. `mgit` performs a pre-flight check before committing: if signing is configured but GPG is misconfigured or the key is missing, it dies with a clear error before touching any repo.

If `commit.gpgsign` is **not set**, `mgit` warns you before each unsigned commit and asks whether to continue:

```
[mgit] WARN: commit.gpgsign is not set for 'libs/crypto' — this commit will be unsigned.
[mgit]       To enable signing: git config --global commit.gpgsign true
Continue without signing? [Y/n]:
```

The default is yes, so pressing Enter proceeds. This makes it easy to notice missing signing config without blocking automated use.

### AI agent and bot exemptions

`mgit` detects known AI coding agents and CI bots by their `git config user.email` and explicitly suppresses signing for them via `--no-gpg-sign`, overriding any global `commit.gpgsign = true`. No configuration needed. The following are recognised out of the box:

| Agent | Email pattern |
|---|---|
| Claude (Anthropic) | `242468646+Claude@users.noreply.github.com`, `claude[bot]@...`, `noreply@anthropic.com` |
| GitHub Copilot | `198982749+Copilot@users.noreply.github.com` |
| GitHub Actions | `41898282+github-actions[bot]@users.noreply.github.com` |
| OpenAI Codex | `codex@example.com`, `noreply@codex.openai.com`, `chatgpt-codex-connector[bot]@...` |
| Google Gemini | `218195315+gemini-cli@users.noreply.github.com`, `gemini-code-assist[bot]@...`, `noreply@gemini.google.com` |
| Any GitHub bot | `*[bot]@users.noreply.github.com` (catch-all) |

When signing is suppressed, a log line is printed showing the matched email and pattern.

To add your own CI or deploy bot emails, see [Configuration](#configuration).

## GitHub CLI

`mgit detach` and `mgit attach` require the `gh` CLI to create and manage GitHub repositories. All other commands do not need it.

If `gh` is not installed, `mgit` will print platform-appropriate instructions and exit — it never installs anything automatically.

```bash
# macOS
brew install gh

# Debian / Ubuntu
sudo apt update && sudo apt install gh

# Fedora / CentOS
sudo dnf install gh

# Windows (winget)
winget install --id GitHub.cli

# Windows (Scoop)
scoop install gh

# All platforms — manual download
# https://github.com/cli/cli/releases/latest
```

After installing, authenticate once:

```bash
gh auth login
```

## Windows

`mgit` works on Windows with no code changes. Use `mgit.cmd` as the launcher:

1. Install [Python 3.6+](https://www.python.org/downloads/) — tick "Add Python to PATH"
2. Install [Git for Windows](https://gitforwindows.org/)
3. Download `mgit` and `mgit.cmd` from this repo, place both in a folder on your PATH
4. Open a new terminal and run `mgit` normally

**Editor:** Git for Windows sets `core.editor` during install (vim, nano, VS Code, Notepad++, etc.). If nothing is configured, `mgit` falls back to `notepad`. Any editor that blocks until the file is closed will work.

**GPG:** Git for Windows ships with GPG. If you use Gpg4win instead, point git at it:

```
git config --global gpg.program "C:\Program Files (x86)\GnuPG\bin\gpg.exe"
```

**Paths:** `mgit` uses `os.path` throughout, which handles Windows path separators correctly.

**gh on Windows:** If `gh` is not found, `mgit` prints winget and Scoop install instructions and exits.

## Configuration

`mgit` works with zero configuration. Optional overrides can be placed in:

- `.mgitconfig` in the repo root (repo-specific)
- `~/.mgitconfig` (user-global)

The first file found wins. Settings in the file **extend** the built-in defaults rather than replacing them.

Copy `mgitconfig.sample` to get started:

```bash
# Linux / macOS
cp mgitconfig.sample ~/.mgitconfig

# Windows
copy mgitconfig.sample %USERPROFILE%\.mgitconfig
```

### Options

```ini
[signing]
# Additional emails that should skip GPG signing.
# One entry per line. Supports Python regex (full-string, case-insensitive).
# These are appended to the built-in bot list.
no_sign_emails =
    myci-bot@mycompany.com
    deploy@mycompany.com

[refs]
# Commit message used when mgit push auto-commits updated submodule refs.
commit_msg = "chore: update submodule refs"

[behavior]
# Print every git command being run.
verbose = false
```

### Verbose mode

```bash
mgit --verbose status
```

The `--verbose` flag can also be set permanently via `~/.mgitconfig`.

## Public submodules inside a private repo

A primary use case for `mgit` is a private root repository that contains one or more public submodules. Because the root only stores SHA pointers, none of the submodule code or history is exposed through the private repo. Each submodule pushes to its own independent remote — public or private — and `mgit` keeps the ordering correct automatically.

`mgit detach` is purpose-built for this workflow. When detaching a subdirectory into a public repo, `mgit` warns before including the private parent repo name in the initial commit message, and defaults to omitting it.

## How commit ordering works

Submodules must be in a consistent state before the parent updates its ref pointer. `mgit` enforces this by processing repos in the following order:

- **commit, push** — bottom-up (deepest submodules first, root last)
- **status, pull, fetch, diff, log** — top-down (root first)

This applies recursively. A submodule that itself contains submodules is handled correctly at every depth.

## Credits

Initial design and implementation by [Aloysius Indrayanto](https://github.com/blue-wind-25),
with architecture discussion and code generation assisted by [Claude](https://claude.ai) (Anthropic).
