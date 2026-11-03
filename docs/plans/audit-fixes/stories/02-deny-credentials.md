# Story 02: Deny credential reads, also through Bash

## Story

02. As the dotfiles owner, I want Claude denied from reading my restic password, gh token, git credentials and every `.env.*`, also through Bash, so that an agent cannot leak my push token or backup key. (idea 05)

## Acceptance criteria

- [ ] Given the installed Claude settings, when Claude tries to read `~/.config/restic/**`, `~/.config/gh/**`, `~/.git-credentials` or any `.env.*` file with its Read tool, then the read is denied, and the settings check fails if any of these rules is removed.
- [ ] Given a Bash command from Claude that names one of those paths (with `cat`, `bat`, `rg`, `jq`, `cp` or any other program, including `~`, `$HOME` and absolute spellings), when it is about to run, then it is blocked with a message naming the protected path.
- [ ] Given a Bash command that only uses those tools without naming the files (`gh pr checks`, `engram-backup --verify`, `rg foo .`), when it runs, then it is not blocked.

## Plan

- Add the missing read denies to the shipped Claude settings and to the list the settings check enforces.
- Add a PreToolUse guard on Bash that matches the protected paths in the command text and blocks with a clear reason.
- Register the guard next to the existing Bash hook in the toolkit plugin; fail open on unreadable input, like the existing hooks.
- Pin both behaviours with hook tests (blocked spellings, allowed tool use).

## Out of scope

- OS-level `sandbox.filesystem.denyRead` (decided: it would break `gh` and `engram-backup` run by Claude).
- Catching obfuscated paths (variables built at run time, base64, scripts that read the files themselves); the guard catches accidental and agent-typed reads only.
- Relative paths after a `cd` (`cd ~/.config && bat gh/hosts.yml`): catching them means resolving the shell's working directory (decided by the user after the first verifier pass).
- Porting the guard to OpenCode or agy.
- Changing the existing 25 deny rules.

## Suggestions (your call)

- Assumption to confirm: "every `.env.*`" is literal, so `.env.example` is blocked too; carve it out only if you want.
- The OpenCode port runs `prefer-modern-cli` (`plugins/toolkit/opencode/toolkit.ts`); a later story could give it the same guard for parity.
- An opt-out env var like the other hooks (`SKIP_...=1`) would defeat the guard when an agent sets it; suggest none.

## Size

normal
Risk: item 2 (credential reads: restic key, gh token, git credentials), item 5 (installed runtime config)

## Log

- L1 request: haz la sugerecnai y luego vamos con la siguiente story
- L2 decision (user): Read denies plus a Bash PreToolUse path guard, not the OS sandbox.
- L3 manual test 2 (fresh session, after `./install.sh --target claude` merged 29 denies; backup `~/.claude/settings.json.bak-20261103-111620`): Read of a control file succeeded; Read of `~/pairtest/.env.pairtest` was denied ("denied by your permission settings"); `bat` on it was blocked by the hook ("protected credential path (.env.pairtest)"). Dummy files removed.
- L4 verifier pass 1: FAIL. The guard missed the globs (`cat .env.*`, `rg TOKEN .env*`) and the `//` and `/./` spellings. Fixed red→green: d6d061b → 9d86fd2 (globs), a754b65 → 0042296 (path normalisation). The user moved relative paths after a `cd` to Out of scope.
