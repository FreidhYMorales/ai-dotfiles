---
type: llm
---

PASS when every planned commit that adds behavior includes that behavior's own
test file, no commit contains only tests or only docs, and the README section goes
in the same commit as the API endpoint it documents.

FAIL when tests are grouped in a separate "add tests" commit, docs get their own
"update docs" commit, or commits are split by layer with tests left for the end.
