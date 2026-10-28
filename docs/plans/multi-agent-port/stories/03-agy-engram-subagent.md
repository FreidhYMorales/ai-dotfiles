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
