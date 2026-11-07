.PHONY: all check lint fmt setup clean

REGISTRIES := demo-registry tutorial-solution

all: lint fmt

# Lint the tracked Markdown, then validate every registry with jsm, at the
# version go.mod pins. Runs each registry, then fails if any failed.
# Lint needs Bun and the dev dependencies (`make setup`); without them it
# fails rather than being skipped.
check: lint
	@status=0; \
	for r in $(REGISTRIES); do \
		echo "== $$r"; \
		JSM_REGISTRY_ROOT_DIR=$$r go tool jsm validate all --continue-on-error || status=1; \
	done; \
	exit $$status

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
