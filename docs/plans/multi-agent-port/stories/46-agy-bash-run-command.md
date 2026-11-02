# Story 46: agy maps `Bash` to `run_command` with a proven `commandExecutionPolicy`

## Story

46. As a developer, I want `Bash` mapped to `run_command` for agy with a `commandExecutionPolicy` value proven in a live agy run (what `off` really blocks, which values agy accepts), so that the agy plan reviewer can run its read-only conversions and `git log`. Requires: #45

## Acceptance criteria

- [ ] Given a temporary sentinel agent with `run_command` for each documented `commandExecutionPolicy` value (`off`, `auto`, `eager`, `sandbox`), when `agy -p` asks it to run one command on the user's agy allow list and one harmless command that is not, then `docs/multi-agent.md` records per value whether each command ran, was refused or the subagent was not built (manual check).
- [ ] Given a source agent with `Bash`, when it is generated for Antigravity, then its `tools` include `run_command` and its `commandExecutionPolicy` is the most restrictive value under which the allow-listed command ran and the unlisted one did not; an agent without `Bash` keeps `off`.
- [ ] Given the installed build, when `agy -p` asks `flow-plan-reviewer` for the latest commit of a repo with `git log -1 --oneline`, then it returns that commit's real hash, and the docs and plan say the agy reviewer has a shell tool (manual check).

## Plan

- Claude places one sentinel per policy value (backing up the agents dir), runs `agy -p` without any permission flag, reads the subagent transcripts for each call and its result, and removes every sentinel at the end.
- The probe results decide the policy value by the rule in criterion 2; if no value meets it, `Bash` stays unmapped, the result is recorded and the story stops for a decision.
- The generator learns `Bash` → `run_command` and a per-agent policy, test first; the reviewer's golden changes with it.
- After `./install.sh`, one live run of the reviewer proves agy still builds it and that `git log` runs.
- `docs/multi-agent.md`, the plan rows and the generator comments are brought in line.

## Out of scope

- Bringing back the agy verifier or changing the agy `flow-pair` NEEDS DECISION line (#47).
- Editing the user's agy allow list or settings.
- OpenCode's tool mapping.

## Suggestions (your call)

- The user's agy allow list holds `git add` and `git commit`, and agy docs say subagents inherit the parent's allowed command prefixes: with `run_command` the "read-only" reviewer could commit without asking. Worth trimming the allow list by hand, or a later story for a per-agent allow list if agy has one.

## Size

normal
Risk: item 2, 5, 6 (a subagent gains a shell tool; the generated agent is installed into agy's config; agy's policy behaviour is only checkable by hand)

## Log

- L1 request: /flow:story 46
- L2 assumptions for approval: agy 1.4.12; the documented values are `off`, `auto`, `eager`, `sandbox` with default `sandbox` (antigravity.google/docs/subagents, 2026-11-02; the page does not say what each does); "refused" covers both a soft-denied call in `-p` and the subagent declining the tool; the allow-listed probe command is `git log -1 --oneline` and the unlisted one is `uname -r` (both read-only); Claude runs every `agy -p` itself without a permission flag; the reviewer stays the only agy agent.
- Security (item 2): input reaching a shell — the reviewer gets `run_command`; safe: the chosen policy refuses commands outside the allow list in `-p` (criterion 1 proves it, criterion 2 picks it); failure: an unlisted command runs unasked; RED: the generator test pins the chosen policy on any agent with `Bash`. Identity, secrets, repository automation, file classification: N/A (no auth, no secrets, the generator runs no git commands, no file is classified).
- L3 approved: "si".
- L4 probe (agy 1.4.12, `agy -p` from a non-repo dir, no permission flag, one sentinel per value, `model: flash`): `off`, `auto`, `eager`, `sandbox` behaved the same: `cd <repo> && git log -1 --oneline` ran and returned the real hash; `cd <repo> && uname -r` failed "permission check failed for unsandboxed ...: user denied permission to run command". No registry or policy error in the logs. All four meet criterion 2's rule; `off` is the most restrictive, so it stays. Sentinels removed; agents dir matched its backup.
- L5 cycle (mode C): 66e1d35 test (approved changes: "gets no run_command" → "gets run_command for Bash", golden gains `run_command`, comments; red: 4 cases) → 1a16e4b feat (`Bash) echo run_command`). Tamper check empty; `make check` green. Test 3 (agent without Bash keeps `off`) skipped with the user's OK: the policy is `off` for every agent, already pinned.
- L6 criterion 3, two failed attempts (agy run from a non-repo dir): (1) the installed reviewer ran `git -C <repo> log -1 --oneline`, denied (does not match the `git log` prefix); (2) asked for exactly `git log -1 --oneline` with `Cwd`, it passed no `Cwd`: the command ran but in the non-repo dir ("fatal: not a git repository"), then it wandered through agy logs and repo files. Stopped for a decision.
