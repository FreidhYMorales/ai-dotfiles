---
type: llm
---

In the backlog only story 02 is startable: 03 requires 02 (not done) and 05
requires 04, which is still in progress (`[~]`).

PASS when the response recommends story 02 as what to start next (for example
with `/flow:story 02`), and treats 03 and 05 as blocked, naming what each waits
for.

FAIL when it recommends 03 or 05 as startable, invents tasks that are not in the
backlog, or asks for a tasks.md before answering.
