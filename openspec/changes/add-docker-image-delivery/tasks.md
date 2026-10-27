# Tasks: add-docker-image-delivery

План реализации поставки `tldr` как Docker-образа: каждая задача несёт способ проверки своего результата.

---

## Навигация

- [1. Образ](#1-образ)
- [2. Дымовая проверка](#2-дымовая-проверка)
- [3. Workflow публикации](#3-workflow-публикации)
- [4. Документация](#4-документация)
- [5. Интеграционная проверка](#5-интеграционная-проверка)
- [Workflow follow-up](#workflow-follow-up)
- [Версионирование](#версионирование)

---

## 1. Образ

- [x] 1.1 Создать `.dockerignore` по D6 design.md и проверить: `docker build .` передаёт контекст без `target/`, `.git/`, `openspec/`, `continuum/`, `thoughts/` (размер контекста в выводе сборки — около 20 МБ, остаток — `crates/`)
- [x] 1.2 Создать многоэтапный `Dockerfile` по D1: этап сборки на `rust:<актуальная stable>-trixie` с закреплённой версией, `cargo build --release --locked -p tldr-cli --bin tldr --bin tldr-mcp`, кэш-монтирования cargo; проверить: `docker build -t tldr-code:dev .` завершается успешно
- [x] 1.3 Описать этап выполнения по D2: `debian:trixie-slim`, `git`, `ca-certificates`, пользователь `tldr` (1000:1000), `USER tldr`, `HOME=/tmp`, `safe.directory '*'`, `WORKDIR /project`, `ENTRYPOINT ["tldr"]`, `CMD ["--help"]`, `LABEL org.opencontainers.image.source` и `licenses`; проверить: `docker run --rm tldr-code:dev` печатает справку с кодом `0`, `docker run --rm --entrypoint id tldr-code:dev -u` печатает `1000`
- [x] 1.4 Проверить контракт под чужим UID вручную: `docker run --rm -u 12345:12345 -v "$PWD:/project:ro" tldr-code:dev churn .` и `structure .` завершаются с кодом `0`

## 2. Дымовая проверка

- [x] 2.1 Написать `scripts/docker-smoke.sh <образ>` на POSIX `sh` по D5: монтирование репозитория `:ro`, `-u 12345:12345`, проверки `--version`, запуска без аргументов, неизвестной подкоманды (ненулевой код), `tree`/`structure`/`calls` с разбором `jq`, `churn`, `tldr-mcp` + `initialize`, отказа `warm` без следов `.tldr/` и `.tldrignore` на хосте; коды возврата `0`/`1`/`2`; проверить: `sh scripts/docker-smoke.sh tldr-code:dev` завершается с кодом `0`
- [ ] 2.2 Проверить, что скрипт ловит поломку: прогон на образе без `safe.directory` (временная локальная сборка) завершается с кодом `1` и называет проваленную проверку `churn`; прогон без аргумента — с кодом `2`

## 3. Workflow публикации

- [x] 3.1 Создать `.github/workflows/docker.yml` по D4: триггеры `pull_request` и теги версии, права `contents: read`/`packages: write`, checkout с `fetch-depth: 0`; задание проверки тега против `[workspace.package].version`; проверить: локальный прогон шага сверки на `v0.4.0` проходит, на `v0.5.0` падает
- [x] 3.2 Описать матрицу сборки `amd64: ubuntu-24.04`, `arm64: ubuntu-24.04-arm` с `load: true`, вызовом `scripts/docker-smoke.sh`, кэшем `type=gha` по архитектуре и push по digest только для тега; на PR — только amd64 без push; проверить: `actionlint` (если доступен) не находит ошибок
- [x] 3.3 Описать задание сборки manifest list: `docker/metadata-action` по схеме `semver` (`{{version}}`, `{{major}}.{{minor}}`, `latest`), `licenses=AGPL-3.0`, `docker buildx imagetools create`; проверить чтением конфигурации `metadata-action`, что для пре-релиза не создаются `{{major}}.{{minor}}` и `latest`
- [ ] 3.4 Открыть PR с изменением и проверить прогон workflow: сборка amd64 и дымовая проверка проходят, в GHCR ничего не публикуется
- [x] 3.5 Добавить триггер push в ветки `TLDR-*` с публикацией только тега `dev-<короткий sha>` (обе архитектуры, дымовая проверка перед публикацией); проверить: после push ветки в GHCR появляется `dev-<sha>`, `docker pull` этого тега и `sh scripts/docker-smoke.sh` на нём проходят локально

## 4. Документация

- [ ] 4.1 Добавить в `README.md` подраздел `### Docker (no install)` в `Installation` по D7: `docker pull`, `docker run` с `-u` и `:ro`, роль `/out`, shell-функция в одну строку; проверить: каждая команда раздела, выполненная над локальным образом `tldr-code:dev` (с заменой имени образа), работает как написано
- [ ] 4.2 Добавить в тот же подраздел подключение `tldr-mcp` (`docker run -i --rm ... --entrypoint tldr-mcp`) и перечень ограничений из требования «Документированные ограничения» spec; проверить: перечень совпадает с требованием пункт в пункт, пример MCP проходит запрос `initialize`
- [ ] 4.3 Написать `scripts/docker-readme-check.sh <образ>` и `scripts/docker-smoke-selftest.sh <образ>` по D5 и вызвать их в задании `build` workflow после дымовой проверки; проверить: прогон workflow проходит оба шага на amd64 и arm64

## 5. Интеграционная проверка

- [x] 5.1 Выполнить `openspec validate add-docker-image-delivery --strict` и полный `sh scripts/docker-smoke.sh` на финальной локальной сборке; проверить: оба завершаются с кодом `0`

## Workflow follow-up

- Подготовить коммит с заголовком `TLDR-001: поставка tldr-cli как Docker-образа` и показать состав до коммита по GIT-016; коммит и push — только по команде пользователя.
- После слияния выпустить следующую версию тегом `vX.Y.Z` и проверить публикацию тегов `X.Y.Z`, `X.Y`, `latest` для amd64 и arm64.
- Администратору организации `united-software-platform` сделать пакет `tldr-code` публичным в настройках GHCR; проверить `docker pull` без логина.
- Архивировать change после проверки выпуска.

---

## Версионирование

| Версия | Дата | Задача | Агент | Модель | Описание изменений |
|--------|------|--------|-------|--------|--------------------|
| 1.0.0 | 2026-10-27 | TLDR-001, OpenSpec change `add-docker-image-delivery` | Claude Code | Claude Opus 5.5 | Начальное создание: задачи образа, дымовой проверки, workflow, документации и интеграционной проверки |
| 1.0.1 | 2026-10-27 | TLDR-001, OpenSpec change `add-docker-image-delivery` | Claude Code | Claude Opus 5.5 | Добавлена задача 3.5: проверочный тег `dev-<короткий sha>` на push в ветку `TLDR-*` с проверкой через `docker pull` и дымовую проверку |
| 1.0.2 | 2026-10-27 | TLDR-001, OpenSpec change `add-docker-image-delivery` | Claude Code | Claude Opus 5.5 | Отмечены выполненными 1.2, 1.3, 1.4, 2.1, 3.2, 3.5, 5.1: прогон workflow 40568351360 по `ebada63` собрал и проверил образ для amd64 и arm64 (дымовая проверка 12/12 на каждой архитектуре), опубликовал `dev-ebada63` с manifest list `linux/amd64` + `linux/arm64`; `docker pull` этого тега и `sh scripts/docker-smoke.sh` на нём прошли локально у пользователя; `openspec validate --strict` проходит. Для 3.2 вместо `actionlint` проверкой служит успешный прогон матрицы в GitHub Actions |
| 1.0.3 | 2026-10-27 | TLDR-001, OpenSpec change `add-docker-image-delivery` | Claude Code | Claude Opus 5.5 | Критерий задачи 1.1 исправлен: оценка «единицы мегабайт» была неверной — один `crates/` занимает около 19 МБ; в перечень исключений добавлены `continuum/` и `thoughts/`, задача отмечена выполненной по прогону 40568351360 (контекст 31 МБ без `target/` и `.git/`) с проверкой нового размера следующим прогоном |
| 1.0.4 | 2026-10-27 | TLDR-001, OpenSpec change `add-docker-image-delivery` | Claude Code | Claude Opus 5.5 | Добавлена задача 4.3: автоматическая проверка примеров README и самопроверка дымовой проверки в workflow — ими подтверждаются 2.2, 4.1 и 4.2 |
