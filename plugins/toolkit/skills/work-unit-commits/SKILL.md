---
name: work-unit-commits
description: "Plan commits as reviewable work units. Trigger: implementation, commit splitting, chained PRs, or keeping tests and docs with code."
license: Apache-2.0
metadata:
  author: gentleman-programming
  version: "1.0"
---

## When to Use

Load this skill when deciding what belongs in each commit or PR.

Use it for:

- Splitting a feature into reviewable work.
- Preparing commits before opening a PR.
- Turning a large change into chained or stacked PRs.
- Keeping reviewer cognitive load healthy.
- Building a planned change (a story or task list) without accidentally producing a PR above 400 changed lines.

## Critical Rules

| Rule | Requirement |
|------|-------------|
| Commit by work unit | A commit represents a deliverable behavior, fix, migration, or docs unit. |
| Do not commit by file type | Avoid `models`, then `services`, then `tests` if none works alone. |
| Keep tests with code | Tests belong in the same commit as the behavior they verify. |
| Keep docs with the user-visible change | Docs belong with the feature or workflow they explain. |
| Tell a story | A reviewer should understand why each commit exists from its diff and message. |
| Future PR-ready | Each commit should be a candidate chained PR when the change grows. |
| Workload guard | If a story or task list expects a >400-line change, group commits into chained PR slices before implementation. |

## Exception: `/flow:pair`

Under `/flow:pair`, a `test:` commit followed by its `feat:`/`fix:` commit is one work unit (an optional `refactor:` may follow).
The red `test:` commit is intentional evidence that the test existed and failed before the code: do not squash it into the code commit or rewrite that history.
"Keep tests with code" applies to the pair of commits, not to each commit alone.

## Work Unit Checklist

Before committing, confirm:

- [ ] The commit has one clear purpose.
- [ ] The repo still makes sense after applying only this commit.
- [ ] Tests or docs for this unit are included when relevant.
- [ ] Rollback is reasonable without reverting unrelated work.
- [ ] Focused test command and exact result are recorded.
- [ ] Runtime harness command/scenario and exact result are recorded, or explicit `N/A` explains why no runtime boundary exists.
- [ ] Rollback boundary names the exact files/behavior removable without unrelated work.
- [ ] The commit message explains the outcome, not the file list.

## Split Examples

| Weak split | Better work-unit split |
|------------|------------------------|
| `add models` | `feat(auth): add token validation domain model and tests` |
| `add services` | `feat(auth): wire token validation into login flow` |
| `add tests` | Tests included with each behavior commit |
| `update docs` | Docs included with the user-facing change they explain |

## PR Relationship

Use work-unit commits as the foundation for chained PRs:

1. Build the smallest independent work unit.
2. Include verification for that unit.
3. Commit it with a Conventional Commit message.
4. If the PR approaches 400 changed lines, promote commits or groups of commits into chained PRs.

## Planned Work Relationship

When a story or task list estimates the size of a change:

- Well under 400 lines: keep work-unit commits inside one PR.
- Near 400 lines: commit by work unit and monitor changed lines before PR creation.
- Over 400 lines: ask whether to split into chained PRs or accept `size:exception`, and record the answer.
- Count authored additions plus deletions for the `>400` threshold. Exclude generated files (goldens, lockfiles, snapshots) from that authored count.

Each planned work unit should map cleanly to a commit or PR with:

- clear start state,
- clear finished state,
- verification in the same unit,
- rollback that does not remove unrelated work.

Its implementation evidence MUST include:

- Focused test command and exact result.
- Runtime harness command/scenario and exact result, or explicit `N/A` with reason.
- Rollback boundary stated independently of commit creation; uncommitted work units still require it.
- When fixing confirmed review findings, group the fixes as atomic work units in one correction pass.

## Commands

```bash
# Review the story before committing
git diff --stat
git diff --cached --stat

# Check recent commit style
git log --oneline -5
```
