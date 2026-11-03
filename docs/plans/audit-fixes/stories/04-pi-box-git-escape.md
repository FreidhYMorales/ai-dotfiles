# Story 04: pi-box cannot plant host git config

## Story

04. As the dotfiles owner, I want a sandboxed pi worker unable to plant git config that runs on my host, so that pi-box keeps its isolation promise. (idea 07)

## Acceptance criteria

- [ ] Given a git project opened in pi-box, when the boxed command tries to change the repository's git config or add a git hook, then the attempt fails and the host repository's config and hooks are unchanged.
- [ ] Given a git project opened in pi-box, when the boxed command edits and creates project files, then the edits land on the host and `git status` / `git diff` run on the host show them, as delegate-local and the worker bench expect.
- [ ] Given a folder outside git opened in pi-box, when the boxed command writes a file, then pi-box still starts and the write lands (no regression from the git protection).

## Plan

- The sandbox keeps the project writable but exposes the repository's git metadata read-only.
- Escape tests plant the two vectors the audit found (`core.fsmonitor` in the config, a hook script) and check the host copy stays untouched.
- A positive test keeps the worker flow alive: files written in the box are visible to host git.
- The header comment of pi-box names `.git` among the read-only parts.
- Assumption: no pi workflow writes to `.git` inside the box (idea 07 flagged it unverified; delegate-local steps 4-6 and the worker bench only read git state on the host).

## Out of scope

- Hardening the host side of delegate-local (`git -c core.fsmonitor= ...` flags in the skill): the sandbox fix closes the hole at its source.
- Nested repositories or submodules a worker might create inside the project.
- Accepted risk (user, 2026-11-03, verifier pass 1): pi-box opened in a folder outside git can `git init` and plant `core.fsmonitor`, which a later host `git status` there runs. Fixing it needs its own design call (refuse or warn); left for a separate story.
- Follow-up (user, 2026-11-03, verifier pass 3): a hooksPath equal to the project root, `include.path` / `includeIf` targets of the global config, symlink chains that pass through the project, and a relative global hooksPath that climbs (`../`) into the project from another repo (verifier pass 5). None applies to the current setup; to be triaged with `/flow:idea`, weighing "pi-box only opens throwaway clones" instead of path enumeration.
- Workers committing inside the box: nothing in delegate-local or the bench needs it (diffs are taken on the host).
- Network, HOME or `/tmp` confinement changes.

## Suggestions (your call)

- If the `.git` entry is a file (a worktree or submodule pointer) rather than a directory, the real git dir lives outside the project and is already invisible; the read-only bind can be skipped quietly in that case.

## Size

normal
Risk: item 2 (sandbox escape to unsandboxed code execution on the host)

## Log

- L1 request: /flow:story 04
- L2 test list approved: (1) git config/hook/.git swap planted in box never reach host; (2) host git status/diff see box edits (guard); (3) non-git folder covered by existing case.
- L3 f7d6bac test (red: 3 FAIL) → 95e3184 fix (ro-bind .git); 6581b95 guard test (CA2, green on arrival, bites against a ro-project mutation). make check: All checks passed (7 steps).
- L4 verifier pass 1: NEEDS DECISION. Bypass 1: core.hooksPath inside the project (this repo's git-hooks/ is the global hooksPath). Bypass 2: non-git folder `git init` + core.fsmonitor. User: fix 1, accept 2 as risk (Out of scope).
- L5 671d398 test (red: hooksPath writable) → bf5f1ee fix (ro-bind resolved hooksPath inside root). make check green.
- L6 verifier pass 2: FAIL. Bypass A: hooksPath inside root that does not exist yet (`--ro-bind-try` skips it; box creates it). Bypass B: hooksPath two+ levels deep (box renames the parent folder). Also: ~/.gitconfig symlinks into ~/Mio/Configuraciones (a git repo); pi-box opened there can rewrite the global git config. Second FAIL → NEEDS DECISION, stopped.
- Risk: item 2 (sandbox escape to unsandboxed code execution on the host)
- L7 user: A/B/C in scope. e2caa16 → 6c77003 (A: refuse a missing hooksPath inside root); 117b7a1 → 1e20487 (B: ro-bind the top folder below root); 7c1b2a8 → 5c19f76 (C: `protect` helper also covers ~/.gitconfig / GIT_CONFIG_GLOBAL and XDG git config). make check green each step; probed on the real repo: box cannot write git-hooks/ or .git/config.
- L8 verifier pass 3: FAIL. D: `.git` file pointing to a gitdir inside the project (bare + worktree layout) leaves that gitdir's config writable when a hooksPath is set (reproduced by the driver). E: a local core.hooksPath hides a global one inside the project. Follow-up candidates: hooksPath == project root, include.path/includeIf targets, symlink chains through the project. Stopped for a user decision.
- L9 user: fix D and E here, exotic cases to follow-up. 6ed1306 → 0a58fca (D: protect --git-dir / --git-common-dir); 01d7500 → 9060ea1 (E: protect the absolute global hooksPath). Verifier pass 4: FAIL, 9060ea1 broke C3 with a relative global hooksPath. f95b02e → 2a1c0ea (only an absolute global hooksPath is protected).
- L10 verifier pass 5: PASS (C1, C2, C3 at HEAD; red before fix confirmed for every pair; tamper check clean on all 9 test commits). make check: All checks passed (7 steps); pi-box.test.sh: All cases passed.
- Risk: item 2 (sandbox escape to unsandboxed code execution on the host)
