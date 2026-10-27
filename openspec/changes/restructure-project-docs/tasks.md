# Tasks

Шаги реализации изменения `restructure-project-docs`. Решения — в [design.md](./design.md),
требования — в [spec](./specs/project-docs/spec.md).

---

## Навигация

- [1. Подготовка](#1-подготовка)
- [2. Документ кейсов](#2-документ-кейсов)
- [3. CONTRIBUTING](#3-contributing)
- [4. README](#4-readme)
- [5. Шапка проверки README](#5-шапка-проверки-readme)
- [6. Интеграционная проверка](#6-интеграционная-проверка)
- [Workflow follow-up](#workflow-follow-up)
- [Версионирование](#версионирование)

---

## 1. Подготовка

- [x] 1.1 Получить от владельца сигнал «правка TLDR-001 закончена»; до сигнала apply не начинается
- [x] 1.2 Пройти гейт GIT-020 для `README.md` и `scripts/docker-readme-check.sh`: `git status --` и `git diff --` по каждому пути пусты; при незакоммиченных правках — остановиться и запросить коммит у владельца

## 2. Документ кейсов

- [x] 2.1 Создать `docs/use-cases.md` из образца навыка `project-docs` (`templates/use-cases.md`) на английском: заголовок, назначение с указанием читателя и ссылками на `README.md` и `CONTRIBUTING.md`, навигация; пометки `> **Образец:**` сняты — проверка: `grep -c 'Образец' docs/use-cases.md` даёт `0`
- [x] 2.2 Написать кейсы 1–8 в порядке D3 с метками «**When.**», «**What I do.**», «**What I get.**» от первого лица; команды кейсов 2 и 4 скопировать байт-в-байт из нынешнего `README.md` — проверка: `diff` команд с `scripts/docker-readme-check.sh` расходится только именем образа
- [x] 2.3 Добавить таблицу версий по D7 с записью `1.0.0` — проверка: таблица последняя в файле, колонки `Version | Date | Task | Agent | Model | Changes`

## 3. CONTRIBUTING

- [x] 3.1 Создать `CONTRIBUTING.md` из образца `templates/contributing.md` на английском с разделами D6 в порядке DGN-008; голос безличный — проверка: заголовки `##` идут как Repository layout → Docker image → Release → Badges → Checks → Rules and process
- [x] 3.2 В «Checks» назвать каждую проверку одной командой, свести коды `0`/`1`/`2` в таблицу «Code / Meaning / What to do» с оговоркой для selftest, указать зависимости `docker` и `jq`, внести правило D5 — проверка: каждая команда раздела запускается из корня как написана (`sh scripts/docker-smoke.sh` без аргумента даёт код `2`)
- [x] 3.3 В «Badges» внести таблицу D4; в «Rules and process» назвать нормы кодами со ссылками на `rules/` (DGN-010) и окружение агента строкой «`make help`» — проверка: относительные ссылки на `rules/*.md` и якоря существуют
- [x] 3.4 Добавить таблицу версий по D7 с записью `1.0.0`

## 4. README

- [x] 4.1 Переписать `README.md` по каркасу D2: блок из четырёх бейджей D4 между заголовком и назначением, назначение 1–3 строки без числа команд — проверка: разделы `##` идут как What you need → Step 1 → Step 2 → Step 3 → Where next → Limitations → License, таблицы версий нет
- [x] 4.2 Шаги 1–3: команды `docker pull`, первого запуска и shell-функции скопировать байт-в-байт из нынешнего `README.md`; шаги заканчиваются строками «More — case 1», «More — cases 2, 3», «More — case 4» со ссылками на якоря `docs/use-cases.md` — проверка: каждый якорь совпадает с заголовком кейса
- [x] 4.3 «Where next»: `docs/use-cases.md`, `tldr --help`, `docs/commands/`, `docs/MCP.md`, `docs/TROUBLESHOOTING.md`, `docs/ARCHITECTURE.md`, `CONTRIBUTING.md`; таблицы «Commands» и «Output formats» удалены — проверка: в `README.md` нет таблицы подкоманд
- [x] 4.4 «Limitations»: пять ограничений образа из нынешнего `README.md` без изменения состава и сборка semantic, проверенная только на macOS; «License»: AGPL-3.0 со ссылкой `./LICENSE` — проверка: требование «Документированные ограничения» spec `docker-image` выполняется
- [x] 4.5 Проверить бейджи: URL изображений отвечают и рисуют значения (версия `v0.4.0`, статус workflow), ссылки ведут на пакет GHCR, Actions и `./LICENSE`

## 5. Шапка проверки README

- [x] 5.1 В шапке `scripts/docker-readme-check.sh` заменить ссылку на подраздел «Docker (no install)» шагами `README.md` и кейсами 2 и 4 `docs/use-cases.md`; команды скрипта не трогать — проверка: `git diff scripts/docker-readme-check.sh` затрагивает только строки комментария

## 6. Интеграционная проверка

- [x] 6.1 Повторный аудит навыком `project-docs` по `README.md`, `docs/use-cases.md`, `CONTRIBUTING.md` — проверка: таблица расхождений пуста
- [x] 6.2 Если в окружении есть Docker: `docker build -t tldr-code:smoke .` и `sh scripts/docker-readme-check.sh tldr-code:smoke` завершаются кодом `0`; если Docker нет — записать в итог, что проверка оставлена CI-шагу «README examples»
- [x] 6.3 `openspec validate restructure-project-docs --strict` проходит без ошибок

## Workflow follow-up

- Показать владельцу состав коммитов и предложенные сообщения (GIT-016): файлы SDD-kit (`rules/`, `CLAUDE.md`, `AGENTS.md`) отдельно от документации; коммит — только по явной команде, описания задачи подтверждает владелец (GIT-010). Без коммита `rules/` ссылки «Rules and process» в `CONTRIBUTING.md` ведут в пустоту.
- Архивировать change после ревью владельца.

---

## Версионирование

| Версия | Дата | Задача | Агент | Модель | Описание изменений |
|--------|------|--------|-------|--------|--------------------|
| 1.0.0 | 2026-10-27 | TLDR-001, OpenSpec change `restructure-project-docs` | Claude Code | Claude Opus 5.5 | Начальное создание: шесть групп задач и follow-up по коммитам и архивации |
