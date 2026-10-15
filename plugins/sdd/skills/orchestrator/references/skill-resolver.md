# Skill Resolver

Any agent that **delegates work to sub-agents** uses this protocol to pass relevant skills.

## Why This Exists

Sub-agents start with no skill context. The delegator already sees the session's available-skills list (user, project, and plugin skills), so it selects the relevant ones and tells the sub-agent exactly what to load.

## When to Apply

Before every sub-agent launch that reads, writes, reviews, tests, documents, or creates project artifacts. Skip only for purely mechanical commands.

## The Protocol

### Step 1: Collect Candidates

Use the skills listed in your own session context (name + description/trigger). Also consider project conventions the sub-agent must honor: `AGENTS.md`, project `CLAUDE.md`, and files they reference.

### Step 2: Match Relevant Skills

| Context | Match against |
| --- | --- |
| Code/files | Skill trigger/description mentions the language, framework, tool, or path |
| Task/action | Skill trigger/description mentions PRs, review, docs, tests, comments, commits |

Prefer the smallest useful set (at most five; code context beats task context). Never pass SDD phase skills (`sdd-*`) or `sdd:orchestrator` to phase agents; they load their own phase skill.

### Step 3: Pass Skill Names (and Paths When Known)

```markdown
## Skills to load before work

Load these with the Skill tool before reading, writing, reviewing, testing, or creating artifacts:

- toolkit:go-testing
- typescript   (path: /abs/path/.claude/skills/typescript/SKILL.md)
```

Plugin skills are referenced by their namespaced name (`<plugin>:<skill>`). For user/project skills, add the absolute `SKILL.md` path so a sub-agent without the Skill tool can Read it instead. `SKILL.md` is the source of truth; never pass summaries.

### Step 4: Report Resolution

Sub-agents report `skill_resolution`:

- `paths-injected` — received a skills block and loaded every listed skill.
- `self-resolved` — no block received; loaded skills it matched itself.
- `none` — no skills loaded.

If a sub-agent reports anything other than `paths-injected`, re-check the skill selection before the next delegation.
