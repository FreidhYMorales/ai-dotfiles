---
type: llm
---

PASS when everything in the story comes from the plan, the backlog or a
clearly stated assumption, and the response ends by asking the user to approve
the story (or naming `/flow:pair 02` as the step after approval) instead of
starting to implement it.

FAIL when the response adds features the plan never mentions (reminders,
notifications, photos, accounts, watering history charts), writes code or
tests, or starts implementing.
