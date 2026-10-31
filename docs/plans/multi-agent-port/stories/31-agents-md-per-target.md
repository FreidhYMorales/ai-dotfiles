# Story 31: AGENTS.md per target with its rule lines

## Story

31. As a developer, I want `AGENTS.md` generated per target with its rule lines (OpenCode runs `make check` before saying done as `require-check` does, agy follows the pause protocol, `/flow:x` means `/flow-x` in raw support files) so that OpenCode and agy close work by the same rules as Claude. Requires: #08

## Acceptance criteria

- [ ] Given `./install.sh --target opencode`, when I open `~/.config/opencode/AGENTS.md`, then it holds the shared rules with `/flow-x` names, a line saying `/flow:x` in a skill's support files means `/flow-x`, and a rule to run `make check` before saying done when the repo root Makefile has a `check` target and the tree is dirty, skipped while the `flow-pair-red` marker names the current branch.
- [ ] Given `./install.sh --target antigravity`, when I open `~/.gemini/config/AGENTS.md`, then it holds the same rules and `/flow:x` line plus a rule that a message starting with "pausa"/"pausar"/"pause" saves an engram checkpoint (topic `checkpoint/pause`), starts no new work and replies in at most 5 lines, with resume by `agy --continue`; and it has no `make check` rule (agy has the Stop gate, #06).
- [ ] Given a change to the shared rules, when I run `make check` without regenerating the golden fixtures, or the generated rules keep a Claude-only form, then the check fails and names the file.

## Plan

- The generator reads the shared rules once and writes one `AGENTS.md` per target through the existing name map and Claude-only checks, with a golden each.
- Each target gets only the rule lines its hooks do not cover: OpenCode the `make check` line (it has `pause`, #20), agy the pause line (it has the Stop gate, #06); both get the `/flow:x` → `/flow-x` line.
- The installer links the generated `AGENTS.md` at the paths it already uses for each target; the raw link is replaced, and the agy cleanup of the unread `antigravity-cli/AGENTS.md` stays.
- `docs/multi-agent.md` says the targets read a generated rules file, not the raw symlink.

## Out of scope

- Claude's `~/.claude/CLAUDE.md` and the repo-root `AGENTS.md` symlink: unchanged.
- Generated support files with target names (plan item 8b).
- Moving gentle-ai skills aside (#32), `ai-update` (#11), OpenCode commands for other skills (#14).
- A live run proving the models follow the rule lines: that is the smoke run (#13).

## Suggestions (your call)

- `pause.sh` already holds the protocol text (no new work, at most 5 lines, what is running, uncommitted changes, how to resume); the agy line can reuse its wording so both stay alike.

## Size

normal
Risk: item 3 (the rules file both agents load), item 5 (install.sh relinks the rules in OpenCode and agy dirs), item 6 (whether a model follows a rule line is not caught by a test here)

## Log

- L1 request: "/flow:story 31"
- L2 assumptions for approval: the source is `claude/CLAUDE.md` (the repo-root `AGENTS.md` links to it); agy has no prompt-submit hook, so its pause line tells the agent to save the checkpoint itself with engram; `agy --continue` is the resume command (`agy --help`, 1.4.9: "Continue the most recent conversation"); the OpenCode rule line has no cache of the last green tree (only `require-check` has one).
- L3 approved by the user ("si apruebo").
- L4 test list approved ("si"): gen-agents 1 OpenCode `AGENTS.md` golden with the `make check` and `/flow:<skill>` lines and no pause line, 2 agy `AGENTS.md` golden with the pause and `/flow:<skill>` lines and no `make check` line; install 3 OpenCode rules link is the generated file and an earlier raw link leaves no `.bak-*`, 4 the same for agy. C3 needs no new test: `verify.sh` compares the whole tree and scans all output for Claude-only forms.
- L5 step 1 red e3c3f06. Stop rule 3: the generator now reads `claude/CLAUDE.md` from `GEN_SOURCE`, but seven existing fixtures in gen-agents.test.sh copy only `plugins/flow` and `plugins/toolkit`, so the generator exits 1 there (as in #27 L7). Needs the user: change those fixtures to also copy `claude/`, or another way.
- L6 steps: 1 red e3c3f06, approved fixture change 2796837 (each source fixture also copies `claude/`, user: "si, lo apruebo"), green fecdc41; 2 f693f72 → 32fc249; 3 2632dad → 90d4abe (`link_rules` removes only our raw rules link, so no `.bak-*`); 4 9139399 → 8423663. Docs ad-hoc commit below. Full `make check` took 326s, over the 300s require-check Stop hook timeout, so the hook reports a timeout whenever a turn ends with a dirty tree (not a failing test; see suggestions).
