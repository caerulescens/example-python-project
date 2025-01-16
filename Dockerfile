ARG VERSION_DEBIAN=bookworm
ARG VERSION_PYTHON=3.12
ARG VERSION_UV=0.5.13
ARG APP_PATH=/opt/app
ARG APP_NAME=example_python_project
ARG APP_VERSION=0.1.0
ARG APP_HOST=0.0.0.0
ARG APP_PORT=8000
ARG USER=appuser
ARG USER_GID=10001
ARG USER_UID=10001

FROM python:${VERSION_PYTHON}-slim-${VERSION_DEBIAN} AS base
LABEL maintainer="caerulescens <caerulescens.github@proton.me>"
ARG USER
ARG USER_GID
ARG USER_UID
ENV \
    DEBIAN_FRONTEND=noninteractive \
    DEBCONF_NOWARNINGS=yes
RUN set -ex \
    && groupadd --system --gid "${USER_GID}" "${USER}" \
    && useradd --system --uid "${USER_UID}" --gid "${USER_GID}" --no-create-home "${USER}" \
    && apt-get update \
    && apt-get purge -y --auto-remove \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

FROM ghcr.io/astral-sh/uv:python${VERSION_PYTHON}-${VERSION_DEBIAN}-slim AS builder
ARG VERSION_UV
ARG APP_PATH
ENV \
    PIP_NO_CACHE_DIR=true \
    PIP_DISABLE_PIP_VERSION_CHECK=true \
    PIP_DEFAULT_TIMEOUT=100 \
    UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy
WORKDIR ${APP_PATH}
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    uv sync --frozen --no-install-project --no-dev
RUN uv tool install granian
ADD . ${APP_PATH}
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev

FROM base AS runtime
ARG APP_PATH
ARG APP_NAME
ARG APP_HOST
ARG APP_PORT
ARG USER
ENV \
    PYTHONUNBUFFERED=true \
    PYTHONDONTWRITEBYTECODE=true \
    PYTHONFAULTHANDLER=true \
    PYTHONHASHSEED=random \
    APP_NAME=${APP_NAME} \
    APP_HOST=${APP_HOST} \
    APP_PORT=${APP_PORT}
ENV PATH="${APP_PATH}/.venv/bin:${PATH}"
WORKDIR ${APP_PATH}
COPY --from=builder --chown=${USER}:${USER} ${APP_PATH} ${APP_PATH}
USER ${USER}
CMD ["sh", "-c", "granian /app/src/example_python_project"]
EXPOSE ${PORT}
