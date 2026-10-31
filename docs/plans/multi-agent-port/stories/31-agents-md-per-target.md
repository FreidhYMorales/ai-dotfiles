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
