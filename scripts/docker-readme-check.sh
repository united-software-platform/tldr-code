#!/bin/sh
# Проверка Docker-примеров документов на образе tldr: шагов README.md и кейсов 2 и 4
# docs/use-cases.md (design.md изменения add-docker-image-delivery, D5; restructure-project-docs, D5).
# Скрипт документы не разбирает и хранит копии команд: пример меняется вместе со скриптом в одном коммите.
#
# Создаёт во временном каталоге проект на Python и выполняет над ним команды README так,
# как их запускает пользователь: под собственным UID, с проектом :ro и каталогом /out.
# Имя образа в командах README заменяется аргументом скрипта.
#
# Использование: sh scripts/docker-readme-check.sh <образ>
# Коды возврата: 0 — все примеры работают как написано, 1 — есть расхождения, 2 — ошибка вызова или окружения.

set -u

image="${1:-}"
if [ -z "$image" ]; then
    echo "usage: sh scripts/docker-readme-check.sh <image>" >&2
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

work=$(mktemp -d) || exit 2
# Проект читаем и для пользователя образа по умолчанию: пример MCP запускается без -u
chmod 755 "$work"
trap 'rm -rf "$work"' EXIT
cd "$work" || exit 2

me="$(id -u):$(id -g)"
failures=0

pass() { echo "ok   - $1"; }
fail() { echo "FAIL - $1" >&2; failures=$((failures + 1)); }

# Проект с ошибкой, которую fix apply исправляет детерминированно: импорт из stdlib
printf 'def load(text):\n    return json.loads(text)\n' > app.py
cat > error.txt <<'EOF'
Traceback (most recent call last):
  File "app.py", line 2, in load
    return json.loads(text)
NameError: name 'json' is not defined
EOF
app_before=$(cat app.py)

# Функция из README; образ подставлен аргументом
tldr() { docker run --rm -u "$me" -v "$PWD:/project:ro" "$image" "$@"; }

# 1. Основной вызов: structure . над проектом :ro
if out=$(tldr structure . 2>/dev/null) && printf '%s' "$out" | jq empty 2>/dev/null; then
    pass "structure . on read-only project"
else
    fail "structure . on read-only project"
fi

# 2. Shell-функция из README
if tldr --version 2>/dev/null | grep -q "tldr"; then
    pass "shell function runs tldr --version"
else
    fail "shell function runs tldr --version"
fi

# 3. Запись результата в /out: каталог создаётся заранее, файл принадлежит пользователю
mkdir -p out
if docker run --rm -u "$me" -v "$PWD:/project:ro" -v "$PWD/out:/out" "$image" \
    fix apply -s app.py --error-file error.txt -o /out/app.py >/dev/null 2>&1 \
    && grep -q '^import json' out/app.py 2>/dev/null \
    && [ "$(ls -ln out/app.py | awk '{print $3}')" = "$(id -u)" ]; then
    pass "fix apply writes patched file to /out"
else
    fail "fix apply writes patched file to /out"
fi

# 4. MCP-сервер в форме из README: без -u, stdio
init_request='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"docker-readme-check","version":"0"}}}'
if printf '%s\n' "$init_request" \
    | docker run -i --rm -v "$PWD:/project:ro" --entrypoint tldr-mcp "$image" 2>/dev/null \
    | jq -e 'select(.id == 1) | .result' >/dev/null 2>&1; then
    pass "tldr-mcp answers initialize"
else
    fail "tldr-mcp answers initialize"
fi

# 5. Ограничения: семантический поиск отсутствует
if tldr semantic "load json" . >/dev/null 2>&1; then
    fail "semantic is an unknown subcommand"
else
    pass "semantic is an unknown subcommand"
fi

# 6. Ограничения: команды с записью в проект под :ro
if tldr warm . >/dev/null 2>&1; then
    fail "warm fails on read-only project"
else
    pass "warm fails on read-only project"
fi

if tldr fix apply -s app.py --error-file error.txt -i >/dev/null 2>&1; then
    fail "fix apply -i fails on read-only project"
else
    pass "fix apply -i fails on read-only project"
fi

mkdir -p .tldr/cache
echo '{}' > .tldr/cache/call_graph.json
tldr cache clear >/dev/null 2>&1
if [ -f .tldr/cache/call_graph.json ]; then
    pass "cache clear removes nothing on read-only project"
else
    fail "cache clear removes nothing on read-only project"
fi

if [ "$(cat app.py)" = "$app_before" ]; then
    pass "project on host is unchanged"
else
    fail "project on host is unchanged"
fi

if [ "$failures" -gt 0 ]; then
    echo "$failures check(s) failed" >&2
    exit 1
fi
echo "all checks passed"
