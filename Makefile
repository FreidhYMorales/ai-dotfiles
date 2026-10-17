# Verification harness: agent output is accepted when `make check` passes.
# `check` runs every step and prints a summary; the sub-targets run one area.
.PHONY: check lint validate test eval

check:
	@bash scripts/check.sh

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
