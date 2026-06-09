# How This Repo Is Structured & How to Keep It In Sync

## Remotes

This repo has two remotes:

| Name     | URL                              | Purpose                          |
|----------|----------------------------------|----------------------------------|
| `origin` | https://github.com/openai/codex  | The official upstream repo       |
| `fork`   | https://github.com/dzammit/codex | Your personal fork on GitHub     |

## Branches

| Branch                         | Purpose                                                  |
|--------------------------------|----------------------------------------------------------|
| `main`                         | Tracks `origin/main` — the official latest code         |
| `fix/windows-shell-hang-18983` | Your custom branch — upstream code + your Windows fixes |

## Your Custom Commits (on top of upstream)

Three commits sit on the fix branch above `origin/main`:

1. `ca3f91a10f` — fix(cli): use try_send for rollout items to prevent deadlock
2. `cbc8dcf6fe` — Handle Windows device path aliases *(your main fix)*
3. `05d451a140` — fix(cli): use try_send for shell stream events to prevent deadlock

These are your Windows-specific fixes that haven't been merged upstream.

## How to Update (manual steps)

If `download_latest.bat` isn't available, these are the equivalent manual steps:

```bat
:: 1. Fetch latest from the official repo
git fetch origin

:: 2. Switch to main and fast-forward it
git switch main
git merge --ff-only origin/main

:: 3. Switch to your fix branch and rebase your commits on top of latest
git switch fix/windows-shell-hang-18983
git rebase origin/main

:: 4. Rebuild
cd codex-rs
cargo build --release --bin codex
cd ..
```

If `git rebase` reports a conflict, git will pause and tell you which file has a conflict.
Open that file, look for the `<<<<<<` markers, resolve them, then run:

```bat
git add <the-file>
git rebase --continue
```

## What download_latest.bat Does

`download_latest.bat` automates the manual steps above. Run it from the repo root
whenever you want to update to the latest upstream code. It:

1. Checks for an in-progress rebase and aborts early if one exists.
2. Stashes any uncommitted changes so they don't block the rebase.
3. Fetches `origin` (the official repo).
4. Rebases your 3 fix commits on top of `origin/main`.
5. Restores your stashed changes.
6. Runs `cargo build --release --bin codex` to rebuild the CLI.

## What Was Done to Re-sync (June 2026)

The local repo had drifted because `main` was 1310 commits behind `origin/main`,
making the fix branch *appear* to have 1313 unique commits. In reality it only ever
had the 3 fix commits above.

Steps taken:
1. `git switch main && git merge --ff-only origin/main` — brought local main up to date.
2. `git rebase origin/main` on the fix branch — already up to date (no conflicts).
3. `git push fork fix/windows-shell-hang-18983 --force-with-lease` — pushed to fork.
4. `git push fork main` — pushed updated main to fork.
