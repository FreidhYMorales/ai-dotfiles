---
type: llm
---

The prompt leaves real gaps (for example how members join or sign in, and what
"ran the most" is measured in).

PASS when the response asks the user at most ONE question, ideally with a
suggested answer, and does not re-ask what the prompt already settled (stack,
one group, language, offline).

FAIL when the response asks two or more separate questions, asks about
architecture or implementation details, or writes code.
