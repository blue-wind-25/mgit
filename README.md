# mgit

A recursive multi-repo git wrapper that treats a git repository with submodules as a single unit. Run one command at the root and `mgit` does the right thing across every submodule, at every level of nesting, in the correct order.

## Why

Standard git does not understand that submodules need to be committed and pushed before the parent updates its ref pointers. It also does not enforce signing consistently across all repos in a tree, and it does not know to skip signing when an AI coding agent is doing the committing.

`mgit` handles all of this transparently. It is a single Python script with no dependencies beyond the Python standard library and stock `git`.

## Requirements

- Python 3.6 or later
- git (any stock version)
- GPG configured for signing (required for human committers; see [Signing](#signing))
- Linux or macOS — tested on CentOS 7 and Ubuntu 18+

## Installation

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
| `mgit push` | Push all submodules, update refs in parent, push root |
| `mgit pull` | Pull root, then sync and update all submodules |
| `mgit fetch` | Fetch all repos |
| `mgit diff` | Diff all repos |
| `mgit log` | Log all repos |
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

`mgit push` then: pushes each submodule to its own remote, stages the updated ref pointers in the root, makes an automatic signed commit (`chore: update submodule refs`), and pushes the root.

### Working from a subdirectory

`mgit` detects the root of the current repo and operates from there. Running `mgit` from inside a submodule only operates on that submodule and its own nested submodules — it does not walk up to parent repos.

## Signing

GPG commit signing is **enforced by default** for all human committers. If no signing key is configured, `mgit commit` refuses with a clear error before touching anything.

To configure signing:

```bash
git config --global user.signingkey <YOUR_KEY_ID>
git config --global commit.gpgsign true
```

### AI agent and bot exemptions

`mgit` detects known AI coding agents and CI bots by their `git config user.email` and skips signing for them automatically. No configuration needed. The following are recognised out of the box:

| Agent | Email pattern |
|---|---|
| Claude (Anthropic) | `242468646+Claude@users.noreply.github.com`, `claude[bot]@...`, `noreply@anthropic.com` |
| GitHub Copilot | `198982749+Copilot@users.noreply.github.com` |
| GitHub Actions | `41898282+github-actions[bot]@users.noreply.github.com` |
| OpenAI Codex | `codex@example.com`, `noreply@codex.openai.com`, `chatgpt-codex-connector[bot]@...` |
| Google Gemini | `218195315+gemini-cli@users.noreply.github.com`, `gemini-code-assist[bot]@...`, `noreply@gemini.google.com` |
| Any GitHub bot | `*[bot]@users.noreply.github.com` (catch-all) |

When signing is skipped, a log line is printed showing the matched email and pattern.

To add your own CI or deploy bot emails, see [Configuration](#configuration).

## Configuration

`mgit` works with zero configuration. Optional overrides can be placed in:

- `.mgitconfig` in the repo root (repo-specific)
- `~/.mgitconfig` (user-global)

The first file found wins. Settings in the file **extend** the built-in defaults rather than replacing them.

Copy `mgitconfig.sample` to get started:

```bash
cp mgitconfig.sample ~/.mgitconfig
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

## How commit ordering works

Submodules must be in a consistent state before the parent updates its ref pointer. `mgit` enforces this by processing repos in the following order:

- **commit, push** — bottom-up (deepest submodules first, root last)
- **status, pull, fetch, diff, log** — top-down (root first)

This applies recursively. A submodule that itself contains submodules is handled correctly at every depth.

## Credits

Initial design and implementation by [Aloysius Indrayanto](https://github.com/blue-wind-25),
with architecture discussion and code generation assisted by [Claude](https://claude.ai) (Anthropic).
