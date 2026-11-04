# Story 17: Honest dry-run for pruned broken links

## Story

17. As the dotfiles owner, I want `install.sh --dry-run` to stop saying it pruned a broken link it only reported, so that a dry-run never claims a change it did not make. (idea 18, from #15)

## Acceptance criteria

- [ ] Given a broken link into the repo or the build dir, when I run `./install.sh --dry-run`, then the output names it as `[dry-run] rm <path>`, the link is still there, and no `pruned broken link: <path>` line appears.
- [ ] Given the same broken link, when I run `./install.sh`, then it is removed and `pruned broken link: <path>` is still printed.

## Plan

- Print the "pruned" line only when the run is not a dry-run, the same fix `prune_backups` (story 15) and the uninstall (story 16) got.
- Cover the dry-run case in the existing install tests with a throwaway HOME; the real-run case is already pinned by the existing OpenCode and agy prune tests.

## Out of scope

- Other install lines that also print in a dry-run (`linked:`, `removed raw skill`, `removed Claude-only skill`, `removed unread rules link`, `moved …`, `set: git core.hooksPath`).
- Any change to which links are pruned.

## Suggestions (your call)

- Assumption: criterion 2 needs no new test; `install-opencode.test.sh` ("the removal is reported") and `install-agy.test.sh` already assert the real-run line, and they must stay green unchanged.
- Signal: `link_file` and the other lines listed above make the same claim under `--dry-run` (e.g. `linked: <path>` after `[dry-run] ln -s`). That is a wider story; say so if you want it as an idea.

## Size

normal
Risk: item 5 (install script)

## Log

- L1 request: /flow:story 17
- L2 approved (user, 2026-11-04), scope: the prune_links line only.
- L3 test list approved: one new dry-run case in `install-opencode.test.sh`; criterion 2 covered by the existing real-run assertions in `install-opencode.test.sh` and `install-agy.test.sh`, unchanged. Mode C.
- L4 commits: 8e48f46 test (red: "FAIL dry-run claims no pruned link") → 51f15c9 fix.
- L5 evidence: `install-opencode.test.sh` and `install-agy.test.sh` "All cases passed"; `make check` "All checks passed (7 steps)"; tamper check empty.
- L6 verifier: PASS (51f15c9), red replayed at 8e48f46, with two notes outside the criteria: the new case uses a build-dir link only (a repo link shares the same condition and print line; the verifier ran one once by hand, correct); `[dry-run] rm <path>` prints twice for a link in `skills/` under `--target opencode`, because `link_skills` and `link_generated` both prune that dir (predates this story, output still accurate).
- L7 Risk: item 5 (install script).
