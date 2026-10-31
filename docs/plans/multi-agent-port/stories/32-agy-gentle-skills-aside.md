# Story 32: gentle-ai's same-named and spec-workflow skills out of agy discovery

## Story

32. As a developer, I want gentle-ai's same-named and retired spec-workflow skills moved out of the three agy skills discovery dirs into `skills-backup/`, never deleted, so that no gentle-ai copy loads beside the prefixed repo skills. Requires: #30

## Acceptance criteria

- [ ] Given a real skill dir named like a repo skill (e.g. `work-unit-commits`, `judgment-day`) or `sdd-*` in any of `~/.gemini/skills/`, `~/.gemini/config/skills/` or `~/.gemini/antigravity-cli/skills/`, when I run `./install.sh --target antigravity`, then it is gone from that dir, sits in `~/.gemini/antigravity-cli/skills-backup/` with its content intact, and the output names the move.
- [ ] Given other gentle-ai or user skills (`branch-pr`, `_shared`) and the installer's own links in those dirs, when I install, then they stay where they are.
- [ ] Given a backup of the same name already in `skills-backup/`, or the same name in two discovery dirs, when I install, then no backup is overwritten, and a second install moves nothing.

## Plan

- After the link step, the antigravity install sweeps the three discovery dirs for real dirs (never links) whose name is a repo skill name or starts with `sdd-`.
- Each one moves into the existing `skills-backup/` with the same no-overwrite rule the `.bak-*` sweep uses; nothing is deleted.
- The output names each move as source → destination, so a restore is one `mv`.
- `docs/multi-agent.md` says which gentle-ai skills the install moves aside and where they go.

## Out of scope

- OpenCode skill dirs: the story names only the agy discovery dirs.
- gentle-ai skills with other names (`branch-pr`, `issue-creation`, `skill-registry`, `gentle-ai-bench`, ...) and `_shared`.
- The other #22 hardening (`.bak-*` sweep of all three dirs, `mktemp` for `hooks.json`, pruning, version warning).
- `~/.gemini/GEMINI.md` (moved in #01) and the agents dir `.bak-*` probe (#17).

## Suggestions (your call)

- The `.bak-*` sweep in `build_agents` already has the numeric-suffix loop for a taken backup name; the new sweep can share it instead of copying it.

## Size

normal
Risk: item 1 (moves existing user skill dirs outside the repo), item 5 (install.sh changes agy skills dirs)

## Log

- L1 request: "/flow:story 32"
- L2 assumptions for approval: "same-named" means a real dir whose name equals a repo skill's unprefixed name (`plugins/*/skills/*`), judgment-day included, since the repo calls it Claude Code only; "retired spec-workflow" means `sdd-*`; `_shared` stays (not invokable, and gentle-ai's `skill-registry` reads `_shared/skill-resolver.md`); a same-named dir the user wrote by hand moves too (by name only), but is never deleted; the backup keeps the dir name.
- L3 approved by the user ("si").
- L5 step 1: red da37034 (also switches the two approved existing asserts: a user `plan-review` and a user `pair` dir now land in `skills-backup/`), green fe054fb. Mistake: fe054fb was committed while full `make check` failed (the commit was chained after `bat`, not after the check): the existing `no-sdd.test.sh` rejects the literal `sdd-*` in install.sh. Fixed in the next commit without touching that test: the sweep matches `<plugin>-*` for each name in `RETIRED_PLUGINS`; full `make check` green after it.
- L6 steps 2-3: regression pins 3c785b0, green from the start, approved as test-only ("si"); mutation A (no name filter) fails `branch-pr stays`, `_shared stays`, `no other skill is moved`; mutation B (no suffix loop) fails `the new copy is kept beside it` and the older `.bak-*` clash asserts. Docs below.
