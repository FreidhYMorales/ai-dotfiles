# Story 08: blind plan review in OpenCode and Antigravity

## Story

08. As a developer, I want `/flow-plan-review` to run its blind reviewer subagent in OpenCode and Antigravity so that I can review plans outside Claude. Requires: #16

## Acceptance criteria

- [ ] Given `./install.sh --target opencode`, when I run `/flow-plan-review` on a plan in OpenCode, then a fresh read-only `flow-plan-reviewer` subagent reviews it and `plan-review-<N>.md` is saved with the reviewer's structure (manual check, recorded in the story log).
- [ ] Given `./install.sh --target antigravity`, when I look in agy's agents and skills dirs, then `flow-plan-reviewer` uses only the frontmatter and registry tool names recorded in #16, and the `flow-plan-review` skill delegates through `invoke_subagent` with no Claude-only names, paths or tools left.
- [ ] Given a change to the plan-review skill or the plan-reviewer agent, when I run `make check` without regenerating the golden fixtures, or the generated output keeps a Claude-only form (`flow:` names, `../../agents/`, `${CLAUDE_PLUGIN_ROOT}`, `mcp__engram__`), then the check fails and names the file.

## Plan

- A generator reads the plan-review skill and the plan-reviewer agent and writes one output per target into a gitignored build dir, applying the name map (`flow:x` → `flow-x`), absolute quoted repo paths, target tool names and per-target agent frontmatter (read-only tools; agy `model: pro` until the role map lands).
- `make check` generates into a temp dir and compares it with committed golden fixtures, plus a leftover scan for Claude-only forms.
- `install.sh` runs the generator into a temp dir, swaps the build in atomically, links the generated agent and skill per target, and removes only its own old raw `plan-review` link.
- The `/flow-plan-review` command exists in both targets under the name map.
- `docs/multi-agent.md` stops listing plan-review as Claude-only.

## Out of scope

- Any other skill or agent through the generator (#09, #10, #14); `CLAUDE_ONLY_SKILLS` stays.
- `ai-update` regeneration (#11) and the role model map file (#12).
- A live agy run of the reviewer: blocked on agy quota, it lands with #17 / #13.
- Changing the Claude Code plugin files or their behaviour.

## Suggestions (your call)

- Keep the generator a plain bash + `sd`/`jq` script next to the other `scripts/`; the checks already follow that shape (`scripts/check-*.sh`).

## Size

normal
Risk: item 3 (build layout and name map become contracts), item 5 (install.sh writes into OpenCode and agy dirs), item 6 (the live subagent run is a manual check)

## Log

- L1 request: "/flow:story 08"
- L2 assumptions for approval: this story is plan item 4 minus `ai-update` (#11) and the role map (#12); the `/flow-plan-review` command belongs here, not in #10; agy's live run waits for quota (story 03 L7-L9), so agy is proven by format against #16 only; agy reviewer model is `pro` (plan: opus → `pro` without a map entry), OpenCode inherits; one line in `docs/multi-agent.md` follows the precedent of stories 18-20.
- L3 approved by the user ("si apruebo").
- L4 agy tool map (user: "si, la sugerida"): `Glob` and `Bash` are mapped to "not available yet" and omitted on purpose; any other unmapped tool is a generator error; `find_by_name`/`run_command` wait for #17.
- L5 test list approved ("si, apruebo la lista"): integration bash tests — 1 OpenCode agent golden, 2 OpenCode skill + command golden, 3 agy agent golden, 4 agy skill golden, 5 unmapped tool errors, 6 stale golden or Claude-only leftover fails naming the file, 7 install opencode links + drops raw link + idempotent, 8 install antigravity links + drops own raw link + keeps a user dir, 9 failed generation keeps the previous build; 10 manual OpenCode `/flow-plan-review` run. Build dir `build/agents/` (override `AI_BUILD_DIR`), written repo path overridable for goldens; agy gets the skill only (command check in #09).
- L6 manual check C1 (OpenCode 2.2.2, user ran `./install.sh --target opencode`; `opencode run --standalone --auto "/flow-plan-review docs/plans/multi-agent-port/plan.md"`, exit 0): the main agent loaded the `flow-plan-review` skill, called the `subagent` tool with `agent: flow-plan-reviewer` and "Review blind. Follow your rubric and output structure exactly.", wrote `plan-review-4.md` with the reviewer structure (Verdict, Findings, Scope vs deadline, Unnamed risks, Questions) and saved the engram summary through `tools.engram.mem_save`. Pass.
