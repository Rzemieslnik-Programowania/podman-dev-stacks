# 🐳 Podman Dev Stacks

> Reproducible, rootless, zero-system-pollution development environments using **Podman**.
> No Docker daemon. No root. Nothing installed globally. Everything containerized.

---

## ⚡ One-Line Install

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/podman-dev-stacks/main/install.sh | bash
```

That's it. The installer will:
1. Check that Podman is installed
2. Clone this repository to `~/podman-dev-stacks`
3. Make all scripts executable
4. Add scripts to your `PATH`
5. Pull all development images

### Install options

```bash
# Choose a custom install directory
curl -fsSL .../install.sh | bash -s -- --dir ~/.local/podman-dev-stacks

# Skip pulling images (do it later manually)
curl -fsSL .../install.sh | bash -s -- --no-pull

# Skip modifying PATH
curl -fsSL .../install.sh | bash -s -- --no-path

# Combine options
curl -fsSL .../install.sh | bash -s -- --dir ~/tools/podman-stacks --no-pull
```

### After install — reload your shell

```bash
source ~/.bashrc   # or ~/.zshrc
```

Then jump straight to [Quick Start](#quick-start).

---

## 📋 Table of Contents

- [Prerequisites](#prerequisites)
- [Repository Structure](#repository-structure)
- [Quick Start](#quick-start)
- [Scripts](#scripts)
  - [pull-images.sh](#pull-imagessh)
  - [new-project.sh](#new-projectsh)
  - [stack.sh](#stacksh)
- [Stacks](#stacks)
  - [web-api](#-web-api)
  - [microservices](#-microservices)
  - [devops](#%EF%B8%8F-devops)
  - [cloud-local](#%EF%B8%8F-cloud-local)
  - [data-ml](#-data--ml)
- [Runtimes](#runtimes)
- [Creating a New Project](#creating-a-new-project)
- [Managing Stacks](#managing-stacks)
- [Tips & Tricks](#tips--tricks)

---

## Prerequisites

Install Podman and Podman Compose for your OS:

```bash
# Ubuntu / Debian
sudo apt install podman podman-compose

# Fedora / RHEL
sudo dnf install podman podman-compose

# macOS
brew install podman podman-compose
podman machine init && podman machine start

# Verify
podman --version
podman compose version
```

---

## Repository Structure

```
podman-dev-stacks/
│
├── scripts/
│   ├── pull-images.sh      ← pull all (or selected) images
│   ├── new-project.sh      ← bootstrap a new project from a stack
│   └── stack.sh            ← start / stop / clean stacks
│
├── stacks/
│   ├── web-api/            ← Postgres + Redis + MailHog
│   ├── microservices/      ← Postgres + Kafka + Jaeger + Prometheus + Grafana
│   ├── devops/             ← Gitea + Jenkins + SonarQube + Portainer
│   ├── cloud-local/        ← LocalStack + MinIO
│   └── data-ml/            ← Jupyter + Postgres + MinIO
│
└── runtimes/
    ├── node/               ← Node.js LTS
    ├── python/             ← Python 3.13
    ├── rust/               ← Rust latest
    ├── go/                 ← Go 1.23
    └── java/               ← Java 21 (Temurin)
```

---

## Quick Start

### Option A — One-liner (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/podman-dev-stacks/main/install.sh | bash
source ~/.bashrc   # or ~/.zshrc
```

### Option B — Manual clone

```bash
git clone https://github.com/YOUR_USERNAME/podman-dev-stacks.git
cd podman-dev-stacks
chmod +x scripts/*.sh
./scripts/pull-images.sh
```

### Start a stack

```bash
stack.sh up web-api
```

### Bootstrap a new project

```bash
new-project.sh my-api web-api --node
cd my-api
podman compose up -d
```

---

## Scripts

### `pull-images.sh`

Pulls all development images into Podman. Already-present images are skipped.

```bash
# Pull everything
./scripts/pull-images.sh

# Pull only a specific category
./scripts/pull-images.sh databases
./scripts/pull-images.sh runtimes
./scripts/pull-images.sh devtools
```

**Available categories:**

| Category | What it pulls |
|---|---|
| `databases` | Postgres, MySQL, MariaDB, MongoDB, Redis, Elasticsearch, InfluxDB, Neo4j, CouchDB |
| `brokers` | RabbitMQ, Kafka, Zookeeper, NATS |
| `webservers` | NGINX, Caddy, Traefik, HAProxy |
| `devtools` | MailHog, MinIO, LocalStack, WireMock, Verdaccio |
| `observability` | Grafana, Prometheus, Jaeger, Zipkin, Loki, Kibana |
| `auth` | Keycloak, Dex, Vault |
| `testing` | Selenium Chrome, SonarQube |
| `cicd` | Jenkins, Gitea, Portainer |
| `runtimes` | Node.js, Python, Rust, Go, Java, PHP, Ruby, .NET |
| `all` | Everything above (default) |

---

### `new-project.sh`

Bootstraps a new project directory by copying a stack's `compose.yml` and
optionally merging in a language runtime.

```bash
./scripts/new-project.sh <project-name> <stack> [flags]
```

**Flags:**

| Flag | Runtime added |
|---|---|
| `--node` | Node.js LTS |
| `--python` | Python 3.13 slim |
| `--rust` | Rust latest |
| `--go` | Go 1.23 |
| `--java` | Java 21 Temurin |

**Examples:**

```bash
# Node.js API + Postgres + Redis + MailHog
./scripts/new-project.sh my-api web-api --node

# Python ML project + Jupyter + Postgres + MinIO
./scripts/new-project.sh ml-project data-ml --python

# Rust microservice + Kafka + Grafana + Jaeger
./scripts/new-project.sh payment-service microservices --rust

# Go app + LocalStack (AWS emulation)
./scripts/new-project.sh aws-app cloud-local --go

# Java app + full DevOps stack
./scripts/new-project.sh enterprise-app devops --java
```

Each generated project contains:
- `compose.yml` — ready to run
- `.env` — pre-filled environment variables (edit before committing!)
- `.gitignore` — sensible defaults
- `Dockerfile.<runtime>` — if a runtime was selected

---

### `update-images.sh`

Checks every locally installed dev image against its remote registry and pulls updates where available. Skips images not yet installed (run `pull-images.sh` first for those).

```bash
# Update all images
update-images.sh

# Update only a category
update-images.sh runtimes
update-images.sh databases

# Dry run — see what is outdated without pulling anything
update-images.sh --check

# Update and clean up old dangling layers afterwards
update-images.sh --prune

# Save an update report to a file
update-images.sh --log ~/update-report.txt

# List all locally present dev images with size and date
update-images.sh --list
```

**How digest comparison works:**

If `skopeo` is installed, the script compares local vs remote image digests without downloading anything first — only images that actually changed get pulled. Without `skopeo`, it pulls each image and detects changes from Podmans output.

Install `skopeo` for faster, bandwidth-efficient updates:
```bash
# Ubuntu/Debian
sudo apt install skopeo

# Fedora/RHEL
sudo dnf install skopeo

# macOS
brew install skopeo
```

**All options:**

| Option | Description |
|---|---|
| `--check` | Dry run — report what would update, pull nothing |
| `--prune` | Remove dangling image layers after updating |
| `--list` | Show all locally installed dev images with size and date |
| `--log FILE` | Write a summary report to a file |

---


### `stack.sh`

Controls stacks without navigating into directories.

```bash
./scripts/stack.sh <command> [stack]
```

| Command | Description |
|---|---|
| `up [stack]` | Start a stack (or all stacks) |
| `down [stack]` | Stop a stack, data preserved |
| `clean [stack]` | Stop + wipe all volumes (asks for confirmation) |
| `ps` | Show all running containers across all stacks |
| `logs <stack>` | Follow logs for a stack |

**Examples:**

```bash
# Start the web-api stack
./scripts/stack.sh up web-api

# Stop it
./scripts/stack.sh down web-api

# See what's running
./scripts/stack.sh ps

# Wipe everything and start fresh
./scripts/stack.sh clean web-api

# Follow microservices logs
./scripts/stack.sh logs microservices
```

---

## Stacks

### 🌐 web-api

Best for: REST APIs, web backends, full-stack apps.

| Service | Port | Credentials |
|---|---|---|
| PostgreSQL | `5432` | user: `dev` / pass: `devpass` / db: `mydb` |
| Redis | `6379` | — |
| MailHog (SMTP) | `1025` | — |
| MailHog (UI) | `8025` | http://localhost:8025 |

```bash
cd stacks/web-api && podman compose up -d
```

---

### 🔬 microservices

Best for: event-driven systems, service meshes, distributed tracing.

| Service | Port | Credentials |
|---|---|---|
| PostgreSQL | `5432` | user: `dev` / pass: `devpass` |
| Kafka | `9092` | — |
| Jaeger UI | `16686` | http://localhost:16686 |
| Prometheus | `9090` | http://localhost:9090 |
| Grafana | `3000` | http://localhost:3000 (admin / admin) |

```bash
cd stacks/microservices && podman compose up -d
```

To add your service as a Prometheus scrape target, edit `stacks/microservices/prometheus.yml`.

---

### 🛠️ devops

Best for: self-hosted CI/CD, code quality, container management.

| Service | Port | Credentials |
|---|---|---|
| Gitea | `3000` | http://localhost:3000 (set up on first visit) |
| Jenkins | `8080` | http://localhost:8080 (see logs for initial password) |
| SonarQube | `9000` | http://localhost:9000 (admin / admin) |
| Portainer | `9443` | https://localhost:9443 (set up on first visit) |

```bash
cd stacks/devops && podman compose up -d

# Get Jenkins initial admin password
podman logs devops-jenkins 2>&1 | grep -A 3 "Please use the following password"
```

---

### ☁️ cloud-local

Best for: AWS-compatible development without cloud costs.

| Service | Port | Credentials |
|---|---|---|
| LocalStack | `4566` | — |
| MinIO API (S3) | `9000` | — |
| MinIO UI | `9001` | http://localhost:9001 (minioadmin / minioadmin) |

```bash
cd stacks/cloud-local && podman compose up -d

# Use AWS CLI pointed at LocalStack
export AWS_DEFAULT_REGION=us-east-1
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
aws --endpoint-url=http://localhost:4566 s3 mb s3://my-bucket
aws --endpoint-url=http://localhost:4566 s3 ls
aws --endpoint-url=http://localhost:4566 dynamodb list-tables
```

To enable additional AWS services, edit the `SERVICES` variable in the compose file:
```yaml
SERVICES: s3,sqs,sns,lambda,dynamodb,secretsmanager,iam,cloudwatch
```

---

### 🧬 Data / ML

Best for: data science, machine learning, data pipelines.

| Service | Port | Credentials |
|---|---|---|
| JupyterLab | `8888` | http://localhost:8888?token=devtoken |
| PostgreSQL | `5432` | user: `dev` / pass: `devpass` / db: `datasets` |
| MinIO UI | `9001` | http://localhost:9001 (minioadmin / minioadmin) |

```bash
cd stacks/data-ml && podman compose up -d
```

Notebooks saved inside the container are mirrored to your current directory automatically.

---

## Runtimes

Each runtime in `runtimes/` provides:
- `Dockerfile` — production-ready multi-stage build
- `compose-service.yml` — service snippet (merged into project compose by `new-project.sh`)

| Runtime | Image | Key volumes cached |
|---|---|---|
| Node.js | `node:lts` | `node_modules` |
| Python | `python:3.13-slim` | `pip-cache` |
| Rust | `rust:latest` | `cargo-registry`, `cargo-git`, `target` |
| Go | `golang:1.23` | `go-cache`, `go-modules` |
| Java | `eclipse-temurin:21` | `maven-cache` |

Use them standalone:

```bash
# Node.js REPL
podman run --rm -it docker.io/node:lts node

# Python script
podman run --rm -v $(pwd):/app:Z -w /app docker.io/python:3.13 python main.py

# Rust build
podman run --rm -v $(pwd):/app:Z -w /app docker.io/rust:latest cargo build

# Go run
podman run --rm -v $(pwd):/app:Z -w /app docker.io/golang:1.23 go run main.go

# Java run
podman run --rm -v $(pwd):/app:Z -w /app docker.io/eclipse-temurin:21 java Main.java
```

---

## Creating a New Project

Full walkthrough example — a Node.js API with Postgres, Redis, and MailHog:

```bash
# 1. Bootstrap
./scripts/new-project.sh my-api web-api --node

# 2. Enter project
cd my-api

# 3. Review and edit .env
cat .env
# Edit credentials, ports, etc. as needed

# 4. Start services
podman compose up -d

# 5. Check everything is running
podman compose ps

# 6. Install Node dependencies
podman compose run --rm app npm install

# 7. Start your app
podman compose up

# 8. When done for the day — stop (data preserved)
podman compose down

# 9. Resume tomorrow
podman compose up -d
```

---

## Managing Stacks

### Running multiple stacks simultaneously

Each stack uses its own named volumes and container names — they won't conflict.
The only thing to keep unique is **host ports** if running stacks at the same time.

```bash
# Run web-api and data-ml at the same time — no conflict
./scripts/stack.sh up web-api
./scripts/stack.sh up data-ml

./scripts/stack.sh ps
```

### Customising ports

Override ports via `.env` in your project directory:

```bash
# .env
POSTGRES_PORT=5433
APP_PORT=4000
```

### Data persistence

Volumes are stored in `~/.local/share/containers/storage/volumes/` — fully isolated
from your system. To inspect:

```bash
podman volume ls
podman volume inspect <volume-name>
```

---

## Tips & Tricks

**Alias `podman compose` as `dc` for speed:**
```bash
echo "alias dc='podman compose'" >> ~/.bashrc && source ~/.bashrc
dc up -d
dc logs -f
dc down
```

**See all running containers across all projects:**
```bash
podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

**Stop everything at once:**
```bash
podman stop $(podman ps -q)
```

**Free up space (remove unused images and volumes):**
```bash
podman system prune --volumes
```

**Pin image versions in production** — never use `:latest` for real deployments:
```yaml
image: docker.io/postgres:16.2   # ✅ pinned
image: docker.io/postgres:latest  # ⚠️ avoid
```

**Check image sizes:**
```bash
podman images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
```

---

## License

MIT — use freely, modify, share.

---

## Publishing to GitHub

To make your one-liner work, push this repo to GitHub and update the URLs.

### 1. Create the repository

```bash
# On GitHub: create a new public repo called "podman-dev-stacks"
# Then locally:

cd ~/podman-dev-stacks
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/podman-dev-stacks.git
git push -u origin main
```

### 2. Replace YOUR_USERNAME

In `install.sh`, update these two lines with your actual GitHub username:

```bash
REPO_URL="https://github.com/YOUR_USERNAME/podman-dev-stacks.git"
RAW_URL="https://raw.githubusercontent.com/YOUR_USERNAME/podman-dev-stacks/main"
```

Also update the one-liner URL in `README.md`.

Then commit and push:

```bash
git add install.sh README.md
git commit -m "Set GitHub username"
git push
```

### 3. Your one-liner is live

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/podman-dev-stacks/main/install.sh | bash
```

Share this URL — anyone with Podman installed can run it and have the full toolkit in seconds.

---

## Keeping Images Up to Date

Run the updater periodically to stay current:

```bash
# Quick update check (no downloading)
update-images.sh --check

# Apply all updates
update-images.sh

# Update and clean old layers
update-images.sh --prune

# Update only runtimes (most frequently changing)
update-images.sh runtimes
```

You can also add it to a cron job for automatic weekly updates:

```bash
# Edit crontab
crontab -e

# Add — runs every Sunday at 02:00, logs to file
0 2 * * 0 /path/to/podman-dev-stacks/scripts/update-images.sh --prune --log ~/podman-update.log
```
# podman-dev-stacks
# podman-dev-stacks
