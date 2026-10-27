---
type: llm
---

PASS when the response asks the user at most ONE question (ideally with a
suggested answer) and does not re-ask what the prompt already settled (stack,
single club, roles, offline, language).

FAIL when the response asks two or more separate questions, asks about
architecture or implementation details, or writes code.
