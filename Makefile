.PHONY: all lint fmt setup clean

all: lint fmt

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
