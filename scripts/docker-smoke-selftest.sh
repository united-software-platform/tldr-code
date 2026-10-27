#!/bin/sh
# Самопроверка scripts/docker-smoke.sh: скрипт обязан ловить поломку образа
# (design.md изменения add-docker-image-delivery, D5).
#
# Из проверяемого образа без пересборки делается образ без safe.directory — так ломается
# git под чужим UID. Дымовая проверка на нём обязана завершиться кодом 1 и назвать churn,
# а вызов без аргумента — кодом 2. Сборщик не нужен: образ получается через docker commit,
# поэтому самопроверка работает и при buildx-сборщике по умолчанию.
#
# Использование: sh scripts/docker-smoke-selftest.sh <образ>
# Коды возврата: 0 — дымовая проверка ловит поломку, 1 — не ловит, 2 — ошибка вызова или окружения.

set -u

image="${1:-}"
if [ -z "$image" ]; then
    echo "usage: sh scripts/docker-smoke-selftest.sh <image>" >&2
    exit 2
fi

if ! docker image inspect "$image" >/dev/null 2>&1; then
    echo "error: image $image not found locally" >&2
    exit 2
fi

script_dir=$(cd "$(dirname "$0")" && pwd)
broken="tldr-code:smoke-selftest-$$"
failures=0

pass() { echo "ok   - $1"; }
fail() { echo "FAIL - $1" >&2; failures=$((failures + 1)); }

# Образ без safe.directory: та же точка входа, пользователь и CMD, что у исходного
cid=$(docker create -u root --entrypoint git "$image" config --system --unset-all safe.directory) || exit 2
trap 'docker rm -f "$cid" >/dev/null 2>&1; docker rmi -f "$broken" >/dev/null 2>&1' EXIT
if ! docker start -a "$cid" >/dev/null; then
    echo "error: cannot remove safe.directory from $image" >&2
    exit 2
fi
docker commit \
    --change 'USER tldr' \
    --change 'ENTRYPOINT ["tldr"]' \
    --change 'CMD ["--help"]' \
    "$cid" "$broken" >/dev/null || exit 2

# 1. Поломка git ловится: код 1, проваленная проверка названа
report=$(sh "$script_dir/docker-smoke.sh" "$broken" 2>&1)
code=$?
if [ "$code" -eq 1 ] && printf '%s\n' "$report" | grep -q '^FAIL - churn'; then
    pass "smoke test fails with code 1 and names churn"
else
    fail "smoke test fails with code 1 and names churn (got code $code)"
    printf '%s\n' "$report" >&2
fi

# 2. Ошибка вызова отделена от проваленной проверки
sh "$script_dir/docker-smoke.sh" >/dev/null 2>&1
code=$?
if [ "$code" -eq 2 ]; then
    pass "smoke test without image exits with code 2"
else
    fail "smoke test without image exits with code 2 (got code $code)"
fi

if [ "$failures" -gt 0 ]; then
    echo "$failures check(s) failed" >&2
    exit 1
fi
echo "all checks passed"
