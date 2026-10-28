# Story 03: an Antigravity subagent reads engram

## Story

03. As a developer, I want an Antigravity subagent that can read my engram memory so that the agents I port later can use it.

## Acceptance criteria

- [ ] Given a probe subagent in agy's agents dir with only read tools and engram's search tools, when I ask `agy -p` to delegate an engram search to it, then it returns a real observation from my memory, and `docs/multi-agent.md` records the agents dir agy 1.4.9 reads, the frontmatter it accepts, how it is invoked and the exact tool names (built-in and engram) (manual check).
- [ ] Given a probe subagent with an unknown tool name, when I invoke it with a time limit, then `docs/multi-agent.md` records what agy does (error, ignores it, or hangs) (manual check).
- [ ] Given the check is done, when I look at `~/.gemini/`, then every probe is gone and nothing else there has changed.

## Plan

- Read agy's bundled customization docs for the subagent format and tool names, then confirm each by hand like stories 01 and 02 (plant, `agy -p`, remove).
- Use engram's read-only tools only, so the check never writes to my memory.
- Run every invocation under a timeout, since a wrong tool name may hang the subagent.
- Record the findings as a table in `docs/multi-agent.md`; it becomes the input of the generator's agy tool map.

## Out of scope

- Installing or generating any real agent (the generator, story 08 on).
- `agy plugin import claude` and whether `/flow-pair` runs as a command (story 09).
- Engram registration checks in `install.sh` (story 04).
- OpenCode subagents.

## Suggestions (your call)

- agy is now 1.4.9; the rules and skills tables from stories 01 and 02 were checked on 1.4.7. A quick re-run of those sentinels is cheap, but it is not this story.

## Size

normal
Risk: item 6 (agy subagent behaviour is only checkable by hand)

## Log

- L1 request: "Podrias hacer el merge de la historia 2 a main, y seguimos con las historias?"
- L2 assumptions for approval: this story is plan item 1's subagent half only (the plugin-import half lands with story 09, which needs it); engram is already registered in agy (`agy mcp list` shows `engram`, `--tools=agent`); the probe uses read-only engram tools; no code or installer change, so no automated test.
- L3 approved by the user ("si").
- L4 test list approved: 3 manual checks (C1 probe reads engram, C2 unknown tool, C3 `~/.gemini` unchanged); no code, so no `test:`/`fix:` commits.
- L5 partial findings (agy 1.4.9, `agy -p` from an empty non-git dir, logs via `--log-file`): the bundled `agy-customizations` docs do not cover subagents; antigravity.google/docs/subagents gives the global dir `~/.gemini/config/agents/<name>.md` (or `<name>/agent.md`) and frontmatter `name`, `description`, `tools`, `mainAgent`, `subagent`, `model` (`inherit|flash|pro`), `commandExecutionPolicy`, `mcpServers`, `skills`/`plugins`. A probe there is found by `invoke_subagent` by `name:`. In `tools:`, `read_file`, `view_file`, `grep_search` resolve; `mem_search`, `mem_get_observation`, `call_mcp_tool`, `mcp_engram_mem_search` fail with `tool "<name>" not found in registry` (the names agy reports to its own model are not registry names). With engram declared under `mcpServers:` (name, command, args) the subagent starts.
- L6 C2 answer: an unknown tool name does not hang; the subagent is never built, the error is only in the log, and the main agent says it is waiting and exits 0 (silent failure).
- L7 blocker: in `-p` mode a subagent tool needing approval is soft-denied (`print mode, soft-denying`); `--mode auto` is not available for the account; Claude Code's auto-mode classifier refused to run `--dangerously-skip-permissions`, so the user ran it, and agy hit `RESOURCE_EXHAUSTED` (quota resets in ~54 h) before the subagent called engram. C1 (a real observation back) is still open.
- L8 C3 checked: probe and `~/.gemini/config/agents/` removed; a before/after path+mtime listing differs only in agy runtime state (annotations, presence, cache, implicit, updater, regenerated `mcp/engram/*.json` and `plugin_data`). Side finding: `~/.gemini/GEMINI.md` (85 KB, truncated to 23 KB) and the old `antigravity-cli/AGENTS.md` link are back, so story 01's install has not been re-run since the merge.
- L9 paused: resume when agy quota resets, with the `mcpServers:` probe and `--dangerously-skip-permissions` run by the user.
- L10 split (user: "marca la parte de agy como pendiente… así no nos detenemos solo por agy"): 03 → #16 (the format findings in L5-L6, done, 1b835b8) and #17 (C1 and the story 05 agy confirmation, waiting on agy quota). Story 08 now requires #16 instead of #03.
