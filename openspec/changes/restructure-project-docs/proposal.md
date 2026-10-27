# Proposal

Зачем и что меняется в изменении `restructure-project-docs`: перестройка документов проекта для людей
по норме [`rules/project-docs-rules.md`](../../../rules/project-docs-rules.md) с основным путём через Docker-образ.

---

## Навигация

- [Why](#why)
- [What Changes](#what-changes)
- [Capabilities](#capabilities)
- [Impact](#impact)
- [Версионирование](#версионирование)

---

## Why

Изменение `add-docker-image-delivery` сделало образ `ghcr.io/united-software-platform/tldr-code` способом
пользоваться `tldr` без установки, но `README.md` остался документом апстрима: Docker — один из трёх
вариантов установки, справочные таблицы команд стоят посреди пути, ограничения образа спрятаны в раздел
установки, бейджей нет, а `CONTRIBUTING.md` и документа кейсов нет вовсе. Аудит навыком `project-docs`
от 2026-10-27 нашёл расхождения по DGN-001, DGN-002, DGN-003, DGN-004, DGN-005, DGN-009, DGN-011.

## What Changes

- `README.md` перестраивается по каркасу DGN-003: блок из четырёх бейджей, «What you need», три шага основного
  пути через Docker-образ, «Where next», «Limitations», «License». Разделы «Why», «Installation», «Quick start»,
  «Commands», «Output formats», «Daemon mode», «Documentation» в прежнем виде удаляются.
- Заводится документ кейсов `docs/use-cases.md`: восемь кейсов за пределами основного пути — четыре
  для образа и четыре для нативной установки.
- Заводится `CONTRIBUTING.md`: устройство репозитория, сборка и теги образа, выпуск, бейджи, проверки
  с таблицей кодов возврата, правила и процесс.
- Комментарий в шапке `scripts/docker-readme-check.sh` указывает на новые места примеров. Команды скрипта
  не меняются.
- Все три документа пишутся на английском — по решению владельца, в отступление от DOC-001: читатель
  апстрима и пользователь образа англоязычны. Правила `rules/` не меняются.

Вне рамки изменения:

- остальные документы `docs/` (`INSTALL.md`, `MCP.md`, `SETUP.md`, `TROUBLESHOOTING.md`, `ARCHITECTURE.md`,
  `commands/`) и `docs/prompts/docker.md`;
- код, `Dockerfile`, workflow и логика проверочных скриптов;
- коммит файлов SDD-kit (`rules/`, `CLAUDE.md`, `AGENTS.md`) — отдельное действие по запросу владельца;
- кейс запуска `tldr` в CI — отложен до появления проверяемого примера.

## Capabilities

### New Capabilities

- `project-docs`: что документы проекта для людей гарантируют читателю — основной путь через образ,
  бейджи, кейсы за пределами основного пути, проверки для правящего систему и связь Docker-примеров
  документов с проверкой `scripts/docker-readme-check.sh`.

### Modified Capabilities

Нет. Требование «Документированные ограничения» capability `docker-image` по-прежнему выполняется:
ограничения образа переезжают в раздел «Limitations» `README.md` без изменения состава.

## Impact

- Файлы: `README.md` (переписывается), `docs/use-cases.md` и `CONTRIBUTING.md` (новые),
  `scripts/docker-readme-check.sh` (только комментарий).
- CI: `docker-readme-check.sh` README не разбирает и хранит копии команд, поэтому новый каркас шаг
  «README examples» в `.github/workflows/docker.yml` не ломает.
- Внешние ссылки: якоря `README.md` апстрима (`#installation`, `#commands` и т. п.) перестают существовать.
- Бейджи зависят от публичности репозитория и пакета GHCR: на 2026-10-27 оба доступны анонимно.

---

## Версионирование

| Версия | Дата | Задача | Агент | Модель | Описание изменений |
|--------|------|--------|-------|--------|--------------------|
| 1.0.0 | 2026-10-27 | TLDR-001, OpenSpec change `restructure-project-docs` | Claude Code | Claude Opus 5.5 | Начальное создание по итогам аудита навыком `project-docs` и интервью с владельцем |
