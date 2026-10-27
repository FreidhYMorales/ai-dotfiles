---
type: llm
---

PASS when the refined story for deleting the account is sized `normal` (not
`small`) because it is high risk, and it is written, or explicitly about to be
written once approved, as a story file under
`docs/plans/plant-watering/stories/` (for example `03-delete-account.md`).

FAIL when the story is sized `small`, says `Risk: none`, or is kept chat-only
with no story file.
