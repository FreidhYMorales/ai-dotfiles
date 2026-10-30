# Story 26: an empty or missing verifier report is NEEDS DECISION

## Story

26. As a developer, I want `pair` to treat an empty or missing verifier report as NEEDS DECISION, never PASS, checked with `make eval`, so that a silent verifier never passes a story in any agent.

## Acceptance criteria

- [ ] Given a high-risk story at pair's check step, when the verifier comes back with an empty report, then pair says NEEDS DECISION, stops for the user and leaves the backlog line open (no `[x]`, no close commit).
- [ ] Given a high-risk story at pair's check step, when the verifier's report has no `Verdict:` line, then pair treats it the same way: NEEDS DECISION, never PASS.
- [ ] Given the flow evals, when I run `make eval PLUGIN=flow CASE=<the new case>`, then a case that hands pair an empty verifier report passes only if pair ends in NEEDS DECISION and does not close the story.

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
