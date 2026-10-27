# syntax=docker/dockerfile:1

# Образ tldr: анализ кода без установки инструмента. Проект монтируется в /project только для
# чтения, результат — в stdout. Решения по устройству образа — в design.md изменения
# openspec/changes/add-docker-image-delivery (D1, D2).

# Версия Rust закреплена явно: в репозитории нет rust-toolchain.toml, а плавающий тег
# сделал бы сборку невоспроизводимой. Повышается отдельной правкой.
ARG RUST_VERSION=1.99
ARG DEBIAN_RELEASE=trixie

# --- Сборка ------------------------------------------------------------------------------------
FROM rust:${RUST_VERSION}-${DEBIAN_RELEASE} AS build

WORKDIR /src
COPY . .

# Реестр cargo и target/ живут в кэш-монтированиях: повторная сборка не тянет зависимости заново.
# Содержимое кэш-монтирования в слой не попадает, поэтому бинари копируются в /dist.
RUN --mount=type=cache,target=/usr/local/cargo/registry,sharing=locked \
    --mount=type=cache,target=/usr/local/cargo/git,sharing=locked \
    --mount=type=cache,target=/src/target,sharing=locked \
    cargo build --release --locked -p tldr-cli --bin tldr --bin tldr-mcp \
    && install -D -m 0755 -t /dist target/release/tldr target/release/tldr-mcp

# --- Выполнение --------------------------------------------------------------------------------
FROM debian:${DEBIAN_RELEASE}-slim

# git нужен командам на основе истории (churn, hotspots, change-impact, bugbot).
# safe.directory '*': под -u "$(id -u):$(id -g)" владелец смонтированного репозитория и UID
# процесса расходятся, и без этой настройки git отказывает с «dubious ownership».
RUN apt-get update \
    && apt-get install -y --no-install-recommends git ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && git config --system --add safe.directory '*' \
    && groupadd -g 1000 tldr \
    && useradd -u 1000 -g tldr -M -d /tmp -s /usr/sbin/nologin tldr \
    && install -d -o tldr -g tldr /project /out

COPY --from=build /dist/ /usr/local/bin/

# Под произвольным UID из -u записи в /etc/passwd нет; /tmp доступен на запись любому UID
ENV HOME=/tmp

LABEL org.opencontainers.image.title="tldr-code" \
      org.opencontainers.image.description="Token-efficient code analysis CLI, no install required" \
      org.opencontainers.image.source="https://github.com/united-software-platform/tldr-code" \
      org.opencontainers.image.licenses="AGPL-3.0"

WORKDIR /project
USER tldr

ENTRYPOINT ["tldr"]
CMD ["--help"]
