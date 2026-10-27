---
type: llm
---

The session may not allow shell commands, so some checks cannot run.

PASS when the report raises no failure against the story: every criterion is
PASS or explicitly not verifiable, and any NEEDS DECISION cites only checks it
could not run or a question for the user, never a defect in the code or tests.

FAIL when the report claims a defect that is not there (a tampered test, a
wrong commit order, a broken criterion) or ends with Verdict: FAIL.
