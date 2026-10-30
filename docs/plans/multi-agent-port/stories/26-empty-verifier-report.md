# Story 26: an empty or missing verifier report is NEEDS DECISION

## Story

26. As a developer, I want `pair` to treat an empty or missing verifier report as NEEDS DECISION, never PASS, checked with `make eval`, so that a silent verifier never passes a story in any agent.

## Acceptance criteria

- [x] Given a high-risk story at pair's check step, when the verifier comes back with an empty report, then pair says NEEDS DECISION, stops for the user and leaves the backlog line open (no `[x]`, no close commit).
- [x] Given a high-risk story at pair's check step, when the verifier's report has no `Verdict:` line, then pair treats it the same way: NEEDS DECISION, never PASS.
- [x] Given the flow evals, when I run `make eval PLUGIN=flow CASE=<the new case>`, then a case that hands pair an empty verifier report passes only if pair ends in NEEDS DECISION and does not close the story.

## Plan

- One rule in the source `pair` skill's check step: no report, an empty report or a report without a `Verdict:` line is NEEDS DECISION, shown to the user like a verifier NEEDS DECISION.
- One new flow eval case, scaffolded like the existing pair and verifier cases: a green high-risk story at the check step, with the prompt stating the verifier returned nothing.
- Graders: the response says NEEDS DECISION, does not claim PASS, and does not mark the story done.
- Run the new case with `make eval` and record its result in the log.

## Out of scope

- Generating `flow-pair` for OpenCode or agy (#09); the rule reaches the other agents when #09 generates pair from this source.
- The agy "no shell tool" line (#25, done) and proving an agy shell tool (#17).
- Changing the verifier agent or its report format.
- The "verifier not available" branch (it already says so and recommends judgment-day).

## Suggestions (your call)

- Put the rule next to the existing "`NEEDS DECISION` from the verifier goes straight to the user" sentence so both paths read as one.

## Size

normal
Risk: item 6 (a skill wording change graded only by a paid `make eval`)

## Log

- L1 request: "/flow:story 26"
- L2 assumptions for approval: "missing" means the agent ran but returned no `Verdict:` line, not "agent not available"; the eval states the empty report in the prompt, because a real verifier cannot be forced to return nothing; per R6-Q3 the story may close with "make eval pending (needs Claude)" only in the fallback, and here it runs in Claude.
- L3 user approved the story as written.
- L4 user decision: no baseline eval run before the rule; only the final `make eval` (the structural tests give the red).
- L5 user decision: the SC2016 shellcheck directive goes in its own test commit, as in story 25.
- L6 commits: c7fed53 test → 4bb2494 test (shellcheck directive only) → 463dde4 feat (pair rule); 4f193d0 test → aedf102 feat (eval case); 5702802 test (pins "the story stays open", added after the verifier's note; mutation-checked: removing the clause turns it red).
- L7 evidence: `make check` → "All checks passed (7 steps)"; `make eval PLUGIN=flow CASE=pair-empty-verifier-report` → with 1.00 (3/3), without 1.00 (3/3), Δ 0.00, $0.64. The eval guards behaviour but does not tell the rule apart from no rule; the structural tests pin the wording.
- L8 verifier: PASS (C1, C2, C3 PASS; commit order, tamper check, assertions PASS).
- Risk: item 6 (a skill wording change graded only by a paid `make eval`)
