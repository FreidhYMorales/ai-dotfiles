#!/usr/bin/env bash
# A project skill with a folded multi-line description, a Keywords section and
# tutorial prose instead of runtime rules.
set -eu
mkdir -p .claude/skills/release-notes
cat >.claude/skills/release-notes/SKILL.md <<'MD'
---
name: release-notes
description: >
  This skill helps you write release notes.
  Use it for releases.
---

# Release notes

Release notes are an important part of any project. In this guide we will
walk through the history of release notes and why teams write them, and then
look at a few ways you might choose to write them for your own project.

You could group changes by type, or maybe by component, depending on taste.

## Keywords

release, changelog, notes
MD
