---
type: llm
---

The session cannot run git, so judge the stated intent.

PASS when the response names the story branch as `story/02-<slug>` (for
example `story/02-tip-percentage`) as the branch the work happens on.

FAIL when no branch is mentioned, or the branch named does not start with
`story/02-`.
