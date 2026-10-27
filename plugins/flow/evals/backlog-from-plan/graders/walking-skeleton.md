---
type: llm
---

PASS when the response proposes a backlog of at most 15 numbered one-line user
stories in the form `NN. [ ] As a <who>, I want <what> so that <why>.` (with an
optional ` Requires: #NN` suffix) that cover the plan's v1 scope, and story 01
is a walking skeleton: the smallest slice of the core value usable end to end
(for example a member adds an item and sees it on the shared list), not
sign-up or sign-in on its own.

FAIL when stories are split by layer or are technical ("set up the database",
"create the API"), carry estimates, priorities or acceptance criteria, add
anything the plan lists as out of scope, or story 01 is sign-up/sign-in or
another supporting concern alone.
