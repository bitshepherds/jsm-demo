# Contributing to the JSM Demo Registry

This project follows a **Documentation-as-Code** approach. We use [Bun](https://bun.sh/) to manage our documentation tooling to ensure consistency with GitHub's rendering.

## 🛠 Setup

### 1. Install Bun

Install [Bun](https://bun.sh/) (a fast JavaScript runtime) and then run:

### 2. Install Dependencies

```bash
bun install
```

### 3. Install VS Code Extensions

When starting the IDE, you will be prompted to install the recommended extensions.

### Manual Formatting & Linting

If you are not using VS Code, you can run these commands manually:

```bash
# Format all files
bun run fmt

# Lint Markdown files
bun run lint
```

`bun run lint` lints only the Markdown files git tracks, so `git add` a new doc before you lint it.

## ✅ Checks

`make check` lints the tracked Markdown first, then validates the registry, then replays every step of `docs/getting-started.md`. Every pull request's CI runs the same steps, `make lint validate` in its `check` job and `make replay` in its own job, so a Markdown style error fails it.

`make check` needs:

- [Go](https://go.dev/dl/), at the version `go.mod` pins. `go tool jsm` fetches jsm itself.
- Bun and the dev dependencies: run `make setup`, or `bun install`, first.
- [git](https://git-scm.com/downloads): the replay copies the checkout into a git repo of its own, and runs the page's `git restore` there.

## 🚀 Commit Workflow

We use **Conventional Commits**. Our pre-commit hooks (via `lefthook`) will automatically:

- Format your staged files using **Prettier**.
- Lint your Markdown files using **markdownlint**.

If your code doesn't meet the standards, the commit will be rejected with an explanation.
