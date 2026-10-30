---
name: flow-integrate
description: "Trigger: integrate, merge teammate work, review delivered package, teammate PR, /flow-integrate. Check a delivered work package against its contract and tests, list deviations, propose minimal fixes."
license: MIT
metadata:
  author: FreidhYMorales
  version: "1.0"
---

## Activation Contract

Load when a teammate delivers a work package (PR, branch, or files) created by `/flow-split`, or when the user asks to merge or check teammate work.

## Hard Rules

- The package's frozen contract is the source of truth. Never silently rewrite the contract to fit the delivery.
- If the contract itself is wrong, stop and ask the user; a contract change means updating the contract file, every affected package, and the plan.
- Propose minimal fixes; do not refactor or restyle working code beyond the package conventions.
- Do not merge, push, or comment on the PR without explicit user approval.
- Talk to the user in their language; review notes for the teammate are in the language the user chooses.

## Decision Gates

| Deviation | Action |
|---|---|
| Signature/type/schema differs from contract | Fix the delivery to match the contract |
| Files outside "Files to deliver" changed | Revert those files unless the user approves |
| Dependency not in the allowlist | Remove it or ask the user to approve it |
| Tests fail | Diagnose; propose the smallest fix |
| Missing behavior (states, edge cases) | List it; fix if small, else return to the teammate |
| Contract is genuinely wrong | Ask the user before changing anything |

## Execution Steps

1. Identify the package file (`docs/work-packages/NN-<slug>.md`) and the delivery (`gh pr view`/`gh pr diff`, branch, or files).
2. Diff the delivered files against "Files to deliver"; flag extras and missing files.
3. Compare signatures, types, schema and I/O against the frozen contract files in the repo.
4. Check dependencies against the allowlist (package manifests, lockfiles, imports).
5. Run the package tests and the CI checks (tests, lint, typecheck) locally.
6. Report deviations in the table below, each with a minimal fix and who should apply it (you or the teammate).
7. On user approval, apply the fixes, re-run tests, and prepare the merge. Do not merge without approval.
8. Update the plan's `Collaboration` section (package status) and save the outcome to engram (type `decision`, topic `integrate/<package>`).

## Output Contract

```
## Integration: package NN <title> — <ready | ready with fixes | return to teammate>
| # | Deviation | Contract reference | Minimal fix | Fixed by |
Tests: <pass/fail summary>   CI: <lint/typecheck summary>
Feedback for teammate (3 lines): <...>
```

Final message: the report, and the one action you need approved next.
