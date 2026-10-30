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
