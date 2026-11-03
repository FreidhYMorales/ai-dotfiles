# Story 14: remaining OpenCode commands

## Story

14. As a developer, I want the remaining `flow-`/`toolkit-` commands in OpenCode, checked against its built-in commands, so that nothing I use in Claude is missing there (judgment-day stays Claude-only until v2). Requires: #30

## Acceptance criteria

- [ ] Given `./install.sh --target opencode`, when I look in OpenCode's commands dir, then every generated flow and toolkit skill has a command of the same `flow-`/`toolkit-` name that loads it, and judgment-day has none.
- [ ] Given a generated command whose name matches an OpenCode built-in command, when I run `make check`, then the check fails and names the colliding command.
- [ ] Given OpenCode after install, when I run one of the new commands (`/flow-next`), then its generated skill loads by its prefixed name (manual check, recorded in the story log).

## Plan

- The generator emits a command for each OpenCode skill that has none yet: `toolkit-work-unit-commits`, the 8 remaining flow skills and the 9 remaining toolkit skills, the same way the 6 existing commands are made; a golden each.
- A test compares every generated OpenCode command name with OpenCode's built-in command list and fails on a match.
- The installer already links the generated commands dir; only its expectations change if the new links need asserting.
- `docs/multi-agent.md` says every ported skill has an OpenCode command.

## Out of scope

- judgment-day and the `jd-*` agents in any target (v2).
- Antigravity commands: agy reaches skills by skill expansion (#27 L10, agy work frozen).
- Changing any skill's text or the Claude Code plugin files.
- README and install.sh header docs (#15).

## Suggestions (your call)

- `gen.sh` loops `skill opencode` over `FLOW_REST` and `TOOLKIT_REST` (lines 259-264); switching those loops and the `work-unit-commits` line to `opencode_skill` is likely the whole generator change.

## Size

normal
Risk: item 3 (command names OpenCode parses), item 6 (the live command run is a manual check)

## Log

- L1 request: "/flow:story 14"
- L2 assumptions for approval: "remaining" means the 18 OpenCode skills without a command today (work-unit-commits, research, handoff, next, idea, split, integrate, foundation, bootstrap, ship, chained-pr, cli-tools, cognitive-doc-design, comment-writer, delegate-local, go-testing, skill-creator, skill-improver); the built-in list is taken from the installed OpenCode (v2.2.5) and written into the test, with the version named; the manual check mirrors #30 L8 (`opencode run` on a toy repo in the scratchpad); `pair` keeps its existing command and `disable-model-invocation` mapping.
- L3 approved by the user ("si").
- L4 test list approved ("si"): 1 gen-agents the 18 new command goldens, `/flow-next` loads `flow-next`, no `toolkit-judgment-day` command; 2 install-opencode the 18 command links are the generated ones (one red step with 1); 3 gen-agents no generated command shares a name with an OpenCode 2.2.5 built-in, green from the start by construction (prefixed names), proven by mutation; 4 manual `/flow-next`. Built-in list read from the 2.2.5 binary (`slash:{name:...}` entries with aliases, plus server `init` and `review`); `/pair` (alias `/web`) is a built-in.
- L5 steps: 1+2 red 0bae662 (19 and 18 cases failed: command files missing), green 06a4952 (gen.sh calls `opencode_skill` for work-unit-commits and both loops; goldens regenerated, only the 18 new command files changed); 3 guard c8add8a, a mutation that copied `flow-pair.md` to `pair.md` in gen.sh failed with `colliding: commands/pair.md`, reverted. Docs c1af046.
- L6 manual check C3 (OpenCode 2.2.5, toy repo in the session scratchpad; the user ran `./install.sh --target opencode`, which linked the 18 new commands): PASS. The default OpenAI model hit its usage limit (429), so the run used `-m opencode/big-pickle --standalone` as in #30 L8. `/flow-next` called `skill flow-next` as its first tool call, read the backlog, listed #02 and #04 Ready and #03 blocked on #04, and named `/flow-story 02` and `/flow-pair 02`.
- L7 check: `make check </dev/null` → "All checks passed (7 steps)". Verifier (flow:verifier, fresh): PASS (C1 pass; C2 pass with the approved green-by-construction guard proven by mutation; C3 pass by the manual run in L6; commit order and tamper check pass). Note: the built-in list is hand-kept for OpenCode 2.2.5 and needs a refresh on an OpenCode upgrade.
- L8 evidence: test→code pair 0bae662→06a4952; guard c8add8a; docs c1af046; log 9c53626. No skill source changed, so no `make eval`.
- Risk: item 3 (command names OpenCode parses), item 6 (the live command run is a manual check)
