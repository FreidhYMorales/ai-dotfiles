# Verification Report: opt-in-packs

Mode: Strict TDD, openspec store. Verified on `main` at baa7c92 (all 8 PRs merged plus follow-up fixes). Date: 2026-10-19.

## Verdict: PASS WITH WARNINGS

CRITICAL 0, WARNING 5, SUGGESTION 3. Matrix: 40/42 scenarios covered by a passing test, 2 not (see below). Requirements: 30/32 fully covered, 2 partial.

## Completeness (tasks.md)

| Item | State |
|---|---|
| Phases 1-8 (1.1-8.1) | all ticked, matches code on main |
| 0.5, 0.6 | open (need the user at the screen); blocks nothing already shipped, but the hook message wording and PATH fallback were never checked in a real launcher |
| 9.1 Ponytail eval (SHOULD) | open, no verdict file in `docs/packs.md` or the plan |
| 0.1-0.4, 0.7 | unticked in tasks.md although apply-progress (Batch 6, 8) says the maintainer session did them; docs/packs.md documents the subdirectory result (0.7). WARNING: stale checkboxes |

## Build and tests (real runs)

| Command | Exit | Result |
|---|---|---|
| `make check` | 0 | 7/7 steps, "All checks passed" |
| `bash scripts/tests/ai-pack-core.test.sh` | 0 | 50 PASS, 0 FAIL (default and LC_ALL=C) |
| `bash scripts/tests/ai-pack-skill.test.sh` | 0 | 174 PASS, 0 FAIL (default and LC_ALL=C) |
| `bash scripts/tests/ai-pack-npm.test.sh` | 0 | 71 PASS, 0 FAIL (default and LC_ALL=C) |
| `bash scripts/tests/ai-pack-manifest.test.sh` | 0 | 47 PASS, 0 FAIL (default and LC_ALL=C) |
| `bash scripts/tests/checks.test.sh` | 0 | "All cases passed" (49 lines) both locales |
| `plugins/toolkit/hooks/tests/pack-hint.test.sh` | 0 | 79 PASS, 0 FAIL (default and LC_ALL=C) |
| `plugins/toolkit/hooks/tests/hooks-off.test.sh` | 0 | "All cases passed" (40 PASS) both locales |
| `plugins/toolkit/hooks/tests/stdin-socket.test.sh` | 0 | "All cases passed" (8 lines) both locales |

PASS counts are lines starting with PASS (counted from saved output). Coverage tool: none for bash (skipped, not a failure). Mutation: apply reported `make mutate HOOKS=pack-hint` 17/18 (not re-run).

## TDD compliance

| Check | Result |
|---|---|
| TDD evidence table present for every batch (1-7) | OK; Batch 8 is docs only (no table needed) |
| RED test files exist | OK, all listed test files exist |
| GREEN: tests pass now | OK, all suites above pass |
| Triangulation | OK, multiple cases per behavior |
| Safety net | OK |
| Assertion quality | No tautologies or ghost loops seen in the PASS labels; assertions check file content, exit codes, state files. One noted limit: core "654 vs 644" hash case cannot fail as non-root (disclosed in apply-progress) |

## Spec conformance matrix

Legend: P = covered by a passing test (file: label).

### ai-pack-cli (18 requirements, 25 scenarios)

| Requirement / scenario | Evidence |
|---|---|
| Commands and project key / subdirectory and non-git | P core: "git root from a subdirectory", "non-git directory uses the cwd", "absolute/relative --cwd", "symlinked path", "second worktree", "GIT_DIR ignored" |
| Startup dependency check / missing jq | P core: "missing jq prints the pacman line", "writes nothing", "missing flock names its package". npm requires `npm`: P npm: "implicit npm requirement fails/hint" |
| Preflight / missing chromium | P npm "requires": "prints the pacman line", "says nothing was written"; skill "preflight" |
| Preflight / integrity or network failure | P skill "fetched": checksum mismatch and network error write nothing; npm "integrity mismatch" (7 asserts) |
| Self-ignoring whole-dir writes / worktrees clean | P skill "worktrees stay clean" (3 asserts), "dir is self-ignoring" |
| Self-ignoring / re-sync without nesting | P skill "re-sync does not nest", "replaced dir swapped back on failure" |
| Journal after move / killed run | P skill "signal" (TERM rolled back) and "stale stage deleted". Ordering (journal after move, under lock) by source inspection only |
| Adoption by hash / adoptable then adopted | P skill "unjournaled matching dir is adoptable", "adoptable view writes no state", "adoption is journaled" |
| Adoption / foreign target | P skill "foreign target refused", "foreign content untouched", "refusal writes no state" |
| Rollback / second tool fails | P skill "first tool dir rolled back", "no journal after rollback"; npm "rollback after the machine layer" |
| State files / newer schema | P core "newer schema refuses/leaves file alone"; npm "unwritable journal" (schema 99) at add level |
| State files / older schema | P core "older schema uses defaults" (state level); skill "list works without any state". No list-level test with an older file (SUGGESTION) |
| npm layer / network failure during install | P npm "install failure": staging removed, machine.json untouched |
| npm layer / bin collision | P npm "bin collision" (file and symlink) |
| Refcounts / shared tool kept | P skill "remove shared tools" (10 asserts) |
| Remove / hand-edited file | P skill "edited file warns / tells how to re-add / keeps dir / loses journal entry" |
| Remove / runtime output | P skill "leftover is kept / printed / stays out of git status" |
| Re-sync over hand edits / edited copy | P skill "edited copy warns", "edited copy unchanged" |
| Purge / live projects | P skill "purge refuses while another project uses the tool", "refusal lists the project"; npm "purge refuses while B uses it" |
| Purge / dead roots | P skill "dead root is shown/dropped", "purge succeeds once the other root is gone" |
| List / drift and width | P skill "list shows drift", "no line exceeds 70 columns", UTF-8 cases |
| Shadow / nested shadow | P skill "nested personal skill shadows by dir name", "frontmatter name shadows", "depth-6 plugin cache", "shadow shown by list" |
| Machine-wide upgrade / notice | P npm "machine-wide upgrade": restart notice, "list in B shows the machine version" |
| Ignore round trip | P core "ignore ..." and "unignore clears only that pack" |
| Post-change notices / skill-only add | P skill "notice to reload plugins". Requirement half "restart Claude in this project" (Playwright config): NOT implemented, no test (WARNING 1) |

Covered scenarios: 25/25 (the unimplemented notice is in the requirement text, not a scenario). Requirement partial: Post-change notices.

### pack-hint (7 requirements, 10 scenarios)

| Requirement / scenario | Evidence |
|---|---|
| Thin hook / fallback binary | P pack-hint "binary lookup" (XDG_BIN_HOME, ~/.local/bin, PATH wins), "binary gets: hint --cwd <hook cwd>". `timeout 1.5` and hooks.json `"timeout": 2` and version bump 0.11.0: manual inspection (hooks.json l.36, plugin.json, marketplace.json), no test |
| systemMessage only / output shape | P pack-hint "vite project: systemMessage only", "stub with v1 prefix: systemMessage only" |
| Silent failure / hooks off | P hooks-off pack-hint case, pack-hint "opt-out" (silent, nothing written); "failures stay silent" (timeout, unknown prefix, binary missing, ai-pack fails) |
| Detection and cadence / vite | P pack-hint "hint shown" (suggests add, names ignore, hints.json records epoch) |
| Cadence | P "shown 31 days ago prints", "5 days ago silent", exact 30 days edge both sides |
| Silence / dotfiles repo | P "this dotfiles repo: silent / no hints.json / no state dir" |
| Silence / partly active | P "partly active pack: silent" |
| Silence / corrupt input | P "corrupt package.json: silent" |
| Silence / newer schema | P "newer hints schema: silent / file unchanged" |
| Write-limited / concurrent sessions | P "two parallel sessions (rounds 1-3): one hint", "lock held: silent", "state dir holds hints.json and the lock only" |

Covered 10/10.

### pack-manifest (7 requirements, 7 scenarios)

| Requirement / scenario | Evidence |
|---|---|
| Schema / valid manifest | P manifest "schema_version is 1", "every pack tool is defined", "every tool has kind, layers and project_dirs" |
| Pinned sources / unlicensed rules not committed | NOT COVERED AND CONTRADICTED: manifest test asserts the opposite ("vendor dir holds SKILL.md, rules.md and the upstream LICENSE", "rules.md is the upstream command.md"). See WARNING 2 |
| Pinned tree hash / deterministic | P core "hash is deterministic across umasks"; skill "template is deterministic across projects" |
| Requirements declaration / min version | P manifest "playwright needs node >= 22, npm and chromium with the pacman hint" |
| Detect rules / diagrams is manual | P manifest "diagrams has no rules", "web detects vite..., index.html" |
| v1 contents / pack membership | P manifest "web has playwright, web-design-guidelines, taste", "diagrams has archify", version and pin checks. `executablePath`/`outputDir` content of `cli.config.json` is not asserted by a test (checked by eye and by a real run, WARNING 3) |
| Vendor exclusion / vendored script not linted | P checks "failing script under packs/vendor/ is skipped" and `make check` passes with vendored files |

Covered 6/7 scenarios.

### Totals

32 requirements: 30 covered, 2 partial (Post-change notices; Pinned sources). 42 scenarios: 40 covered by a passing test, 1 contradicted (unlicensed rules), 1 partly weak (v1 contents config values). Uncovered: none are "manual only" except hook timeout/version bump (inspection).

## Design coherence and deviations (from apply-progress)

None of the recorded deviations breaks a spec, with two exceptions that are not fully recorded:

1. web-design-guidelines (Batch 6 text says "in-house template plus fetched rules is kept as instructed"; later commits 5fd0a2a/546b52e vendored `rules.md` plus the MIT LICENSE, `packs.json` source is `vendored` at commit 4ecfb9f). This contradicts the spec scenario and plan lines 47, 172, 204, 308 (fetched, never committed). The rationale is valid (upstream became MIT in 2025-09) and `packs/vendor/README.md` documents it, but apply-progress Batch 6 was not corrected and the spec/plan were not amended.
2. Post-change notice "restart Claude in this project" was never implemented; apply-progress does not list it as a deviation; `docs/packs.md` l.26 says "the command says which", which is untrue for the Playwright config case.

Other deviations (all consistent with specs): CLI split into `remove.sh` and `machine.sh`; EXIT trap instead of INT/TERM trap; hint message wording shortened to 51 chars; taste dir named `design-taste-frontend`; `.taste-skill` leftover declared outside a tool dir so `remove` never prints it; archify rendered example pages (11.9 MB) trimmed from the vendored tree (README documents it; spec says "vendored v3.2.0 patched"); `list` shows the current project only; hint "active" is journal-based; `cmd_hint` always exits 0; `XDG_*` seams instead of `AI_PACK_DATA/BIN`; PR 4 at 450 lines vs budget 400.

## Demo results (isolated: HOME, XDG_STATE/DATA/CACHE/BIN under `/tmp/claude-1000/-home-deadlock-Documents-MISC-DOTFILES-IA/8d895d09-ab44-4e5c-81eb-47cb6ae3ce4d/scratchpad/verify/demo`, two scratch git repos A and B)

1. Add web affects only that project: PASS. `ai-pack add web` in A (real network, npm pack with sha512, `--ignore-scripts`, no browser download) printed "ok: active playwright web-design-guidelines taste" and "run /reload-plugins". `git status` clean in A. B `list` shows everything "not added", B tree is only `package.json`. Bin link `playwright-cli` created under the scratch XDG_BIN_HOME only. Real playwright add therefore passes with network, beyond the PR 4 smoke.
2. Hint cadence: PASS. In B (vite): first `hint` printed `v1<TAB>vite detected: ai-pack add web (ai-pack ignore web)`; second silent; +5 days silent; +31 days printed again; `hints.json` holds the epoch. This repo: silent, exit 0, no state written. The hook script run with a startup input produced `{"systemMessage": "vite detected: ..."}` only.
3. Remove: PASS. With a hand-edited `web-design-guidelines/SKILL.md` and files in `.playwright/output/`, `remove web --purge` removed `playwright-cli` and `design-taste-frontend`, printed "left in place: .playwright/output/ (runtime output; delete it yourself)", warned "SKILL.md was changed by hand", kept that dir and printed "delete .claude/skills/web-design-guidelines to re-add"; npm prefix and bin link were purged (`data/ai-pack/npm` empty, bin dir empty); `diagrams` stayed active; `remove diagrams` then deleted archify. `git status` clean throughout.

Real state check: `/home/deadlock/.local/state/ai-pack/ignored.json` is an empty pre-existing file (mtime before this session, from the PR 5 harness leak recorded in apply-progress); `~/.local/share/ai-pack` does not exist. Nothing was written there. Repo working tree stayed clean.

## Issues

CRITICAL: none.

WARNING:
1. Post-change notice "restart Claude in this project" (Playwright config) is not implemented and untested; docs/packs.md l.26 overstates it. Fix code or amend the spec and the doc line.
2. Spec scenario "Unlicensed rules are not committed" and plan decisions 204/248/308 are contradicted by the shipped vendored `rules.md` (upstream is now MIT). Amend the spec/plan (and Batch 6 note) or revert; archive should sync the delta spec accordingly.
3. `cli.config.json` content (`executablePath`, `outputDir`) has no automated assertion.
4. Tasks 0.5 and 0.6 open (hook message render and PATH-less launcher), 9.1 open (SHOULD).
5. tasks.md 0.1-0.4 and 0.7 are unticked though done; archive would show stale state.

SUGGESTION:
1. Add a list-level test with an older-schema file (scenario "Older schema").
2. Add a test asserting hooks.json `timeout: 2` and the toolkit version in plugin.json and marketplace.json.
3. Record the trimmed archify examples as a deviation from "vendored v3.2.0" in the spec.

## Result

next_recommended: fix WARNING 1 and 2 (small), tick Phase 0 items, then `sdd-archive`. No blocker for archive if the user accepts the warnings.
