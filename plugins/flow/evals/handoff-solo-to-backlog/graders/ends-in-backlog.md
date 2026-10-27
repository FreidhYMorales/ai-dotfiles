---
type: llm
---

The session cannot write files, so judge the stated intent.

PASS when the response ends the solo plan in a backlog (it uses or names
`/flow:backlog`, or proposes one-line backlog stories for `backlog.md` next to
the plan) and names `/flow:story 01` as the next step.

FAIL when it recommends any `/sdd:` command, writes or proposes a `tasks.md`
task list with estimates, or starts writing code.
