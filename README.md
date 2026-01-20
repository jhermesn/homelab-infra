# Personal Homelab Infrastructure

Microservices and observability infrastructure based on Docker, focused on security, comprehensive monitoring, and ease of management to facilitate local testing of my services.

---
# Architecture

## Diagram
![Architecture Diagram](./Homelab.png)

## Services (Base Infrastructure)

| Service | Internal Host | Default Port | Function |
|---------|--------------|--------------|--------|
| **Nginx Proxy Manager** | `homelab-npm` | `8090` (HTTP) / `4443` (HTTPS) | Gateway & SSL |
| **Cloudflare Tunnel** | `homelab-tunnel` | N/A (Outbound) | Secure Remote Access |
| **MySQL 8** | `homelab-mysql` | `3306` | Relational Database |
| **Adminer** | `homelab-adminer` | `8080` | Database Management |
| **Redis** | `homelab-redis` | `6379` | Cache & Messaging |
| **Redis Insight** | `homelab-redis-insight` | `5540` | Redis GUI |
| **Grafana** | `homelab-grafana` | `3000` | Data Visualization |
| **Loki** | `homelab-loki` | `3100` | Log Aggregation |
| **Promtail** | `homelab-promtail` | N/A (Internal) | Log Shipping |
| **Tempo** | `homelab-tempo` | `3200` | Distributed Tracing (Traces) |
| **Prometheus** | `homelab-prometheus` | `9090` | Metrics Collection |
| **Mimir** | `homelab-mimir` | `9009` | Long-term Metrics Storage |
| **Uptime Kuma** | `homelab-uptime-kuma` | `3001` | Status Page & Monitoring |
| **OTEL Collector** | `homelab-otel-collector` | `4317` (gRPC) / `4318` (HTTP) | Telemetry Ingestion |
| **Node Exporter** | `homelab-node-exporter` | `9100` | Host Metrics |
| **Dockge** | `homelab-dockge` | `5001` | Docker Web Management |
| **Backup (Rclone)** | *Sidecar* | N/A | Automatic Off-site Backup |

---

# Setup

### 1. Prerequisites
- Docker and Docker Compose installed.
- Git.

### 2. Installation
```bash
git clone https://github.com/jhermesn/homelab-infra .

cp .env.example .env
nano .env # Setup your variables

# 3. (Optional) Setup Rclone for backup
# If you skip this, the backup service will fail but the infra will start.
# See the "Backup" section below.
```

### 3. Start Infrastructure
Use the deploy script to start the core infrastructure:
```bash
./deploy.sh infra start
```
Wait till you see the message: "[SUCCESS] Infrastructure started!".

---

## Backup Configuration (SharePoint)

The `backup-logs` service uses **Rclone** to send old logs and traces to the cloud. Interactive setup is only needed the first time.

---

## Adding New Services

1. Copy the template:
    ```bash
    cp -r services/_template services/my-new-app
    ```
2. Edit the `docker-compose.yaml` (ensure the `homelab` network is configured).
3. Start with the script:
    ```bash
    ./deploy.sh service my-new-app
    ```

---

## Useful Commands (Deploy Script)

The `./deploy.sh` script manages everything:

- `./deploy.sh infra start` -> Starts/Restarts the base infrastructure.
- `./deploy.sh infra stop` -> Stops the base infrastructure.
- `./deploy.sh service <name>` -> Starts a specific service (e.g., `demo-crud`).
- `./deploy.sh all` -> Starts EVERYTHING.
- `./deploy.sh status` -> Shows a summary of running containers.
- `./deploy.sh logs <container>` -> Shortcut to view logs.
---

## Updates / Maintenance

Since automatic deployment via CI/CD is not in use, to update the infrastructure (new versions of Docker Compose, `.env`, or scripts), manually execute on the server:

```bash
# 1. Update repository
git pull origin main

# 2. Update Docker images
docker compose pull

# 3. Restart infrastructure (recreates containers if necessary)
./deploy.sh infra
```

---

## Observability

The stack comes pre-configured. To instrument your application (Node.js/Go/Python):

- **Logs:** Just log to stdout (console.log). Promtail collects automatically.
- **Metrics/Traces:** Send to `homelab-otel-collector:4317` (gRPC) or `:4318` (HTTP).

Access `http://localhost:3000` (Grafana) to visualize.