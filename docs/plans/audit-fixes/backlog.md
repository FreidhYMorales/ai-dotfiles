# Backlog: audit-fixes

## Context

- What: close the gaps found by the 2026-11-02 config audit (agy out of scope beyond what is integrated). Plan: none; source: `docs/ideas.md` ideas 05-12 and 14-17.
- Stack: bash, Claude Code plugins (hooks, skills), systemd user units, GitHub Actions, `make check`.
- Expensive decisions: the require-check trust rule (#03) changes which repos get gated; denying credential reads (#02) may block tools Claude runs (`gh`, `engram-backup`).
- Test command: `make check`
- Single test: `bash scripts/tests/<name>.test.sh` (plugin hooks: `bash plugins/toolkit/hooks/tests/<name>.test.sh`)

## Backlog

01. [x] 282c0d0 As the dotfiles owner, I want the CI `check` job to fail only when something is really broken, with margin under its timeout, so that a red run means something again. (idea 08)
02. [x] 6abf651 As the dotfiles owner, I want Claude denied from reading my restic password, gh token, git credentials and every `.env.*`, also through Bash, so that an agent cannot leak my push token or backup key. (idea 05)
03. [x] daad54d As the dotfiles owner, I want the require-check gate to warn when I stop with a red check, to ignore a stale red marker and to run only in trusted repos, so that the gate cannot be skipped or abused. (idea 06)
04. [x] 2a1c0ea As the dotfiles owner, I want a sandboxed pi worker unable to plant git config that runs on my host, so that pi-box keeps its isolation promise. (idea 07)
05. [x] 9f5141a As the dotfiles owner, I want tests proving the global gitleaks hook blocks a secret, chains to the repo hook and honours `SKIP_GITLEAKS`, so that my last barrier before a push cannot regress silently. (idea 11)
06. [x] 16e6c33 As the dotfiles owner, I want `docs/recovery.md` plus `install.sh` proven on a clean Arch container, with every dependency listed, no abort without a user bus and an honest dry-run, so that I can rebuild the setup when a disk dies. (idea 10)
07. [x] ed2e079 As the dotfiles owner, I want the CI recovery drill to restore memories a real engram binary can find, so that I know my memory survives, not just a SQLite file. (idea 17)
08. [x] 9064644 As the dotfiles owner, I want a startup note when my Claude Code differs from look's pinned version, so that I bump the pin before the band breaks silently. (idea 09)
09. [-] split → #14, #15, #16
10. [~] As the dotfiles owner, I want `ai-update` to keep only the last two engram copies and roll back binary and database together on a failed doctor, so that an update can never strand my memory. (idea 15)
11. [ ] As the dotfiles owner, I want offline startups without a network wait and timer runs that retry after boot, so that a bad connection costs nothing. (idea 14)
12. [ ] As the dotfiles owner, I want the README, the mutation list, the bench validation, the repo ignores and the vendored licenses to match reality, so that the repo tells the truth about itself. (idea 16)
13. [x] b61d153 As the dotfiles owner, I want `install.sh` to tell a missing user bus apart from a real `systemctl --user daemon-reload` failure and show the error, so that a broken unit is never reported as "no systemd user session". (story 06 verifier note)
14. [x] 4ff0dba As the dotfiles owner, I want a startup warning when the global git hooksPath points to a missing directory, and `install.sh` to repair it, so that moving the repo never turns off gitleaks unnoticed. (idea 12, from #09)
15. [x] 48019f1 As the dotfiles owner, I want `install.sh` to prune its own old `*.bak-*` copies, keeping the newest ones, so that backups stop piling up. (idea 12, from #09)
16. [x] 28c798a As the dotfiles owner, I want a basic `install.sh --uninstall` that removes only what the installer put in place, so that I can take the setup off a machine cleanly. (idea 12, from #09)
17. [x] 51f15c9 As the dotfiles owner, I want `install.sh --dry-run` to stop saying it pruned a broken link it only reported, so that a dry-run never claims a change it did not make. (idea 18, from #15)
18. [x] 2be9666 As the dotfiles owner, I want the look test "an agent missing from agent.list on two polls in a row is stopped" to stop failing CI at the 5 s watchdog, so that a red run means something again. (idea 19, from #15)
19. [x] 8e9cf81 As the dotfiles owner, I want every look harness test to have the 30 s budget, and `make check` to fail when one lacks it, so that a slow CI runner stops turning `main` red one case at a time. (idea 21, from #18)
