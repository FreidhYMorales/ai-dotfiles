# Story 21: taste-skill ships its license

## Story

21. As the dotfiles owner, I want `ai-pack add web` to copy taste-skill with its MIT `LICENSE`, so that projects receive the notice the license requires. (idea 16, from #12)

## Acceptance criteria

- [ ] Given a project without the taste skill, when I run `ai-pack add web`, then `.claude/skills/design-taste-frontend/LICENSE` holds the MIT text of upstream tag v2.1.2, byte for byte.
- [ ] Given a project with an earlier, unedited copy of the skill, when I run `ai-pack add web` again, then the copy gains the `LICENSE` and its other files stay the same.
- [ ] Given the next taste-skill bump, when I follow "Update and re-pin", then the procedure tells me to keep the `LICENSE`, and `make check` fails if it went missing.

## Plan

- Copy the `LICENSE` from the root of the pinned upstream tarball into the vendored skill. Its archive sha256 already matches the one recorded in the vendor README, and the file's sha256 is `4575a543ab88dad12ccea7d97e563d0bce5b448b06072e65d3264497dad326df`.
- Re-pin the taste entry in the pack manifest to the new tree hash.
- Update the vendor README: where the license lives, and that it comes from the repo root, outside the directory the procedure replaces.
- Pin the license's presence and bytes in the manifest test, as `web-design-guidelines` already does.

Assumptions:

- `ai-pack` needs no code change: it already replaces an unedited copy when the pin changes, and its re-sync test covers that.
- A copy edited by hand keeps today's behaviour: it stays unchanged and `ai-pack` warns, so it gets no `LICENSE`.
- Existing projects get the file only when the owner runs `ai-pack add` again. The tag stays v2.1.2, so `ai-pack list` shows no update for them.

## Out of scope

- Moving to taste-skill v2.1.3.
- A new `ai-pack` notice for copies that changed with no new version.
- Licenses of anything not vendored, such as the skill the `playwright` npm package supplies.
- The bench validation (#22).

## Suggestions (your call)

## Size

normal
Risk: item 5 (vendored pack bytes and manifest pin)

## Log

- L1 request: /flow:story 21
