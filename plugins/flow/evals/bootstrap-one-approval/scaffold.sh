#!/usr/bin/env bash
# Workspace state right after /flow:foundation: docs written, nothing scaffolded.
set -eu
mkdir -p docs
cat >docs/architecture.md <<'DOC'
# Architecture: route-tracker

- Status: approved
- Mode: greenfield

## Stack

| Layer | Choice |
|---|---|
| Language | TypeScript |
| Frontend | Vite + React (PWA) |
| Tests | Vitest |

## Architecture style

Feature-based.

```
src/
  features/
  shared/
```

## CI / deploy

- Quality gate: `make check`, created by `/flow:bootstrap` from this recipe (in order):
  1. Format check: `npx prettier --check .`
  2. Lint: `npx eslint .`
  3. Typecheck: `npx tsc --noEmit`
  4. Tests: `npx vitest run`
DOC
printf '# AGENTS.md\n\nFollow docs/architecture.md. Conventional commits.\n' >AGENTS.md
