# tldr

[![Version](https://img.shields.io/github/v/tag/united-software-platform/tldr-code?sort=semver&label=version)](https://github.com/united-software-platform/tldr-code/pkgs/container/tldr-code)
[![License: AGPL-3.0](https://img.shields.io/badge/license-AGPL--3.0-blue)](./LICENSE)
[![Docker image](https://github.com/united-software-platform/tldr-code/actions/workflows/docker.yml/badge.svg)](https://github.com/united-software-platform/tldr-code/actions/workflows/docker.yml)
[![Platforms: linux/amd64, linux/arm64](https://img.shields.io/badge/platforms-linux%2Famd64%20%7C%20linux%2Farm64-blue)](https://github.com/united-software-platform/tldr-code/pkgs/container/tldr-code)

Token-efficient code analysis for LLMs: function signatures, call graphs, taint flows, complexity and dead code
of 18 languages as structured JSON instead of raw source dumps. Here is the path from nothing but Docker
to your first analysis; other tasks are in the [use cases](./docs/use-cases.md), changing tldr itself — in [`CONTRIBUTING.md`](./CONTRIBUTING.md).

---

## Contents

- [What you need](#what-you-need)
- [Step 1. Pull the image](#step-1-pull-the-image)
- [Step 2. Run your first analysis](#step-2-run-your-first-analysis)
- [Step 3. Call tldr like a local binary](#step-3-call-tldr-like-a-local-binary)
- [Where next](#where-next)
- [Limitations](#limitations)
- [License](#license)

---

## What you need

- Docker on a `linux/amd64` or `linux/arm64` host; on macOS, Docker Desktop. Rust and the tldr CLI are not needed.
- A project in one of the supported languages: Python, TypeScript, JavaScript, Go, Rust, Java, C, C++, Ruby,
  Kotlin, Swift, C#, Scala, PHP, Lua, Luau, Elixir, OCaml.

---

## Step 1. Pull the image

```bash
docker pull ghcr.io/united-software-platform/tldr-code:latest
```

Docker picks the native image for your architecture. `:latest` follows every release.

More — [case 1](./docs/use-cases.md#case-1-i-want-to-pin-an-image-version).

---

## Step 2. Run your first analysis

Go to the root of your project and run:

```bash
docker run --rm \
  -u "$(id -u):$(id -g)" \
  -v "$PWD:/project:ro" \
  ghcr.io/united-software-platform/tldr-code:latest structure .
```

The project is mounted read-only at `/project`, so paths are relative to its root. Everything after the
image name is passed to `tldr` unchanged; without arguments the image prints `tldr --help`. The result —
functions, classes and imports of your code as JSON — goes to stdout, so redirect or pipe it as usual.

More — cases [2](./docs/use-cases.md#case-2-i-want-to-write-a-result-file-from-the-container), [3](./docs/use-cases.md#case-3-i-want-to-run-commands-that-modify-my-project).

---

## Step 3. Call tldr like a local binary

Add a shell function to `~/.bashrc` or `~/.zshrc` and open a new shell:

```bash
tldr() { docker run --rm -u "$(id -u):$(id -g)" -v "$PWD:/project:ro" ghcr.io/united-software-platform/tldr-code:latest "$@"; }
```

Now `tldr` runs in the current directory like an installed tool:

```bash
# What's in this codebase?
tldr structure src/

# Who calls this function?
tldr impact parse_config src/

# Find dead code
tldr dead src/

# Security scan
tldr secure src/

# Full health dashboard
tldr health src/
```

More — [case 4](./docs/use-cases.md#case-4-i-want-to-connect-an-mcp-client-to-the-image).

---

## Where next

- Pinned versions, files written from the container, MCP clients, native install, semantic search, the daemon,
  external linters — in the [use cases](./docs/use-cases.md).
- All commands and output formats are printed by `tldr --help`, the options of one command by `tldr <command> --help`;
  the [command reference](./docs/commands/) describes them in detail.
- MCP tools — in [`docs/MCP.md`](./docs/MCP.md), common problems — in [`docs/TROUBLESHOOTING.md`](./docs/TROUBLESHOOTING.md),
  how tldr works inside — in [`docs/ARCHITECTURE.md`](./docs/ARCHITECTURE.md).
- If you want to change tldr itself — [`CONTRIBUTING.md`](./CONTRIBUTING.md).

---

## Limitations

Of the image:

- Semantic search is not included: `embed`, `semantic` and `similar` are unknown subcommands.
- Daemon mode is not supported: the container exits after each command.
- With the project mounted read-only, commands that write into it do not work: `warm` and `fix apply -i` fail, `cache clear` removes nothing. Mount the project without `:ro` if you need them.
- `bugbot` skips the baseline comparison: it needs `git worktree add`, which writes into `.git/`.
- External linters (`pyright`, `eslint`, `ruff`, `golangci-lint`, `cargo clippy` and others) are not in the image, so `diagnostics`, `fix check` and the linter stage of `bugbot` report them as missing.

Of the native install: semantic search (`--features semantic`) builds reliably on macOS; other platforms are unverified.

---

## License

tldr is distributed under AGPL-3.0; the license text is in [`LICENSE`](./LICENSE).
