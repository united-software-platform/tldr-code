# Proposal

Зачем и что меняется в изменении `align-docker-badge-style`: бейдж статуса Docker-workflow в `README.md`
приводится к стилю остальных бейджей.

---

## Навигация

- [Why](#why)
- [What Changes](#what-changes)
- [Capabilities](#capabilities)
- [Impact](#impact)
- [Версионирование](#версионирование)

---

## Why

Бейдж `Docker image` в `README.md` — собственный SVG GitHub (`actions/workflows/docker.yml/badge.svg`):
с логотипом GitHub, другим шрифтом и высотой. Остальные три бейджа рисует shields.io в стиле flat, поэтому
блок выглядит неоднородно — замечание владельца по снимку `docs/img.png`.

## What Changes

- Изображение бейджа `Docker image` в `README.md` заменяется на shields.io
  `github/actions/workflow/status/united-software-platform/tldr-code/docker.yml` с подписью `docker image`.
  Ссылка бейджа — запуски workflow в Actions — не меняется.
- В таблице раздела «Badges» `CONTRIBUTING.md` источник значения бейджа дополняется сервисом отрисовки:
  shields `github/actions/workflow/status`.

Вне рамки: остальные бейджи, состав блока, сам workflow.

## Capabilities

### New Capabilities

Нет.

### Modified Capabilities

Нет. Требование «Бейджи README» capability `project-docs` стиль отрисовки не задаёт: состав, источник
значения и цели ссылок остаются прежними, поэтому изменение объявляет `skip_specs`.

## Impact

- Файлы: `README.md` (одна строка блока бейджей), `CONTRIBUTING.md` (одна строка таблицы «Badges»).
- Внешние зависимости: бейдж статуса начинает зависеть от shields.io, как и остальные три; GitHub
  при этом остаётся источником статуса.

---

## Версионирование

| Версия | Дата | Задача | Агент | Модель | Описание изменений |
|--------|------|--------|-------|--------|--------------------|
| 1.0.0 | 2026-10-27 | TLDR-001, замечание владельца: бейдж Docker image выбивается из стиля (`docs/img.png`) | Claude Code | Claude Opus 5.5 | Начальное создание |
