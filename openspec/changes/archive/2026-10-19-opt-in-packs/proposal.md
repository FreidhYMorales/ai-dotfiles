# Proposal: Opt-in packs

Source of truth: `docs/plans/packs/plan.md` (approved after four blind reviews). This proposal does not reopen its decisions.

## Intent

Tools only some projects need (browser checks, design rules, diagrams) would add tokens and supply-chain risk to every session. Packs keep the base lean and turn on pinned, reviewed extras per project. They **supersede the README roadmap item `install.sh --profile minimal`**: the base install stays unchanged.

## Scope

### In Scope
- `packs/packs.json` manifest (schema_version 1; kinds `skill` + `npm`; sources vendored/fetched/npm; layers; requires; project_dirs; leftovers; detect rules).
- `bin/ai-pack` CLI: `list`, `add`, `remove [--purge]`, `ignore`, `unignore`, internal `hint --cwd`. Covers state + flock, per-file journal, stage + `mv -T`/`--exchange`, adoption by hash, refcounts, preflight + rollback, drift and shadow warnings.
- Packs `web` (playwright-cli, web-design-guidelines, taste-skill) and `diagrams` (archify), with vendored pins in `packs/vendor/`.
- Toolkit hook `pack-hint.sh` (SessionStart, `systemMessage` only) + toolkit version bump.
- Tests (`scripts/tests/ai-pack.test.sh`, hook tests), `check-shell.sh` exclusion, `upstreams.json` entries, `docs/packs.md`, README rows + roadmap line replaced.

### Out of Scope (v2 / LATER)
- `bigcode` pack (kinds `binary` + `mcp`, codebase-memory-mcp).
- Kind `plugin`; brand `DESIGN.md` (`design-md <brand>`); `ai-pack doctor`/`prune`.
- More packs (data, mobile, infra); Ponytail adoption (SHOULD eval only).
- Windows, macOS, other distros, non-Claude agents.

## Capabilities

### New Capabilities
- `pack-manifest`: `packs.json` schema, tool kinds/sources/pins, v1 pack contents (frozen contract).
- `ai-pack-cli`: commands, state files, journal, activation/removal/purge rules, error states.
- `pack-hint`: SessionStart hint detection, 30-day cadence, silence rules, hook wiring.

### Modified Capabilities
None (no existing specs in `openspec/specs/`).

## Approach

Plain bash CLI linked by the existing `install.sh` `bin/*` loop. Project writes are whole self-ignoring dirs only; machine installs go to `~/.local/share/ai-pack` and `~/.local/bin`. The hook delegates to `ai-pack hint`, so detection logic and the project key live in one place.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `bin/ai-pack` | New | CLI |
| `packs/packs.json`, `packs/vendor/` | New | Manifest + vendored pins |
| `plugins/toolkit/hooks/` | Modified | `pack-hint.sh`, hooks.json, version bump |
| `scripts/check-shell.sh`, `Makefile` | Modified | Vendor exclusion, `HOOKS` mutate list |
| `scripts/tests/` | New | ai-pack tests |
| `upstreams.json`, `README.md`, `docs/packs.md` | Modified/New | Pins, docs, roadmap |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| ~8.85 dev-days far exceed 400-line budget | High | Chained PRs by work unit (decided in tasks) |
| Open manual checks (playwright skill path, taste-skill standalone, Archify patch, subdirectory start) | Med | Early manual check task; fallbacks in plan |
| Unpinned npm transitive deps | Med | sha512 tarball integrity; documented |
| Hook/CLI version skew, PATH from launchers | Low | Versioned `hint` output; `~/.local/bin` fallback |

## Rollback Plan

Run `ai-pack remove --purge <pack>` per project, then revert the PR chain and delete `~/.local/state/ai-pack` and `~/.local/share/ai-pack`. Leftover dirs are self-ignored and safe to delete by hand. `AI_HOOKS_OFF=pack-hint` silences the hook at once.

## Dependencies

- Runtime: `jq`, `flock`, `curl`, `sha256sum`, coreutils >= 9.5; `npm`, `node >= 22`, `chromium` for `web`.

## Success Criteria

- [ ] `ai-pack add web` activates only in that project; other projects and worktrees show clean `git status`.
- [ ] Hint appears once per 30 days in a vite project, never in this repo, costs 0 tokens.
- [ ] `ai-pack remove web` removes created dirs, keeps hand-edited copies with a warning, lists leftovers.
- [ ] `make check` passes.
