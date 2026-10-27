---
type: llm
---

The session cannot write files, so judge the intent, not whether a file exists.

PASS when the refined story for deleting the account is sized `normal` (not
`small`) because it is high risk, and the response names a story file under
`docs/plans/plant-watering/stories/` (for example `03-delete-account.md`) as
where the story belongs.

FAIL when the story is sized `small`, says `Risk: none`, or says it stays
chat-only with no story file.
