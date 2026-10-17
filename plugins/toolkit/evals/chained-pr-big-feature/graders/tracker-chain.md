---
type: llm
---

PASS when the plan splits the work into several PRs of at most about 400 changed
lines each, uses a draft (do-not-merge) tracker or integration branch/PR that the
child PRs target so nothing reaches main early, and orders them migration -> API
-> UI.

FAIL when it keeps one 1200-line PR, merges slices straight into main before the
feature is complete, or gives no PR order.
