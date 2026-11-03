# Backlog: audit-fixes

## Context

- What: close the gaps found by the 2026-11-02 config audit (agy out of scope beyond what is integrated). Plan: none; source: `docs/ideas.md` ideas 05-12 and 14-17.
- Stack: bash, Claude Code plugins (hooks, skills), systemd user units, GitHub Actions, `make check`.
- Expensive decisions: the require-check trust rule (#03) changes which repos get gated; denying credential reads (#02) may block tools Claude runs (`gh`, `engram-backup`).
- Test command: `make check`
- Single test: `bash scripts/tests/<name>.test.sh` (plugin hooks: `bash plugins/toolkit/hooks/tests/<name>.test.sh`)

## Backlog

01. [~] As the dotfiles owner, I want the CI `check` job to fail only when something is really broken, with margin under its timeout, so that a red run means something again. (idea 08)
02. [x] 6abf651 As the dotfiles owner, I want Claude denied from reading my restic password, gh token, git credentials and every `.env.*`, also through Bash, so that an agent cannot leak my push token or backup key. (idea 05)
03. [x] daad54d As the dotfiles owner, I want the require-check gate to warn when I stop with a red check, to ignore a stale red marker and to run only in trusted repos, so that the gate cannot be skipped or abused. (idea 06)
04. [x] 2a1c0ea As the dotfiles owner, I want a sandboxed pi worker unable to plant git config that runs on my host, so that pi-box keeps its isolation promise. (idea 07)
05. [x] 9f5141a As the dotfiles owner, I want tests proving the global gitleaks hook blocks a secret, chains to the repo hook and honours `SKIP_GITLEAKS`, so that my last barrier before a push cannot regress silently. (idea 11)
06. [ ] As the dotfiles owner, I want `docs/recovery.md` plus `install.sh` proven on a clean Arch container, with every dependency listed, no abort without a user bus and an honest dry-run, so that I can rebuild the setup when a disk dies. (idea 10)
07. [ ] As the dotfiles owner, I want the CI recovery drill to restore memories a real engram binary can find, so that I know my memory survives, not just a SQLite file. (idea 17)
08. [ ] As the dotfiles owner, I want a startup note when my Claude Code differs from look's pinned version, so that I bump the pin before the band breaks silently. (idea 09)
09. [ ] As the dotfiles owner, I want a basic `install.sh --uninstall`, a warning when the global hooksPath points nowhere and pruning of old `*.bak-*`, so that moving the repo never turns off gitleaks unnoticed. (idea 12)
10. [ ] As the dotfiles owner, I want `ai-update` to keep only the last two engram copies and roll back binary and database together on a failed doctor, so that an update can never strand my memory. (idea 15)
11. [ ] As the dotfiles owner, I want offline startups without a network wait and timer runs that retry after boot, so that a bad connection costs nothing. (idea 14)
12. [ ] As the dotfiles owner, I want the README, the mutation list, the bench validation, the repo ignores and the vendored licenses to match reality, so that the repo tells the truth about itself. (idea 16)
