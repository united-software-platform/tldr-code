# Design

Как перестраиваются `README.md`, `docs/use-cases.md` и `CONTRIBUTING.md` в изменении `restructure-project-docs`.
Мотивация — в [proposal.md](./proposal.md#why), требования — в [spec](./specs/project-docs/spec.md).

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

- `README.md` — документ апстрима на английском. Примеры Docker в подразделе «Docker (no install)» добавлены
  изменением `add-docker-image-delivery`.
- `scripts/docker-readme-check.sh` README не разбирает: он хранит копии команд и выполняет их над временным
  Python-проектом. Шапка скрипта называет подраздел «Docker (no install)».
- Носитель версии — `[workspace.package] version` в `Cargo.toml`; `docker.yml` сверяет с ним тег `vX.Y.Z`.
  На 2026-10-27 у репозитория есть тег `v0.4.0`, но нет GitHub Release.
- Репозиторий `united-software-platform/tldr-code` и пакет GHCR доступны анонимно.
- Цели апстрима (`check` = `fmt` + `lint` + `test`) живут в `MakefileTLDR`; `Makefile` — от SDD-kit.
- `.claude/` в `.gitignore`; `rules/`, `CLAUDE.md`, `AGENTS.md` пока не отслеживаются git.

## Goals / Non-Goals

**Goals:**

- после правки повторный аудит навыком `project-docs` не находит расхождений ни в одном из трёх документов;
- каждый Docker-пример, исполняемый проверкой, остаётся байт-в-байт её копией;
- ни одна возможность и ни один факт апстримного `README.md` не теряются: материал переносится, а не удаляется (DOC-023).

**Non-Goals:**

- автоматическая сверка документов и скрипта — защита остаётся процессной (D5);
- изменение содержания `docs/*.md` апстрима и перевод документов `rules/`.

## Decisions

### D1. Английский язык вопреки DOC-001

Три документа пишутся на английском. Нормативные заголовки и метки переводятся один к одному:

| Норма | Документ |
|-------|----------|
| Что нужно / Шаг N. / Куда дальше / Ограничения / Лицензия | What you need / Step N. / Where next / Limitations / License |
| Кейс N. / Когда / Что делаю / Что получаю | Case N. / When / What I do / What I get |
| Подробнее — кейс N | More — case N / More — cases N, M |
| Устройство репозитория / Проверки / Правила и процесс | Repository layout / Checks / Rules and process |
| Код / Что значит / Что делаю | Code / Meaning / What to do |

Голос по DGN-009: README — «you» в повелительном наклонении, кейсы — «I», `CONTRIBUTING.md` — безлично.

Альтернатива — русский по DOC-001 — отклонена владельцем: читатели апстрима и пользователи образа англоязычны.

### D2. Основной путь — Docker-образ

```text
What you need   Docker (linux/amd64 или linux/arm64; macOS — Docker Desktop), каталог проекта
Step 1. Pull the image                     → More — case 1
Step 2. Run your first analysis            → More — cases 2, 3
Step 3. Call tldr like a local binary      → More — case 4
Commands        карта возможностей автора, десять групп (D8)
Output formats  json, text, compact, sarif, dot (D8)
Where next      docs/use-cases.md, tldr --help, docs/commands/, docs/INSTALL.md, docs/SETUP.md,
                docs/MCP.md, docs/TROUBLESHOOTING.md, docs/ARCHITECTURE.md, CONTRIBUTING.md
Limitations     пять ограничений образа; semantic проверен только на macOS
License         AGPL-3.0, ./LICENSE
```

Назначение под бейджами — полный текст бывшего «Why»: экономия токенов, что именно tldr извлекает, 18 языков.
Следующее предложение называет читателя и отсылает к кейсам и `CONTRIBUTING.md`. Число команд не пишется:
в исходнике оно противоречило само себе (40+ против 60+), а полный состав показывает карта D8.

Step 3 переносит примеры бывшего «Quick start» (`structure`, `impact`, `dead`, `secure`, `health`) в форме
вызова через shell-функцию.

Альтернатива — `cargo install` основным путём — отклонена: поставка через образ — предмет этого форка,
а нативная установка тянет Rust-тулчейн.

DGN-005 говорит о «кейсе N» в единственном числе; перечень «cases 2, 3» принят как допустимое расширение,
одна строка на шаг сохраняется.

### D3. Состав и порядок кейсов

Сначала кейсы образа — ближе к основному пути, затем нативные:

| N | Case | Источник содержания |
|---|------|---------------------|
| 1 | I want to pin an image version | теги `X.Y.Z`, `X.Y`, `latest` из spec `docker-image` |
| 2 | I want to write a result file from the container | пример `/out` с `fix apply` из README |
| 3 | I want to run commands that modify my project | монтирование без `:ro`: `warm`, `fix apply -i`, `cache clear` |
| 4 | I want to connect an MCP client to the image | `--entrypoint tldr-mcp`, команда `claude mcp add`, JSON-конфиг клиента |
| 5 | I want to install tldr natively | `cargo install tldr-cli`, ссылка на `docs/INSTALL.md` |
| 6 | I want natural-language code search | `--features semantic`, модель ~110MB, сборка проверена на macOS |
| 7 | I want faster repeated queries | daemon из бывшего «Daemon mode» |
| 8 | I want diagnostics with external linters | нативная установка и линтеры в `PATH` |

Кейс 8 не описывает производный образ `FROM tldr-code`: он не проверяется и зависит от стека проекта.
Кейс запуска в CI отложен (см. proposal).

Кейсы 2 и 4 несут команды, которые исполняет `docker-readme-check.sh`; кейс 3 — нет: скрипт проверяет
только отказ записи под `:ro`. Метка «**If it fails.**» допускается после «What I get» там, где у кейса
есть типичный сбой: например, каталог `out/` во владении root.

### D4. Бейджи

| Badge | Value source | Mode | Link target |
|-------|--------------|------|-------------|
| Version | git-теги `vX.Y.Z` (shields `github/v/tag`, `sort=semver`) | dynamic | страница пакета GHCR `tldr-code` |
| License | `AGPL-3.0` | static | `./LICENSE` |
| Docker image | статус workflow `docker.yml` (`actions/workflows/docker.yml/badge.svg`) | dynamic | запуски workflow в Actions |
| Platforms | `linux/amd64 \| linux/arm64` | static | страница пакета GHCR `tldr-code` |

Тег выбран вместо GitHub Release: Release в репозитории нет, и бейдж показал бы «no releases». Тег — значение,
под которым `docker.yml` публикует образ, и CI сверяет его с `Cargo.toml`. Альтернатива — `version`
из `Cargo.toml` на `main` — отклонена: она показывает ещё не выпущенную версию.

Разметка — штатный Markdown `[![alt](img)](link)` по DOC-015 и DOC-005. Ссылка на `LICENSE` — относительная.
Таблица переносится в раздел «Badges» `CONTRIBUTING.md` (DGN-004).

### D5. Связь документов и `docker-readme-check.sh`

Скрипт не переписывается. Меняется только шапка: вместо подраздела «Docker (no install)» она называет шаги
`README.md` и кейсы 2 и 4 `docs/use-cases.md`. В раздел «Checks» `CONTRIBUTING.md` вносится правило:
Docker-пример, исполняемый скриптом, меняется вместе со скриптом в одном коммите.

Альтернатива — скрипт вынимает блоки кода из документов — отклонена: парсинг Markdown хрупок,
а объём доработки выходит за рамку изменения документов.

### D6. Состав `CONTRIBUTING.md`

1. Repository layout — `crates/`, `Dockerfile`, `.dockerignore`, `scripts/docker-*.sh`, `.github/workflows/`
   (`docker.yml`, `release.yml`), `docs/`, `openspec/`, `MakefileTLDR`.
1. Docker image — сборка, теги (`X.Y.Z`, `X.Y`, `latest`, `dev-<sha>`), проверка образа ветки `TLDR-*` по тегу `dev-<sha>`.
1. Release — тег `vX.Y.Z` равен версии workspace; по тегу запускаются `release.yml` (cargo-dist) и `docker.yml`.
1. Badges — таблица D4.
1. Checks — `make -f MakefileTLDR check`, `docker build -t tldr-code:smoke .`, три `scripts/docker-*.sh`,
   `sh tools/make-lint/check.sh`; таблица кодов возврата; правило D5.
1. Rules and process — коды правил со ссылками на `rules/` (GIT-009, GIT-012, MAKE-004, DGN, DOC); окружение
   агента — одна строка «`make help`».

Таблица кодов возврата — одна на три скрипта: семантика `0`/`1`/`2` у них общая. Для selftest
код `1` означает «smoke-проверка не ловит поломку».

`docker-readme-check.sh` и `docker-smoke.sh` требуют `docker` и `jq`; это называется в «Checks».

### D7. Таблицы версий

`CONTRIBUTING.md` и `docs/use-cases.md` получают таблицу версий по DOC-022 и DOC-024 на английском:
`Version | Date | Task | Agent | Model | Changes`, первая запись `1.0.0`. `README.md` таблицу не ведёт.

### D8. Карта возможностей — отступление от DGN-003 и DGN-011

Разделы «Commands» и «Output formats» апстрима возвращаются в `README.md` полностью, между Step 3 и «Where next».
Это осознанное отступление: DGN-003 не допускает справочных разделов в `README.md`, DGN-011 — перечней,
которые печатает инструмент.

Обоснование: карта уровней L1–L5 и групп — авторская структура, которая объясняет, что умеет инструмент.
`tldr --help` печатает подкоманды без этой группировки, а `docs/commands/` разбит по файлам без оглавления.
Без карты `README.md` теряет суть инструмента. Первая версия изменения удалила её без переноса, нарушив DOC-023.

Таблицы групп переносятся без сокращений. Под заголовком каждой группы — строка «Reference:» со ссылкой
на файл справочника:

| Группа | Справочник |
|--------|------------|
| AST Analysis (L1) | `docs/commands/ast.md` |
| Call Graph (L2) | `docs/commands/callgraph.md` |
| Data Flow (L3-L4) | `docs/commands/dataflow.md` |
| Program Dependence (L5) | `docs/commands/dataflow.md`; `taint` — `docs/commands/security.md` |
| Security | `docs/commands/security.md` |
| Quality & Metrics | `docs/commands/quality.md`, `docs/commands/metrics.md` |
| Patterns & Architecture | `docs/commands/patterns.md`; `surface` — `docs/commands/tools.md` |
| Contracts & Verification | `docs/commands/patterns.md` |
| Search & Context | `docs/commands/search.md` |
| Aggregated | `docs/commands/tools.md` |

Сноска `*` для `semantic` и `similar` сохраняется и дополняется: в образе этих команд нет — кейс 6.

Альтернатива — отдельный справочный документ с картой и ссылка из `README.md` — отклонена владельцем:
карта возможностей должна быть видна на главной странице.

## Risks / Trade-offs

- [Внешние ссылки на якоря README апстрима (`#installation`, `#commands`) ломаются] → контент переносится
  в кейсы и «Where next»; прямые переадресации Markdown не поддерживает, риск принят.
- [Пример в документе расходится с копией в скрипте] → правило D5 в «Checks» и требование spec
  «Docker-примеры совпадают с проверкой»; ревью сверяет при каждой правке примера.
- [Ссылка `rules/project-docs-rules.md` → `.claude/skills/project-docs/SKILL.md` после коммита `rules/`
  ведёт в пустоту: `.claude/` игнорируется] → не правится: `rules/` — поставка SDD-kit.
- [`CONTRIBUTING.md` ссылается на `rules/`, которые ещё не в git] → ссылки работают после коммита файлов
  kit'а; без него «Rules and process» ведёт в пустоту. Коммит kit'а — условие завершения, см. tasks.
- [Репозиторий или пакет GHCR станут закрытыми] → бейджи версии и статуса перестанут отрисовываться;
  тогда «Limitations» README называет, какого бейджа нет и почему (DGN-004).
- [Сборка `--features semantic` проверена только на macOS] → фиксируется в «Limitations» и кейсе 6.
- [`README.md` длиннее, справочный блок занимает много места] → карта стоит после шагов и перед «Where next»:
  основной путь она не прерывает.

## Migration Plan

1. Новые файлы `docs/use-cases.md` и `CONTRIBUTING.md` создаются до замены README: ссылки README сразу
   ведут на существующие документы.
1. `README.md` переписывается целиком.
1. Откат — возврат `README.md` к предыдущему коммиту и удаление двух новых файлов; кода и CI правка не касается.

---

## Версионирование

| Версия | Дата | Задача | Агент | Модель | Описание изменений |
|--------|------|--------|-------|--------|--------------------|
| 1.0.0 | 2026-10-27 | TLDR-001, OpenSpec change `restructure-project-docs` | Claude Code | Claude Opus 5.5 | Начальное создание: решения D1–D7 по итогам интервью с владельцем |
| 1.0.1 | 2026-10-27 | TLDR-001, замечание владельца: из README пропали уровни и суть инструмента | Claude Code | Claude Opus 5.5 | Добавлено решение D8: карта возможностей и форматы вывода возвращаются в `README.md` с привязкой групп к `docs/commands/`; D2 и Goals дополнены, добавлен риск длины `README.md` |
