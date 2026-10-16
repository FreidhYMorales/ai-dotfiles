# Project bootstrap template

Show the full plan below (filled in) and get ONE approval for the whole sequence. Stop at the first failing command and report it; do not improvise around it.

## Inputs (ask one at a time; propose defaults)

| Input | Default |
|---|---|
| Repo name | project folder name, kebab-case |
| Owner | the authenticated `gh` user (`gh api user -q .login`) |
| Visibility | private |
| Default branch | `main` |

## Greenfield sequence

1. `git init -b main` (skip if `.git` exists).
2. Write `.gitignore` (stack template + `.env`, `.env.*.local`, `.claude/settings.local.json`) and `.env.example`.
3. Create the chosen folder tree; add `.gitkeep` only to empty leaf folders.
4. Write tooling config decided in Conventions (formatter, linter, typecheck, test runner), the project `.claude/settings.json`, and a `Makefile` whose `check` target runs format check, lint, typecheck and tests (`templates/check.md`). Mandatory for every stack.
5. Install dependencies only if approved in this same plan (listed by name and version).
6. Write one smoke test (e.g. the entry module loads, or `1 + 1 == 2` against the test runner) and run `make check`: it MUST pass before the first commit. An empty suite does not count.
7. Commit: `chore: bootstrap project` (docs from Foundation may go in the same commit).
8. `gh repo create <owner>/<name> --<visibility> --source=. --remote=origin --push` (skip if `origin` exists; never overwrite a remote).
9. Branch protection on `main` (require PR + passing checks) via `gh api`. GitHub Free does not support it on private repos: if the call returns 403, report it and continue.

## Existing project (audit mode): reorganization

Never move files without a migration table the user approved.

1. Verify a clean working tree (`git status --porcelain` empty); otherwise stop and ask the user to commit or stash.
2. Run tests/build and record the baseline result. If there is no `Makefile` with a `check` target, add one (`templates/check.md`) in its own commit before any move.
3. Present the migration table:

   | From | To | Reason |
   |---|---|---|
   | `src/utils/date.ts` | `src/shared/date.ts` | shared helper |

4. Create a branch `refactor/reorganize-structure`.
5. Apply moves with `git mv` only (preserves history); then update imports/paths.
6. Re-run tests/build; the result must match the baseline.
7. Commit: `refactor: reorganize folders to <style>`. Moves only: no behavior changes, no formatting churn in the same commit.
8. Open a PR; large moves (> 400 changed lines) follow `toolkit:chained-pr`.
