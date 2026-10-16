# Project permissions template

Write to `.claude/settings.json` at the project root and commit it (shared with the team). Personal overrides go in `.claude/settings.local.json` (gitignored).

## Tiers

| Tier | Rule | Examples |
|---|---|---|
| `allow` | Read-only or local, reversible commands the workflow runs constantly | test, lint, format, typecheck, build, dev server, `git status/diff/log/add/commit`, `gh pr view/list/create` |
| `ask` | Outward-facing or hard to reverse | `git push`, `gh pr merge`, dependency install/add, migrations against shared DBs, deploy |
| `deny` | Destructive, never needed by the agent | `git push --force`, `git reset --hard`, `rm -rf`, `gh repo delete` |

Secret-file `Read` denies live in the global settings; do not duplicate them here.

## Base

Replace `<...>` with the exact commands chosen in the Conventions and Testing steps. Use the same command spelling as the project scripts.

```json
{
  "permissions": {
    "allow": [
      "Bash(<test command>:*)",
      "Bash(<lint command>:*)",
      "Bash(<format command>:*)",
      "Bash(<typecheck command>:*)",
      "Bash(<build command>:*)",
      "Bash(git status:*)",
      "Bash(git diff:*)",
      "Bash(git log:*)",
      "Bash(git add:*)",
      "Bash(git commit:*)",
      "Bash(git switch:*)",
      "Bash(git checkout -b:*)",
      "Bash(gh pr view:*)",
      "Bash(gh pr list:*)",
      "Bash(gh pr create:*)",
      "Bash(gh pr checks:*)"
    ],
    "ask": [
      "Bash(git push:*)",
      "Bash(gh pr merge:*)",
      "Bash(<dependency install command>:*)"
    ],
    "deny": [
      "Bash(git push --force:*)",
      "Bash(git push -f:*)",
      "Bash(git reset --hard:*)",
      "Bash(rm -rf:*)",
      "Bash(gh repo delete:*)"
    ]
  }
}
```

## Example: Node + pnpm

```json
"allow": ["Bash(pnpm test:*)", "Bash(pnpm lint:*)", "Bash(pnpm format:*)", "Bash(pnpm typecheck:*)", "Bash(pnpm build:*)"],
"ask": ["Bash(pnpm add:*)", "Bash(pnpm install:*)"]
```

## Notes

- `deny` on Bash prefixes is a safety net, not a guarantee: flag order or shell wrappers can bypass it. Real protection for `main` is branch protection on the remote.
- Temporary grants (e.g. `gh pr merge` during a test run) go in `settings.local.json`, never in the committed file.
