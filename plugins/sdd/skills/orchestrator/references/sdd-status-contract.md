# SDD Status Contract

Shared contract for SDD commands and phase skills. Build structured status before acting on a change so orchestration never guesses state, paths, or edit scope. Status is always reconstructed manually from the active artifact store; there is no external dispatcher.

## Purpose

Commands that select, continue, apply, verify, or archive an SDD change MUST first produce or consume structured status. The status is the handoff between orchestrator and phase executor.

## Change Selection

- If a change name is provided, use that exact change after confirming it exists in the selected artifact store.
- If no change name is provided, infer only when the active change is unambiguous from session state or there is exactly one active change.
- If multiple active changes match or the active change is unclear, ask the user to choose. Do not guess.
- If no active change exists, report that and suggest `/sdd:new <change>`.

## How to Build Status

- **engram**: `mem_search(query: "sdd/{change-name}/", project: "{project}")` to list artifacts, then `mem_get_observation(id)` for each artifact you need to inspect (tasks for progress, verify-report for verdict).
- **openspec**: read `openspec/changes/{change-name}/` (proposal.md, specs/, design.md, tasks.md, verify-report.md, state.yaml).
- **hybrid**: Engram first; filesystem fallback. Report `artifactStore: hybrid`.
- **none**: only what the conversation holds; say so.

## Status Schema

Return status as markdown with these fields, or as equivalent YAML/JSON:

```yaml
changeName: <change-name-or-null>
artifactStore: openspec | engram | hybrid | none
changeRoot: <absolute path to openspec/changes/<change> or null>
artifactPaths:            # file paths (openspec/hybrid) or topic keys (engram)
  proposal: []
  specs: []
  design: []
  tasks: []
  applyProgress: []
  verifyReport: []
contextFiles:             # readable inputs the next phase must read
  proposal: []
  specs: []
  design: []
  tasks: []
  applyProgress: []
  verifyReport: []
artifacts:
  proposal: missing | done | partial
  specs: missing | done | partial
  design: missing | done | partial
  tasks: missing | done | partial
  applyProgress: missing | done | partial
  verifyReport: missing | done | partial
taskProgress:
  total: 0
  completed: 0
  pending: 0
  allComplete: false
dependencies:
  proposal: blocked | ready | all_done
  specs: blocked | ready | all_done
  design: blocked | ready | all_done
  tasks: blocked | ready | all_done
  apply: blocked | ready | all_done
  verify: blocked | ready | all_done
  archive: blocked | ready | all_done
applyState: blocked | all_done | ready
verifyVerdict: none | pass | pass-with-warnings | fail
actionContext:
  mode: repo-local | workspace-planning
  workspaceRoot: <absolute path>
  allowedEditRoots: [<absolute paths>]
nextRecommended: propose | spec | design | tasks | apply | verify | archive | sdd-new | select-change | resolve-blockers
blockedReasons: []
```

Empty path fields are arrays, not null. `changeName` and `changeRoot` are nullable; every other section is present so consumers parse status the same way every time. `nextRecommended` is a bounded machine token; human explanation belongs in `blockedReasons`.

## Apply State

- `blocked`: required apply artifacts are missing, task selection is ambiguous, or action context makes edits unsafe.
- `all_done`: tasks artifact exists and every implementation task is checked `[x]`.
- `ready`: tasks artifact exists, at least one implementation task is unchecked, and edit scope is safe.

## Dependency States

- `proposal`, `specs`, `design`, and `tasks` report whether prerequisite artifacts are blocked, ready, or all done. `specs` and `design` need only `proposal`; `tasks` needs both.
- `apply` is `ready` only when specs, design, and tasks exist and task progress is not all done.
- `verify` is `ready` only after every task is complete.
- `archive` is `ready` only when tasks are complete and the latest `verify-report` verdict is `pass` or `pass-with-warnings` with zero CRITICAL issues. A `fail` verdict routes back to `apply` (fix) and then `verify` again.

## Routing Rules

- Route only by `nextRecommended` and dependency states; never infer from free text.
- When `nextRecommended` is a planning token (`propose`, `spec`, `design`, `tasks`), launch that phase: missing planning artifacts are the expected output of those phases, not blockers.
- When `blockedReasons` is non-empty, do not proceed to apply or archive; report the reasons and stop. `nextRecommended: verify` may still run to refresh evidence.
- When `nextRecommended` is `resolve-blockers`, report `blockedReasons` and stop.

## Action Context Guard

The orchestrator MUST carry `actionContext` into any phase launch.

- Default: `mode: repo-local`, `workspaceRoot` = git root (or cwd), `allowedEditRoots: [workspaceRoot]`.
- If tasks target paths outside `allowedEditRoots` (another repository or folder), set `applyState: blocked` and add a blocked reason naming each outside root and both exits: edit tasks so every work unit stays inside the allowed roots, or the user explicitly authorizes the extra roots for this change (record the authorization in the tasks artifact).
- If context cannot prove a file is inside `allowedEditRoots`, stop and ask.
- `workspace-planning` (multi-repo planning with no edit roots) never edits; treat linked repos as read-only context.

## Status Output

Every command that acts on a change MUST show status before launching an executor:

- Active change selection and how it was resolved.
- Artifact statuses and paths/topics used as context.
- Task progress and the unchecked task list when tasks exist.
- Next recommended action.
- `blockedReasons`, plus any edit-root blockers.
