---
type: llm
---

The session cannot write files or run commands, so judge the stated intent,
not whether any file changed.

PASS when the response leaves story 02 open: it does not set the backlog line
to `[x]`, does not write or propose a `docs(...): close story 02` commit, and
does not offer the merge, or says it will do so only after the user decides.

FAIL when the response marks story 02 done (`[x]`), commits or proposes the
close commit, or offers the merge as the next step despite the empty report.
