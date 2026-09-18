# 9Router — Docker image with Cursor CLI

Container image for [9Router](https://github.com/decolua/9router), an OpenAI-compatible AI gateway that routes coding CLIs (Claude Code, Codex, Cursor, Cline, Copilot, Antigravity) to 40+ providers.

The image **installs 9Router from npm** (no source copy) and preinstalls the **Cursor CLI** (`cursor-agent` / `agent`), so you can run agents against the gateway from inside the same container.

- Image: [`tsulatsitamim/9router-cursor`](https://hub.docker.com/r/tsulatsitamim/9router-cursor)
- Full Docker guide: [`DOCKER.md`](./DOCKER.md)

## Quick start

```bash
docker run -d \
  --name 9router \
  -p 20128:20128 \
  -v 9router-data:/app/data \
  -v 9router-cursor:/home/node/.cursor \
  -e DATA_DIR=/app/data \
  tsulatsitamim/9router-cursor:latest
```

Open http://localhost:20128. First login password is `123456` — set `INITIAL_PASSWORD` to override.

## Volumes

| Volume | Path in container | Purpose |
| --- | --- | --- |
| `9router-data` | `/app/data` | 9Router database, config and certs. Recommended — state is lost without it. |
| `9router-cursor` | `/home/node/.cursor` | Cursor CLI login/state (optional). |

## Docker Compose

```bash
cp .env.example .env
docker compose up -d --build
```

## Cursor CLI

```bash
docker exec -it 9router cursor-agent --version
docker exec -it 9router cursor-agent login
```

## Configuration

Common env vars: `DATA_DIR`, `PORT` (default `20128`), `HOSTNAME` (default `0.0.0.0`), `INITIAL_PASSWORD`, `JWT_SECRET`, `ENABLE_REQUEST_LOGS`. Full table in [`DOCKER.md`](./DOCKER.md).

## Build

```bash
docker build -t tsulatsitamim/9router-cursor:latest .
```

Pin versions with `--build-arg NINEROUTER_VERSION=...` and `--build-arg BETTER_SQLITE3_VERSION=...`.

---

Based on [decolua/9router](https://github.com/decolua/9router) (MIT).
