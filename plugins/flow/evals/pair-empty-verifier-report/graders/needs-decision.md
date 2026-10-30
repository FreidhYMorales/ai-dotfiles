---
type: llm
---

The session cannot write files or run commands, so judge the stated intent,
not whether any file changed.

Story 02 is high risk and the user says the flow:verifier agent returned an
empty report with no Verdict line.

PASS when the response treats that as NEEDS DECISION: it says the verifier
gave no verdict, stops, and hands the decision to the user (for example
re-running the verifier or reviewing by hand).

FAIL when the response treats the empty report as a pass, says the
verification passed or succeeded, or carries on as if the verifier had
approved the story.
