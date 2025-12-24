# syntax=docker/dockerfile:1

# An example of using standalone Python builds with multistage images.

# First, build the application in the `/app` directory
FROM ghcr.io/astral-sh/uv:bookworm-slim AS builder
ENV UV_COMPILE_BYTECODE=1 UV_LINK_MODE=copy

# Omit development dependencies
ENV UV_NO_DEV=1

# Configure the Python directory so it is consistent
ENV UV_PYTHON_INSTALL_DIR=/python

# Only use the managed Python version
ENV UV_PYTHON_PREFERENCE=only-managed

# Install Python before the project for caching
RUN uv python install 3.12

WORKDIR /app
COPY backend/pyproject.toml backend/uv.lock ./
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked --no-install-project

# Then, add the rest of the project source code and install it
COPY backend/src/. ./
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked

# Then, use a final image without uv
FROM debian:bookworm-slim

ENV LANG="C.UTF-8" \
    TZ=Asia/Shanghai \
    PUID=1000 \
    PGID=1000 \
    UMASK=022

# Install dependencies for entrypoint (gosu for user switching, shadow for usermod/groupmod)
RUN set -ex && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        gosu \
        tini \
        ca-certificates \
        tzdata \
        openssl \
        netbase \
    && rm -rf /var/lib/apt/lists/* && \
    # Add user
    mkdir -p /home/ab && \
    groupadd -r -g 911 ab && \
    useradd -r -g ab -u 911 -d /home/ab -s /sbin/nologin ab

# Copy the Python version
COPY --from=builder --chown=python:python /python /python

# Copy the application from the builder
COPY --from=builder --chown=ab:ab /app /app

# Place executables in the environment at the front of the path
ENV PATH="/app/.venv/bin:$PATH"

WORKDIR /app

COPY --chmod=755 entrypoint.sh /entrypoint.sh

ENTRYPOINT ["tini", "-g", "--", "/entrypoint.sh"]

EXPOSE 7892
VOLUME [ "/app/config" , "/app/data" ]
