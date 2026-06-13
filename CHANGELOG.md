# Changelog

All notable changes to mgit are documented here.

## [1.6.0] — 2026-06-14

### Added

- **`mgit upsub [path ...]`** — new command to advance submodule(s) to the latest commit on their tracked remote branch and stage the updated ref pointer(s) in the parent repo. Accepts optional submodule paths to limit the update to specific submodules; without arguments all submodules are updated. After running, complete the update with `mgit commit` and `mgit push`.

- **Auto-reattach after `upsub`** — `git submodule update --remote` always leaves submodules in a detached HEAD state. `mgit upsub` now automatically reattaches each submodule to its remote branch and fast-forwards the local branch to match. The branch is detected from the remote tracking refs already populated by the update — no `.gitmodules` `branch =` configuration required, compatible with git 1.8.x and later.
