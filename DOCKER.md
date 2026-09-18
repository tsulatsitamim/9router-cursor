# Docker

Run 9Router in a container. The image bundles the 9Router server **and the Cursor CLI** (`cursor-agent` / `agent`), so you can run agents against 9Router from inside the same container.

- Build locally from this repo's [`Dockerfile`](./Dockerfile) (Debian slim + glibc, required by the Cursor CLI).
- Published image: [`decolua/9router`](https://hub.docker.com/r/decolua/9router) — multi-platform `linux/amd64` + `linux/arm64` (built from the same Dockerfile by CI).

> The Cursor CLI ships glibc-only binaries, so this image is Debian-based (glibc).

---

# 👤 For Users

## Quick start

### Option A — build locally (includes Cursor CLI)

```bash
git clone https://github.com/decolua/9router.git
cd 9router
docker build -t 9router:latest .
docker run -d \
  --name 9router \
  -p 20128:20128 \
  -v "$HOME/.9router:/app/data" \
  -e DATA_DIR=/app/data \
  9router:latest
```

### Option B — published image

```bash
docker run -d \
  --name 9router \
  -p 20128:20128 \
  -v "$HOME/.9router:/app/data" \
  -e DATA_DIR=/app/data \
  decolua/9router:latest
```

App listens on port `20128`. Open: http://localhost:20128

## Volumes to mount

| Volume / path | Mount to | Required | Purpose |
| --- | --- | --- | --- |
| `9router-data` (or `$HOME/.9router`) | `/app/data` | Recommended | 9Router state: SQLite DB, config, certs, MITM files. Without it, all state is lost when the container is removed. |
| `9router-cursor` (or `$HOME/.cursor`) | `/home/node/.cursor` | Optional | Persists Cursor CLI login/state so you don't re-authenticate after a rebuild. |

```bash
# Recommended: persist both app data and Cursor CLI state
docker run -d \
  --name 9router \
  -p 20128:20128 \
  -v "$HOME/.9router:/app/data" \
  -v "$HOME/.cursor:/home/node/.cursor" \
  -e DATA_DIR=/app/data \
  9router:latest
```

## Data persistence

```bash
-v "$HOME/.9router:/app/data" \
-e DATA_DIR=/app/data
```

Without `DATA_DIR`, the app falls back to `~/.9router/` (macOS/Linux) or `%APPDATA%\9router\` (Windows). In the container, `DATA_DIR=/app/data` makes the bind mount work.

Data layout under `$DATA_DIR/`:

```text
$DATA_DIR/
├── db/
│   ├── data.sqlite       # main SQLite database
│   └── backups/          # auto backups
└── ...                   # certs, logs, runtime configs
```

Host path: `$HOME/.9router/db/data.sqlite`
Container path: `/app/data/db/data.sqlite`

## Cursor CLI

The image preinstalls the Cursor CLI for the unprivileged `node` user and puts it on `PATH` (`/home/node/.local/bin`):

```bash
docker exec -it 9router cursor-agent --version
docker exec -it 9router agent --version     # `agent` is an alias for the same CLI
```

Authenticate once (state persists if you mounted `/home/node/.cursor`):

```bash
docker exec -it 9router cursor-agent login
```

Example: point the Cursor CLI at your 9Router endpoint. Inside the container the server is on `http://127.0.0.1:20128/v1`:

```bash
docker exec -it 9router sh -lc '
  export OPENAI_BASE_URL=http://127.0.0.1:20128/v1
  export OPENAI_API_KEY=<your-9router-api-key>
  cursor-agent -p "summarize this repository"
'
```

## Manage container

```bash
docker logs -f 9router        # view logs
docker stop 9router           # stop
docker start 9router          # start again
docker rm -f 9router          # remove
```

## Optional env vars

```bash
docker run -d \
  --name 9router \
  -p 20128:20128 \
  -v "$HOME/.9router:/app/data" \
  -e DATA_DIR=/app/data \
  -e PORT=20128 \
  -e HOSTNAME=0.0.0.0 \
  -e ENABLE_REQUEST_LOGS=true \
  9router:latest
```

| Variable | Default | Description |
| --- | --- | --- |
| `JWT_SECRET` | auto-generated (`$DATA_DIR/jwt-secret`) | JWT signing secret for the dashboard auth cookie |
| `INITIAL_PASSWORD` | `123456` | First login password when no saved hash exists. Override this. |
| `DATA_DIR` | `~/.9router` (`/app/data` in this image) | Main app data location (SQLite at `$DATA_DIR/db/data.sqlite`) |
| `PORT` | `20128` | Service port |
| `HOSTNAME` | `0.0.0.0` | Bind host |
| `NODE_ENV` | `production` | Runtime environment |
| `BASE_URL` | `http://localhost:20128` | Server-side internal base URL used by cloud sync |
| `CLOUD_URL` | `https://9router.com` | Server-side cloud sync endpoint |
| `NEXT_PUBLIC_BASE_URL` | `http://localhost:3000` | Backward-compatible/public base URL |
| `NEXT_PUBLIC_CLOUD_URL` | `https://9router.com` | Backward-compatible/public cloud URL |
| `API_KEY_SECRET` | `endpoint-proxy-api-key-secret` | HMAC secret for generated API keys |
| `MACHINE_ID_SALT` | `endpoint-proxy-salt` | Salt for stable machine ID hashing |
| `ENABLE_REQUEST_LOGS` | `false` | Write request/response logs under `logs/` |
| `AUTH_COOKIE_SECURE` | `false` | Force `Secure` auth cookie (set `true` behind HTTPS) |
| `REQUIRE_API_KEY` | `false` | Enforce Bearer API key on `/v1/*` routes |
| `HTTP_PROXY`, `HTTPS_PROXY`, `ALL_PROXY`, `NO_PROXY` | empty | Optional outbound proxy for upstream provider calls |
| `SEARXNG_URL` | `http://localhost:8888/search` | Endpoint for the built-in SearXNG web-search provider |
| `HEADROOM_URL` | empty | Point at a Headroom sidecar (see below) |

Do not commit secrets. `.env` is not baked into the image (`.dockerignore`); inject config with `--env-file` or `-e`.

## Optional Headroom sidecar

To use [Headroom](https://github.com/chopratejas/headroom) in Docker, run it as a separate service and point 9Router at that proxy (see [`docker-compose.yml`](./docker-compose.yml)):

```yaml
services:
  9router:
    build: .
    ports:
      - "20128:20128"
    volumes:
      - "$HOME/.9router:/app/data"
    environment:
      DATA_DIR: /app/data
      HEADROOM_URL: http://headroom:8787
    depends_on:
      - headroom

  headroom:
    image: ghcr.io/chopratejas/headroom:latest
    ports:
      - "8787:8787"
```

In the dashboard, open `Endpoint` → `Token Saver` → `Headroom`, confirm the URL is `http://headroom:8787`, recheck status, then enable Headroom.

If Headroom runs on the Docker host instead of as a sidecar, use `http://host.docker.internal:8787` on macOS/Windows. On Linux, add `--add-host=host.docker.internal:host-gateway` or the equivalent compose `extra_hosts` entry.

## Update to latest

```bash
# published image
docker pull decolua/9router:latest
docker rm -f 9router
# re-run the quick start command

# local build
git pull
docker build -t 9router:latest .
docker rm -f 9router && docker run ... 9router:latest
```

To pin the installed server or SQLite driver versions, build with:

```bash
docker build \
  --build-arg NINEROUTER_VERSION=latest \
  --build-arg BETTER_SQLITE3_VERSION=13.0.3 \
  -t 9router:latest .
```

---

# 🛠 For Developers

## What the image does

1. Base: `node:22-bookworm-slim` (Node 22, glibc — needed by the Cursor CLI).
2. Installs `ca-certificates`, `curl`, `bash`, `git`, `tini`.
3. `npm install -g 9router@latest` (the published package bundles the standalone Next.js server under `app/`).
4. `npm install -g better-sqlite3@13` (N-API prebuilds; the primary DB driver).
5. Installs the Cursor CLI into `/home/node/.local` as the `node` user.
6. Runs as the unprivileged `node` user, with `tini` as PID 1.

Running as `node` means mounted volumes under `/app/data` must be writable by the image's `node` user (uid 1000 in the official Node images).

## Build image locally (test)

```bash
docker build -t 9router:latest .

docker run --rm -p 20128:20128 \
  -v "$HOME/.9router:/app/data" \
  -e DATA_DIR=/app/data \
  9router:latest
```

Health check (built into the image):

```bash
docker inspect --format '{{.State.Health.Status}}' 9router
curl -fsS http://localhost:20128/ >/dev/null && echo up
```

## Publish (automatic via CI)

Push a git tag `v*` → GitHub Actions builds multi-platform (amd64+arm64) from [`Dockerfile`](./Dockerfile) and pushes to:

- `ghcr.io/decolua/9router:v{version}` + `:latest`
- `decolua/9router:v{version}` + `:latest`

```bash
# Use scripts/release.js (recommended)
node scripts/release.js "Release title" "Notes"

# Or manually
git tag v0.4.x && git push origin v0.4.x
```

Workflow: [`.github/workflows/docker-publish.yml`](./.github/workflows/docker-publish.yml)
