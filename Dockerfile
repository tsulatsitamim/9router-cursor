# syntax=docker/dockerfile:1.7
#
# 9Router gateway with the Cursor CLI (cursor-agent) preinstalled.
#
# Base image note: the Cursor CLI ships glibc-only binaries (native modules
# tagged *.linux-x64-gnu.node and a cursor-agent-sea ELF linked against
# /lib64/ld-linux-x86-64.so.2), so it cannot run on Alpine/musl. This image
# therefore uses Debian slim (glibc).
#
# The server is installed from the published `9router` npm package, which
# bundles the complete standalone Next.js app under `app/`.

ARG NODE_IMAGE=node:22-bookworm-slim
FROM ${NODE_IMAGE}

LABEL org.opencontainers.image.title="9router"
LABEL org.opencontainers.image.description="9Router AI gateway with Cursor CLI (cursor-agent)"
LABEL org.opencontainers.image.source="https://github.com/decolua/9router"

WORKDIR /app

ENV NODE_ENV=production \
    PORT=20128 \
    HOSTNAME=0.0.0.0 \
    NEXT_TELEMETRY_DISABLED=1 \
    DATA_DIR=/app/data \
    NODE_PATH=/usr/local/lib/node_modules \
    DEBIAN_FRONTEND=noninteractive

# ca-certificates/curl: Cursor CLI installer + container healthcheck
# bash:                cursor-agent wrapper + installer
# git:                 used by some agent workflows
# tini:                PID 1 init for clean signal handling
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates curl bash git tini \
    && rm -rf /var/lib/apt/lists/*

# The published `9router` package ships the full standalone server. Skip the
# postinstall (it only warms desktop runtime deps / tray, not needed here).
ARG NINEROUTER_VERSION=latest
RUN npm install -g "9router@${NINEROUTER_VERSION}" --ignore-scripts \
    && npm cache clean --force

# SQLite driver. better-sqlite3 13.x is N-API and ships prebuilt binaries
# (linux-x64/arm64 gnu + musl) inside the package, so no build toolchain is
# needed and sql.js (whose .wasm is stripped on npm publish) is not required.
ARG BETTER_SQLITE3_VERSION=13.0.3
RUN npm install -g "better-sqlite3@${BETTER_SQLITE3_VERSION}" --ignore-scripts \
    && npm cache clean --force

# Cursor CLI installs into $HOME/.local for the unprivileged `node` user and
# exposes `agent` + `cursor-agent` in $HOME/.local/bin.
ENV HOME=/home/node
USER node
RUN curl -fsSL https://cursor.com/install | bash
USER root
ENV PATH="/home/node/.local/bin:${PATH}"

# Runtime directories + ownership. The npm-installed app may write its Next
# cache into its own directory, so hand it to the unprivileged user.
RUN mkdir -p /app/data \
    && chown -R node:node /app/data /home/node \
    && chown -R node:node /usr/local/lib/node_modules/9router

EXPOSE 20128

HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=3 \
    CMD curl -fsS "http://127.0.0.1:${PORT}/" >/dev/null || exit 1

USER node

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["node", "/usr/local/lib/node_modules/9router/app/custom-server.js"]
