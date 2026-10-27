# tldr use cases

What I do with tldr when the main path in [`README.md`](../README.md) is not enough: a pinned image,
files written from the container, an MCP client, a native install for features the image lacks.
If I change tldr itself, I go to [`CONTRIBUTING.md`](../CONTRIBUTING.md).

---

## Contents

- [Case 1. I want to pin an image version](#case-1-i-want-to-pin-an-image-version)
- [Case 2. I want to write a result file from the container](#case-2-i-want-to-write-a-result-file-from-the-container)
- [Case 3. I want to run commands that modify my project](#case-3-i-want-to-run-commands-that-modify-my-project)
- [Case 4. I want to connect an MCP client to the image](#case-4-i-want-to-connect-an-mcp-client-to-the-image)
- [Case 5. I want to install tldr natively](#case-5-i-want-to-install-tldr-natively)
- [Case 6. I want natural-language code search](#case-6-i-want-natural-language-code-search)
- [Case 7. I want faster repeated queries](#case-7-i-want-faster-repeated-queries)
- [Case 8. I want diagnostics with external linters](#case-8-i-want-diagnostics-with-external-linters)
- [Versioning](#versioning)

---

## Case 1. I want to pin an image version

**When.** `:latest` moves with every release, and I need the same tldr in my scripts today and in a month.

**What I do.** I pull a release tag instead of `:latest`:

```bash
docker pull ghcr.io/united-software-platform/tldr-code:0.4.0
```

Every release `vX.Y.Z` publishes three tags: `X.Y.Z` never moves, `X.Y` follows patch releases,
`latest` follows every release. I use the same tag in my shell function:

```bash
tldr() { docker run --rm -u "$(id -u):$(id -g)" -v "$PWD:/project:ro" ghcr.io/united-software-platform/tldr-code:0.4.0 "$@"; }
```

When I need a byte-for-byte identical image, I resolve the tag to a digest and use the reference it prints:

```bash
docker inspect --format '{{index .RepoDigests 0}}' ghcr.io/united-software-platform/tldr-code:0.4.0
```

**What I get.** `tldr --version` prints the version from the tag, and it does not change until I change the tag.

---

## Case 2. I want to write a result file from the container

**When.** A command writes a file I asked for, such as a patched source from `fix apply -o`, and stdout is not enough.

**What I do.** I create the output directory first and mount it as `/out` next to the read-only project:

```bash
mkdir -p out
docker run --rm -u "$(id -u):$(id -g)" \
  -v "$PWD:/project:ro" -v "$PWD/out:/out" \
  ghcr.io/united-software-platform/tldr-code:latest fix apply -s app.py --error-file error.txt -o /out/app.py
```

**What I get.** `out/app.py` with the fix, owned by my user. The project itself stays untouched.

**If it fails.** If `out/` did not exist before the run, Docker creates it owned by root and the container
cannot write there. I remove it, create it with `mkdir -p out` and run the command again.

---

## Case 3. I want to run commands that modify my project

**When.** I need `fix apply -i`, `warm` or `cache clear`: they write into the project and fail when it is mounted `:ro`.

**What I do.** I mount the project without `:ro` and keep `-u` so that new files belong to me:

```bash
docker run --rm -u "$(id -u):$(id -g)" \
  -v "$PWD:/project" \
  ghcr.io/united-software-platform/tldr-code:latest fix apply -s app.py --error-file error.txt -i
```

**What I get.** `app.py` is fixed in place. `warm` and `cache clear` work the same way in this mount.

**If it fails.** Files owned by UID `1000` mean I dropped `-u`: the image then runs as its own user.
I fix the owner with `sudo chown -R "$(id -u):$(id -g)" .tldr` and keep `-u` from then on.

---

## Case 4. I want to connect an MCP client to the image

**When.** My agent or editor speaks the Model Context Protocol (MCP), and I want it to call tldr without installing it.

**What I do.** The MCP server `tldr-mcp` is in the image and talks over stdin/stdout. This is the command
the client starts:

```bash
docker run -i --rm -v "$PWD:/project:ro" --entrypoint tldr-mcp ghcr.io/united-software-platform/tldr-code:latest
```

In Claude Code I register it from the project root; `$PWD` is expanded once, at registration:

```bash
claude mcp add tldr -- docker run -i --rm -v "$PWD:/project:ro" --entrypoint tldr-mcp ghcr.io/united-software-platform/tldr-code:latest
```

Other clients get the same command in their config, with an absolute project path:

```json
{
  "mcpServers": {
    "tldr": {
      "command": "docker",
      "args": ["run", "-i", "--rm", "-v", "/path/to/project:/project:ro",
               "--entrypoint", "tldr-mcp", "ghcr.io/united-software-platform/tldr-code:latest"]
    }
  }
}
```

**What I get.** The client lists the tldr tools and runs them against my project. Tools and their
arguments are described in [`MCP.md`](./MCP.md).

---

## Case 5. I want to install tldr natively

**When.** I need what the image lacks — semantic search, the daemon, external linters — or I do not use Docker.

**What I do.** I install the crate with a Rust toolchain:

```bash
cargo install tldr-cli
tldr --version
```

The crate is published by the upstream project [parcadei/tldr-code](https://github.com/parcadei/tldr-code).
Prebuilt binaries and a source build are in [`INSTALL.md`](./INSTALL.md).

**What I get.** A local `tldr` binary with every command except semantic search; case 6 adds it.

---

## Case 6. I want natural-language code search

**When.** I look for code by meaning — "where do we retry HTTP calls" — rather than by name.

**What I do.** I install tldr natively with the `semantic` feature and query my project:

```bash
cargo install tldr-cli --features semantic
tldr semantic 'retry http calls' src/
```

The feature adds three commands:

- `tldr semantic '<query>' <path>` — natural-language code search;
- `tldr embed <path>` — build the embedding index;
- `tldr similar <file>` — find similar fragments.

**What I get.** Code fragments ranked by meaning. The first run downloads the arctic-embed-m model
(~110MB) and caches it.

**If it fails.** The feature pulls in `fastembed` and ONNX Runtime and builds reliably on macOS only.
On other platforms the build is unverified: if it does not compile for me, I use the image for everything
else and send the build fix as a PR.

---

## Case 7. I want faster repeated queries

**When.** I run many queries against the same codebase, and each one parses it again.

**What I do.** With a native install (case 5) I start the daemon, warm its cache and query as usual:

```bash
tldr daemon start
tldr warm src/          # Pre-warm cache
tldr calls src/         # Fast — cache hit
tldr daemon stop
```

**What I get.** Repeated queries are answered from the in-memory cache. The image cannot do this:
its container exits after each command.

---

## Case 8. I want diagnostics with external linters

**When.** `diagnostics`, `fix check` or the linter stage of `bugbot` report `pyright`, `eslint`, `ruff`,
`golangci-lint` or `cargo clippy` as missing — the image does not contain them.

**What I do.** I install tldr natively (case 5), install the linters of my language so that they are on
`PATH`, and run the command from there. `tldr diagnostics --help` prints its options.

**What I get.** Diagnostics with the linters' findings instead of "missing" reports.

---

## Versioning

| Version | Date | Task | Agent | Model | Changes |
|---------|------|------|-------|-------|---------|
| 1.0.0 | 2026-10-27 | TLDR-001, OpenSpec change `restructure-project-docs` | Claude Code | Claude Opus 5.5 | Initial version: eight cases beyond the main path of `README.md` — four for the image, four for the native install |
