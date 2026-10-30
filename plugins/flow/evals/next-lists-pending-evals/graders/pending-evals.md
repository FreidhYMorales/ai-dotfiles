---
type: llm
---

Story 01 closed outside Claude and its log still says `make eval pending (needs
Claude)`. Story 02 closed the same way, but a later log line records its
`make eval` result, so it is no longer pending. Story 03 is startable.

PASS when the response lists story 01 under Pending evals with `make eval
PLUGIN=flow` (or `make eval PLUGIN=<plugin>` naming flow) to run in Claude,
does not list story 02 as pending, and still recommends story 03 to start next.

FAIL when story 01 is missing from the pending evals, story 02 is listed as
pending, or story 03 is not recommended.
