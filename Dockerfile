ARG PYTHON_VERSION=3.12.1
ARG BUILD_PATH=/opt/build
ARG INSTALL_PATH=/opt/app
ARG HOST=0.0.0.0
ARG PORT=8000
ARG USER=appuser
ARG USER_GID=10001
ARG USER_UID=10001

FROM python:${PYTHON_VERSION}-slim-bookworm AS base
LABEL maintainer="caerulescens <caerulescens.github@proton.me>"
ARG HOST
ARG PORT
ARG USER
ARG USER_GID
ARG USER_UID
ENV \
    # os
    DEBIAN_FRONTEND=noninteractive \
    DEBCONF_NOWARNINGS=yes \
    # python
    PYTHONUNBUFFERED=true \
    PYTHONDONTWRITEBYTECODE=true \
    PYTHONFAULTHANDLER=true \
    PYTHONHASHSEED=random \
    # pip
    PIP_NO_CACHE_DIR=true \
    PIP_DISABLE_PIP_VERSION_CHECK=true \
    PIP_DEFAULT_TIMEOUT=100 \
    # uv
    # todo: uv environment variables
    UV_HOME=... \
    UV_CACHE_DIR=... \
    # uvicorn
    # todo: uvicorn/ruvicorn environment variables
ENV PATH="${UV_HOME}/bin:$VENV_PATH/bin:$PATH"
RUN set -ex \
    && groupadd --system --gid "${USER_GID}" "${USER}" \
    && useradd --system --uid "${USER_UID}" --gid "${USER_GID}" --no-create-home "${USER}" \
    && apt-get update \
    && apt-get purge -y --auto-remove \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

FROM base as builder
ARG BUILD_PATH
WORKDIR $BUILD_PATH
# todo: copy
# todo: package

FROM base as runtime
ARG BUILD_PATH
ARG INSTALL_PATH
ARG PORT
ARG USER
WORKDIR $INSTALL_PATH
# todo: copy
USER $USER
CMD ["python", ""]
EXPOSE $PORT





FROM python:${PYTHON_VERSION}-slim-bookworm AS base
LABEL maintainer="caerulescens <caerulescens.github@proton.me>"
ARG HOST
ARG PORT
#ARG WORKERS=1
#ARG LOG_LEVEL=info
#ARG BACKLOG=2048
#ARG TIMEOUT_KEEP_ALIVE=5
#ARG TIMEOUT_GRACEFUL_SHUTDOWN=30
ARG USER
ARG USER_GID
ARG USER_UID
ENV \
    # os
    DEBIAN_FRONTEND=noninteractive \
    DEBCONF_NOWARNINGS=yes \
    PYSETUP_PATH=/opt/pysetup \
    VENV_PATH=/opt/pysetup/.venv \
    # python
    PYTHONUNBUFFERED=true \
    PYTHONDONTWRITEBYTECODE=true \
    PYTHONFAULTHANDLER=true \
    PYTHONHASHSEED=random \
    # pip
    PIP_NO_CACHE_DIR=true \
    PIP_DISABLE_PIP_VERSION_CHECK=true \
    PIP_DEFAULT_TIMEOUT=100 \
    # poetry
    POETRY_VERSION=1.7.1 \
    POETRY_HOME=/opt/poetry \
    POETRY_CACHE_DIR=/tmp/poetry_cache \
    POETRY_VIRTUALENVS_OPTIONS_NO_PIP=true \
    POETRY_INSTALLER_MODERN_INSTALLATION=true \
    POETRY_NO_INTERACTION=true \
    POETRY_NO_ANSI=true \
    POETRY_INSTALLER_PARALLEL=true \
    POETRY_VIRTUALENVS_IN_PROJECT=true \
    POETRY_VIRTUALENVS_CREATE=true \

    UVICORN_HOST=$HOST \
    UVICORN_PORT=$PORT \
    UVICORN_WORKERS=$WORKERS \
    UVICORN_LOG_LEVEL=$LOG_LEVEL \
    UVICORN_LOOP=auto \
    UVICORN_HTTP=auto \
    UVICORN_WS=auto \
    UVICORN_INTERFACE=auto \
    UVICORN_BACKLOG=$BACKLOG \
    UVICORN_TIMEOUT_KEEP_ALIVE=$TIMEOUT_KEEP_ALIVE \
    UVICORN_TIMEOUT_GRACEFUL_SHUTDOWN=$TIMEOUT_GRACEFUL_SHUTDOWN

ENV PATH="$POETRY_HOME/bin:$VENV_PATH/bin:$PATH"
RUN set -ex \
    && groupadd --system --gid "${USER_GID}" "${USER}" \
    && useradd --system --uid "${USER_UID}" --gid "${USER_GID}" --no-create-home "${USER}" \
    && apt-get update \
    && apt-get install -y tini \
    && apt-get purge -y --auto-remove \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

FROM base AS builder
WORKDIR $PYSETUP_PATH
RUN pip install poetry=="${POETRY_VERSION}"
COPY poetry.lock pyproject.toml ./
RUN --mount=type=cache,target="${POETRY_CACHE_DIR}" poetry install --without dev --no-root

FROM base AS runtime
COPY --from=builder $PYSETUP_PATH $PYSETUP_PATH
WORKDIR /opt
COPY src/fastapi_server_postgresql/ /opt/fastapi_server_postgresql
USER $USER
ENTRYPOINT ["tini", "--", "uvicorn", "fastapi_server_postgresql.main:app"]
EXPOSE $PORT
