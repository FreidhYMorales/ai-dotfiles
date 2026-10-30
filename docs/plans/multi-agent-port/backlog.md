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
09. [ ] As a developer, I want `/flow-backlog`, `/flow-story` and `/flow-pair` with the verifier in OpenCode and Antigravity so that I can build stories outside Claude. Requires: #06, #08, #24, #25, #26
10. [ ] As a developer, I want every other flow and toolkit skill generated for both agents, with `/flow-plan` and `/flow-fill-gaps`, so that the whole planning path works outside Claude (gentle-ai copies with the same names and its retired spec-workflow skills moved aside in agy). Requires: #08, #24
11. [ ] As a developer, I want `ai-update` to regenerate and relink the OpenCode and Antigravity outputs so that they never go stale after a pull. Requires: #08
12. [ ] As a developer, I want one role model map for the generated agents so that I can point the reviewers at a strong or local model without editing each agent. Requires: #08
13. [ ] As a developer, I want a recorded smoke run of a high-risk story in OpenCode and Antigravity so that I trust the fallback before I need it. Requires: #09, #10, #12
14. [ ] As a developer, I want the remaining `flow-`/`toolkit-` commands in OpenCode, checked against its built-in commands, so that nothing I use in Claude is missing there (judgment-day stays Claude-only until v2). Requires: #10
15. [ ] As a developer, I want the README, the install.sh header and `docs/multi-agent.md` to describe the port so that I know how each agent is set up. Requires: #10
16. [x] 1b835b8 As a developer, I want the Antigravity subagent format recorded (agents dir, frontmatter, tool names agy resolves, engram through `mcpServers:`) so that the agents I port later use names agy accepts.
17. [ ] As a developer, I want the Antigravity checks that need agy quota run in a real agy session (first a PreToolUse `deny` probe under `--dangerously-skip-permissions`, hook checks recorded "unproven" if the flag bypasses it; a subagent returns a real engram observation; the PreToolUse payload and the `ask` answer of the toolkit hook; the Stop gate continues on a failing check and lets a cancel stop; the session-start context arrives; the rules and skills sentinels on 1.4.9; a `.bak-*` file in the agents dir; `find_by_name` and `run_command` in the registry) so that the agy port rests on proven behaviour. Requires: #16, #06, #18
18. [x] a671015 As a developer, I want the session-start hooks (host info, pack hint, backup status) in Antigravity so that agy starts with the same context as Claude. Requires: #05
19. [x] cb83ca5 As a developer, I want the session-start hooks (host info, pack hint, backup status) in OpenCode so that OpenCode starts with the same context as Claude. Requires: #05
20. [x] 65a0908 As a developer, I want `pause` in OpenCode so that I can stop an OpenCode session safely with a checkpoint saved. Requires: #19
21. [ ] As a developer, I want the OpenCode pause hook to skip a user message without an id instead of throwing so that a malformed history never breaks a session. Requires: #20
22. [ ] As a developer, I want the OpenCode hooks cut off at their timeouts and the installer hardened (all three agy skills dirs swept of `.bak-*`, agy `hooks.json` written through `mktemp`, generated links pruned when the build dir is outside the repo, a warning when agy is not the pinned 1.4.9) so that a stuck hook or a second install never breaks a session. Requires: #08
23. [-] split → #24, #25, #26
24. [x] 0f05602 As a developer, I want the generator to turn bare support-file references into absolute repo paths only when the file exists in that skill's dir, with `verify.sh` flagging any it missed, so that generated skills never point at missing files and skill-creator's layout prose stays intact. Requires: #08
25. [x] b456554 As a developer, I want agy agents to declare engram under `mcpServers:` and a `commandExecutionPolicy` each, and the agy `flow-pair` to say a high-risk story ends in NEEDS DECISION while its verifier has no shell tool, so that agy agents reach memory and never pretend to verify. Requires: #08, #16
26. [ ] As a developer, I want `pair` to treat an empty or missing verifier report as NEEDS DECISION, never PASS, checked with `make eval`, so that a silent verifier never passes a story in any agent.
