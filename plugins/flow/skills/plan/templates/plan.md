# Plan: <feature>

- Status: draft | reviewed | approved
- Deadline: <date>
- Mode: solo | collaborative (<n> people)
- Supersedes: <earlier proposal items this plan replaces, or "none">

## Research

<Short findings brief from /flow:research, or "not run". Mark each item v1 or v2.>

## Product vision

- **v1 (deliverable by deadline):** <what it does and why it matters>
- **v2 (later):** <what v1 data/features enable next>

## Core model

<Entities, relations, key events. Keep it to a short list or ASCII diagram.>

## Foundation

<Summary from /flow:foundation: stack, architecture style, key conventions; links to docs/architecture.md, docs/adr/, AGENTS.md. "n/a" for existing projects with established conventions.>

## Screens

### <Screen name>

```
<chosen ASCII wireframe, final mix>
```

- Chosen: <e.g. B with A's list>
- Rules: <behavior, validation, navigation>
- States: empty | loading | error | offline -> <what each shows>

| UI element | Backend demand |
|---|---|
| <e.g. ETA per stop> | <e.g. per-stop ETA computed from segment times> |

<Repeat per screen.>

## Data captured / data inventory

| Screen | Data shown | Actions (events) | Source |
|---|---|---|---|

## Scope

| Item | Priority (MUST/SHOULD/LATER) | Est. dev-days | Demo value |
|---|---|---|---|

## Demo data

<Seed data needed to demo every MUST screen and state; format and where it lives.>

## Data gaps & assumptions

| Gap | Assumption | Owner | Resolved? |
|---|---|---|---|

## Deferred to v2

- <item> — <why deferred>

## Demo priorities

1. <what the evaluator must see first>

## Collaboration

- Mode: solo | collaborative
- People: <filled by /flow:split>
- Frozen contracts: <links to schema/types/I-O/seed files>
- Work packages: <links to docs/work-packages/*.md>

## Plan-review resolutions

| # | Finding | Resolution | Decided by |
|---|---|---|---|
