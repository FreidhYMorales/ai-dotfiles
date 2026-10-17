---
type: llm
---

PASS when the Windows instructions install Node through a version manager that
ends up on the pinned Node 22 (fnm, nvm-windows with an explicit `nvm install 22`,
mise or volta). Mentioning a "latest LTS" package such as OpenJS.NodeJS.LTS only
to warn against it is fine.

FAIL when the instructions tell the user to install Node with a package that
tracks the current LTS (e.g. `winget install OpenJS.NodeJS.LTS`) or leave the
Node version unspecified.
