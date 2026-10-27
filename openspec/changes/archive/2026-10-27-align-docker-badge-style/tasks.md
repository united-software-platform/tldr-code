# Tasks

Шаги реализации изменения `align-docker-badge-style`. Мотивация и рамка — в [proposal.md](./proposal.md).

---

## Навигация

- [1. Подготовка](#1-подготовка)
- [2. Бейдж](#2-бейдж)
- [Workflow follow-up](#workflow-follow-up)
- [Версионирование](#версионирование)

---

## 1. Подготовка

- [x] 1.1 Пройти гейт GIT-020 для `README.md` и `CONTRIBUTING.md`: `git status --` и `git diff --` по каждому пути пусты; при незакоммиченных правках — остановиться и запросить коммит у владельца

## 2. Бейдж

- [x] 2.1 В `README.md` заменить URL изображения бейджа `Docker image` на `https://img.shields.io/github/actions/workflow/status/united-software-platform/tldr-code/docker.yml?label=docker%20image`, ссылку на запуски workflow оставить — проверка: URL отвечает `200` и рисует `docker image: passing`, остальные строки блока бейджей не изменены
- [x] 2.2 В таблице «Badges» `CONTRIBUTING.md` дополнить источник значения бейджа `Docker image` сервисом shields `github/actions/workflow/status` — проверка: `git diff` затрагивает одну строку таблицы

## Workflow follow-up

- Показать владельцу состав коммита и предложенное сообщение (GIT-016); коммит — только по явной команде.
- Архивировать change после ревью владельца.

---

## Версионирование

| Версия | Дата | Задача | Агент | Модель | Описание изменений |
|--------|------|--------|-------|--------|--------------------|
| 1.0.0 | 2026-10-27 | TLDR-001, замечание владельца: бейдж Docker image выбивается из стиля (`docs/img.png`) | Claude Code | Claude Opus 5.5 | Начальное создание: подготовка и две задачи на бейдж |
