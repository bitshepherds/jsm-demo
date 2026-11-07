.PHONY: all check validate replay scenarios lint fmt setup clean

all: lint fmt

# The gate: lint the tracked Markdown, then the registry, then the
# getting-started page's replay, then each scenario page's breaking edit. Lint
# needs Bun and the dev dependencies (`make setup`); without them it fails
# rather than being skipped.
check: lint validate replay scenarios

# Validate the registry with jsm, at the version go.mod pins.
# -C runs every schema even after a failure: without it, validate stops at the
# first failure and reports schemas it never ran as passed
# (bitshepherds/json-schema-manager#155).
validate:
	@go tool jsm -r registry validate all -C

# Replay every step of docs/getting-started.md in a temporary copy of the repo.
replay:
	@scripts/replay-getting-started.sh

# Make each docs/scenarios page's breaking edit in a temporary copy of the
# registry, and check that jsm refuses it with the rule the page names.
scenarios:
	@scripts/check-scenarios.sh

# Run linter
lint:
	@bun run lint

# Format code
fmt:
	@bun run fmt

# Setup development environment
setup:
	@bun install
	@lefthook install

# Clean build artifacts
clean:
	@rm -rf dist/
