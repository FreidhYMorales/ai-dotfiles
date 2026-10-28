# Plan review: multi-agent-port (review 2)
Verdict: PASS WITH CHANGES
Summary: The only change since review 1 is commit 995a114, which swaps SDD for the backlog → story → pair loop. None of review 1's 14 findings were addressed: the "Plan-review resolutions" table is empty, so it looks like `/flow:fill-gaps` was skipped. Findings 7 and 11 are partly moot now that sdd is gone. The new item 5 also brings its own problems: the loop is started by slash commands, the Stop gate has to honour pair's red marker, and the loop depends on toolkit skills. There is no deadline, so scope still fits.

## Status of review 1 findings
| R1 # | Status | Note |
|---|---|---|
| 1 agy rules path conflict | open | plan.md lines 23 and 89 are unchanged. The bundled `~/.gemini/antigravity-cli/builtin/skills/agy-customizations/SKILL.md` lines 53 and 70 still name `~/.gemini/config/` as the global root. `install.sh` line 274 already links `~/.gemini/config/AGENTS.md`. |
| 2 deleting GEMINI.md | open | Core model "Installer" (line 46) and item 0 still say "back up and remove". `~/.gemini/GEMINI.md` (85k) is still there. |
| 3 overwriting herdr / engram.ts | open | `~/.gemini/config/hooks.json` keys are `["herdr"]`. `~/.config/opencode/plugins/` still has `engram.ts` and `herdr-agent-state.js`. |
| 4 adapter input contract (cwd, source, reentry) | open, now wider | See new finding N3 (red marker). |
| 5 `pause` mapping, "7 hooks" count | open | Item 3 (line 72) still says 7 hooks, but line 101 defers `update-check`. |
| 6 agy skills discovery and collisions | open, more evidence | `~/.gemini/antigravity-cli/skills/` holds `*.bak-20261023-170049` copies of the same skills, and `~/.gemini/skills/` holds gentle-ai `work-unit-commits` and `judgment-day`. |
| 7 path rewriting, space in the repo path | partly moot | The sdd orchestrator is gone. Still open: the `DOTFILES IA` space in the path, `../pair/references` in story, and "this skill's base directory" in `plugins/flow/skills/pair/SKILL.md` line 64. |
| 8 where the build dir lives, staleness | open | Core model "Generator" still says "or similar". |
| 9 agy subagent and MCP tool names | open, now on the MUST path | The bundled agy docs have no subagent doc at all (`docs/` = hooks, json_configs, mcp_servers, plugins, rules, skills). `invoke_subagent` and `~/.gemini/config/agents/` come only from the web research. `flow:verifier` now depends on them. |
| 10 pruning old links and migrating tests | open, now wider | `scripts/tests/install.test.sh` lines 201-217 and 231 assert that the loop is NOT linked. |
| 11 parallel delegation, `general-purpose` fallback | partly moot | Only judgment-day (item 6, SHOULD) is left, plus the plan-review fallback. |
| 12 `engram setup` overwriting | open | Item 2 still says "`engram setup` if it writes the expected config". |
| 13 command collisions with built-ins | open | `plan` and `next`, and now `pair` and `story` as agy `/name`. |
| 14 docs list | open | Not added. Also `docs/multi-agent.md` line 36 and the `install.sh` comment at lines 33-36. |

## Findings
| # | Category | Severity (blocker/major/minor) | Finding | Evidence | Suggested fix |
|---|---|---|---|---|---|
| 1 | Process | major | All 14 review 1 findings are unresolved and the resolutions table is empty. The plan goes into a second review with the same open majors (agy paths, deleting GEMINI.md, overwriting herdr hooks, adapters that fail open, build dir freshness, agy subagent format). | plan.md "Plan-review resolutions" (lines 119-122); `git log` shows only 995a114 since review 1 | Run `/flow:fill-gaps` against plan-review-1.md and record a decision per finding before the backlog. |
| 2 | Contradiction | major | Item 5 (MUST) depends on item 7 (SHOULD). `pair` has `disable-model-invocation: true` and "Run only when the user types `/flow:pair NN`". The skills and rules all say `/flow:backlog`, `/flow:story` and `/flow:pair`. OpenCode has no colon commands (Data gaps line 92), and agy exposes skills as `/pair`. Without commands and a rewrite of `/flow:*`, pair either never runs or refuses to. | `plugins/flow/skills/pair/SKILL.md` lines 3-4 and 14; `story/SKILL.md` lines 13, 31 and 68; `backlog/SKILL.md` lines 52 and 81; plan.md items 5 and 7, Core model "Skills" (line 43 rewrites agent names, not slash commands) | Promote the OpenCode commands for backlog, story and pair to MUST inside item 5. Add a `/flow:x` → target-form rewrite to the generator. Map `disable-model-invocation` per target (OpenCode: command only; agy: check that `/pair` works), and add a golden test for it. |
| 3 | Technical correctness | major | The Stop gate must honour pair's red marker. Pair commits a failing test on purpose and writes `flow-pair-red`. `require-check` turns that into a `systemMessage` instead of blocking. In agy, if the adapter maps Stop to `{"decision":"continue"}` and doesn't carry this exit-0-with-message path, every red step loops the agent until it reaches the forced-invocation limit. That breaks the demo-5 story and burns quota. | `plugins/toolkit/hooks/require-check.sh` lines 43-57; `pair/SKILL.md` line 57; plan.md item 3 ("`require-check` Claude + agy only") | Put "red marker → allow with message" into the neutral hook contract. Add an agy adapter golden test: a red marker on the same branch must give allow, not continue. |
| 4 | Gap / migration | major | Item 5 never says to remove the current exclusion. `CLAUDE_ONLY_SKILLS="backlog story pair"` in `install.sh` and the install tests that pin it have to go, or flip to positive assertions. The comment and `docs/multi-agent.md` line 36 also need updating. | `install.sh` lines 33-36 and 177-193; `scripts/tests/install.test.sh` lines 201-217 and 231 | Add to item 5: "red" tests first, asserting the generated loop skills exist per target, then drop `CLAUDE_ONLY_SKILLS` and its cleanup block. |
| 5 | Gap | major | The loop depends on more than its four named parts. Pair cites the `toolkit:work-unit-commits` skill and falls back to `/toolkit:judgment-day` when the verifier is missing. In agy, gentle-ai copies of both sit in `~/.gemini/skills`, and `.bak-*` copies sit in `antigravity-cli/skills`, so which copy wins is undefined. | `pair/SKILL.md` lines 64 and 91; `eza ~/.gemini/skills ~/.gemini/antigravity-cli/skills` | Add `work-unit-commits` to item 5's generated set, and rewrite `toolkit:`/`flow:` skill references. Make the item 0 discovery test cover `.bak-*` dirs and gentle-ai duplicates; have the installer prune its own `.bak-*` skill dirs. |
| 6 | Technical correctness | minor | Repo rules are linked verbatim and name `/flow:*` commands and "`references/high-risk.md` of the `flow:pair` skill". Those don't exist under those names in either target. | `AGENTS.md` lines 28, 30 and 37; Core model "Source of truth" ("never hand-edited per agent") | Run `AGENTS.md` through the same name and command rewrite, or add one rule line mapping `/flow:x` to each target's form. |
| 7 | Technical correctness | minor | The verifier fallback path `${CLAUDE_PLUGIN_ROOT}/skills/pair/references/` resolves to the source tree. Fine, as long as the generator rewrites it and pair passes absolute paths "from this skill's base directory", which is a Claude concept. | `plugins/flow/agents/verifier.md` line 23; `pair/SKILL.md` line 64 | The generator replaces "this skill's base directory" with the absolute generated path. A golden test fails if any `${CLAUDE_PLUGIN_ROOT}` or "base directory" text is left. |
| 8 | Scope | minor | Item 8's smoke covers the loop but never asserts the high-risk path, so the verifier sub-agent could go unexercised. Repo evals already exist for this. | `plugins/flow/evals/story-high-risk`, `verifier-catches-tampered-test`, `verifier-passes-good-story`; plan.md item 8 | Make the toy story high-risk, so the smoke must show the verifier running in both targets. Optionally reuse the eval scaffolds as the toy repo. |

## Scope vs deadline
| Item | Est. dev-days | Cut (MUST/SHOULD/LATER) |
|---|---|---|
| 0. agy rules and skills discovery test (sentinel files, `.bak-*` and gentle-ai collisions), then the installer fix; opt-in handling of GEMINI.md | 0.75 | MUST |
| 1. Spike: `agy plugin import`, plus an agy subagent that calls engram MCP (real tool names, agent dir) | 0.5 | MUST |
| 2. Engram MCP check per target (verify only, no `engram setup`) | 0.5 | MUST |
| 3. Hooks: neutral contract including the red marker, 6 cores, agy jq-merge adapter, OpenCode `toolkit.ts`, golden tests | 3.25 | MUST |
| 4. Generator skeleton + plan-reviewer + golden tests + staleness check + gitignored build dir | 2 | MUST |
| 5. Loop skills + verifier + `work-unit-commits`, `/flow:*` rewrite, `disable-model-invocation` mapping, drop `CLAUDE_ONLY_SKILLS` and its tests | 1.5 | MUST |
| 7a. OpenCode commands for backlog, story and pair (needed by item 5) | 0.25 | MUST |
| Pruning old links and `.bak-*` dirs, migrating install tests | 0.5 | MUST |
| 8. Manual smoke with a high-risk toy story in both targets | 1.5 | MUST |
| Docs: README, `install.sh` header, multi-agent.md | 0.25 | SHOULD |
| 7b. Remaining `/flow:*` commands | 0.25 | SHOULD (demo value medium) |
| 6. judgment-day agents (sequential judges) | 0.5 | SHOULD (demo value medium) |
| `pause` for agy, `require-check` for OpenCode | n/a | LATER |
Total MUST: 10.75 dev-days vs available: unbounded (no deadline, solo) -> fits

The plan's 7.75 days undercounts the hooks, the migration and the command dependency.

## Unnamed risks
- **The Stop loop on red commits in agy.** Every pair red step fires Stop while `make check` fails. Likelihood: high if the marker isn't ported. Mitigation: finding 3's golden test.
- **The verifier format is unverified.** agy's agent format comes only from web docs that conflict with the bundled 1.4.7 docs. A wrong tool name can hang the subagent (Research line 27). The verifier then hangs or never loads, and pair falls back to judgment-day, which is SHOULD and maybe not ported. Likelihood: medium. Mitigation: do item 1's spike before item 4 and give the subagent a timeout. If it fails, pair should say "verifier unavailable" and stop.
- **Shadowed skills in agy.** The `.bak-*` dirs and gentle-ai copies can shadow the generated `work-unit-commits`, so pair runs with gentle-ai's commit rules and mixes `test:`/`feat:` commits. Likelihood: medium. Mitigation: the item 0 discovery test, and prune the installer's own backups.
- **Plan edits can break `make check`.** `scripts/tests/multi-agent-plan.test.sh` bans the word "sdd" and requires every cited `plugins/` path to exist. Fill-gaps edits that quote review 1 (which cites `plugins/sdd/...`) will fail. Likelihood: medium. Mitigation: don't copy sdd paths into plan.md; refer to review 1 by finding number.
- **Quota during the smoke.** A full loop plus the verifier in two agents is costly. Likelihood: medium. Mitigation: a one-function toy story, with cheap models except for the verifier.

## Questions for the user (max 5)
1. Do you still use Gemini CLI or gentle-ai's `~/.gemini/GEMINI.md` and `~/.gemini/skills`? This decides whether the installer may remove or shadow them. My recommendation: never delete them; shadow by precedence after the item 0 test, and make any removal opt-in.
2. In OpenCode and agy, should the commands keep a `flow-` prefix (`/flow-pair 03`) or use bare names (`/pair 03`)? This changes the generator rewrite, the rules text and the collision checks with built-ins (`plan`). My recommendation: `flow-` everywhere, for one predictable form.
3. Should OpenCode accept the `make check` Stop gate as a rule-only instruction for v1 (no blocking hook exists)? My recommendation: yes, plus one generated rule line.
4. If the agy verifier subagent proves unworkable in the spike, should high-risk stories in agy stop with NEEDS DECISION, or run the verifier inline in the same session (not blind)? My recommendation: stop with NEEDS DECISION; an inline verifier defeats the "fresh, did not write the code" contract.
5. Should `ai-update` regenerate and re-link the OpenCode and agy outputs on every update? My recommendation: yes.

Technical recommendations I resolved myself: gitignore the build dir and add a staleness check to `make check`; jq-merge a named `toolkit` key into agy `hooks.json`; link a separate OpenCode `toolkit.ts`; quote every generated path (the repo path has a space); only verify engram, never run `engram setup`; rewrite `/flow:*`, `flow:`/`toolkit:` names and "this skill's base directory" in the generator, with golden tests that fail on leftovers; have the installer prune its own `.bak-*` skill dirs.
