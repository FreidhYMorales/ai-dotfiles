# Story 30: every other skill in OpenCode and Antigravity

## Story

30. As a developer, I want every other flow and toolkit skill generated for OpenCode and Antigravity, with `/flow-plan` and `/flow-fill-gaps` commands, so that the whole planning path works outside Claude. Requires: #08, #24, #27

## Acceptance criteria

- [ ] Given `./install.sh --target opencode` or `--target antigravity`, when I look in that target's skills dir, then every flow and toolkit skill except judgment-day is there under its `flow-`/`toolkit-` name from the generated build, and no raw link to a repo skill is left.
- [ ] Given OpenCode after install, when I run `/flow-plan` and `/flow-fill-gaps`, then the generated skill loads by its prefixed name and its references to other flow skills and agents use the target names (manual check, recorded in the story log).
- [ ] Given a change to any generated skill source, when I run `make check` without regenerating the golden fixtures, or the generated output keeps a Claude-only form, then the check fails and names the file.

## Plan

- The generator gains the remaining flow skills (plan, research, fill-gaps, handoff, next, idea, split, integrate, foundation, bootstrap) and toolkit skills (ship, chained-pr, cli-tools, cognitive-doc-design, comment-writer, delegate-local, go-testing, skill-creator, skill-improver) for both targets, reusing the #08 name map, the #24 support-file paths, the #25 agy mapping and the #27 "(Claude Code only)" rewrite; a golden each.
- OpenCode gets only the `/flow-plan` and `/flow-fill-gaps` commands; agy reaches skills as slash commands by skill expansion (#27 L10).
- The installer's ported list covers every flow and toolkit skill except judgment-day, so the raw links leave both targets; judgment-day stays Claude-only.
- `docs/multi-agent.md` lists the ported skills.

## Out of scope

- The generated `AGENTS.md` and its per-target rule lines (#31).
- Moving gentle-ai's same-named and `sdd-*` skills aside in agy (#32).
- OpenCode commands for the other skills and the built-in collision test (#14).
- `ai-update` (#11), the role model map (#12), the smoke run (#13), generated support files (plan item 8b).
- A live agy run: blocked on agy quota (#17); agy is proven by format only.
- Changing the Claude Code plugin files or their behaviour.

## Suggestions (your call)

- `gen.sh` already emits each item with one `skill`/`opencode_skill` call (lines 187-196); the remaining skills are likely more calls or one loop over the ported list, not a new layer.
- `PORTED_SKILLS` in `install.sh` and the call list in `gen.sh` now name the same set twice; one shared list would keep them from drifting.

## Size

normal
Risk: item 3 (generated skill and command names other agents parse), item 5 (install.sh rewrites links in OpenCode and agy dirs), item 6 (the live OpenCode `/flow-plan` run is a manual check)

## Log

- L1 request: "/flow:story 10"
- L2 split: #10 needed more than 3 criteria (plan item 5b), so `10. [-] split → #30, #31, #32`; this story is the first. #13 and #15 now require #30-#32, #14 requires #30.
- L3 assumptions for approval: "every other skill" is the 19 flow and toolkit skills not yet generated (`look` has no skills); OpenCode skills without a command are reachable by the skill tool, their commands wait for #14; the manual check mirrors #27 L13 (`opencode run` with a model that calls the skill tool); `skill-creator`'s directory-only prose stays as #24 pinned it.
- L4 approved by the user ("si").
- L5 test list approved ("si"): gen-agents 1 OpenCode remaining skills + `/flow-plan`, `/flow-fill-gaps` command goldens, 2 agy remaining skills goldens, 6 stale toolkit golden names the file (regression pin); install 3 OpenCode links, 4 agy links; manual 5 OpenCode `/flow-plan` and `/flow-fill-gaps`. Existing install asserts switch (approved): raw `plan`/`ship` links (lines 206, 208, 349, 350) become `flow-plan`/`toolkit-ship`; the same-run backup test uses a real `toolkit-ship` dir instead of `ship`.
- L6 steps: 1 (999f0fc → a230a6e) and 2 (d4b3fe3 → a435829) green; 3 red 9ae54d7, the approved agy assert swaps committed apart (0ed74fc) because `PORTED_SKILLS` is shared and the OpenCode change flipped them, green 97eb413; 4 regression pin b7ad21c, green from the start for the same reason, approved as test-only ("si"); a mutation back to the old list fails `no raw repo skill link is left for antigravity`.
- L7 test 6 dropped (user: "si"): `verify.sh` compares every file, so a toolkit golden pin repeats the existing stale case; dropping `ship` from the generator still reports `stale golden: .../toolkit-ship/SKILL.md`, so it could never be red.
- L8 docs 79c25c3. Manual check C2 (OpenCode 2.2.2, `-m opencode/big-pickle`, `--standalone`, toy repo in the session scratchpad; the user ran `./install.sh --target opencode`, which removed the 19 raw links and linked the generated skills plus `/flow-plan` and `/flow-fill-gaps`): PASS. `/flow-plan` called `skill flow-plan` as its second tool call and it loaded; it read `templates/plan.md` and `templates/screen-variants.md` by absolute repo path, wrote `docs/plans/due-dates/plan.md` and named `/flow-plan-review`, `/flow-foundation`, `/flow-bootstrap`. `/flow-fill-gaps` called `skill flow-fill-gaps` second, edited the plan and named `/flow-plan-review` next. Side effects: both runs saved engram entries (`plan/due-dates`, `plan/due-dates/resolutions`, a session summary) from the toy repo; the non-interactive run marked its questions `[assumed]` (expected).
- L9 check: `make check </dev/null` → "All checks passed (7 steps)". Verifier (flow:verifier, fresh): PASS (C1-C3 pass, C2 by the manual run in L8; commit order and tamper check pass with the approved deviations L6-L7). Antigravity proven by format only, as out of scope allows.
- L10 evidence: test→code pairs 999f0fc→a230a6e, d4b3fe3→a435829, 9ae54d7 (+0ed74fc)→97eb413; regression pin b7ad21c; docs 79c25c3. No skill source changed, so no `make eval`.
- Risk: item 3 (generated skill and command names other agents parse), item 5 (install.sh rewrites links in OpenCode and agy dirs), item 6 (the live OpenCode `/flow-plan` run is a manual check)
