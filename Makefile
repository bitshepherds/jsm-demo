.PHONY: all build run clean test test-race test-cover check-coverage cover-html lint fmt snapshot release-check setup

all: build

# Build the application
build:
	@go run scripts/build/main.go

# Run GoReleaser snapshot
snapshot:
	@go run scripts/snapshot/main.go

# Run the application
run:
	@go run cmd/jsm/main.go

# Clean build artifacts
clean:
	@go run scripts/clean/main.go
	@go clean

# Run tests
test:
	@go run scripts/tester/main.go ./... -v

# Run linter
lint:
	@go run scripts/lint/main.go

# Format code with gofumpt
fmt:
	@go run scripts/fmt/main.go

# Setup development environment
setup:
	@go run scripts/setup/main.go
