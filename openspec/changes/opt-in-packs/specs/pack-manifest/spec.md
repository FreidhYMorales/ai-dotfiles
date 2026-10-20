# Delta for pack-manifest

## ADDED Requirements

### Requirement: Manifest schema

`packs/packs.json` MUST carry `schema_version` 1 and define tools and packs as objects keyed by name. A tool has `kind` skill|npm, `source`, `layers` (array: machine and/or project), `requires`, `project_dirs`, `leftovers`. A pack has `tools` and `detect`. This schema, including detect rules, is a frozen contract.

#### Scenario: Valid manifest
- GIVEN the repo manifest
- WHEN parsed with `jq`
- THEN `schema_version` is 1 and every pack tool names a defined tool
- AND every tool has a kind of `skill` or `npm`

### Requirement: Pinned sources

Each tool MUST declare one source: vendored (tag + pinned tree hash, under `packs/vendor/`), fetched (pinned commit URL + sha256, never committed), or npm (exact version + sha512 integrity of the `npm pack` tarball).

#### Scenario: Licensed rules are vendored with their license
- GIVEN the `web-design-guidelines` tool (upstream added an MIT LICENSE in 2025-09)
- WHEN the repo is inspected
- THEN its SKILL.md is in-house
- AND the rules are vendored as `rules.md` (upstream `command.md` at a pinned commit) with the upstream LICENSE, under `packs/vendor/web-design-guidelines/`
- AND the pinned tree hash covers all three files

Amended after implementation (2026-10-19). The original scenario said the rules were a fetched pin with no committed copy because the upstream had no LICENSE file. That reason no longer holds, so the shipped code vendors the file (commit 4ecfb9f).

Note on "vendored": a vendored tool MAY omit unused upstream files when `packs/vendor/README.md` says so. `archify` omits the 15 rendered showcase pages `examples/*.html` (11.9 MB); nothing in the skill reads them, and the pinned hash is of the trimmed tree.

### Requirement: Pinned tree hash

The pinned hash MUST be a sha256 over NUL-sorted lines of (file type, exec bit, relative path, file sha256) of the final directory contents, excluding `.gitignore`. It MUST NOT depend on umask, and templating MUST be deterministic.

#### Scenario: Deterministic hash
- GIVEN the same input copied twice under different umasks
- WHEN the tree hash is computed
- THEN both hashes are equal

### Requirement: Requirements declaration

`requires` entries MUST accept `cmd`, optional `min`, and `hint`. Kind `npm` tools MUST require `npm`. The `web` tools MUST require `chromium` (hint `sudo pacman -S chromium`) and `node` >= 22.

#### Scenario: Min version declared
- GIVEN the `web` pack
- WHEN its requires are read
- THEN `node` has `min` 22 and `chromium` has the pacman hint

### Requirement: Detect rules

A pack's `detect` MAY use `files_any` and `package_deps_any`. `web` MUST use `package_deps_any` vite, react, vue, svelte, next, astro, or `files_any` root `index.html`. `diagrams` MUST have no rules.

#### Scenario: Diagrams is manual
- GIVEN the `diagrams` pack
- WHEN its detect rules are read
- THEN there are none

### Requirement: v1 pack contents

Pack `web` MUST contain playwright-cli (npm 0.1.22, with `.playwright/cli.config.json` setting `executablePath` `/usr/bin/chromium` and `outputDir` `.playwright/output`, the latter a leftover), web-design-guidelines, and taste-skill (vendored v2.1.2). Pack `diagrams` MUST contain archify (vendored v3.2.0, patched to disable the update check).

#### Scenario: Pack membership
- GIVEN the manifest
- WHEN pack tools are listed
- THEN `web` = playwright, web-design-guidelines, taste and `diagrams` = archify

### Requirement: Vendor exclusion from lint

`scripts/check-shell.sh` MUST skip `packs/vendor/`, and `make check` MUST pass with vendored files present.

#### Scenario: Vendored script not linted
- GIVEN a non-conforming shell file in `packs/vendor/`
- WHEN `make check` runs
- THEN it passes
