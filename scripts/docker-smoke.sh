#!/bin/sh
# Дымовая проверка Docker-образа tldr (design.md изменения add-docker-image-delivery, D5).
#
# Запускает образ на корне этого репозитория, смонтированном только для чтения, под UID,
# которого нет в образе, и проверяет контракт поставки: точку входа, коды возврата, JSON
# команд анализа, git под чужим UID, MCP-сервер и отказ записи в проект.
#
# Использование: sh scripts/docker-smoke.sh <образ>
# Коды возврата: 0 — проверка пройдена, 1 — есть проваленные проверки, 2 — ошибка вызова или окружения.

set -u

image="${1:-}"
if [ -z "$image" ]; then
    echo "usage: sh scripts/docker-smoke.sh <image>" >&2
    exit 2
fi

for tool in docker jq; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "error: $tool not found in PATH" >&2
        exit 2
    fi
done

if ! docker image inspect "$image" >/dev/null 2>&1; then
    echo "error: image $image not found locally" >&2
    exit 2
fi

repo_root=$(cd "$(dirname "$0")/.." && pwd)
foreign_uid="12345:12345"
failures=0

expected_version=$(sed -n '/^\[workspace\.package\]/,/^\[/s/^version = "\(.*\)"/\1/p' "$repo_root/Cargo.toml")
if [ -z "$expected_version" ]; then
    echo "error: version not found in [workspace.package] of Cargo.toml" >&2
    exit 2
fi

pass() { echo "ok   - $1"; }
fail() { echo "FAIL - $1" >&2; failures=$((failures + 1)); }

# Запуск tldr над проектом :ro под чужим UID
tldr_run() {
    docker run --rm -u "$foreign_uid" -v "$repo_root:/project:ro" "$image" "$@"
}

# Запуск команды анализа: код 0 и валидный JSON в stdout
check_json() {
    name="$1"
    shift
    if out=$(tldr_run "$@" 2>/dev/null) && printf '%s' "$out" | jq empty 2>/dev/null; then
        pass "$name"
    else
        fail "$name"
    fi
}

# 1. Версия в образе совпадает с версией workspace
if tldr_run --version 2>/dev/null | grep -q "$expected_version"; then
    pass "--version reports $expected_version"
else
    fail "--version reports $expected_version"
fi

# 2. Запуск без аргументов печатает справку с кодом 0
if docker run --rm "$image" 2>/dev/null | grep -q "Usage"; then
    pass "no arguments prints help"
else
    fail "no arguments prints help"
fi

# 3. Без -u процесс выполняется не от root
if [ "$(docker run --rm --entrypoint id "$image" -u 2>/dev/null)" != "0" ]; then
    pass "default user is not root"
else
    fail "default user is not root"
fi

# 4. Код возврата tldr передаётся контейнером
if tldr_run definitely-not-a-command >/dev/null 2>&1; then
    fail "unknown subcommand exits non-zero"
else
    pass "unknown subcommand exits non-zero"
fi

# 5. Команды анализа на проекте :ro
check_json "tree ." tree .
check_json "structure crates/tldr-mcp" structure crates/tldr-mcp
check_json "calls crates/tldr-mcp" calls crates/tldr-mcp

# 6. git работает с репозиторием чужого владельца
if docker run --rm -u "$foreign_uid" -v "$repo_root:/project:ro" --entrypoint git "$image" \
    -C /project rev-parse HEAD >/dev/null 2>&1; then
    pass "git reads repository under foreign UID"
else
    fail "git reads repository under foreign UID"
fi
check_json "churn ." churn .

# 7. MCP-сервер отвечает на initialize через stdio
init_request='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"docker-smoke","version":"0"}}}'
if printf '%s\n' "$init_request" \
    | docker run -i --rm -u "$foreign_uid" -v "$repo_root:/project:ro" --entrypoint tldr-mcp "$image" 2>/dev/null \
    | jq -e 'select(.id == 1) | .result' >/dev/null 2>&1; then
    pass "tldr-mcp answers initialize"
else
    fail "tldr-mcp answers initialize"
fi

# 8. Команда с записью в проект отказывает и не оставляет следов на хосте
tldr_dir_before=$([ -e "$repo_root/.tldr" ] && echo yes || echo no)
tldrignore_before=$([ -e "$repo_root/.tldrignore" ] && echo yes || echo no)
if tldr_run warm . >/dev/null 2>&1; then
    fail "warm fails on read-only project"
else
    pass "warm fails on read-only project"
fi
tldr_dir_after=$([ -e "$repo_root/.tldr" ] && echo yes || echo no)
tldrignore_after=$([ -e "$repo_root/.tldrignore" ] && echo yes || echo no)
if [ "$tldr_dir_before" = "$tldr_dir_after" ] && [ "$tldrignore_before" = "$tldrignore_after" ]; then
    pass "project on host is unchanged"
else
    fail "project on host is unchanged"
fi

if [ "$failures" -gt 0 ]; then
    echo "$failures check(s) failed" >&2
    exit 1
fi
echo "all checks passed"
