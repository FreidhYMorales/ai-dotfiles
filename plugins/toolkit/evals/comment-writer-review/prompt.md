---
max_turns: 4
allowed_tools: [Read, Glob, Grep, Skill]
---

Write the GitHub PR review comment I should post: the PR adds `parseConfig(path)`, but it has no test for an empty or missing file, and right now an empty file returns `nil, nil` instead of an error. Give me just the comment text.
