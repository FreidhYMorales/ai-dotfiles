# Story 42: agy subagent reaches engram; `find_by_name` and `run_command` in the registry

## Story

42. As a developer, I want a real agy subagent to return an engram observation through `mcpServers:`, and `find_by_name` and `run_command` checked in agy's registry, so that ported agents reach memory and later get the tools they need. Requires: #16

## Acceptance criteria

- [x] Given a temporary sentinel agent in agy's agents dir that declares engram under `mcpServers:` exactly as the generator emits it, when `agy -p` asks it for an existing engram observation by ID, then it returns that observation's exact title, and `docs/multi-agent.md` records the result with the agy version and date (manual check).
- [x] Given a temporary sentinel agent whose `tools` are `find_by_name` and `run_command`, plus a control agent with only proven names, when `agy -p` asks each to find a file and run a harmless read-only command, then `docs/multi-agent.md` records, per tool, whether agy built the subagent and whether the tool ran, from the answer and agy's log (manual check).
- [x] Given the results, when they are recorded, then the "wait for #17" wording in the docs, the plan and the generator comment names what is now proven, and if both tools are proven a new backlog story covers mapping `Glob`/`Bash` for agy; the generated output does not change.

## Plan

- Claude places the sentinel agents (backing up anything they would touch), runs `agy -p` for each, reads agy's log for build errors, and removes every sentinel at the end, leaving the agents dir as before.
- The engram check only reads: it asks for an observation that already exists, so nothing new lands in memory; a made-up answer is caught because the exact title must match.
- Results go into `docs/multi-agent.md` as a short table next to the existing agy subagent rows; the plan's open-risk rows and the comment above the agy tool map are brought in line.
- Any mismatch (engram not reached, a tool missing from the registry, a soft-denied call) is recorded as is; follow-up work becomes a new backlog story, nothing is fixed here.

## Out of scope

- Mapping `Glob`/`Bash` in the generator, regenerating goldens, or bringing back the agy verifier (a new story if the tools are proven).
- Porting judgment-day or its `jd-*` agents to agy (v2).
- Hooks, rules and skills discovery (#39, #40, #41, #43).

## Suggestions (your call)

- None.

## Size

normal
Risk: item 5, 6 (temporary sentinel agents in agy's config dir; agy's registry and MCP wiring are only checkable by hand)

## Log

- L1 request: /flow:story 42
- L2 assumptions for approval: the installed agy is 1.4.12; Claude runs `agy -p` itself, and if `-p` soft-denies a tool call the user reruns that one case with `--dangerously-skip-permissions`; a tool counts as in the registry when agy builds the subagent with no registry error in its log, even if `-p` then soft-denies the call; this story only records, the tool mapping is a later story.
- L3 approved: "si, lo apruebo".
- L4 manual (agy 1.4.12, Gemini 3.8 Flash, `agy -p` outside any repo, no permission flag): four temporary sentinels in `~/.gemini/config/agents/`. Engram: the subagent called `call_mcp_tool` (engram `mem_get_observation`, id 762) and returned the exact title "multi-agent-port: agy-quota checks parked as story 17"; the main agent called no engram tool; nothing saved. `find_by_name` and `run_command` subagents were built and ran (`run_command` returned the file's random token; `bat` is in the user's agy allow list); the `view_file` control returned the same token; no registry error in any log. Sentinels removed; the agents dir matched its backup.
- L5 commits: 68cb342 docs (results table, plan, generator comment; backlog #44 for mapping `Glob`/`Bash`); a6a5c4c docs (three stale "#17" notes the verifier found). No test/feat pair: the approved test list was manual plus the existing goldens. `make check`: "All checks passed (7 steps)".
- L6 verifier: first FAIL (C3: stale "#17" wording at plan.md:47, gen.sh:77, gen.sh:202), fixed in a6a5c4c; recheck PASS. Note: the `find_by_name` row's answer (a path) is only loosely "a value the prompt did not contain"; the call itself is in the transcript.
- Risk: item 5, 6 (temporary sentinel agents in agy's config dir; agy's registry and MCP wiring are only checkable by hand)
