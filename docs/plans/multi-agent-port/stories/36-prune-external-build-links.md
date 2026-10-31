# Story 36: prune links into an external build dir

## Story

36. As a developer, I want generated links pruned when the build dir is outside the repo so that a custom `AI_BUILD_DIR` never leaves dangling links. Requires: #08

## Acceptance criteria

- [ ] Given `AI_BUILD_DIR` outside the repo and a generated OpenCode or agy link whose entry is no longer generated, when I run the installer, then the dangling link is removed and reported as `pruned broken link`.
- [ ] Given a dangling link in a target dir that points neither into the repo nor into the build dir, when I run the installer, then it is left untouched.

## Plan

- The prune step treats a link as ours when it points into the repo or under the build dir path, as the links are written; nothing else changes.
- One install test per criterion in the OpenCode or agy install tests; the sandbox already runs with the build dir outside the repo, so a planted dangling link into it reproduces the bug.

## Out of scope

- A relative `AI_BUILD_DIR` (links would be relative too; not supported today).
- Pruning live links, real files or dirs, or anything under other dirs than the ones the installer already prunes.
- Changing the build swap, the default build path or `ai-update`.

## Suggestions (your call)

- The "points into the repo" check is repeated in `link_skills`; a small helper for "is this link ours" could serve both, only if it stays one function.

## Size

normal
Risk: item 1, 5 (the installer deletes links in config dirs other tools own)

## Log

- L1 request: /flow:story 36
- Assumption: links count as ours by their raw target under `$BUILD_DIR/` (the path `link_generated` writes), not its resolved generation dir.
- Red: 8e1e2f1 `test(install): prune dangling links into a build dir outside the repo`; 2 cases failed (the external link not removed, not reported); the foreign-link guard passed by design.
- Green: 5eb4595 `fix(install): prune dangling links into a build dir outside the repo`; `install-opencode.test.sh` "All cases passed"; `make check` "All checks passed (7 steps)"; tamper check empty.
- Verifier: PASS (both criteria; BUILD_DIR edge cases empty, `/`, glob chars, trailing slash checked; optional: an agy case for C1).
- Risk: item 1, 5 (the installer deletes links in config dirs other tools own)
