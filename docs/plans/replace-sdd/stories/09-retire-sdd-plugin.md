# Story 09: retire the sdd plugin

## Story

09. As a developer, I want the `sdd` plugin removed from the repo, the marketplace and my machine so that only the new loop is installed. Requires: #03, #05, #06

## Acceptance criteria

- [x] Given a machine where `sdd` is installed and linked, when I run the installer, then the plugin is uninstalled and every link into this repo that no longer resolves is removed, while links that still resolve and anything that is not such a link stay untouched.
- [x] Given a machine without `sdd`, when I run the installer twice, then `sdd` is never installed or linked and the second run changes nothing.
- [x] Given the repo, when I list the marketplace, then `sdd` is not offered, its folder is gone, the upstream reference notes it carried are kept outside it, the changed plugin versions are bumped and `make check` passes.

## Plan

- The installer drops `sdd` from the plugins it installs and uninstalls it when it finds it installed.
- One prune pass removes broken links that point into this repo, in every place the installer links to (Claude, OpenCode, Antigravity, bin, units).
- The plugin folder and its marketplace entry go; the vendored upstream notes move to a reference folder.
- Install tests cover: sdd present then removed, broken repo links pruned, a resolving link and a foreign link kept, second run a no-op.

## Out of scope

- Text references to SDD anywhere else (README, `claude/CLAUDE.md`, `docs/multi-agent.md`, toolkit skills, `openspec/config.yaml`, flow skills) and the `rg -iw sdd` allowlist test: story 10.
- The skill-local "4+ files" wording in `research`, `foundation` and `plan`: story 10.
- Old engram `sdd/*` and `sdd-init/*` topics: left as they are.
- `openspec/specs/` and `openspec/changes/archive/` (frozen history).

## Suggestions (your call)

- After this story the always-on rules still say "SDD commands are `/sdd:*`" until story 10 lands; merging 09 and 10 close together avoids a session that points to a missing plugin.

## Size

normal
Risk: item 1 (uninstalls a plugin and deletes links on the user's machine), item 3 (marketplace others install from), item 5 (install script)

## Log

- L1 request: `/flow:story 07`
- L2 split: story 07 needed more than 3 criteria (plugin and installer, plus every text reference and the allowlist test). Backlog: `07. [-] split → #09, #10`; story 08 now `Requires: #10` so `/flow:next` can still reach it. The gate (quickshell `notch-workspaces-osd` archived) is met: bdf396e, pushed.
- L3 assumptions for approval: "`docs/upstream/`" in the plan row means moving `plugins/sdd/upstream/` there; the prune only touches broken links that point into this repo; `flow`, `toolkit` and `look` versions change only if their files change here.
- L4 approved by the user ("si").
- L5 test list approved: 4 integration cases in `install.test.sh` and a new structural `plugins.test.sh`; user approved changing two existing install assertions ("all plugins are installed" without sdd; "sdd skills are linked for opencode" → "no sdd skill is linked for opencode").
- L6 cycles (mode C): 839868e→cdea935 retired plugins uninstalled when found (substring match: real `claude plugin list` prints `  ❯ sdd@ai-dotfiles`); 61ec22a, 0f30baa→e0d55a0 prune broken repo links in output-styles, bin, units and both skills folders (0f30baa renames the test link to `retired-skill` with the user's approval: `orchestrator` collided with the real sdd skill; red re-shown with the code set aside); 0b0261e pin (resolving, foreign and real entries kept; removing the repo-path guard fails the foreign case); a519ea3→7c4dd51 sdd out of `PLUGINS`; 15aa6db→3bbe68a sdd folder deleted (68 files), upstream notes moved to `docs/upstream/`, marketplace entry and description updated. The "not linked" half of test 4 moved to the test 5 step (skills link from `plugins/*/skills/*`). User approved deleting gitignored eval results under the sdd folder. No flow/toolkit/look file changed: no version bump. Every code commit gated on `make check` ("All checks passed (7 steps)").
- L7 verifier (`flow:verifier`): Verdict: PASS. Notes: `--dry-run` prints "pruned broken link" after the dry-run line (same pattern as the existing Claude-only cleanup); `README.md` and `upstreams.json` still mention `plugins/sdd` (story 10).
- L8 Risk: item 1 (uninstalls a plugin and deletes links on the user's machine), item 3 (marketplace others install from), item 5 (install script).
