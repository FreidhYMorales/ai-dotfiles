# Architecture: <project>

- Status: draft | approved
- Mode: greenfield | audit (existing stack)
- Last updated: <date>
- ADRs: [docs/adr/](adr/)

## Constraints

| Constraint | Value |
|---|---|
| Deadline | <date> |
| Team | <n people; skills per person> |
| Hosting / budget | <e.g. free tier, Vercel + Supabase> |
| Required capabilities | <offline, maps, realtime, auth...> |
| Target devices | <phone, desktop, both> |

## Stack

| Layer | Choice | Why (ADR) |
|---|---|---|
| Language | <e.g. TypeScript> | <ADR-0001> |
| Frontend | | |
| Backend / data | | |
| Key libraries | | |

## Architecture style

<Style name (e.g. feature-based "screaming"), and one line on why it is proportional. Note what was rejected as over-engineering.>

```
<folder tree>
```

| Folder | What goes here | What must NOT go here |
|---|---|---|

## Conventions

- Naming: <files, components, functions, constants>
- Formatter / linter: <exact tools and config files>
- Commits: conventional commits, no AI attribution
- Branching / PR flow: <e.g. feature branches -> PR -> 1 review -> squash merge>
- Dependencies: allowlist; no new dependency without approval
- Contracts: <paths>; never changed without agreement

## Testing

| Layer | Tool | What MUST be tested | Command |
|---|---|---|---|
| Unit / domain | | Domain logic | |
| Contract | | Shared types, API I/O | |
| Golden | | Outputs vs source material | |

Strict TDD: write the failing test first.

## Config & secrets

- `.env.example` committed with every key and a dummy value.
- `.gitignore`: `.env`, `.env.*` (except `.env.example`), <build/cache dirs>.
- CI/deploy secrets: <platform secret store>.

## CI / deploy

- CI on every PR: tests, lint, typecheck (<workflow file>).
- Deploy target: <platform, trigger>.

## Observability & errors

<Logging, error boundaries, how sync/network failures are surfaced to the user. Proportional to size.>

## Accessibility & i18n

<Contrast, labels, keyboard/touch targets; UI language(s) vs code language. "n/a" if no UI.>
