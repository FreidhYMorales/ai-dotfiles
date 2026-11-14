# Verification harness: agent output is accepted when `make check` passes.
# `check` runs every step and prints a summary; the sub-targets run one area.
.PHONY: check check-fast lint validate test eval mutate

check:
	@bash scripts/check.sh

# The fast tier the require-check Stop hook runs between turns: static checks
# only, no tests or bench. `check` stays the gate for a story, a ship and CI.
check-fast:
	@bash scripts/check-shell.sh
	@bash scripts/check-json.sh
	@bash scripts/check-structure.sh
	@bash scripts/check-settings.sh
	@bash scripts/check-skills.sh
	@bash scripts/check-workflows.sh

lint:
	@bash scripts/check-shell.sh
	@bash scripts/check-skills.sh

validate:
	@bash scripts/check-json.sh
	@bash scripts/check-structure.sh
	@bash scripts/check-settings.sh

test:
	@bash scripts/run-tests.sh

# Skill evals run real Claude sessions (they use the plan's quota), so they are
# not part of `check`. --scaffold runs our own cases' scaffold.sh to seed the
# workspace. Usage: make eval PLUGIN=flow [CASE=<glob>]
PLUGIN ?= flow
eval:
	@cd plugins/$(PLUGIN) && claude plugin eval . --scaffold --no-publish --trust-plugin --max-cost-usd 6 $(if $(CASE),--case '$(CASE)')

# Mutation testing for the toolkit hooks (slow; not part of `check`): flips one
# operator at a time and reports mutants the tests fail to catch.
HOOKS ?= prefer-modern-cli require-check update-check host-info pause pack-hint backup-status protect-credentials hooks-path
mutate:
	@for h in $(HOOKS); do echo "### $$h"; bash scripts/mutate.sh plugins/toolkit/hooks/$$h.sh bash plugins/toolkit/hooks/tests/$$h.test.sh; done
