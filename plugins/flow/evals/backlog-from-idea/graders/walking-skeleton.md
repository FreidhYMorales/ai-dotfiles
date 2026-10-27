---
type: llm
---

PASS when the response proposes a backlog of at most 15 numbered one-line user
stories in the form `NN. [ ] As a <who>, I want <what> so that <why>.` (with an
optional ` Requires: #NN` suffix), where story 01 is a walking skeleton: the
smallest slice usable end to end (for example one member suggests a book and
sees it listed).

FAIL when stories are split by layer or are technical ("set up the database",
"create the API"), carry estimates, priorities or acceptance criteria, invent
features the prompt never mentioned (payments, ratings, multiple clubs), or
story 01 is not usable end to end.
