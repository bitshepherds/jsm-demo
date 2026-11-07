.PHONY: all check lint fmt setup clean

all: lint fmt

# Lint the tracked Markdown, then validate the registry with jsm, at the
# version go.mod pins. Lint needs Bun and the dev dependencies (`make setup`);
# without them it fails rather than being skipped.
# -C runs every schema even after a failure: without it, validate stops at the
# first failure and reports schemas it never ran as passed
# (bitshepherds/json-schema-manager#155).
check: lint
	@go tool jsm -r registry validate all -C

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
