# Vendored pack sources

Each directory here is copied into a project by `ai-pack add`. The manifest
(`packs/packs.json`) pins every directory by `ai-pack hash`, so these bytes must
not change without re-pinning. `scripts/check-shell.sh` does not lint this tree.
This README sits outside the hashed directories on purpose.

| Dir | Upstream | Tag | License | Archive sha256 (GitHub tag tarball) |
|---|---|---|---|---|
| `taste-skill/` | github.com/Leonxlnx/taste-skill, `skills/taste-skill/` | v2.1.2 (commit b9ca2fd) | MIT (`taste-skill/LICENSE`, from the repo root) | `d6adddbb1b3f5782702299be1918bcfb048ca20809d318703a8bf2f8bd197ff5` |
| `archify/` | github.com/tt-a1i/archify, `archify/` | v3.2.0 (commit 208acba) | MIT (`archify/LICENSE`) | `b9490be6e01c9cf1f6a2163f44c22feeb4b3435e254eea99ea0b3dfa08b07480` |
| `playwright/` | in-house | n/a | n/a | n/a |
| `web-design-guidelines/` | github.com/vercel-labs/web-interface-guidelines, `command.md` as `rules.md` (+ in-house `SKILL.md`) | commit 4ecfb9f | MIT (`web-design-guidelines/LICENSE`) | `rules.md`: `d246b026f4f29b5823a9cc857f9edf3d2507002e055e32040cadeaf3b38e0234` |

Tarball URL: `https://github.com/<repo>/archive/refs/tags/<tag>.tar.gz`.

## taste-skill

Verbatim, plus the repo root `LICENSE`, which upstream keeps outside
`skills/taste-skill/`. The frontmatter name is `design-taste-frontend`, so the
project dir is `.claude/skills/design-taste-frontend` (Claude lists project skills
by dir name). It needs node >= 22 and chromium. At run time it writes
`.taste-skill/` in the project (declared as a leftover).

## archify

Verbatim except two functions, so the pinned copy never starts a child process
or reaches the network to look for updates:

- `archify/scripts/check-update.mjs`: `updatesDisabled()` returns `true`.
- `archify/bin/delivery-update.mjs`: `startDeliveryUpdateCheck()` returns
  `unavailable('disabled')` before spawning the checker.

Both edits carry the comment `ai-dotfiles vendor patch`; they are one separate
commit on top of the verbatim copy. Needs node >= 18.

The 15 rendered showcase pages `archify/examples/*.html` (11.9 MB) are left out:
nothing in the skill or its scripts reads them. The example JSON inputs, which
`SKILL.md` and `bin/archify.mjs` use, are kept. Verified after the trim:
`archify doctor` reports ready, and `render` and `demo` work; `archify examples`
still prints the paths of the removed pages.

## playwright

`cli.config.json` points Playwright at the system `/usr/bin/chromium`, writes
output to `.playwright/output` (a declared leftover) and sets
`allowUnrestrictedFileAccess` so `file://` pages open. Never run
`playwright-cli install --skills`: it edits the project `.gitignore` and
downloads a browser. Verified pair: Chromium 154, node 26, playwright-cli 0.1.22.

## web-design-guidelines

`SKILL.md` is written in-house and points at `rules.md`, which is `command.md`
from github.com/vercel-labs/web-interface-guidelines (MIT since 2025-09; its
`LICENSE` is copied next to it) at commit
`4ecfb9fb8d1d3b7009674869b3aaee2f904042e1`, verbatim
(sha256 `d246b026f4f29b5823a9cc857f9edf3d2507002e055e32040cadeaf3b38e0234`).
Keeping it as a separate file avoids a second frontmatter block inside
`SKILL.md`, and `add web` needs no network for it.

## Update and re-pin

1. Download the new tag tarball into an empty dir, record its sha256 here, and
   compare it with the upstream tag commit (`git ls-remote`).
2. Replace the directory with the verbatim upstream bytes (no install scripts).
   Keep `taste-skill/LICENSE`: copy it again from the root of the tarball, since
   `skills/taste-skill/` does not hold it, and update its sha256 in
   `scripts/tests/ai-pack-manifest.test.sh` and
   `scripts/tests/ai-pack-taste-license.test.sh` if it changed.
3. Re-apply the archify edits above and keep the `ai-dotfiles vendor patch` marker;
   delete `archify/examples/*.html` again.
4. Run `bin/ai-pack hash packs/vendor/<dir>` and put the result in `packs.json`.
5. Update the `reviewed` value in `upstreams.json`, then run `make check`.
