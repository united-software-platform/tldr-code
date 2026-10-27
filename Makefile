.PHONY: help init init-host init-env init-dirs init-gitignore init-ssh-key init-ssh-config \
	openspec-init registry-lint project-new register-project project-bootstrap \
	layout-generate layout-apply layout-status scan-workspace move-project extract-project revert-layout \
	edit-entry rename-project add-value deprecate-value detach-project readme group-compose kit-update

.DEFAULT_GOAL := help

# Список целей собирается из комментариев вида '## описание' в самом Makefile:
# описание живёт рядом с целью, поэтомуновая цель попадает в вывод без правки в двух местах.
help: ## Список команд с описаниями
	@printf 'Команды окружения SDD Developer Kit:\n\n'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| sed 's/:.*## /|/' \
		| awk -F'|' '{printf "  make %-18s %s\n", $$1, $$2}'
	@printf '\nПорядок установки и переменные окружения — в README.md проекта kit'"'"'а.\n'

# Значение переменной из .env: файл заполняется пользователем и на момент первого
# запуска init может быть неполным, поэтому пустое значение заменяется умолчанием
# из .env.example. Разбор построчный, а не через include: .env — файл секретов,
# и его содержимое не должно попадать в пространство имён переменных make.
env_value = $$(sed -n 's/^$(1)=//p' .env 2>/dev/null | tail -n 1)

# Разбор SSH-переменных из .env с умолчаниями. Собран в одном месте и переиспользуется
# шагами подготовки: значения не расходятся между шагами, а добавление переменной не
# требует править каждый шаг. Каждый шаг подставляет присвоения в начало своей строки
# рецепта — переменные shell не переживают переход к следующей строке.
ssh_vars = ssh_key="$(call env_value,SSH_KEY)"; ssh_key="$${ssh_key:-.ssh/id_ed25519}"; \
	ssh_config="$(call env_value,SSH_CONFIG)"; ssh_config="$${ssh_config:-.ssh/config}"; \
	git_host="$(call env_value,GIT_HOST)"; \
	git_user="$(call env_value,GIT_USER)"; git_user="$${git_user:-git}"; \
	container_ssh="$(call env_value,CONTAINER_SSH_DIR)"; container_ssh="$${container_ssh:-/home/claude/.ssh}"

# Единая точка входа подготовки: хостовая часть и инструменты SDD. Под-цели вызываются
# рецептом, а не перечислены зависимостями: зависимости при make -j пошли бы параллельно,
# а обе под-цели пишут в общие файлы корня проекта.
init: ## Полная подготовка проекта: хостовая часть и инструменты SDD
	@$(MAKE) --no-print-directory init-host
	@$(MAKE) --no-print-directory openspec-init
	@echo "Готово. Дальше: заполнить .env (GIT_HOST, CLAUDE_PROFILE) и создать каталог профиля в .claude-accounts/"

# Хостовая часть подготовки — всё, что делается до контейнера: файл секретов, каталоги ключей
# и профилей, записи в .gitignore, SSH-ключ проекта и конфигурация SSH для git-хоста. Шаги
# вызываются рецептом, а не перечислены зависимостями: зависимости при make -j пошли бы
# параллельно, а шаги пишут в общие файлы корня проекта.
#
# Цель остаётся отдельной: хостовую подготовку повторяют после заполнения .env, не трогая
# развёртывание инструментов SDD.
init-host: ## Хостовая подготовка: .env, каталоги, SSH-ключ и конфигурация SSH, .gitignore
	@$(MAKE) --no-print-directory init-env
	@$(MAKE) --no-print-directory init-dirs
	@$(MAKE) --no-print-directory init-gitignore
	@$(MAKE) --no-print-directory init-ssh-key
	@$(MAKE) --no-print-directory init-ssh-config

# Файл секретов. Существующий .env не перезаписывается: в нём заполненные пользователем значения,
# а .env.example — только умолчания.
init-env: ## Создать .env из .env.example
	@if [ -f .env ]; then \
		echo "  .env уже существует — оставлен без изменений"; \
	else \
		cp .env.example .env; \
		echo "  создан .env из .env.example"; \
	fi

# Каталоги ключей и профилей аккаунтов. Права 700 на .ssh — требование ssh-клиента: с более
# широкими правами он отказывается работать с лежащим внутри ключом.
init-dirs: ## Создать каталоги .ssh и .claude-accounts
	@mkdir -p .ssh .claude-accounts
	@chmod 700 .ssh

# Записи в .gitignore. Каждая добавляется однократно: повторный прогон находит её точным
# совпадением строки и пропускает. Перевод строки дописывается перед записью, если файл им
# не заканчивается, — иначе запись склеилась бы с последней строкой.
init-gitignore: ## Добавить в .gitignore .env, .ssh/ и .claude-accounts/
	@touch .gitignore
	@for entry in .env .ssh/ .claude-accounts/; do \
		grep -qxF "$$entry" .gitignore >/dev/null 2>&1 && continue; \
		[ -s .gitignore ] && [ -n "$$(tail -c 1 .gitignore)" ] && printf '\n' >> .gitignore; \
		printf '%s\n' "$$entry" >> .gitignore; \
		echo "  в .gitignore добавлено: $$entry"; \
	done

# SSH-ключ проекта. Существующий ключ не перезаписывается: он может быть уже зарегистрирован
# в git-сервисе. Проверка ssh-keygen — часть этого шага: без утилиты бессмысленна именно
# генерация ключа, и при отдельном вызове цели проверка обязана выполниться.
init-ssh-key: ## Создать SSH-ключ проекта (ed25519)
	@if ! command -v ssh-keygen >/dev/null 2>&1; then \
		echo "Ошибка: не найдена утилита ssh-keygen — установите пакет openssh-client" >&2; \
		exit 1; \
	fi
	@$(ssh_vars); \
	mkdir -p "$$(dirname "$$ssh_key")"; \
	if [ -f "$$ssh_key" ]; then \
		echo "  SSH-ключ $$ssh_key уже существует — оставлен без изменений"; \
	else \
		ssh-keygen -q -t ed25519 -f "$$ssh_key" -N "" -C "sdd-developer-kit@$$(basename "$$(pwd)")"; \
		chmod 600 "$$ssh_key"; \
		chmod 644 "$$ssh_key.pub"; \
		echo "  создан SSH-ключ $$ssh_key (ed25519, без passphrase)"; \
		echo ""; \
		echo "  Добавьте публичный ключ в git-сервис — без этого push из контейнера не пройдёт:"; \
		echo ""; \
		cat "$$ssh_key.pub"; \
		echo ""; \
	fi

# Конфигурация SSH для git-хоста. Существующая конфигурация не перезаписывается: в ней могут быть
# правки пользователя. Путь ключа записывается от каталога SSH внутри контейнера — файл читает
# ssh из контейнера, а не с хоста.
init-ssh-config: ## Создать конфигурацию SSH для git-хоста из .env
	@$(ssh_vars); \
	mkdir -p "$$(dirname "$$ssh_config")"; \
	if [ -f "$$ssh_config" ]; then \
		echo "  $$ssh_config уже существует — оставлен без изменений"; \
	elif [ -z "$$git_host" ]; then \
		echo "  GIT_HOST не задан — $$ssh_config не создан;"; \
		echo "  заполните GIT_HOST в .env и выполните make init повторно"; \
	else \
		printf 'Host %s\n  HostName %s\n  User %s\n  IdentityFile %s/%s\n  IdentitiesOnly yes\n' \
			"$$git_host" "$$git_host" "$$git_user" "$$container_ssh" "$$(basename "$$ssh_key")" \
			> "$$ssh_config"; \
		chmod 644 "$$ssh_config"; \
		echo "  создан $$ssh_config: хост $$git_host, ключ $$container_ssh/$$(basename "$$ssh_key")"; \
	fi

# Инициализация OpenSpec в проекте. Skills, команды агента и каталог openspec/ создаёт сама
# утилита из образа, а не поставка kit'а: иначе они остаются от той версии, что лежала
# в архиве, и расходятся с OPENSPEC_VERSION образа. Язык артефактов задаётся ключом --language,
# поэтому openspec/config.yaml тоже не входит в поставку.
#
# Цель вызывается из init и остаётся отдельной: после смены версии OpenSpec в образе
# инструменты обновляются повторным вызовом, без прохода по хостовой части подготовки.
openspec-init: ## Развернуть инструменты SDD: openspec init в контейнере агента
	@if [ ! -f .env ]; then \
		echo "Ошибка: нет файла .env — сначала выполните make init" >&2; \
		exit 1; \
	fi
	@profile="$${CLAUDE_PROFILE:-$(call env_value,CLAUDE_PROFILE)}"; \
	profile="$${profile:-__no_profile__}"; \
	accounts="$${CLAUDE_ACCOUNTS_DIR:-$(call env_value,CLAUDE_ACCOUNTS_DIR)}"; \
	accounts="$${accounts:-.claude-accounts}"; \
	mkdir -p "$$accounts/$$profile"
	docker compose --profile claude run --rm -T claude \
		openspec init --tools claude --language ru

# Проверка моделей пространства: реестра проектов и словаря значений фасетов. Вход сам собирает
# изолированное окружение при первом запуске, поэтому цель не зависит от подготовки проекта
# и вызывается в любой момент. Имя цели и имя подкоманды различаются намеренно: имя цели стоит
# в белом списке раннера и в порождённых беклогах, а имя подкоманды выведено из понятия
# операции. Коды возврата пробрасываются как есть: 0 — норма, 1 — нарушения, 2 — ошибка
# окружения.
registry-lint: ## Проверить реестр проектов и словарь значений фасетов
	@sh tools/workspace/ws.sh validate-models

# Заведение проекта: сверка ввода со словарём, запись реестра с пустым путём и файл миграции
# заведения каталога. Каталог создаёт накат — make layout-apply VERSION=версия, запускаемый
# владельцем. Значения фасетов приходят переменными вызова: выводить их из имени, содержимого
# или хоста репозитория запрещено, а пустота задаётся литералом null. Имя обязательно здесь,
# прочие значения проверяет скрипт и называет недостающие разом. Коды возврата скрипта: 0 —
# проект заведён, 1 — ввод не позволяет завести запись, 2 — ошибка вызова или окружения; make
# любой ненулевой код рецепта возвращает как 2, поэтому 1 и 2 различаются по выводу либо
# прямым вызовом tools/workspace/ws.sh create-project.
project-new: ## Завести проект: запись реестра и миграция заведения (NAME=… PURPOSE=… ORIGIN=…)
	@test -n "$(NAME)" || { echo "укажите имя проекта: make project-new NAME=имя PURPOSE=назначение ORIGIN=происхождение ORG=организация GROUP=группа CUSTOMER=заказчик FROM=год TO=год STATUS=положение TECH=технологии DOMAINS=области ROLES=роли" >&2; exit 2; }
	@sh tools/workspace/ws.sh create-project --name "$(NAME)" --purpose "$(PURPOSE)" \
		--origin "$(ORIGIN)" --organization "$(ORG)" --group "$(GROUP)" \
		--customer "$(CUSTOMER)" \
		--period-from "$(FROM)" --period-to "$(TO)" --status "$(STATUS)" \
		--technologies "$(TECH)" --domains "$(DOMAINS)" --roles "$(ROLES)" \
		$(if $(TEMPLATE),--template "$(TEMPLATE)") $(if $(NO_MIGRATION),--no-migration)

# Регистрация проекта: запись реестра для каталога, который уже лежит по целевому пути своей
# записи. Миграция не порождается и накат не требуется — переносить нечего. Путь каталога
# обязателен и сверяется с путём, выведенным из фасетов по действующему шаблону: расхождение
# прогон прекращает. Переменная пути названа DIR, а не PATH: переменные командной строки make
# уходят в окружение рецепта, и PATH затёр бы системный. Значения записи обязательны, когда
# записи ещё нет; записи, заведённой прежде с пустым путём, вызов дописывает только путь,
# и значения записи в этом случае запрещены. Коды возврата скрипта: 0 — проект
# зарегистрирован, 1 — ввод или состояние пространства не позволяют, 2 — ошибка вызова или
# окружения; make любой ненулевой код рецепта возвращает как 2, поэтому 1 и 2 различаются
# по выводу либо прямым вызовом tools/workspace/ws.sh register-project.
register-project: ## Зарегистрировать лежащий каталог: запись реестра (NAME=… DIR=…)
	@test -n "$(NAME)" -a -n "$(DIR)" || { echo "укажите имя и каталог: make register-project NAME=имя DIR=путь PURPOSE=назначение ORIGIN=происхождение ORG=организация GROUP=группа CUSTOMER=заказчик FROM=год TO=год STATUS=положение TECH=технологии DOMAINS=области ROLES=роли" >&2; exit 2; }
	@sh tools/workspace/ws.sh register-project --name "$(NAME)" --path "$(DIR)" \
		$(if $(PURPOSE),--purpose "$(PURPOSE)") $(if $(ORIGIN),--origin "$(ORIGIN)") \
		$(if $(ORG),--organization "$(ORG)") $(if $(GROUP),--group "$(GROUP)") \
		$(if $(CUSTOMER),--customer "$(CUSTOMER)") \
		$(if $(FROM),--period-from "$(FROM)") $(if $(TO),--period-to "$(TO)") \
		$(if $(STATUS),--status "$(STATUS)") $(if $(TECH),--technologies "$(TECH)") \
		$(if $(DOMAINS),--domains "$(DOMAINS)") $(if $(ROLES),--roles "$(ROLES)") \
		$(if $(TEMPLATE),--template "$(TEMPLATE)")

# Порождение беклога подъёма проекта: шаблон рендерится значениями вызова в файл
# backlog/bootstrap/<имя>/tasks.md. Пространство прогон не меняет — заведение записи стоит первой
# задачей беклога, а исполняет беклог агент. Обязательны значения записи и признак REMOTE;
# при REMOTE=yes обязательны NAMESPACE и VISIBILITY: ни пространство имён, ни видимость
# не выводятся из словаря или фасетов. Коды возврата скрипта: 0 — беклог порождён, 1 — ввод
# не позволяет его породить, 2 — ошибка вызова или окружения; make любой ненулевой код рецепта
# возвращает как 2, поэтому 1 и 2 различаются по выводу либо прямым вызовом
# tools/workspace/ws.sh bootstrap-project.
project-bootstrap: ## Породить беклог подъёма (NAME=… PURPOSE=… ORIGIN=… REMOTE=…)
	@test -n "$(NAME)" || { echo "укажите имя проекта: make project-bootstrap NAME=имя PURPOSE=назначение ORIGIN=происхождение ORG=организация GROUP=группа CUSTOMER=заказчик FROM=год TO=год STATUS=положение TECH=технологии DOMAINS=области ROLES=роли REMOTE=нужен-ли-репозиторий" >&2; exit 2; }
	@sh tools/workspace/ws.sh bootstrap-project --name "$(NAME)" --purpose "$(PURPOSE)" \
		--origin "$(ORIGIN)" --organization "$(ORG)" --group "$(GROUP)" \
		--customer "$(CUSTOMER)" \
		--period-from "$(FROM)" --period-to "$(TO)" --status "$(STATUS)" \
		--technologies "$(TECH)" --domains "$(DOMAINS)" --roles "$(ROLES)" \
		--remote "$(REMOTE)" $(if $(NAMESPACE),--remote-namespace "$(NAMESPACE)") \
		$(if $(VISIBILITY),--remote-visibility "$(VISIBILITY)") \
		$(if $(HOST),--remote-host "$(HOST)")

# Порождение беклога приведения состава группы: шаблон рендерится значениями вызова в файл
# backlog/compose-group/<штамп>/tasks.md: предмет беклога — штамп прогона, потому что процесс
# повторяем над одной группой, и лежащий беклог прежнего прогона препятствием не является.
# Приведение состава — процесс, а не операция перечня:
# пространство прогон не меняет — объявление значения словаря стоит первой задачей
# беклога, а исполняет беклог агент. Обязательны GROUP и TITLE; NAMES пуст при роспуске группы.
# Предусловие одно: действующий шаблон раскладки несёт подстановку группы — иначе приводить
# размещение нечем. Коды возврата скрипта: 0 — беклог порождён, 1 — ввод или состояние
# не позволяют его породить, 2 — ошибка вызова или окружения; make любой ненулевой код рецепта
# возвращает как 2, поэтому 1 и 2 различаются по выводу либо прямым вызовом
# tools/workspace/ws.sh compose-group.
group-compose: ## Породить беклог состава группы (GROUP=… TITLE=… NAMES=…)
	@test -n "$(GROUP)" || { echo "укажите группу: make group-compose GROUP=идентификатор TITLE=название NAMES=имена-через-запятую [SYNONYMS=синонимы] [TEMPLATE=шаблон]" >&2; exit 2; }
	@sh tools/workspace/ws.sh compose-group --group "$(GROUP)" --title "$(TITLE)" \
		$(if $(NAMES),--names "$(NAMES)") $(if $(SYNONYMS),--synonyms "$(SYNONYMS)") \
		$(if $(TEMPLATE),--template "$(TEMPLATE)")

# Реструктуризация раскладки: по шаблону пути и текущему состоянию реестра создаётся файл
# версии в каталоге layout/. Каталоги не переносятся и реестр не правится — результат читает
# владелец перед накатом. Имя миграции обязательно: make layout-generate NAME=lenvendo_split.
# Шаблон необязателен: без него берётся действующий по журналу применённого, а названный меняет
# раскладку — им вводится сегмент группы. Имя цели и имя подкоманды входа различаются намеренно:
# имя цели выведено из предмета, имя подкоманды — из понятия операции. В белый список раннера
# цель не внесена: реструктуризацию запускает владелец на хосте.
# Коды возврата: 0 — файл создан либо переносить нечего, 1 — запись без вычислимого пути,
# 2 — ошибка окружения.
layout-generate: ## Породить миграцию раскладки (NAME=имя, TEMPLATE=шаблон)
	@test -n "$(NAME)" || { echo "укажите имя миграции: make layout-generate NAME=имя" >&2; exit 2; }
	@sh tools/workspace/ws.sh restructure-layout "$(NAME)" \
		$(if $(TEMPLATE),--template "$(TEMPLATE)")

# Накат миграции раскладки: переносит каталоги и приводит поле path записей реестра.
# Версия обязательна: make layout-apply VERSION=20260912153553. Операции сверяются целиком
# до первого переноса, поэтому невыполнимая операция останавливает накат, не изменив
# пространство. Коды возврата: 0 — накат выполнен либо операции выполнены ранее,
# 1 — накат невозможен, 2 — ошибка окружения или сорвавшийся перенос.
layout-apply: ## Накатить миграцию раскладки (VERSION=версия)
	@test -n "$(VERSION)" || { echo "укажите версию: make layout-apply VERSION=штамп" >&2; exit 2; }
	@sh tools/workspace/ws.sh apply-layout "$(VERSION)"

# Действующая раскладка по журналу применённого и перечень неприменённых файлов версий.
# Состояние пространства не меняется. Коды возврата: 0 — отчёт напечатан, 2 — ошибка окружения.
layout-status: ## Показать действующую раскладку каталогов проектов
	@sh tools/workspace/ws.sh layout-status

# Сканирование пространства: сверка дерева каталогов с реестром в оба направления, отчёт
# о расхождениях и мусоре. Состояние пространства не меняется, вердикта отчёт не выносит,
# поэтому кода 1 у цели нет. Шаблон пути по умолчанию — шаблон действующей раскладки.
# Коды возврата: 0 — отчёт напечатан, 2 — ошибка вызова или окружения.
scan-workspace: ## Просканировать пространство: расхождения дерева и реестра (TEMPLATE=шаблон)
	@sh tools/workspace/ws.sh scan-workspace \
		$(if $(TEMPLATE),--template "$(TEMPLATE)")

# Перемещение проектов: одна миграция с операцией размещения на каждую названную запись и один
# беклог наката. Имена приходят через запятую, как TECH и DOMAINS: состав группы приводится одним
# накатом и одним подтверждением. Целевой путь выводится из фасетов записи по действующему шаблону,
# источником служит её путь; запись, уже лежащая по целевому пути, операции не даёт и порождения
# не прекращает. Отступления прочих записей печатаются справочно и код возврата не меняют. Каталоги
# приводит накат — make layout-apply VERSION=версия, запускаемый владельцем по стоп-знаку беклога.
# Коды возврата скрипта: 0 — миграция порождена, 1 — записи нет, путь пуст либо ни одна запись
# места не меняет, 2 — ошибка вызова или окружения; make любой ненулевой код рецепта возвращает
# как 2, поэтому 1 и 2 различаются по выводу либо прямым вызовом tools/workspace/ws.sh.
move-project: ## Переместить проекты: миграция и беклог наката (NAME=имя[,имя…])
	@test -n "$(NAME)" || { echo "укажите имя записи либо перечень через запятую: make move-project NAME=имя[,имя] [TEMPLATE=шаблон]" >&2; exit 2; }
	@sh tools/workspace/ws.sh move-project --name "$(NAME)" \
		$(if $(TEMPLATE),--template "$(TEMPLATE)")

# Извлечение проекта из монорепозитория: запись с пустым путём, миграция со источником и беклог
# наката. Каталог переносится как есть — расщепление истории git остаётся работой автора проекта.
# Значения записи приходят переменными вызова: выводить их из пути источника или содержимого
# каталога запрещено, пустота задаётся литералом null. Коды возврата скрипта: 0 — запись заведена
# и миграция порождена, 1 — ввод или состояние не позволяют извлечение, 2 — ошибка вызова
# или окружения.
extract-project: ## Извлечь проект: запись, миграция и беклог наката (SOURCE=путь NAME=имя)
	@test -n "$(SOURCE)" && test -n "$(NAME)" || { echo "укажите источник и имя: make extract-project SOURCE=путь NAME=имя PURPOSE=назначение ORIGIN=происхождение ORG=организация GROUP=группа FROM=год STATUS=положение ROLES=роли" >&2; exit 2; }
	@sh tools/workspace/ws.sh extract-project --source "$(SOURCE)" --name "$(NAME)" \
		--purpose "$(PURPOSE)" --origin "$(ORIGIN)" --organization "$(ORG)" \
		$(if $(GROUP),--group "$(GROUP)") \
		$(if $(CUSTOMER),--customer "$(CUSTOMER)") --period-from "$(FROM)" \
		$(if $(TO),--period-to "$(TO)") --status "$(STATUS)" \
		$(if $(TECH),--technologies "$(TECH)") $(if $(DOMAINS),--domains "$(DOMAINS)") \
		--roles "$(ROLES)" $(if $(TEMPLATE),--template "$(TEMPLATE)")

# Возврат раскладки: встречная миграция порождается переворотом операций названной версии.
# Предусловие одно: версия числится в журнале применённого. Произвольный целевой путь операция
# не принимает — оба пути уже подтверждены состоявшимся накатом. Коды возврата скрипта:
# 0 — встречная миграция порождена, 1 — версия не применена, файла версии нет либо все её
# операции являются первичными размещениями, 2 — ошибка вызова или окружения.
revert-layout: ## Вернуть раскладку: встречная миграция и беклог наката (VERSION=версия)
	@test -n "$(VERSION)" || { echo "укажите версию: make revert-layout VERSION=штамп" >&2; exit 2; }
	@sh tools/workspace/ws.sh revert-layout --version "$(VERSION)"

# Правка записи реестра: назначение и любые из девяти фасетов. Непереданное значение
# сохраняется, пустота задаётся литералом null. Имя записи и путь операция не правит: имя —
# идентичность записи, путь правит накат миграции. Смена фасета, входящего в шаблон пути,
# делает путь записи расходящимся с шаблоном — операция об этом сообщает, но каталог не трогает.
# Коды возврата скрипта: 0 — запись правлена либо значения совпали, 1 — ввод или состояние
# не позволяют правку, 2 — ошибка вызова или окружения; make любой ненулевой код
# рецепта возвращает как 2, поэтому 1 и 2 различаются по выводу либо прямым вызовом
# tools/workspace/ws.sh.
edit-entry: ## Править запись реестра (NAME=… и правимые поля)
	@test -n "$(NAME)" || { echo "укажите имя записи: make edit-entry NAME=имя [PURPOSE=…] [ORIGIN=…] [ORG=…] [GROUP=…] [CUSTOMER=…] [FROM=…] [TO=…] [STATUS=…] [TECH=…] [DOMAINS=…] [ROLES=…]" >&2; exit 2; }
	@sh tools/workspace/ws.sh edit-entry --name "$(NAME)" \
		$(if $(PURPOSE),--purpose "$(PURPOSE)") $(if $(ORIGIN),--origin "$(ORIGIN)") \
		$(if $(ORG),--organization "$(ORG)") $(if $(GROUP),--group "$(GROUP)") \
		$(if $(CUSTOMER),--customer "$(CUSTOMER)") \
		$(if $(FROM),--period-from "$(FROM)") $(if $(TO),--period-to "$(TO)") \
		$(if $(STATUS),--status "$(STATUS)") $(if $(TECH),--technologies "$(TECH)") \
		$(if $(DOMAINS),--domains "$(DOMAINS)") $(if $(ROLES),--roles "$(ROLES)") \
		$(if $(TEMPLATE),--template "$(TEMPLATE)")

# Переименование проекта: имя записи и миграция смены размещения одним прогоном. Каталог
# приводит накат — make layout-apply VERSION=версия, запускаемый владельцем по стоп-знаку
# порождённого беклога. Запись с пустым путём переносить нечего: миграция и беклог не порождаются.
# Прежнее имя остаётся в операциях применённых миграций, и версии, предшествующие
# переименованию, повторному накату не подлежат. Коды возврата скрипта: 0 — запись
# переименована, 1 — записи нет, новое имя непригодно либо её называет неприменённая миграция,
# 2 — ошибка вызова или окружения; make любой ненулевой код рецепта возвращает как 2, поэтому
# 1 и 2 различаются по выводу либо прямым вызовом tools/workspace/ws.sh rename-project.
rename-project: ## Переименовать проект: имя записи и миграция (NAME=… NEW_NAME=…)
	@test -n "$(NAME)" -a -n "$(NEW_NAME)" || { echo "укажите действующее и новое имя: make rename-project NAME=имя NEW_NAME=имя [TEMPLATE=шаблон]" >&2; exit 2; }
	@sh tools/workspace/ws.sh rename-project --name "$(NAME)" --new-name "$(NEW_NAME)" \
		$(if $(TEMPLATE),--template "$(TEMPLATE)")

# Пополнение словаря значением фасета. Значение, уже покрытое идентификатором или синонимом
# существующей записи, отклоняется с указанием этой записи: обиходное написание — синоним,
# а не новое значение. Обязательны раздел, идентификатор и название. Коды возврата скрипта:
# 0 — значение добавлено, 1 — значение покрыто существующей записью либо раздела нет,
# 2 — ошибка вызова или окружения; make любой ненулевой код
# рецепта возвращает как 2, поэтому 1 и 2 различаются по выводу либо прямым вызовом
# tools/workspace/ws.sh.
add-value: ## Пополнить словарь значением (SECTION=… ID=… NAME=…)
	@test -n "$(SECTION)" && test -n "$(ID)" && test -n "$(NAME)" || { echo "укажите раздел, идентификатор и название: make add-value SECTION=раздел ID=идентификатор NAME=название [SYNONYMS=…] [KIND=…] [OWNED=1]" >&2; exit 2; }
	@sh tools/workspace/ws.sh add-value --section "$(SECTION)" --id "$(ID)" --name "$(NAME)" \
		$(if $(SYNONYMS),--synonyms "$(SYNONYMS)") $(if $(KIND),--kind "$(KIND)") \
		$(if $(OWNED),--owned)

# Устаревание значения словаря: признак устаревания и замена. Удаления операция не
# предусматривает — пока на значение ссылается запись реестра, оно фиксирует исторический
# факт. Замена обязательна и задаётся идентификатором значения того же раздела либо литералом
# null, если замены нет. Коды возврата скрипта: 0 — значение помечено, 1 — значения, раздела
# или замены нет, 2 — ошибка вызова или окружения; make любой ненулевой код
# рецепта возвращает как 2, поэтому 1 и 2 различаются по выводу либо прямым вызовом
# tools/workspace/ws.sh.
deprecate-value: ## Пометить значение словаря устаревшим (SECTION=… ID=… REPLACED_BY=…)
	@test -n "$(SECTION)" && test -n "$(ID)" && test -n "$(REPLACED_BY)" || { echo "укажите раздел, значение и замену: make deprecate-value SECTION=раздел ID=идентификатор REPLACED_BY=замена-или-null" >&2; exit 2; }
	@sh tools/workspace/ws.sh deprecate-value --section "$(SECTION)" --id "$(ID)" \
		--replaced-by "$(REPLACED_BY)"

# Вывод проекта из пространства: путь записи приводится к пустому значению. Диск операция
# не трогает — она приводит запись к факту, а не меняет его. Предусловие одно: каталога
# по текущему пути записи нет; при существующем каталоге операция отказывает. Коды возврата
# скрипта: 0 — запись выведена либо путь уже пуст, 1 — каталог лежит в пространстве либо
# записи нет, 2 — ошибка вызова или окружения; make любой ненулевой код
# рецепта возвращает как 2, поэтому 1 и 2 различаются по выводу либо прямым вызовом
# tools/workspace/ws.sh.
detach-project: ## Вывести проект из пространства: путь записи к пустому значению (NAME=…)
	@test -n "$(NAME)" || { echo "укажите имя записи: make detach-project NAME=имя" >&2; exit 2; }
	@sh tools/workspace/ws.sh detach-project --name "$(NAME)"

# Перестроение перечня проектов в README из реестра и журнала применённого. Правится участок
# между маркерами блока, текст вне них не затрагивается. Накат миграции делает то же самое
# завершающим шагом, поэтому цель нужна для правок реестра без миграции — например назначения
# проекта. Коды возврата: 0 — блок перестроен либо уже совпадает, 2 — README непригоден
# для перестроения или ошибка окружения.
readme: ## Перестроить перечень проектов в README
	@sh tools/workspace/ws.sh rebuild-readme

# Обновление состава SDD Developer Kit до тега VERSION (VERSION=v1.5.0). Состав сверяется
# трёхсторонне: эталон установленной версии из архива тега манифеста, проект и эталон новой.
# Конфликт файла, потеря цели Makefile или расхождение манифеста с эталоном останавливают
# обновление до записи. DRY_RUN=1 — только план, ничего не записывается.
kit-update: ## Обновить SDD Developer Kit до тега VERSION (VERSION=v1.5.0, DRY_RUN=1 — план)
	@test -n "$(VERSION)" || { echo "укажите тег kit'а: make kit-update VERSION=v1.5.0" >&2; exit 2; }
	@DRY_RUN="$(DRY_RUN)" sh tools/kit-update/update.sh "$(VERSION)"

# >>> liquibase-forge
.PHONY: liquibase-update liquibase-rollback forge-env-sync forge-env-check forge-env-up

# Шлюз Liquibase Forge. Цели исполняет раннер по запросу агента: параметры приходят файлом
# .forge/liquibase-request.json, исход уходит файлом .forge/liquibase-result.json. make сводит
# любую ошибку рецепта к коду 2, поэтому истинный код исхода — только в файле результата.
# Логика проверки запроса живёт в скрипте. .env загружается рецептом, а не берётся из окружения
# раннера: учётные данные и перечень тестовых БД действуют сразу после правки .env, без
# перезапуска раннера.
liquibase-update: ## Накат changelog Liquibase по .forge/liquibase-request.json
	@set -a && . ./.env && set +a && python3 tools/liquibase/gateway.py update

liquibase-rollback: ## Откат changeset Liquibase по .forge/liquibase-request.json
	@set -a && . ./.env && set +a && python3 tools/liquibase/gateway.py rollback

# Подготовка окружения Liquibase Forge. Цели входят в белый список раннера: агент выполняет
# их сам, без ручных шагов на хосте.
forge-env-sync: ## Дописать в .env недостающие переменные Liquibase Forge из .env.example
	@sh tools/forge-env/sync-env.sh

forge-env-check: ## Проверить версию Compose (2.20+) и состав сервисов с include:
	@sh tools/forge-env/check.sh

forge-env-up: ## Загрузить и собрать образы, поднять lbfr-db и lbfr-db-test до healthy
	@sh tools/forge-env/up.sh
# <<< liquibase-forge
