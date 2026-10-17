---
name: bootstrap
description: "Trigger: bootstrap the project, create the repo, scaffold, set up the folders and tooling, reorganize folders, /flow:bootstrap. Execute the decisions /flow:foundation documented: git, folder tree, tooling, Makefile check, smoke test, first commit, GitHub repo; or a git mv reorganization PR."
license: MIT
metadata:
  author: FreidhYMorales
  version: "1.0"
---

## Activation Contract

Load after `/flow:foundation` has written `docs/architecture.md` (stack, folder tree, quality-gate recipe). This skill EXECUTES those decisions; it does not choose stacks or structure. If `docs/architecture.md` is missing, stop and recommend `/flow:foundation`.

## Hard Rules

- Talk to the user in their language; commits, files and engram entries are in English.
- Never scaffold, move files, install dependencies or create remotes without approval. Fill in `templates/sequences.md` completely and get ONE approval for the whole plan, then run it end to end without further stops.
- Stop at the first failing command and report it; do not improvise around it.
- `make check` must pass before the first commit, with at least one real smoke test (`templates/check.md`). An empty suite does not count.
- Never overwrite an existing remote, never force-push, never move files without an approved migration table, and only with `git mv`.
- Conventional commits, no AI attribution. Moves and behavior changes never share a commit.

## Decision Gates

| Situation | Action |
|---|---|
| No `.git` | Greenfield sequence starts with `git init -b main` |
| `origin` already exists | Skip `gh repo create`; push to it |
| Existing files do not match the documented tree | Reorganization sequence: migration table, branch, `git mv`, PR |
| Working tree is dirty | Stop; ask the user to commit or stash |
| Dependencies would be installed | List each by name and version in the plan; install only if approved there |
| Branch protection returns 403 (GitHub Free, private repo) | Report it and continue |
| Reorganization PR over 400 changed lines | Split it with `toolkit:chained-pr` |

## Execution Steps

1. Read `docs/architecture.md`, `docs/development.md` and `AGENTS.md`; confirm the tree, tooling and `make check` recipe to apply.
2. Ask the inputs one at a time with defaults (repo name, owner, visibility, branch).
3. Fill in the matching sequence from `templates/sequences.md` and present it as one plan.
4. On approval, run it; finish with `make check` green and the commit pushed (or the PR open).
5. Save one engram entry (type `decision`, topic `bootstrap/<project>`): repo URL or PR, commit SHA, anything skipped.
6. Tell the user next: `/flow:plan-review`.

## Output Contract

Repo URL (greenfield) or PR URL (reorganization), first commit SHA, `make check` result, skipped steps with reasons.

## References

- `templates/sequences.md` — greenfield and reorganization command sequences.
- `templates/check.md` — `make check` rules, per-stack recipes and smoke tests.
