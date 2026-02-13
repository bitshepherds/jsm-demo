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

## 🚀 Commit Workflow

We use **Conventional Commits**. Our pre-commit hooks (via `lefthook`) will automatically:

- Format your staged files using **Prettier**.
- Lint your Markdown files using **markdownlint**.

If your code doesn't meet the standards, the commit will be rejected with an explanation.
