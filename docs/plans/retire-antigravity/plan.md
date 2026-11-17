# Plan: retire-antigravity

- Status: approved; plan-review-6 PASS, its minors folded in; backlog in `backlog.md`
- Deadline: no date; lands before `clean-install` stage 3 (publish), which comes before the reinstall
- Mode: solo
- Supersedes: the Antigravity half of `multi-agent-port` (closed); idea 29 is this plan

The repo supports Claude Code and OpenCode only. Antigravity (agy) stops being generated, installed, tested and documented. Nothing under `~/.gemini/` is cleaned up: the system is about to be reinstalled.

## Platforms

| Target | In v1? | Min version / form factor | Distribution |
|---|---|---|---|
| The user's Arch machine, Claude Code with the `toolkit`, `flow` and `look` plugins | yes, unchanged | Current versions | This repo's `install.sh` |
| OpenCode, through the generated rules, skills and agents | yes, output byte for byte unchanged | Current generator (`scripts/gen-agents`) | Same |
| Antigravity (`agy`, `~/.gemini/`) | removed | n/a | n/a |

- Out of scope: cleaning `~/.gemini/` on this machine (links, `hooks.json` `toolkit` key, `skills-backup/`); the reinstall drops them.

## Research

Exploration run on 2026-11-17 (read-only subagent), cited by file:line in the scope rows. Key facts:

- agy-only, deleted whole: `plugins/toolkit/hooks/agy/` (3 adapters) and their 3 tests in `plugins/toolkit/hooks/tests/agy-*.test.sh`; `scripts/tests/install-agy.test.sh`, `scripts/tests/install-agy-skills.test.sh`; `scripts/gen-agents/golden/antigravity/` (26 files).
- The adapters call the Claude hooks, never the reverse; no Claude hook or its test uses `agy/`.
- `gen.sh`: no OpenCode output goes through an agy function (`agy_words`, `agy_tools`, `agy_agent`, `agy_rules`, the antigravity branch of `model_for`); removing them and the `antigravity` key of `models.json` keeps every `golden/opencode/*` file identical.
- `install.sh`: `--target` accepts `claude|opencode|antigravity|all`; with no `--target` it auto-detects agy (`command -v agy|antigravity`, or `ANTIGRAVITY_DIR` exists, `:552-554`). Only `bin/ai-update:378-384` passes `--target`, and it adds `antigravity` when its dir exists. Tests match only the `^done\. Active targets:` prefix.
- `scripts/tests/install-lib.sh:34-45` puts a fake `agy` on every sandbox `PATH`, so every target-less install test currently installs agy too.
- Four `gen-agents.test.sh` cases fail after the removal rather than shrink: `:237-248` (a tool outside the agy map is an error; only `agy_tools` rejects it), `:268` (expects an antigravity golden in the stale-golden output), `:419` (stale antigravity key in a map, harmless), `:438-441` (missing model entry expects a failure naming `antigravity`).
- `toolkit` changes (its `hooks/agy/` goes), so it bumps 0.21.0 → 0.22.0 in `plugin.json` and `marketplace.json` (kept equal by `pack-hint.test.sh:350-351`). `flow` and `look` do not change.
- CI and `Makefile` never mention agy; `run-tests.sh` re-balances shards by itself.

## Product vision

- **v1 (deliverable by deadline):** one installer, one generator, one set of docs for two agents. Each skill change touches one golden set instead of two; the two slowest install test files (79.5 s and 50.5 s) disappear.
- **v2 (later):** n/a. Returning to agy means rebuilding the adapters from git history (after `clean-install` stage 3, the private `ai-dotfiles-history` repo).

## Core model

- Targets: `claude`, `opencode`; `all` = both.
- Generated outputs: `build/agents/opencode/` only, compared with `scripts/gen-agents/golden/opencode/`.
- Hooks: Claude Code hooks (`plugins/toolkit/hooks/`), OpenCode plugin (`plugins/toolkit/opencode/`).

## Foundation

n/a: existing repo with established conventions (`AGENTS.md`, `docs/development.md`).

## Screens

n/a: no UI. The only user-facing output is `install.sh`'s, below.

### install.sh output

```
$ ./install.sh --target all
...
done. Active targets: claude opencode.

$ ./install.sh                                   (auto-detect: whichever of claude, opencode is installed; never antigravity)

$ ./install.sh --target antigravity
unknown target: antigravity                      (exit non-zero, existing message)
```

- Rules: `--target antigravity` is rejected like any unknown target; `all` means `claude opencode`; auto-detection never picks agy, even when `agy` is installed or `~/.gemini/antigravity-cli` exists.
- States: n/a.

| UI element | Backend demand |
|---|---|
| Target list in usage and errors | `resolve_targets` accepts only `claude`, `opencode`, `all` |
| `done. Active targets:` line | No agy target ever resolved |

## Data captured / data inventory

n/a.

## Scope

Order: Installer, then Generator, then Toolkit, then Docs; each story leaves `make check` green on its own. Every row starts from a failing test that pins the new behaviour; deleting agy tests or cases is pre-approved here and is not a RED step.

Shared-file rule (plan-review-4): line numbers below locate the agy content; they are not deletion ranges. In a file shared with Claude or OpenCode, remove only the agy lines, arguments and array entries; every OpenCode case, Claude case and user-data case stays, rewritten where it named agy. Each story triages its files with the code open. Before closing a story, `rg -n -i 'agy|antigravity|\.gemini'` over the files that story owns shows only the regression REDs the plan names; a file two rows touch is scanned only on the lines the closing story owns (plan-review-5 #1). The Installer story scans `install.sh`, `bin/ai-update`, `scripts/tests/install-*.test.sh`, `scripts/tests/install-lib.sh`, `scripts/tests/ai-update.test.sh` and the `port-docs.test.sh`/`tiered-docs.test.sh` lines it edits; `port-docs.test.sh:34-35,62-63,67` and `tiered-docs.test.sh:44-46` belong to Docs.

| Item | Priority (MUST/SHOULD/LATER) | Est. dev-days | Demo value |
|---|---|---|---|
| Installer: `install.sh` drops the antigravity target (`install_antigravity`, `merge_agy_hooks`, `unmerge_agy_hooks`, its uninstall branch, `move_to_backup`, `AGY_PINNED`, `ANTIGRAVITY_DIR`, `GEMINI_CONFIG_DIR`, the agy exception in `prune_backups`, header and usage text, the Stop-timeout comment at `:428`, and every other agy comment and variable in the file, e.g. `:13,51,53,58,113,248`); `--target antigravity` errors; `all` = claude opencode; no agy auto-detection. `bin/ai-update` stops adding `antigravity` and loses `ANTIGRAVITY_DIR` and its agy comments (`:9-11,46,373-378`). RED: `--target antigravity` fails with `unknown target: antigravity`; `--target all` ends with `done. Active targets: claude opencode.`; with a sandbox `agy` stub on `PATH` and `~/.gemini/antigravity-cli` present, a target-less install's `^done\. Active targets:` line does not contain `antigravity` (never an exact target list: auto-detection reads the host `PATH`, which differs between this machine and CI); `ai-update` with Antigravity and OpenCode dirs passes `--target opencode` only (`regen-both` rewritten); with only an Antigravity dir it regenerates nothing (`regen-agy` rewritten to `no_install`). Tests: `install-agy.test.sh` and `install-agy-skills.test.sh` deleted; the fake `agy` leaves `install-lib.sh`; agy cases leave `install-uninstall` (`:4`, `:80-90`; in the leave-alone case only the `.gemini` `mkdir` argument at `:115`, `:117` and the `.gemini` entry of `kept` at `:120`, while its OpenCode setup and the rest of `kept` stay; `:139-140`, `:160-161` deleted; `:165-175` kept and rewritten to OpenCode-only filters, title and labels, since it is the only check that `--uninstall --target claude` leaves OpenCode links alone; the `> 10` and `> 5` link counts still hold), `install-backups` (`:124-142`), `install-claude` (`:156`), `install-fresh` (`:76-77`), `ai-update` (agy parts only: `-u ANTIGRAVITY_CONFIG_DIR` at `:128`, the section header at `:723`, the `.gemini` mkdir in the `regen-check` case, labels at `:764-765`; `regen-opencode`, `regen-fail` and `regen-none` stay unchanged); the install.sh-pinning assertions move here: in `port-docs.test.sh` only the agy lines go (`:47` `agy=` awk, `:49`, `:54-56`), while `:45-46`, `:48` and `:50-53` keep pinning the OpenCode header; `tiered-docs.test.sh:51-53` is deleted with the comment it pins. Each changed assertion is reviewed, not only the deletions, because the fake `agy` no longer runs. Any test that needs the generated build passes `--target opencode` or `all` explicitly; the `install-lib.sh` stub removal and the `install.sh` change land in the same GREEN step. Risk: items 1, 3, 5 (backup prune guard and uninstall, `--target` contract, installer) | MUST | 0.8 | No agy install |
| Generator: `gen.sh` drops every agy function, call, comment (header `:2,5` included) and the `antigravity` branch of `model_for`; `models.json` drops its `antigravity` key; `golden/antigravity/` deleted; `verify.sh` keeps passing. RED: the generated tree has no `antigravity/` directory. Hard gate: `git diff main -- scripts/gen-agents/golden/opencode` is empty. Tests: agy blocks and loops leave `gen-agents.test.sh`, `flow-pair.test.sh:141`, `flow-new-repo-tiers.test.sh:66-67`, `no-openspec.test.sh:37`; pre-approved rewrites: `:237-248` deleted (the tool map was agy's; the lost coverage is accepted, OpenCode agents never map tools), `:268` expects only OpenCode files, `:419` loses the antigravity key, `:438-441` drops the opencode entry and expects a failure naming `opencode`, `:409` (an OpenCode guard against agy wording) deleted while `:408` stays, and in the `mem` block (`:343-369`) only the `antigravity/` frontmatter assertions go: `mem: generator exits 0` stays, rewritten to assert that the generator exits 0 and the OpenCode reviewer file holds no `mcp__engram__`, since it is the only check that an `mcp__engram__*` tool does not break or leak into OpenCode generation. Requires the Installer row. Risk: item 3 (generated OpenCode output) | MUST | 0.4 | One golden set |
| Toolkit: `plugins/toolkit/hooks/agy/` and its 3 tests deleted; toolkit bumped to 0.22.0 in `plugin.json` and `marketplace.json`; `./install.sh` rerun; the Claude hooks and their tests unchanged. RED: in `no-sdd.test.sh`, `plugins/toolkit/hooks/agy` does not exist and the toolkit version is `at_least 0.22.0` (the repo's convention, so the next bump does not break it); `pack-hint.test.sh:350-351` keeps both manifests equal. Requires the Installer row (it links the adapters). Risk: item 5 (plugin release) | MUST | 0.15 | Hooks for two agents |
| Docs: `README.md` (`:3,9,61,65,125-126`), `README.md:125-126` (closed roadmap items) reworded to name OpenCode only while keeping the phrases `port-docs.test.sh:37-41` pins (`- [x] Port the Claude-only parts`, `judgment-day ... v2`), `docs/multi-agent.md` (OpenCode only: drop the Antigravity column, agy rules and skills discovery tables, subagents, hooks and smoke-run sections), `.gitignore:15` comment; the remaining `port-docs.test.sh` and `tiered-docs.test.sh` agy assertions (README and `multi-agent.md` text) removed or moved to OpenCode text (pre-approved), named because some carry no agy keyword: `port-docs.test.sh:34-35` (README agy rules path), `:62-63` (the agy-only herdr/`hooks.json` paragraph, `docs/multi-agent.md:30`), `:67` ("agy work is frozen"), `tiered-docs.test.sh:44-46` (the Stop-gate text that lives only in the Antigravity column, `docs/multi-agent.md:17`; the check-fast wording stays pinned by `tiered-docs.test.sh:40-41`); no agy paragraph is kept just to satisfy a test; idea 29 marked done in `docs/ideas.md`; open items narrowed: idea 20 (pending) names only the plugins and the marketplace, without agy's `toolkit` hooks key and `unmerge_agy_hooks`, and `multi-agent-port` backlog #47 (parked) becomes `[-] dropped: superseded by retire-antigravity`. RED: a `no-agy` structural test, like `no-sdd` and `no-openspec`, written in this story only, after the other three rows are merged: `rg -i 'agy|antigravity|\.gemini'` over `git ls-files` (so this machine and CI scan the same files) outside `docs/plans/`, `docs/ideas.md`, `packs/vendor/` and `scripts/tests/no-agy.test.sh` itself finds nothing except the regression REDs of the earlier rows, allowed by an `allowed_lines` regex as in `no-sdd.test.sh`, each alternative anchored on file path plus a stable fragment rather than a full assertion title (the `--target antigravity` rejection, the auto-detect `agy` stub and `.gemini` setup, `regen-agy`/`regen-both`, the generated tree without `antigravity/`, `hooks/agy` absent); a guard checks that the raw scan still sees `docs/ideas.md` (as `no-openspec.test.sh:42-46` does). The Docs story never deletes or weakens an earlier row's RED to make the scan pass. History (`docs/plans/*` except #47, closed `docs/ideas.md` entries) stays as written. This row does the AI repo's part of `clean-install`'s SHOULD "Docs wording cleanup: stale Gemini and gentle-ai mentions" for Gemini. Requires the other three rows. Risk: item 6 (docs only pinned by text) | MUST | 0.45 | Docs match the repo |

Total: about 1.8 dev-days, no deadline (before the reinstall).

## Demo data

n/a.

## Data gaps & assumptions

| Gap | Assumption | Owner | Resolved? |
|---|---|---|---|
| `~/.gemini/config/hooks.json` keeps a `toolkit` key pointing at deleted adapters until the reinstall | Accepted: the user does not run agy before reinstalling; the reinstall starts from an empty home and `clean-install` drops `agy` from the SYS bootstrap (`plan/clean-install` 49861d9), so `~/.gemini` should not come back; even if agy were reinstalled it is harmless, since `install.sh` never targets it (no cleanup note) | user | yes |
| `install-uninstall.test.sh:25,170` count links (`> 10`, `> 5`) with agy links included | Claude plus OpenCode give far more than 10 links and OpenCode alone more than 5; thresholds unchanged (plan-review-1 #6) | planner | yes |
| `~/.gemini` links dangle once the first new install swaps out the old `build/agents.*` generation, and `--uninstall` no longer removes them | Accepted until the reinstall | planner | yes |
| Old `--target antigravity` invocations outside the repo | None known; only `bin/ai-update` passes `--target` | planner | yes |
| Plan files and ideas that describe agy | Kept as history, not edited | planner | yes |

## Deferred to v2

- Cleaning `~/.gemini/` on an existing machine — the reinstall removes it.

## Demo priorities

1. `./install.sh` ends with `done. Active targets: claude opencode.` on this machine, with `agy` still installed.
2. `make check` green, with the two agy install test files gone from the slowest report.
3. `git diff main -- scripts/gen-agents/golden/opencode` empty.

## Collaboration

- Mode: solo
- People: n/a
- Frozen contracts: n/a
- Work packages: n/a

## Plan-review resolutions

| # | Finding | Resolution | Decided by |
|---|---|---|---|
| plan-review-1 #1 | install.sh-pinning assertions sat in the Docs row | `port-docs.test.sh:47-55` and `tiered-docs.test.sh:51-53` move to the Installer row | planner |
| plan-review-1 #2 | No order between rows | Order Installer, Generator, Toolkit, Docs; each story leaves `make check` green; Generator requires Installer | planner |
| plan-review-1 #3 | No RED test for three rows | One RED per row: installer target cases, no `antigravity/` in the generated tree, toolkit `hooks/agy` absent and 0.22.0, `no-agy` structural test | planner |
| plan-review-1 #4 | No repo-wide "agy is gone" check | The Docs row's `no-agy` test, excluding `docs/plans/`, `docs/ideas.md`, `packs/vendor/` | planner |
| plan-review-1 #5 | Wrong output path | `build/agents/opencode/` | planner |
| plan-review-1 #6 | Link-count gap left open | Resolved: counts still hold; `.gemini` filters and wording at `install-uninstall.test.sh:4,160-173` join the Installer row | planner |
| plan-review-1 #7 | Idea 20 and multi-agent-port #47 are open items, not history | Docs row narrows idea 20 to plugins and marketplace and drops #47 | user |
| plan-review-1 #8 | Deleting `gen-agents.test.sh:237-248` loses tool-map coverage | Accepted: OpenCode agents never map tools; noted in the Generator row | planner |
| plan-review-1 #9 | `~/.gemini` links dangle, uninstall cannot remove them | Accepted until the reinstall; Data gaps row | planner |
| plan-review-1 Q1 | Will the reinstall restore `~/.gemini`? | No: empty home; no cleanup note | user |
| plan-review-1 Q2 | Update idea 20 and #47? | Yes, in the Docs story (#7) | user |
| plan-review-2 #1 | `ai-update.test.sh:723-765` also holds OpenCode regeneration cases | Only agy parts change; `regen-opencode`, `regen-fail`, `regen-none` stay; `regen-both` rewritten to `--target opencode` | planner |
| plan-review-2 #2 | No RED for "Antigravity dir only" | `regen-agy` rewritten: nothing is regenerated (`no_install`) | planner |
| plan-review-2 #3 | `no-agy` would match itself and has no guard | Excludes `scripts/tests/no-agy.test.sh`; guard that the raw scan sees `docs/ideas.md` | planner |
| plan-review-2 #4 | Toolkit RED used exact version equality | `at_least 0.22.0` in `no-sdd.test.sh` plus `hooks/agy` absent | planner |
| plan-review-2 #5 | `no-agy` timing implicit | Written in the Docs story only, after the other three rows are merged | planner |
| plan-review-3 #1 | `port-docs.test.sh:47-55` also pins the OpenCode header | Delete only `:47`, `:49`, `:54-56`; keep `:45-46`, `:48`, `:50-53` | planner |
| plan-review-3 #2 | Auto-detect RED asserted a host-dependent target list | Auto-detect asserts only "no `antigravity`"; exact list asserted with `--target all` | planner |
| plan-review-3 #3 | `all` = claude opencode had no RED | `--target all` prints `done. Active targets: claude opencode.` | planner |
| plan-review-3 #4 | README `:125-126` closed items are edited but pinned | Reworded to OpenCode only, keeping the `port-docs.test.sh:37-41` phrases | planner |
| plan-review-3 #5 | `install-uninstall.test.sh:160-173` triage unclear | `:160-161` deleted; `:165-175` kept and rewritten to OpenCode-only | planner |
| plan-review-3 risk | Install tests inherit the host `PATH` | No install test asserts host-dependent detection; stub or target explicitly | planner |
| plan-review-4 #1 | `no-agy` would fail on the earlier rows' REDs | `allowed_lines` regex for those REDs, as in `no-sdd`; never delete a RED to pass | planner |
| plan-review-4 #2 | `install-uninstall.test.sh:115-120` mixes OpenCode, user data and agy | Only the agy argument, line and `kept` entry go; the case stays | planner |
| plan-review-4 #3 | agy comments and variables outside the rows | Installer and Generator rows cover every agy comment and variable in their files; per-story scan before closing | planner |
| plan-review-4 #4 | Scan file source unclear | `git ls-files` | planner |
| plan-review-5 #1 | Installer closing scan hits Docs-owned assertions | Closing scans cover only the lines each story owns; Installer's file list named | planner |
| plan-review-5 #2 | Agy-only assertions without an agy keyword | `port-docs.test.sh:34-35,62-63,67`, `tiered-docs.test.sh:44-46` named as Docs deletions | planner |
| plan-review-5 #3 | `gen-agents.test.sh:409` guards nothing after the removal | Deleted; `:408` stays | planner |
| plan-review-5 #4 | `mem` block holds the only engram-tool check for OpenCode | `mem: generator exits 0` kept, rewritten for OpenCode | planner |
| plan-review-5 #5, Q1 | `clean-install` left "agy kept or dropped" open; agy could ship in the public root commit | `clean-install` drops agy (49861d9 on `plan/clean-install`); deadline: before `clean-install` stage 3; v2 names `ai-dotfiles-history` | user |
| plan-review-6 #1 | Installer risk omitted item 1 | `Risk: items 1, 3, 5` | planner |
| plan-review-6 #2 | Line drift in `ai-update.test.sh` | Cited by case name (`regen-check`) | planner |
| plan-review-6 #3, reviews 4-5 risk | `agy` substring may match ordinary words | Keep the substring; run the scan before committing the `multi-agent.md` rewrite; switch to `\bagy\b` only on a real false hit | planner |
| plan-review-6 #4 | Rewritten `mem` test guards nothing | Also asserts the OpenCode reviewer file holds no `mcp__engram__` | planner |
| plan-review-6 #5 | Target-less tests build only where the host has `opencode` | Tests that need the build pass `--target` explicitly | planner |
| plan-review-6 #6 | Overlap with `clean-install` Gemini wording SHOULD | Docs row does it for the AI repo | planner |
| plan-review-6 risks | Uncommitted plan; mid-RED host `agy`; brittle `allowed_lines` | Plan and idea 29 committed before story 01; stub removal and `install.sh` change in one GREEN; anchors on path + fragment | planner |
| plan-review-4 pattern | Three reviews found line ranges that hit OpenCode code | Shared-file rule: line numbers locate, they do not delimit deletions; stories triage with the code open | planner |
