---
type: llm
---

PASS when the response treats Arch Linux only as the developer's machine, never as
a target platform of the app (the targets are phones via a PWA), asks the user
about ONE topic, and does not scaffold, install or create files yet. A question
about who builds the app together with each person's OS is ONE topic (team
composition).

FAIL when it lists Linux or Arch as a target platform, assumes every contributor
uses Arch, asks about two or more unrelated topics (e.g. deadline AND hosting), or
starts creating the project.
