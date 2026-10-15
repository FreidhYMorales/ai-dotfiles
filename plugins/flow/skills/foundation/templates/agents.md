# AGENTS.md

Rules for ANY AI (CLI or browser) working on this repo. Keep it short; details live in `docs/architecture.md`.

## Stack

<language, framework, data layer, key libraries>

## Folder map

```
<short folder tree with one-line purpose per folder>
```

## Conventions

- Naming: <rule>
- Format/lint: run `<format command>` and `<lint command>` before committing.
- Commits: conventional commits; no AI attribution.
- Tests first (Strict TDD). Run `<test command>`; typecheck with `<typecheck command>`.

## Do not

- Do not change frozen contracts (<paths>) without explicit agreement.
- Do not add dependencies without approval.
- Do not commit secrets; use `.env` (see `.env.example`).
- Do not edit files owned by another work package.
