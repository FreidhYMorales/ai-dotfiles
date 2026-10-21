# Delta for Statusline

## ADDED Requirements

### Requirement: Segment order

The status line MUST render segments in the order `ctx · 5h [↻HH:MM] · 7d · model · repo ⎇ branch[*]`, with every meter before the place. The zellij session name MUST NOT appear.

#### Scenario: Meters before place

- GIVEN a payload with ctx, 5h and 7d data inside a git repo
- WHEN the script renders
- THEN the visible text shows ctx, 5h, 7d, model, then repo and branch, in that order
- AND no zellij session name is present

### Requirement: Eighth-block bars

Each meter MUST draw a 6-cell bar with 1/8-cell precision (`█▉▊▋▌▍▎▏`, 48 steps) computed with integer math on the percent: full cells, one partial glyph, and a dim track for the remaining cells.

#### Scenario: Partial fill

- GIVEN ctx at 42%
- WHEN the bar renders
- THEN it shows 2 full cells, one partial glyph and a dim track for the rest

#### Scenario: Zero percent

- GIVEN a meter at 0%
- WHEN the bar renders
- THEN all 6 cells are dim track

### Requirement: Meter colors

Each meter MUST be green below 50%, yellow below 80%, and red otherwise.

#### Scenario: Color thresholds

- GIVEN meters at 49%, 50%, 79% and 80%
- WHEN each renders
- THEN they are green, yellow, yellow and red respectively

### Requirement: 5h reset time

The 5h meter MUST show `↻HH:MM` from `rate_limits.five_hour.resets_at` only when its usage is at least 80%.

#### Scenario: Reset shown at threshold

- GIVEN 5h usage of 84% and a `resets_at` epoch
- WHEN the script renders
- THEN `↻HH:MM` follows the 5h meter

#### Scenario: Reset hidden below threshold

- GIVEN 5h usage of 79%
- WHEN the script renders
- THEN no reset time is shown

### Requirement: 7d meter

The status line MUST show a 7d meter from `rate_limits.seven_day.used_percentage`.

#### Scenario: 7d present

- GIVEN 7d usage of 61%
- WHEN the script renders
- THEN a 7d bar and `61%` appear after the 5h meter

### Requirement: Place segment

The place MUST show the model name without a leading "Claude ", then repo and branch. A trailing `*` on the branch MUST mark a dirty worktree. Repo MUST be truncated to 16 characters and branch to 20, using `…`.

#### Scenario: Model prefix stripped

- GIVEN model display name "Claude Opus"
- WHEN the script renders
- THEN the model shows as `Opus`

#### Scenario: Dirty marker

- GIVEN a repo with uncommitted changes on branch `main`
- WHEN the script renders
- THEN the branch shows as `main*`

#### Scenario: Long names truncated

- GIVEN a 30-character repo name and a 40-character branch
- WHEN the script renders
- THEN repo is at most 16 and branch at most 20 characters, each ending in `…`

### Requirement: Length budget and right truncation

The worst-case visible length MUST be about 100 columns. Narrow panes MUST lose the end of the branch first and MUST NOT lose a meter, because the host truncates on the right.

#### Scenario: Worst-case length

- GIVEN all meters at 100%, longest allowed model, repo and branch, dirty tree, reset shown
- WHEN the script renders
- THEN the visible length does not exceed the budget asserted by the test

### Requirement: Degraded states

The script MUST degrade without error: no git means no branch; no `rate_limits` means only ctx; a missing quota omits only that meter.

#### Scenario: No git

- GIVEN a directory outside a git repo
- WHEN the script renders
- THEN no branch segment appears and meters are intact

#### Scenario: No rate limits

- GIVEN a payload without `rate_limits`
- WHEN the script renders
- THEN only the ctx meter and place appear

#### Scenario: One quota missing

- GIVEN a payload with 5h but without 7d
- WHEN the script renders
- THEN the 5h meter appears and the 7d meter is omitted

### Requirement: Documented behavior change

Tests and README rows MUST reflect the removed zellij name, the 5h reset rule, the new order and the 7d meter.

#### Scenario: Gate passes

- GIVEN the redesigned script and updated tests
- WHEN `make check` runs
- THEN it passes and README rows describe the new behavior
