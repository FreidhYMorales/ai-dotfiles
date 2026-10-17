---
type: llm
---

PASS when the response presents a complete bootstrap plan and asks for approval of
the whole plan at once, without claiming that any file was created or any command
already ran. A follow-up about how to execute it (this run has no shell) is fine.

FAIL when it claims something was created or ran, asks to approve steps one at a
time, or re-opens decisions docs/architecture.md already made (stack, folders,
gate commands).
