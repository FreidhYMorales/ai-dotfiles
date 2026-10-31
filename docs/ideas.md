# Ideas

Triage log for ideas outside current scope. One row per idea; details below.

| # | Idea | Verdict (GO/DEFER/DROP/SPIKE) | Target (v1/v2/backlog) | Effort (dev-days) | Date | Link |
|---|---|---|---|---|---|---|
| 01 | Replace SDD with a light backlog → story → pair loop | GO | v1 (before multi-agent-port) | 3–5 | 2026-10-26 | [01](#01-replace-sdd-with-a-light-backlog--story--pair-loop) |
| 02 | Split install.test.sh so make check fits the Stop gate comfortably | GO | backlog (multi-agent-port #33) | 0.5 | 2026-10-30 | [02](#02-split-installtestsh-so-make-check-fits-the-stop-gate-comfortably) |

---

## 01. Replace SDD with a light backlog → story → pair loop

- Idea: Retire the `sdd` plugin (7 phases + OpenSpec) and replace it with a light loop: a backlog of one-line stories, one story refined just in time (acceptance criteria, out of scope), then pair programming in small Strict TDD steps with the test committed before the code. Delegation and verification are sized by understanding, risk and resumability, not by file counts; an independent verifier runs only for high-risk changes.
- Motivation: the current flow is waterfall-like and heavy for solo projects; the upstream it came from (gentle-ai) already dropped SDD; porting SDD is the most expensive part of `multi-agent-port`. The loop must also suit local models.
- Raised during: `/flow:plan-review` of multi-agent-port (review 1)
- Date: 2026-10-26

| Criterion | Assessment |
|---|---|
| Feasibility (technical / data / policy-legal) | High: markdown skills plus installer and test cleanup; no external dependency |
| Complexity | Medium: 3 new skills (backlog, story, pair); `flow:handoff` feeds the backlog instead of SDD; new sizing and verification rules in `claude/CLAUDE.md`; retire `plugins/sdd` (63 files) and its references in `install.sh`, `upstreams.json`, `README.md`, `docs/multi-agent.md`, `scripts/tests/install.test.sh`, `plugins/toolkit/skills/work-unit-commits` |
| Effort (dev-days, range) | 3–5 |
| Value / impact | High: lighter daily flow, fewer tokens, fits local models, removes ~2.5 dev-days (item 5) from multi-agent-port |
| Risk | Medium: losing SDD's verify/archive gates. Mitigation: keep Strict TDD, the `require-check` Stop hook, and an independent verifier for high-risk changes |
| Dependencies | `multi-agent-port` plan is paused and must drop item 5 afterwards |
| Fit (v1 / v2 / backlog) | v1, before multi-agent-port |
| Displaces | multi-agent-port (paused until this lands); its item 5 is removed |

- Research:
  - Gentleman Programming, "Matamos al SDD para siempre" (2026-10-20, https://youtu.be/eGJoDxuILK0): SDD as waterfall; ODD (Organic Driven Development) grows process only when needed.
  - gentle-ai repo: issue #4959 retired SDD/OpenSpec (`odd/tasks/remove-sdd-odd-only-main.md`); task size canon (`odd/tasks/task-size-canon.md`): small = understood within one bounded read, contained risk, resumable from the request and `git diff`; file counts never decide; high-risk list: data/irreversible, security, consumed contracts, concurrency, delivery/environment, no test would catch a regression.
  - HolaMundo, "Me equivoqué, NO uses Spec Driven Development" (2026-10-23, https://youtu.be/5JjuF1zpNbI): backlog of one-line user stories, refine one story just in time into a throwaway plan, pair in small TDD steps, commit each test before the code to catch test tampering, vertical slices, strong model for stories and a fast model for implementation.
  - Local models (`plugins/toolkit/skills/delegate-local/SKILL.md:36-47`, `bench/worker/`): good at L1 (one function) and L3 (find the bug) with a check, weak at 2–3 files and long instructions, and they delete or weaken tests (4 of 13 passing patches). One pair step = one test plus minimal code, which matches L1; stories stay on a strong model.
- Recommendation: GO via `/flow:plan`; tradeoff: pauses multi-agent-port for a few days, but the port then carries a smaller flow already in use.
- Decision: GO — SDD is removed entirely (option A); `openspec/specs/` stays as behavior documentation.
- Next: `/flow:plan` (kept short; this change is the first trial of the lighter approach).

## 02. Split install.test.sh so make check fits the Stop gate comfortably

- Idea: the `require-check` Stop hook reported "make check timed out after 300s" on many turn ends in this repo only; make the gate reliable again.
- Findings (measured 2026-10-30, 8 cores): a lone `make check` takes 131s (non-test steps ~9s; tests run per file in parallel, so the total is the slowest file: `install.test.sh` 118-122s with 47 serial installs, then `engram-backup.test.sh` 51s, `gen-agents.test.sh` 26-29s). The 300s timeouts came from overlap: a background `make check` or install suite started by the assistant was still running when the hook started its own. `timeout 300` leaves no orphan test processes. Other projects are fast because their `make check` takes seconds; the hook runs it on every dirty turn end, so here each `/flow:pair` turn waits about 2 minutes.
- Score: feasibility high; complexity low (move sections into 3-4 files with a shared helper, no assert changes); effort 0.5 d; value high here (make check ~131s → ~55s); risk low (order-dependent sections surface); no dependencies; fits the multi-agent-port backlog as a standalone tooling story; displaces nothing on the cut line, done before #12.
- Recommendation: GO; tradeoff: half a day not spent on #12, for ~75s saved on every turn end. Plus a practice rule: never end a turn while a background `make check` or test suite runs.
- Decision: GO (user, 2026-10-30) → backlog #33.
