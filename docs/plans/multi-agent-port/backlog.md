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
03. [ ] As a developer, I want an Antigravity subagent that can read my engram memory so that the agents I port later can use it.
04. [x] 1b42edf As a developer, I want install.sh to tell me when engram is not registered in OpenCode or Antigravity so that memory is shared across all three agents.
05. [ ] As a developer, I want `prefer-modern-cli` to block legacy tools in OpenCode and Antigravity so that every agent follows the same tool rules.
06. [ ] As a developer, I want the `make check` Stop gate in Antigravity, which lets a red pair step through and never traps me after I cancel, so that agy cannot finish on a broken tree. Requires: #05
07. [ ] As a developer, I want the session-start hooks in OpenCode and Antigravity, and `pause` in OpenCode, so that both agents start with the same context as Claude. Requires: #05
08. [ ] As a developer, I want `/flow-plan-review` to run its blind reviewer subagent in OpenCode and Antigravity so that I can review plans outside Claude. Requires: #03
09. [ ] As a developer, I want `/flow-backlog`, `/flow-story` and `/flow-pair` with the verifier in OpenCode and Antigravity so that I can build stories outside Claude. Requires: #06, #08
10. [ ] As a developer, I want every other flow and toolkit skill generated for both agents, with `/flow-plan` and `/flow-fill-gaps`, so that the whole planning path works outside Claude. Requires: #08
11. [ ] As a developer, I want `ai-update` to regenerate and relink the OpenCode and Antigravity outputs so that they never go stale after a pull. Requires: #08
12. [ ] As a developer, I want one role model map for the generated agents so that I can point the reviewers at a strong or local model without editing each agent. Requires: #08
13. [ ] As a developer, I want a recorded smoke run of a high-risk story in OpenCode and Antigravity so that I trust the fallback before I need it. Requires: #09, #10
14. [ ] As a developer, I want judgment-day and the remaining `flow-`/`toolkit-` commands in both agents so that nothing I use in Claude is missing. Requires: #10
15. [ ] As a developer, I want the README, the install.sh header and `docs/multi-agent.md` to describe the port so that I know how each agent is set up. Requires: #13
