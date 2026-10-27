# Design: add-docker-image-delivery

Как собирается, проверяется и публикуется образ `tldr`: устройство `Dockerfile`, workflow
и дымовой проверки, принятые решения и их альтернативы.

---

## Навигация

- [Context](#context)
- [Goals / Non-Goals](#goals--non-goals)
- [Decisions](#decisions)
- [Risks / Trade-offs](#risks--trade-offs)
- [Migration Plan](#migration-plan)
- [Версионирование](#версионирование)

---

## Context

Мотивация — в [proposal.md](./proposal.md#why), требования — в
[specs/docker-image/spec.md](./specs/docker-image/spec.md).

Наблюдаемое состояние репозитория:

- workspace версии `0.4.0` из четырёх crate'ов; бинари `tldr`, `tldr-daemon`, `tldr-mcp` собираются
  из crate `tldr-cli`; `Cargo.lock` в репозитории, `rust-toolchain.toml` нет;
- tree-sitter-грамматики компилируются из C-исходников — на этапе сборки нужен C-компилятор;
- `git` вызывается как внешняя программа: `churn`, `hotspots`, `change-impact`, `bugbot`;
- кэш пишется только внутрь проекта: `warm` создаёт `<проект>/.tldr/` и `<проект>/.tldrignore`,
  `cache stats|clear` и `search` работают с `<проект>/.tldr/cache/`; переменной для переноса кэша нет;
- `fix apply` пишет в stdout, `-o <файл>` — в файл, `-i` — поверх исходника;
- `bugbot` для сравнения с базовой версией делает `git worktree add`, а при ошибке пропускает этот шаг
  с предупреждением;
- `diagnostics`, `fix check` и L1-часть `bugbot` вызывают внешние линтеры из `PATH`;
- `tldr-mcp` — сервер протокола контекста модели (Model Context Protocol, MCP) — работает через stdin/stdout;
- без feature `semantic` подкоманды `embed`, `semantic`, `similar` в CLI не объявлены;
- единственный workflow непрерывной интеграции (Continuous Integration, CI) — `.github/workflows/release.yml`, сгенерированный cargo-dist, триггер —
  тег версии; origin — `github.com/united-software-platform/tldr-code`.

## Goals / Non-Goals

**Goals:**

- локальный `docker build .` даёт тот же образ, что и CI, без дополнительных шагов;
- одна дымовая проверка — один скрипт для человека и для CI;
- сборка arm64 без эмуляции.

**Non-Goals:**

- изменение поведения `tldr` под контейнер: переменные для каталога кэша, режим только для чтения
  в коде — не вводятся;
- переиспользование артефактов cargo-dist в образе;
- уменьшение образа ценой статической сборки на musl.

## Decisions

### D1. Сборка из исходников в многоэтапном Dockerfile

Этап сборки — `rust:<версия>-trixie`, команда
`cargo build --release --locked -p tldr-cli --bin tldr --bin tldr-mcp`. Этап выполнения —
`debian:trixie-slim` с `git` и `ca-certificates`, в него копируются два бинаря в `/usr/local/bin/`.

Версия Rust закрепляется явным тегом образа — актуальной stable на момент реализации: файла
`rust-toolchain.toml` нет, а плавающий тег `rust:trixie` сделал бы сборку невоспроизводимой.

Слой зависимостей кэшируется через `RUN --mount=type=cache` для `~/.cargo/registry` и `target/`;
бинари копируются из кэш-монтирования в обычный каталог этапа, иначе они не попадут в следующий этап.

**Альтернативы:**

- образ из бинарей cargo-dist — быстрее, но локальная сборка расходится с CI и зависит от выпуска;
- `scratch`/distroless со статической сборкой на musl — меньше на десятки мегабайт, но в образе
  нужен `git`, а сборка C-грамматик под musl добавляет отладку без выигрыша для пользователя;
- `alpine` — тот же musl и тот же `git`, выигрыш в размере не окупает расхождение libc с этапом сборки.

### D2. Контракт запуска в образе

- `ENTRYPOINT ["tldr"]`, `CMD ["--help"]`, `WORKDIR /project`.
- Пользователь `tldr` (uid/gid 1000) создаётся и назначается `USER` — выполнение не от `root`
  по [DOCK-012](../../../rules/docker.md#пользователь-контейнера-приложения-dock-012-dock-013).
- `ENV HOME=/tmp`: под произвольным идентификатором пользователя (User Identifier, UID) из `-u` домашнего каталога в `/etc/passwd` нет, а `/tmp`
  доступен на запись любому UID.
- `git config --system --add safe.directory '*'`: без этого git отказывает в работе с репозиторием,
  владелец которого не совпадает с UID процесса (`dubious ownership`), — типичный случай при `-u`.

**Альтернатива** — `ENTRYPOINT` со скриптом-обёрткой, подставляющим `/project` и права: прячет
поведение, ломает передачу аргументов и коды возврата, отвергнута.

### D3. Только упаковка, без правок Rust-кода

Команды, которым нужна запись в проект (`warm`, `cache clear`, `fix apply -i`), под `:ro` завершаются
ошибкой записи; это документируется, а не обходится. Пользователь, которому нужен кэш, монтирует
проект `:rw` осознанно.

**Альтернатива** — переменная `TLDR_CACHE_DIR` в коде: меняет поведение апстримного crate, а выигрыш
мал — при `--rm` каждый запуск начинается с пустого контейнера, а общий том кэша для разных
проектов совпадал бы по пути `/project`.

### D4. Отдельный workflow `docker.yml`

`release.yml` сгенерирован cargo-dist и перезаписывается при `dist init`/`dist generate`; ручная
правка в нём потерялась бы. Отдельный workflow с тем же триггером независим от cargo-dist.

Устройство:

1. **Триггеры**: `pull_request`, теги версии и push в ветки `TLDR-*` — последний даёт проверочный
   образ до выпуска.
1. **check-version** (только на тег): сверяет `${GITHUB_REF_NAME#v}` с `version` из `[workspace.package]`
   корневого `Cargo.toml`, при расхождении — ошибка.
1. **build** — матрица `{amd64: ubuntu-24.04, arm64: ubuntu-24.04-arm}`: `docker/build-push-action`
   с `load: true`, затем `sh scripts/docker-smoke.sh <локальный тег>`, затем push по digest
   (`push-by-digest`) только для тега. На запросе слияния (Pull Request, PR) — только amd64, без push.
1. **merge** (только на тег): `docker buildx imagetools create` собирает manifest list и ставит теги,
   вычисленные `docker/metadata-action` по схеме `semver` — `{{version}}`, `{{major}}.{{minor}}`,
   `latest`; для пре-релиза `metadata-action` сам не ставит `{{major}}.{{minor}}` и `latest`.
   На push в ветку — только `type=sha,prefix=dev-` с явным `latest=false`; сборка обеих архитектур
   и дымовая проверка — те же, что для выпуска.
1. Права workflow: `contents: read`, `packages: write`; вход в реестр контейнеров GitHub (GitHub Container Registry, GHCR) — `GITHUB_TOKEN`.
1. Кэш слоёв — `cache-from/cache-to: type=gha` с отдельным `scope` на архитектуру.
1. Checkout с `fetch-depth: 0` — дымовой проверке `churn` нужна история.

Метки формата Open Container Initiative (OCI) задаёт `metadata-action` (`source`, `version`, `revision`), `licenses=AGPL-3.0`
добавляется явно; `source` дублируется `LABEL` в `Dockerfile`, чтобы локальная сборка тоже несла связь
с репозиторием.

**Альтернативы:**

- custom publish job внутри cargo-dist — связывает образ с успехом всех бинарных выпусков
  и с форматом конфигурации dist;
- arm64 через QEMU на одном раннере — сборка Rust с LTO под эмуляцией в разы дольше.

### D5. Дымовая проверка — скрипт `scripts/docker-smoke.sh`

Аргумент — ссылка на образ. Скрипт монтирует корень репозитория в `/project:ro`, запускает контейнер
под `-u 12345:12345` и проверяет:

| Проверка | Критерий |
|----------|----------|
| `--version` | вывод содержит версию из `Cargo.toml` |
| `tree .`, `structure .`, `calls .` | код `0`, вывод разбирается `jq` |
| `churn .` | код `0` — git работает под чужим UID |
| `tldr-mcp` с запросом `initialize` в stdin | в stdout есть ответ с тем же `id` |
| `warm .` | код ненулевой, проект на хосте без `.tldr/` и `.tldrignore` |

Скрипт — POSIX `sh`, зависимости — `docker` и `jq` (есть на раннерах GitHub). Коды возврата:
`0` — проверка пройдена, `1` — проверка не пройдена, `2` — ошибка вызова или окружения.

### D6. `.dockerignore`

Контекст сборки ограничивается тем, что нужно `cargo build`: исключаются `target/`, `.git/`,
`openspec/`, `rules/`, `.idea/`, `.env*`, каталоги документации. `Cargo.lock` и `crates/` остаются.

### D7. Документация в `README.md`

Подраздел `### Docker (no install)` в `Installation` — на английском, как весь апстримный `README.md`;
это согласованное исключение из [DOC-001](../../../rules/documentation-rules.md#язык-и-терминология).
Содержание: команда `docker run`, shell-функция в одну строку, подключение MCP, ограничения из
[spec](./specs/docker-image/spec.md), примечание о `/out`.

## Risks / Trade-offs

- [Пакет GHCR после первой публикации приватный] → в задачах — шаг для администратора организации;
  до него `docker pull` требует `docker login ghcr.io`.
- [Раннер `ubuntu-24.04-arm` недоступен для репозитория или организации] → запасной вариант — QEMU
  через `docker/setup-qemu-action` в той же матрице ценой времени сборки; решается при первом прогоне.
- [`safe.directory '*'` отключает защиту git от чужих репозиториев] → в образе нет других
  репозиториев и процессов; проект монтируется только для чтения.
- [Размер образа ~100–150 МБ из-за `git` и glibc] → принято: альтернативы — в D1.
- [Теги `dev-<sha>` копятся в GHCR] → удаляются вручную в настройках пакета после проверки;
  автоочистка — отдельной задачей, если тегов станет много.
- [Сборка с LTO и `codegen-units = 1` долгая] → кэш `type=gha` и кэш-монтирования cargo.
- [Поле `repository` в `Cargo.toml` указывает на апстрим `parcadei/tldr-code`] → не меняется в этом
  изменении; метка `source` образа указывает на `united-software-platform/tldr-code`.

## Migration Plan

1. Слить изменение в `main` — workflow на PR собирает и проверяет образ без публикации.
1. Отправить тег следующего выпуска — образ публикуется вместе с бинарями cargo-dist.
1. Администратор организации делает пакет `tldr-code` публичным в настройках GHCR.
1. Откат: удалить `docker.yml`; опубликованные теги удаляются в настройках пакета. Канал `cargo install`
   не затронут.

---

## Версионирование

| Версия | Дата | Задача | Агент | Модель | Описание изменений |
|--------|------|--------|-------|--------|--------------------|
| 1.0.0 | 2026-10-27 | TLDR-001, OpenSpec change `add-docker-image-delivery` | Claude Code | Claude Opus 5.5 | Начальное создание: решения D1–D7 о сборке, контракте запуска, границе изменения, workflow, дымовой проверке, контексте сборки и документации |
| 1.0.1 | 2026-10-27 | TLDR-001, OpenSpec change `add-docker-image-delivery` | Claude Code | Claude Opus 5.5 | Запись `fix` уточнена до подкоманды `fix apply`: ключи `-o` и `-i` принадлежат ей, а не `fix` — выяснено при реализации по `FixApplyArgs` |
| 1.0.2 | 2026-10-27 | TLDR-001, OpenSpec change `add-docker-image-delivery` | Claude Code | Claude Opus 5.5 | В D4 добавлен триггер push в ветки `TLDR-*` с публикацией только тега `dev-<короткий sha>`, в риски — накопление таких тегов. Решение Q7 «без плавающих тегов» уточнено: теги выпусков не меняются, проверочный тег неизменяем и привязан к коммиту |
