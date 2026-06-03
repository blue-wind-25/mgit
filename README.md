# mgit

A recursive multi-repo git wrapper that treats a git repository with submodules as a single unit. Run one command at the root and `mgit` does the right thing across every submodule, at every level of nesting, in the correct order.

## Why

Standard git does not understand that submodules need to be committed and pushed before the parent updates its ref pointers. It also does not enforce signing consistently across all repos in a tree, and it does not know to skip signing when an AI coding agent is doing the committing.

`mgit` handles all of this transparently. It is a single Python script with **zero pip dependencies** — nothing beyond the Python standard library and stock `git`.

## Requirements

- Python 3.6 or later
- git 1.7 or later (stock version shipped with any Linux distro since ~2012)
- GPG configured if you want signed commits (see [Signing](#signing))
- Linux, macOS, or Windows — see [Windows](#windows)
- `gh` (GitHub CLI) — required only for `mgit detach`; see [GitHub CLI](#github-cli)

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
| `mgit sync [-m "msg"]` | Stage tracked changes, commit, and push all repos safely |
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

### Recovery and catch-up with `mgit sync`

If you used plain `git` directly for some operations (or an AI coding agent committed inside a submodule without going through mgit), run:

```bash
mgit sync
```

Or with a custom message:

```bash
mgit sync -m "feat: implement BLE notifications"
```

`mgit sync` does three things in the correct bottom-up order:

1. **`git add -u`** in every repo — stages modifications and deletions to already-tracked files only. Untracked files and build artefacts are never touched, so there is no risk of accidentally committing generated output.
2. **Commit** every repo that has staged changes, using the provided message or `chore: sync` as the default.
3. **Push** all repos — submodules first, then auto-stages any stale submodule ref pointers in the parent, commits the ref update, and pushes the root.

If there is nothing to commit (everything is already committed), `mgit sync` skips straight to the push step — making it safe to run as a general "make sure everything is pushed" command.

`mgit push` on its own is the right tool when you have already committed everything correctly and just need to push in the right order.

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

#### Call forms and repo layout

The call form controls how content is laid out inside the new repo:

```bash
# Default — flat copy, contents go directly to the new repo root
mgit detach gui_frontend/src/jcom

# Trailing slash — also flat, accepted for clarity
mgit detach gui_frontend/src/jcom/

# Shell glob expansion — flat copy from the named items;
# repo name default derived from the common parent (jcom)
mgit detach gui_frontend/src/jcom/*

# Explicit wrapper subdir name
mgit detach gui_frontend/src/jcom --dest-subdir src

# Explicit flat — same as default, accepted for clarity
mgit detach gui_frontend/src/jcom --no-dest-subdir
```

**Default (flat):** contents go directly to the new repo root. Detaching `gui_frontend/src/jcom` creates a repo whose root contains `com/`, `ecma335/`, `winmd/` etc. The submodule mounts at `gui_frontend/src/jcom/` in the parent repo, so all existing paths resolve identically to before the detach.

This is the right default for the common submodule use case: the directory name (`jcom`) is already represented by the submodule mount point, so no wrapper is needed inside the repo.

**Wrapped (`--dest-subdir <name>`):** contents are placed under `<name>/` inside the new repo root. Use this when the repo will primarily be cloned and used standalone — for example, if `jcom` is a Java package root and you want someone cloning the repo to see `jcom/com/`, `jcom/ecma335/` etc. at the top level. Note: when used as a submodule, this creates a `<name>/` subdirectory inside the mount point (`gui_frontend/src/jcom/jcom/`), which is usually not what you want for in-place submodule use.

The submodule mount point in the parent repo is always the detached directory path — only the internal repo layout differs.

#### Interactive prompts

`mgit` will ask for:

- **Owner** — your personal account or any GitHub organisation you belong to (see [Owner selection](#owner-selection) below)
- **New repo name** — editable; defaults to the last path segment (`jcom`), or the common parent name when using glob expansion
- **Description** — optional, passed to `gh repo create`
- **Visibility** — public or private
- **Initial commit message** — whether to include the parent repo name (a privacy warning is shown for public repos)

The sequence performed:

1. Validates the subdir exists, is not already a submodule, and the working tree is clean
2. Creates a temporary git repo, copies contents in (flat or wrapped), and commits
3. Creates the GitHub repo via `gh` and pushes
4. Removes the subdir from the parent with `git rm -r`
5. Adds the new repo back as a submodule
6. Commits the change in the parent

After `mgit detach`, run `mgit push` to push both repos to their remotes.

#### Owner selection

When `mgit detach` runs, it fetches the authenticated GitHub user's login and their organisation memberships. If the user belongs to one or more organisations, a numbered menu is shown:

```
[mgit] Where should the new repo be created?
   1. blue-wind-25 (personal)
   2. my-org (org)
   3. another-org (org)

Select owner [1-3] [1]:
```

Select `1` to create the new repo under your personal account, or choose an org number to create it there. If you belong to no organisations, the personal account is used automatically with no prompt.

The personal account is always the currently authenticated `gh` user — never inferred from the current repo's remote URL.

#### Ownership combinations

`mgit detach` and `mgit attach` work with all combinations of personal and org ownership for both the current repo and the new/target repo:

| Current repo owner | New / target repo owner | `detach` | `attach` |
|---|---|---|---|
| Personal | Personal | ✅ | ✅ |
| Personal | Org | ✅ | ✅ |
| Org | Personal | ✅ | ✅ |
| Org | Org | ✅ | ✅ |

For `detach`, the owner of the new repo is chosen at the prompt — it is independent of who owns the current repo. For `attach`, no new repo is created and ownership is irrelevant; only local git operations are performed.

**Token requirement for org repos:** creating a repo in an organisation requires a classic personal access token with `repo` and `read:org` scopes. Fine-grained tokens cannot list org memberships or create org repos. See [GitHub CLI authentication](#github-cli-authentication) below.

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

`attach` performs only local git operations — it does not call `gh` and does not require any GitHub token.

## GitHub CLI

`mgit detach` requires the `gh` CLI to create GitHub repositories. `mgit attach` does not need it. All other commands do not need it.

`mgit` avoids using gh's `--source` flag (which makes gh call `git -C` internally and requires git 1.8.5+). Instead it creates the repo with `gh repo create` and pushes from the temp directory directly using git. This means any gh version that supports `gh repo create` works, and there is no minimum git version beyond what the rest of mgit requires.

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

## GitHub CLI authentication

`mgit detach` uses `gh` to create repos and list org memberships. `gh` has its own authentication layer, separate from git's credential system (SSH keys, HTTPS credential helpers). There are three ways to authenticate it.

### Token requirements

`mgit detach` calls two GitHub APIs:

- `gh org list` — lists organisations the authenticated user belongs to (`read:org` scope)
- `gh repo create` — creates a repository under a personal account or org (`repo` scope)

These operations require a **classic personal access token** with scopes `repo`, `read:org`, and `gist`.

**Fine-grained personal access tokens do not work** for `mgit detach` when org repos are involved. Fine-grained tokens cannot list org memberships or create repositories in organisations. They will work for personal-to-personal detach only, but mgit will still fail to show the org menu and will silently skip org options.

If you attempt `mgit detach` with a fine-grained token and an org operation is needed, `gh` will return HTTP 403. mgit catches this and prints a clear error with remediation steps.

### Authentication options

#### Option A — `gh auth login` (recommended for most users)

Run once. Credentials are stored in your system keychain (macOS) / Windows Credential Manager / `~/.config/gh/hosts.yml` (Linux). mgit picks them up automatically.

```bash
gh auth login
# Choose: GitHub.com → HTTPS → Paste an authentication token
# Paste your classic PAT when prompted
```

`gh auth login` stores credentials in its own config file — it does **not** read or write `GITHUB_TOKEN` or `GH_TOKEN` in your environment. Your existing env vars are completely unaffected.

#### Option B — `GH_TOKEN` environment variable (session-scoped)

Set `GH_TOKEN` to your classic PAT. `gh` checks `GH_TOKEN` before `GITHUB_TOKEN`, so this lets you keep a fine-grained token in `GITHUB_TOKEN` for your own API work while giving `gh` a different token:

```bash
# Linux / macOS — current session only
export GH_TOKEN=ghp_yourclassictoken

# Windows cmd
set GH_TOKEN=ghp_yourclassictoken

# Windows PowerShell
$env:GH_TOKEN = 'ghp_yourclassictoken'
```

Or inline for a single command:

```bash
GH_TOKEN=ghp_yourclassictoken mgit detach libs/crypto
```

#### Option C — `[gh] token` in `~/.mgitconfig` (persistent, recommended if `GITHUB_TOKEN` is already in use)

If you already have `GITHUB_TOKEN` set in your environment for other purposes (e.g. a fine-grained PAT for your own API), use this option. mgit injects the token as `GH_TOKEN` into `gh` subprocesses only — your `GITHUB_TOKEN` is never read or modified.

```ini
# ~/.mgitconfig
[gh]
token = ghp_yourclassictoken
```

`GH_TOKEN` takes precedence over `GITHUB_TOKEN` in gh's own resolution order, so this correctly overrides your environment's fine-grained token for all mgit gh calls.

### How to find or create a classic PAT

**Create a new classic PAT:**

1. Go to [https://github.com/settings/tokens](https://github.com/settings/tokens)
2. Click **Generate new token (classic)**
3. Set an expiry and a descriptive name (e.g. `mgit-detach`)
4. Select scopes: **repo**, **read:org**, **gist**
5. Click **Generate token** and copy it immediately

**Copy from `gh auth login` stored credentials (Linux only):**

If you previously ran `gh auth login` and want to move that token into `~/.mgitconfig`:

```bash
# The token is in hosts.yml if gh did not use the system keychain
grep oauth_token ~/.config/gh/hosts.yml
```

On macOS and Windows, `gh auth login` stores to the system keychain / Credential Manager rather than `hosts.yml`, so the token is not directly readable from a file. In that case, retrieve the token gh is using:

```bash
gh auth token
```

Then paste the output into `~/.mgitconfig`:

```ini
[gh]
token = ghp_the_token_printed_above
```

### Authentication resolution order

When `mgit` calls `gh`, the token is resolved in this order:

1. `[gh] token` in `.mgitconfig` / `~/.mgitconfig` → injected as `GH_TOKEN` into the subprocess
2. `GH_TOKEN` environment variable already set → left as-is
3. `GITHUB_TOKEN` environment variable set, but no `GH_TOKEN` or config token → mgit explicitly reads the keyring/`hosts.yml` token via `gh auth token` (with both env vars cleared) and injects it as `GH_TOKEN`, then removes `GITHUB_TOKEN`. This is necessary because gh records an active-account preference in `~/.config/gh/hosts.yml` and will use it even if `GITHUB_TOKEN` is merely absent from the env — explicitly injecting the keyring token as `GH_TOKEN` overrides that selection unambiguously.
4. Nothing set → gh does its own resolution (keychain / `hosts.yml` / interactive prompt)

### Coexistence with `GITHUB_TOKEN`

If you have `GITHUB_TOKEN` set in your environment for API work and have run `gh auth login` with a classic PAT, **no extra configuration is needed**. mgit automatically strips `GITHUB_TOKEN` from the environment it passes to `gh`, so `gh` falls through to the stored `gh auth login` credential.

```bash
# In your shell profile — fine-grained PAT for your API
export GITHUB_TOKEN=github_pat_yourfinegrainedtoken

# Run once — classic PAT stored in keychain / gh config
gh auth login   # paste classic PAT with repo, read:org, gist scopes

# mgit detach just works — no GH_TOKEN or [gh] token needed
mgit detach libs/crypto
```

Use the `[gh] token` config option only if you cannot or prefer not to run `gh auth login`, or if you want an explicit token that is not tied to the keychain:

```ini
# ~/.mgitconfig
[gh]
token = ghp_yourclassictoken   # classic PAT — injected as GH_TOKEN for gh calls only
```

```bash
# In your shell profile
export GITHUB_TOKEN=github_pat_yourfinegrainedtoken   # used by your API, stripped for gh
```

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

**gh on Windows:** If `gh` is not found, `mgit` prints winget and Scoop install instructions and exits. For the `[gh] token` option, use your user-global `~/.mgitconfig` — on Windows this resolves to `%USERPROFILE%\.mgitconfig`.

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

[gh]
# Classic personal access token for gh CLI (detach only).
# Required scopes: repo, read:org, gist
# Injected as GH_TOKEN into gh subprocesses — does not affect GITHUB_TOKEN.
# Use this if GITHUB_TOKEN is already set in your environment for other purposes.
# token = ghp_yourclassictoken
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
