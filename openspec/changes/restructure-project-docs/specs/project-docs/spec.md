# Spec Delta

## Purpose

Что документы проекта для людей — `README.md`, `docs/use-cases.md` и `CONTRIBUTING.md` — гарантируют
своему читателю: основной путь через Docker-образ, бейджи, кейсы за пределами основного пути и проверки
для правящего систему.

## ADDED Requirements

### Requirement: Язык документов
`README.md`, `docs/use-cases.md` и `CONTRIBUTING.md` SHALL быть написаны на английском, включая заголовки
каркаса, метки кейсов и таблицы версий. Нормативные заголовки и метки SHALL быть переводом формулировок
`rules/project-docs-rules.md` один к одному.

#### Scenario: Заголовки каркаса
- **WHEN** читатель открывает `README.md`
- **THEN** содержательные разделы озаглавлены «What you need», «Step N. <action>», «Commands», «Output formats», «Where next», «Limitations», «License»

#### Scenario: Метки кейса
- **WHEN** читатель открывает любой кейс `docs/use-cases.md`
- **THEN** кейс озаглавлен `## Case N. <goal>` и несёт метки «**When.**», «**What I do.**», «**What I get.**» в этом порядке

### Requirement: Бейджи README
`README.md` SHALL нести между заголовком и назначением четыре бейджа: версию, лицензию, статус workflow
`Docker image` и платформы образа. Бейдж версии SHALL читать значение из git-тегов `vX.Y.Z` репозитория,
а не из номера, записанного в URL вручную. Бейдж лицензии SHALL ссылаться на `./LICENSE`.

#### Scenario: Выпуск новой версии
- **WHEN** в репозиторий отправлен тег `v0.5.0`
- **THEN** бейдж версии показывает `v0.5.0` без правки `README.md`

#### Scenario: Переход по бейджу лицензии
- **WHEN** читатель нажимает бейдж лицензии
- **THEN** открывается файл `LICENSE` репозитория

### Requirement: Основной путь через образ
Основной путь `README.md` SHALL вести к результату анализа через образ `ghcr.io/united-software-platform/tldr-code`
без установки Rust и `tldr`: загрузка образа, первый анализ, вызов как локального бинаря через shell-функцию.

#### Scenario: Читатель только с Docker
- **WHEN** читатель, у которого установлен только Docker, выполняет шаги `README.md` по порядку
- **THEN** он получает JSON-результат `structure` для своего проекта, не выполняя `cargo install`

### Requirement: Ограничения образа в README
Раздел «Limitations» `README.md` SHALL перечислять всё, что в образе не работает: семантический поиск
(`embed`, `semantic`, `similar`), daemon, команды с записью в проект под `:ro` (`warm`, `fix apply -i`,
`cache clear`), сравнение с базовой версией в `bugbot`, внешние линтеры.

#### Scenario: Поиск ограничения
- **WHEN** читатель ищет, почему `tldr semantic` в образе завершается ошибкой
- **THEN** раздел «Limitations» `README.md` называет семантический поиск неподдерживаемым в образе

### Requirement: Карта возможностей в README
`README.md` SHALL содержать карту возможностей автора — группы AST Analysis (L1), Call Graph (L2),
Data Flow (L3-L4), Program Dependence (L5), Security, Quality & Metrics, Patterns & Architecture,
Contracts & Verification, Search & Context, Aggregated — с каждой командой и её описанием. Каждая группа
SHALL ссылаться на свой файл справочника `docs/commands/`.

#### Scenario: Читатель ищет анализ taint
- **WHEN** читатель ищет, чем найти инъекции в коде
- **THEN** `taint` есть в группах Program Dependence (L5) и Security, а группа Security ссылается на `docs/commands/security.md`

#### Scenario: Команда только для semantic
- **WHEN** читатель видит в карте `semantic` или `similar`
- **THEN** сноска называет фичу `semantic`, её отсутствие в образе и кейс 6 `docs/use-cases.md`

### Requirement: Форматы вывода в README
`README.md` SHALL содержать раздел «Output formats» с форматами `json`, `text`, `compact`, `sarif`, `dot`
и назначением каждого.

#### Scenario: Вывод для GitHub
- **WHEN** читатель хочет загрузить результат в GitHub code scanning
- **THEN** раздел «Output formats» называет `--format sarif`

### Requirement: Содержание апстрима сохранено
Каждый факт апстримного `README.md` SHALL присутствовать в `README.md`, `docs/use-cases.md` или ссылкой
на документ `docs/`: материал переносится, а не удаляется.

#### Scenario: Ссылки на документацию апстрима
- **WHEN** читатель ищет руководства `INSTALL.md`, `SETUP.md`, `TROUBLESHOOTING.md`, `MCP.md`, `ARCHITECTURE.md`
- **THEN** «Where next» `README.md` ссылается на каждое из них

### Requirement: Документ кейсов
Документ `docs/use-cases.md` SHALL содержать сквозную нумерацию кейсов: закрепление версии образа, запись файла в `/out`,
команды с записью в проект, подключение MCP-клиента к образу, нативная установка через cargo,
семантический поиск, daemon, внешние линтеры. `README.md` SHALL ссылаться на него из «Where next».

#### Scenario: Задача за пределами основного пути
- **WHEN** читатель хочет подключить MCP-клиент к `tldr` из образа
- **THEN** кейс `docs/use-cases.md` даёт команду запуска `tldr-mcp` из образа и конфигурацию клиента

#### Scenario: Нативная установка
- **WHEN** читателю нужны semantic или daemon, которых нет в образе
- **THEN** кейсы `docs/use-cases.md` дают команды `cargo install tldr-cli` и `cargo install tldr-cli --features semantic`

### Requirement: Сшивка шагов и кейсов
Шаг `README.md`, у которого есть кейсы, SHALL заканчиваться строкой со ссылками на них; шаг без кейсов
SHALL NOT нести такой строки. Номера в строках SHALL совпадать с номерами кейсов `docs/use-cases.md`.

#### Scenario: Переход от шага к кейсу
- **WHEN** читатель на шаге запуска первого анализа переходит по ссылке «More»
- **THEN** открываются кейсы записи файла в `/out` и команд с записью в проект

### Requirement: Проверки для правящего систему
`CONTRIBUTING.md` SHALL называть каждую проверку одной командой — сборку и тесты Rust, три проверки образа
и проверку `Makefile` — и SHALL сводить коды возврата проверок образа в таблицу «Code / Meaning / What to do».

#### Scenario: Проверка образа перед PR
- **WHEN** правящий систему хочет проверить образ локально до отправки изменений
- **THEN** раздел «Checks» `CONTRIBUTING.md` даёт команду сборки образа и команды трёх скриптов `scripts/docker-*.sh` с таблицей кодов `0`, `1`, `2`

### Requirement: Карта бейджей
`CONTRIBUTING.md` SHALL содержать таблицу бейджей `README.md` с колонками «Badge / Value source / Mode / Link target»
для каждого из четырёх бейджей.

#### Scenario: Переименование workflow
- **WHEN** правящий систему переименовывает `.github/workflows/docker.yml`
- **THEN** таблица бейджей `CONTRIBUTING.md` указывает, что сломается бейдж статуса `Docker image`

### Requirement: Docker-примеры совпадают с проверкой
Каждый Docker-пример `README.md` и `docs/use-cases.md`, исполняемый `scripts/docker-readme-check.sh`,
SHALL совпадать с командой скрипта с точностью до имени образа. `CONTRIBUTING.md` SHALL требовать менять
пример и скрипт в одном коммите.

#### Scenario: Сверка примеров
- **WHEN** ревьюер сравнивает команду shell-функции из `README.md` с функцией `tldr()` в `scripts/docker-readme-check.sh`
- **THEN** они различаются только именем образа

#### Scenario: Правка примера
- **WHEN** правящий систему меняет флаги Docker-примера в документе
- **THEN** раздел «Checks» `CONTRIBUTING.md` требует внести ту же правку в `scripts/docker-readme-check.sh` тем же коммитом
