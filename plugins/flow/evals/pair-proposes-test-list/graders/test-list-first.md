---
type: llm
---

The session cannot write files or run commands, so judge the stated intent,
not whether a test, commit or branch exists.

PASS when the response proposes a test list for story 02 (test names with a
level such as unit or integration) that maps to its acceptance criteria (20%
tip gives 30.00 each, no tip gives 25.00 each, a negative tip is rejected) and
then asks the user to approve the list before writing any test or code.

FAIL when the response writes test code or production code, says it will
start the first test without waiting, or proposes tests unrelated to the
criteria (rounding, currencies, uneven splits).
