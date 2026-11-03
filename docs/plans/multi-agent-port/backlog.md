# Backlog: multi-agent-port

## Context

- What: run the same workflow in OpenCode and Antigravity CLI when Claude quota runs out, generated from this repo's plugins. Plan: `docs/plans/multi-agent-port/plan.md`.
- Stack: bash generator and installer, jq, OpenCode TS plugin, Claude Code plugins as the source, `make check`.
- Expensive decisions: the build layout and the name map (`flow:x` → `flow-x`, `toolkit:x` → `toolkit-x`) become contracts for both targets; the installer writes into configs other tools own (agy `hooks.json`, skills dirs), so it merges and moves, never deletes.
- Test command: `make check`
- Single test: `bash scripts/tests/<name>.test.sh`

## Backlog

01. [x] e56a79d As a developer, I want Antigravity to load my rules from the paths it really reads so that it follows the same rules as Claude when my quota runs out.
02. [x] 02cfca9 As a developer, I want gentle-ai's moved-aside skills kept outside the skills discovery dirs so that they never shadow the repo skills and nothing of gentle-ai is lost. Requires: #01
03. [-] split → #16, #17
04. [x] 1b42edf As a developer, I want install.sh to tell me when engram is not registered in OpenCode or Antigravity so that memory is shared across all three agents.
05. [x] 9b9dd16 As a developer, I want `prefer-modern-cli` to block legacy tools in OpenCode and Antigravity so that every agent follows the same tool rules.
06. [x] 438f13f As a developer, I want the `make check` Stop gate in Antigravity, which lets a red pair step through and never traps me after I cancel, so that agy cannot finish on a broken tree. Requires: #05
07. [-] split → #18, #19, #20
08. [x] 7132f0a As a developer, I want `/flow-plan-review` to run its blind reviewer subagent in OpenCode and Antigravity so that I can review plans outside Claude. Requires: #16
09. [-] split → #27, #28, #29
10. [-] split → #30, #31, #32
11. [x] 94eecc5 As a developer, I want `ai-update` to regenerate and relink the OpenCode and Antigravity outputs so that they never go stale after a pull. Requires: #08
12. [x] e51be8f As a developer, I want one role model map for the generated agents so that I can point the reviewers at a strong or local model without editing each agent. Requires: #08
13. [x] a509777 As a developer, I want a recorded smoke run of a high-risk story in OpenCode and Antigravity so that I trust the fallback before I need it. Requires: #27, #28, #29, #30, #31, #32, #12
14. [~] As a developer, I want the remaining `flow-`/`toolkit-` commands in OpenCode, checked against its built-in commands, so that nothing I use in Claude is missing there (judgment-day stays Claude-only until v2). Requires: #30
15. [ ] As a developer, I want the README, the install.sh header and `docs/multi-agent.md` to describe the port so that I know how each agent is set up. Requires: #30, #31, #32
16. [x] 1b835b8 As a developer, I want the Antigravity subagent format recorded (agents dir, frontmatter, tool names agy resolves, engram through `mcpServers:`) so that the agents I port later use names agy accepts.
17. [-] split → #39, #40, #41, #42
18. [x] a671015 As a developer, I want the session-start hooks (host info, pack hint, backup status) in Antigravity so that agy starts with the same context as Claude. Requires: #05
19. [x] cb83ca5 As a developer, I want the session-start hooks (host info, pack hint, backup status) in OpenCode so that OpenCode starts with the same context as Claude. Requires: #05
20. [x] 65a0908 As a developer, I want `pause` in OpenCode so that I can stop an OpenCode session safely with a checkpoint saved. Requires: #19
21. [x] 5e00538 As a developer, I want the OpenCode pause hook to skip a user message without an id instead of throwing so that a malformed history never breaks a session. Requires: #20
22. [-] split → #34, #35, #36
23. [-] split → #24, #25, #26
24. [x] 0f05602 As a developer, I want the generator to turn bare support-file references into absolute repo paths only when the file exists in that skill's dir, with `verify.sh` flagging any it missed, so that generated skills never point at missing files and skill-creator's layout prose stays intact. Requires: #08
25. [x] b456554 As a developer, I want agy agents to declare engram under `mcpServers:` and a `commandExecutionPolicy` each, and the agy `flow-pair` to say a high-risk story ends in NEEDS DECISION while its verifier has no shell tool, so that agy agents reach memory and never pretend to verify. Requires: #08, #16
26. [x] aedf102 As a developer, I want `pair` to treat an empty or missing verifier report as NEEDS DECISION, never PASS, checked with `make eval`, so that a silent verifier never passes a story in any agent.
27. [x] 133cd5a As a developer, I want `/flow-backlog`, `/flow-story` and `/flow-pair` with the `flow-verifier` subagent generated for OpenCode and Antigravity, with judgment-day the only Claude-only skill left, so that I can build stories outside Claude. Requires: #06, #08, #24, #25, #26
28. [x] c0c12f7 As a developer, I want the OpenCode `flow-verifier` limited to read-only shell commands (`git log/diff/show`, `rg`, `make check`) and unable to start subagents so that the verifier stays read-only outside Claude. Requires: #27
29. [x] 47a4b43 As a developer, I want the generated `flow-pair` to let a skill story close with "make eval pending (needs Claude)" in its log, and `/flow:next` to list pending evals, so that a skill story is not blocked outside Claude and the eval is not forgotten. Requires: #27
30. [x] 97eb413 As a developer, I want every other flow and toolkit skill generated for OpenCode and Antigravity, with `/flow-plan` and `/flow-fill-gaps` commands, so that the whole planning path works outside Claude. Requires: #08, #24, #27
31. [x] 8423663 As a developer, I want `AGENTS.md` generated per target with its rule lines (OpenCode runs `make check` before saying done as `require-check` does, agy follows the pause protocol, `/flow:x` means `/flow-x` in raw support files) so that OpenCode and agy close work by the same rules as Claude. Requires: #08
32. [x] 67f25d2 As a developer, I want gentle-ai's same-named and retired spec-workflow skills moved out of the three agy skills discovery dirs into `skills-backup/`, never deleted, so that no gentle-ai copy loads beside the prefixed repo skills. Requires: #30
33. [x] 0bfc27d As a developer, I want `install.test.sh` split into files that run in parallel so that `make check` takes about a minute and the Stop gate never times out on a turn end.
34. [x] 11bb719 As a developer, I want each OpenCode hook cut off at its timeout, with a timed-out shell check letting the call through, so that a stuck hook never freezes an OpenCode session. Requires: #19, #20
35. [x] 4461543 As a developer, I want the installer to sweep `.bak-*` out of all three agy skills dirs, write agy `hooks.json` through `mktemp`, and warn with the re-run command when agy is not the pinned 1.4.9, so that a second install or an agy upgrade never breaks a session. Requires: #08
36. [x] 5eb4595 As a developer, I want generated links pruned when the build dir is outside the repo so that a custom `AI_BUILD_DIR` never leaves dangling links. Requires: #08
37. [x] de571cb As a developer, I want the Antigravity `flow-pair` to end a high-risk story in NEEDS DECISION without trusting a verifier that cannot run the test command, so that agy never closes a high-risk story on an unverified PASS. Requires: #25, #27
38. [x] 59b2a85 As a developer, I want the `flow-verifier` agent left out of the Antigravity build and install, so that no shell-less agy subagent can hand pair a made-up PASS. Requires: #37
39. [x] 78f1a76 As a developer, I want the Antigravity PreToolUse hook checked in a real agy session (first a `deny` probe under `--dangerously-skip-permissions`, every agy hook check recorded "unproven" if the flag bypasses it; then the payload agy really sends and the toolkit hook's `ask` answer) so that the agy tool rules rest on proven behaviour. Requires: #05, #16
40. [x] 0d7de12 As a developer, I want the Antigravity Stop gate and session-start hook checked in a real agy session (the gate continues on a failing check, lets a cancel stop, and what `executionNum` counts; the session-start context arrives) so that agy's turn end and session start rest on proven behaviour. Requires: #06, #18, #39
41. [x] 602beec As a developer, I want the agy rules and skills sentinels re-run on the installed agy version, plus whether agy discovers a `.bak-*` file in its agents dir, so that the installer links only paths the current agy really reads. Requires: #16
42. [x] a6a5c4c As a developer, I want a real agy subagent to return an engram observation through `mcpServers:`, and `find_by_name` and `run_command` checked in agy's registry, so that ported agents reach memory and later get the tools they need. Requires: #16
43. [x] 143a6c5 As a developer, I want the agy Stop gate to treat `executionNum` 0 as a normal turn end and 1 or more as a re-entry, so that a failing `make check` really holds an agy turn (story #40 saw agy send 0 on every normal turn end, so the gate never runs; with that rule a `continue` forced by another Stop hook makes the gate skip its check, so decide whether that is acceptable). Requires: #06, #40
44. [-] split → #45, #46, #47
45. [x] 70312d8 As a developer, I want the generator to map `Glob` to `find_by_name` for agy, so that the agy plan reviewer can list files the way it does in Claude. Requires: #42
46. [x] 1a16e4b As a developer, I want `Bash` mapped to `run_command` for agy with a `commandExecutionPolicy` value proven in a live agy run (what `off` really blocks, which values agy accepts), so that the agy plan reviewer can run its read-only conversions and `git log`. Requires: #45
47. [-] parked: agy work frozen by the user on 2026-11-02 (little expected use; OpenCode is the secondary agent). As a developer, I want to decide whether the agy `flow-verifier` comes back once agents get `run_command`, and if so build it and re-run the high-risk smoke on it, so that agy closes a high-risk story only on a verifier that really ran `make check` (#13 and #38 saw a shell-less one fake PASS). Requires: #46
48. [x] a32d3dc As a developer, I want the OpenCode hook-timeout tests to pass on the CI runner under the parallel suite while still proving each hook is cut off at its timeout, so that `main` is green again and a real failure is not hidden by a known flake (CI red since d3993c5: "the pack hint is cut off at its 2 s timeout (took 4s)", "the pause hook ... (took 7s)"). Requires: #34
