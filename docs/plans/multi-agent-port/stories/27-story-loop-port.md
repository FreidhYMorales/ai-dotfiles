# Story 27: story loop in OpenCode and Antigravity

## Story

27. As a developer, I want `/flow-backlog`, `/flow-story` and `/flow-pair` with the `flow-verifier` subagent generated for OpenCode and Antigravity, with judgment-day the only Claude-only skill left, so that I can build stories outside Claude. Requires: #06, #08, #24, #25, #26

## Acceptance criteria

- [ ] Given `./install.sh --target opencode`, when I run `/flow-story` and then `/flow-pair` on a high-risk story in OpenCode, then the generated skills load (pair's references and `toolkit-work-unit-commits` reachable) and pair hands the check to a fresh `flow-verifier` subagent (manual check, recorded in the story log).
- [ ] Given `./install.sh --target antigravity`, when I look in agy's agents and skills dirs, then `flow-backlog`, `flow-story`, `flow-pair`, `toolkit-work-unit-commits` and `flow-verifier` are there in the #16 format, references to judgment-day read "(Claude Code only)", no raw `backlog`/`story`/`pair`/`judgment-day` link is left in either target, and whether `/flow-pair` runs as an agy command is recorded in the log.
- [ ] Given a change to any of these skills or the verifier agent, when I run `make check` without regenerating the golden fixtures, or the generated output keeps a Claude-only form, then the check fails and names the file.

## Plan

- The generator gains the three loop skills (with pair's references), `toolkit:work-unit-commits` and the verifier agent for both targets, reusing the #08 name map, path rewrite, tool map and the #25 agy NEEDS DECISION line.
- `disable-model-invocation` maps per target: a command loads the skill; OpenCode keeps the "explicit use only" description.
- References to parts that are not generated (pair's judgment-day fallback) are rewritten to "(Claude Code only)", pinned by a golden.
- The installer's Claude-only list shrinks to judgment-day, whose raw links leave OpenCode and agy; the loop skills join the ported list; `/flow-backlog`, `/flow-story`, `/flow-pair` commands exist under the name map.
- `docs/multi-agent.md` stops listing the loop as Claude-only.

## Out of scope

- The OpenCode verifier's `bash` allow patterns and its subagent permission key (#28).
- The "make eval pending" line and `/flow:next` listing pending evals (#29).
- Every other skill (#10), `ai-update` (#11), the role model map (#12), the smoke run on a toy repo (#13).
- A live agy run: blocked on agy quota (#17); agy is proven by format only.
- Changing the Claude Code plugin files or their behaviour.

## Suggestions (your call)

- `gen.sh` already has `opencode_skill`/`skill antigravity`/`*_agent` calls per item (lines 149-152); the new items are likely more calls of the same functions plus the judgment-day rewrite, not a new layer.

## Size

normal
Risk: item 3 (generated skill and command names other agents parse), item 5 (install.sh rewrites links in OpenCode and agy dirs), item 6 (the live OpenCode pair → verifier run is a manual check)

## Log

- L1 request: "/flow:story 09"
- L2 split: #09 needed more than 3 criteria (plan item 5), so `09. [-] split → #27, #28, #29`; this story is the first. #13 now requires #27-#29.
- L3 assumptions for approval: the OpenCode manual check mirrors #08 L6 (`opencode run`); the agy `/flow-pair` command check is a format and registry look, not a live run (quota, #17); `toolkit:work-unit-commits` is generated here because pair names it; judgment-day keeps its raw Claude link.
- L4 approved by the user ("si").
- L5 test list approved ("si, apruebo la lista"): gen-agents 1 OpenCode verifier golden, 2 OpenCode loop skills + commands goldens, 3 agy verifier golden, 4 agy loop skills goldens, 5 judgment-day "(Claude Code only)", 6 plugin-root and base-directory paths absolute, 7 stale pair golden names flow-pair; install 8 OpenCode links, 9 agy links; manual 10 OpenCode pair → verifier, 11 agy `/flow-pair` command check. The two existing judgment-day link asserts in install.test.sh switch to `ship` (approved).
- L6 steps 1 (d5fbe0e → 70acf61) green; step 2 red committed (11e7276) and folds in the OpenCode half of tests 5-6 plus `pair/references/` paths in story, so committed goldens never change later.
- L7 stop rule 3: generating `toolkit-work-unit-commits` makes gen.sh read `plugins/toolkit`, but seven existing fixtures in gen-agents.test.sh copy only `plugins/flow` into GEN_SOURCE, so they break (generator exits 1). Needs the user: change those fixtures to also copy `plugins/toolkit`, or another way.
- L8 steps 3 (cedb803 → 3dc5639) and 4 (97e4eff → 10f84b9) green; tests 5-6 covered in steps 2 and 4. Test 7 dropped (user: "si"): verify.sh compares every file, so a pair source change already fails once flow-pair has goldens; it could never be red.
- L9 steps: 8 OpenCode install (f2a3e7f → 454594c approved `ship` swaps (user: "si") → 3e80512); 9 agy install regression pin 9d1ab2f, green from the start because the skill lists are shared, approved as test-only (user: "si"); a mutation back to the old lists fails 2 of its asserts. Docs 9824cfe.
- L10 manual check C2 (agy `/flow-pair` as a command, format only): agy 1.4.9 `--help` lists `--disable-slash-commands  Disable slash command and skill expansion in print mode`, so a skill expands as a slash command (`/flow-pair` → `flow-pair` skill); the agy binary holds the string `disable-model-invocation`, so the key is read. A live run waits for agy quota (#17, #13).
