# ContestGrid — Developer's Guide

> Last updated: 2026-03-08

A hands-on guide for building, deploying, and debugging ContestGrid services on your local Rancher Desktop cluster.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Service Inventory](#service-inventory)
3. [Prerequisites](#prerequisites)
4. [Frontend Development](#frontend-development)
5. [Building Container Images](#building-container-images)
6. [Deploying to Rancher Desktop](#deploying-to-rancher-desktop)
7. [Full Build → Deploy Workflow](#full-build--deploy-workflow)
8. [Verifying Deployments](#verifying-deployments)
9. [Kubernetes Manifests](#kubernetes-manifests)
10. [Networking & Istio Routing](#networking--istio-routing)
11. [Configuration & Secrets](#configuration--secrets)
12. [Troubleshooting](#troubleshooting)
13. [Quick-Reference Commands](#quick-reference-commands)

---

## Architecture Overview

```
Browser / Vite Dev Server
        │
        ▼
  Istio Ingress Gateway  (TLS termination — api.contestgrid.local:8443)
        │
   ┌────┴────────────────────────────────────────────┐
   │  /api/*  →  contestgrid-bff (port 3000)         │
   │  /v1/*   →  system & proc services              │
   └────┬────────────────────────────────────────────┘
        │
   ┌────┴──────────────────────────────┐
   │  BFF fans out to:                 │
   │   ├─ contestgrid-core-sys  :3001  │
   │   ├─ contestgrid-officials-sys :3002 │
   │   ├─ contestgrid-billing-sys :3003│
   │   ├─ contestgrid-scheduling-proc :3004 │
   │   └─ contestgrid-billing-proc :3005│
   └───────────────────────────────────┘
        │
   PostgreSQL (192.168.68.50:5432 / contest_lab)
```

All services are Node.js / Express / TypeScript. Images run in the `contestgrid` Kubernetes namespace with Istio sidecar injection.

---

## Service Inventory

| Service | Directory | Port | Health Endpoint | Image Name |
|---------|-----------|------|-----------------|------------|
| BFF | `contestgrid-bff/` | 3000 | `/api/health` | `contestgrid-bff:latest` |
| Core API | `contestgrid-core-sys/` | 3001 | `/v1/health` | `contestgrid-core-sys:latest` |
| Officials API | `contestgrid-officials-sys/` | 3002 | `/v1/health` | `contestgrid-officials-sys:latest` |
| Billing API | `contestgrid-billing-sys/` | 3003 | `/v1/health` | `contestgrid-billing-sys:latest` |
| Scheduling Proc | `contestgrid-scheduling-proc/` | 3004 | `/v1/health` | `contestgrid-scheduling-proc:latest` |
| Billing Proc | `contestgrid-billing-proc/` | 3005 | `/v1/health` | `contestgrid-billing-proc:latest` |
| Frontend | `contestgrid-fe/` | 5173 (dev) | — | — (no container yet) |

---

## Prerequisites

- **Rancher Desktop** running with containerd and Kubernetes 1.28+
- **nerdctl** (ships with Rancher Desktop) — used instead of `docker` to build images
- **kubectl** configured for the local cluster
- **Istio** installed in the cluster (`istio-system` namespace)
- **Node.js 20+** and npm for local builds
- DNS: `api.contestgrid.local` resolving to `127.0.0.1` (via `/etc/hosts` or stub DNS)

See [LOCAL-DEVELOPMENT-SETUP.md](LOCAL-DEVELOPMENT-SETUP.md) for full environment bootstrap instructions.

---

## Database Changes

> **All database schema changes MUST go through Flyway migrations. No manual DDL via psql or other tools.**

Flyway migration files live in `flyway/db/migrations/` and follow the naming convention `V###__description.sql`.

### Running migrations

```bash
cd flyway
export CONTEST_LAB_DB_PASSWORD='<password>'
flyway -configFiles=conf/flyway-contest-lab.conf migrate
```

### Rules

1. **Never** run `ALTER TABLE`, `CREATE TABLE`, `DROP`, or other DDL directly against the database.
2. Every schema change gets a new versioned migration file (e.g., `V018__add_foo_column.sql`).
3. Write idempotent migrations when possible (use `IF NOT EXISTS`, `DO $$ ... $$` blocks).
4. Seed/test data goes in `flyway/db/seeds/` (run manually, not via Flyway).
5. After writing a migration, run `flyway info` to verify it appears as **Pending**, then `flyway migrate` to apply.

---

## Frontend Development

The frontend uses Vite with a dev proxy — you do **not** need to containerize or deploy it to Rancher to develop UI features.

### Start the dev server

```bash
cd contestgrid-fe
npm install    # first time only
npm run dev
```

This starts Vite on `http://localhost:5173` with hot module replacement (HMR). The proxy in `vite.config.ts` forwards `/api/*` requests to the BFF running in Rancher:

```typescript
server: {
  proxy: {
    '/api': {
      target: 'https://api.contestgrid.local:8443',
      changeOrigin: true,
      secure: false,   // accept self-signed cert
    }
  }
}
```

**Use this for:** Layout, styling, component logic, form behavior, navigation — anything that doesn't require the FE to run inside the cluster.

### Production build (for validation)

```bash
npm run build      # outputs to dist/
npm run preview    # serves dist/ locally for a quick check
```

---

## Building Container Images

All services use multi-stage Dockerfiles (Node 20 Alpine):

1. **Builder stage** — `npm ci` → copy source → TypeScript compile (`tsc`)
2. **Runtime stage** — `npm ci --omit=dev` → copy `dist/` → `CMD ["node", "dist/index.js"]`

### Build a single service

```bash
cd ~/projects/contestgrid/<service-dir>
nerdctl build -t <image-name>:latest .
```

### Concrete examples

```bash
# BFF
cd ~/projects/contestgrid/contestgrid-bff
nerdctl build -t contestgrid-bff:latest .

# Core API
cd ~/projects/contestgrid/contestgrid-core-sys
nerdctl build -t contestgrid-core-sys:latest .

# Officials API
cd ~/projects/contestgrid/contestgrid-officials-sys
nerdctl build -t contestgrid-officials-sys:latest .
```

### Why nerdctl and not docker?

Rancher Desktop uses **containerd** as its container runtime. `nerdctl` writes images directly into containerd's image store, which is the same store Kubernetes pulls from. This is why all deployments use `imagePullPolicy: Never` — no registry push is needed.

> **Note:** If you use `docker build` instead, the image may end up in Docker's daemon store and not be visible to K8s. Stick with `nerdctl`.

### Build all services at once

```bash
cd ~/projects/contestgrid
for svc in contestgrid-core-sys contestgrid-officials-sys contestgrid-billing-sys \
           contestgrid-scheduling-proc contestgrid-billing-proc contestgrid-bff; do
  echo "=== Building $svc ==="
  (cd "$svc" && nerdctl build -t "$svc:latest" .)
done
```

---

## Deploying to Rancher Desktop

### First-time deploy (one-time setup per service)

Apply all K8s manifests in the service's `k8s/` folder:

```bash
cd ~/projects/contestgrid/contestgrid-bff
kubectl apply -f k8s/
```

This creates the ConfigMap, Secret (if any), Deployment, Service, and VirtualService.

### Subsequent deploys (after code changes)

After rebuilding the image, restart the deployment to pick up the new image:

```bash
kubectl rollout restart deployment/<service-name> -n contestgrid
kubectl rollout status deployment/<service-name> -n contestgrid
```

The `rollout restart` creates new pods that pull the `:latest` image (from local containerd), while the old pods drain gracefully.

---

## Full Build → Deploy Workflow

Here is the end-to-end cycle for deploying a code change:

```bash
# 1. Make your code changes
#    (edit files in contestgrid-bff/src/...)

# 2. Build locally to catch TypeScript errors
cd ~/projects/contestgrid/contestgrid-bff
npm run build

# 3. Build the container image
nerdctl build -t contestgrid-bff:latest .

# 4. Roll out the new image
kubectl rollout restart deployment/contestgrid-bff -n contestgrid

# 5. Wait for it to be healthy
kubectl rollout status deployment/contestgrid-bff -n contestgrid

# 6. Verify
curl -sk https://api.contestgrid.local:8443/api/health
```

### Quick one-liner per service

```bash
# BFF
cd ~/projects/contestgrid/contestgrid-bff && \
  nerdctl build -t contestgrid-bff:latest . && \
  kubectl rollout restart deployment/contestgrid-bff -n contestgrid && \
  kubectl rollout status deployment/contestgrid-bff -n contestgrid

# Core API
cd ~/projects/contestgrid/contestgrid-core-sys && \
  nerdctl build -t contestgrid-core-sys:latest . && \
  kubectl rollout restart deployment/contestgrid-core-sys -n contestgrid && \
  kubectl rollout status deployment/contestgrid-core-sys -n contestgrid

# Officials API
cd ~/projects/contestgrid/contestgrid-officials-sys && \
  nerdctl build -t contestgrid-officials-sys:latest . && \
  kubectl rollout restart deployment/contestgrid-officials-sys -n contestgrid && \
  kubectl rollout status deployment/contestgrid-officials-sys -n contestgrid

# Billing API
cd ~/projects/contestgrid/contestgrid-billing-sys && \
  nerdctl build -t contestgrid-billing-sys:latest . && \
  kubectl rollout restart deployment/contestgrid-billing-sys -n contestgrid && \
  kubectl rollout status deployment/contestgrid-billing-sys -n contestgrid

# Scheduling Proc
cd ~/projects/contestgrid/contestgrid-scheduling-proc && \
  nerdctl build -t contestgrid-scheduling-proc:latest . && \
  kubectl rollout restart deployment/contestgrid-scheduling-proc -n contestgrid && \
  kubectl rollout status deployment/contestgrid-scheduling-proc -n contestgrid

# Billing Proc
cd ~/projects/contestgrid/contestgrid-billing-proc && \
  nerdctl build -t contestgrid-billing-proc:latest . && \
  kubectl rollout restart deployment/contestgrid-billing-proc -n contestgrid && \
  kubectl rollout status deployment/contestgrid-billing-proc -n contestgrid
```

---

## Verifying Deployments

### Check pod status

```bash
kubectl get pods -n contestgrid
```

All pods should show `2/2 READY` (app container + Istio sidecar) with status `Running`.

### Check a specific deployment

```bash
kubectl describe deployment contestgrid-bff -n contestgrid
```

### Hit health endpoints

```bash
# BFF (via Istio ingress)
curl -sk https://api.contestgrid.local:8443/api/health

# Core API (via port-forward — not exposed externally)
kubectl port-forward svc/contestgrid-core-sys -n contestgrid 3001:80 &
curl http://localhost:3001/v1/health
```

### View logs

```bash
# Tail logs for a service
kubectl logs -f deployment/contestgrid-bff -n contestgrid -c contestgrid-bff

# Last 50 lines
kubectl logs deployment/contestgrid-core-sys -n contestgrid -c contestgrid-core-sys --tail=50
```

### Check events (useful for crash loops)

```bash
kubectl get events -n contestgrid --sort-by='.lastTimestamp' | tail -20
```

---

## Kubernetes Manifests

Each service has a `k8s/` folder with these files:

| File | Purpose |
|------|---------|
| `configmap.yaml` | Environment config (DB host, service URLs, JWT secret) |
| `secret.yaml` | Sensitive values (DB password) — system APIs only |
| `deployment.yaml` | Pod spec, resource limits, health probes, env vars |
| `service.yaml` | ClusterIP service (maps port 80 → container port) |
| `virtualservice.yaml` | Istio routing rules (which URL prefixes → which service) |

### Manifest locations

```
contestgrid-core-sys/k8s/
  ├── configmap.yaml       # DB config, JWT secret
  ├── secret.yaml          # DB password
  ├── deployment.yaml      # 2 replicas, port 3001
  └── service.yaml         # ClusterIP :80 → :3001

contestgrid-bff/k8s/
  ├── configmap.yaml       # Downstream service URLs, CORS, JWT
  ├── deployment.yaml      # 2 replicas, port 3000
  ├── service.yaml         # ClusterIP :80 → :3000
  └── virtualservice.yaml  # /api/* → bff

contestgrid-fe/k8s/
  └── ingress/
      ├── contestgrid-gateway-tls.yaml      # Istio Gateway (TLS)
      └── contestgrid-virtualservice.yaml   # Core-sys catch-all route
```

---

## Networking & Istio Routing

### Istio Gateway

Defined in `contestgrid-fe/k8s/ingress/contestgrid-gateway-tls.yaml`:

- **Hosts:** `api.contestgrid.local`, `api.contestgrid.com`
- **Port 80:** HTTP → HTTPS redirect
- **Port 443:** TLS SIMPLE mode, credential `contestgrid-tls-secret`

### VirtualService routing

| VirtualService | URI Prefix(es) | Destination Service |
|----------------|-----------------|---------------------|
| `contestgrid-bff` | `/api/` | `contestgrid-bff:80` |
| `contestgrid-officials-sys` | `/v1/officials`, `/v1/associations`, `/v1/bookings`, `/v1/assignments` | `contestgrid-officials-sys:80` |
| `contestgrid-billing-sys` | `/v1/billing/`, `/v1/billing-payments`, `/v1/rates`, `/v1/payments` | `contestgrid-billing-sys:80` |
| `contestgrid-scheduling-proc` | `/v1/scheduling`, `/v1/workflows/contests`, `/v1/workflows/assignments` | `contestgrid-scheduling-proc:80` |
| `contestgrid-billing-proc` | `/v1/billing-proc`, `/v1/workflows/payments`, `/v1/workflows/payroll` | `contestgrid-billing-proc:80` |
| `contestgrid-core-sys` | catch-all (no prefix match) | `contestgrid-core-sys:80` |

### Inter-service communication

Services within the cluster communicate over plain HTTP using K8s DNS:

```
http://contestgrid-core-sys         → core API (port 80 → 3001)
http://contestgrid-officials-sys    → officials API (port 80 → 3002)
http://contestgrid-billing-sys      → billing API (port 80 → 3003)
```

These URLs are configured in the BFF's ConfigMap (`bff-config`).

---

## Configuration & Secrets

### System APIs (core, officials, billing)

Environment variables from ConfigMap + Secret:

| Env Var | Source | Example Value |
|---------|--------|---------------|
| `DB_HOST` | ConfigMap `core-api-config` | `192.168.68.50` |
| `DB_PORT` | ConfigMap | `5432` |
| `DB_NAME` | ConfigMap | `contest_lab` |
| `DB_USER` | ConfigMap | `contestgrid_lab_id` |
| `DB_SCHEMA` | ConfigMap | `app` |
| `DB_PASSWORD` | Secret `core-api-secrets` | *(redacted)* |
| `DB_SSL_MODE` | Deployment YAML (hardcoded) | `require` |
| `JWT_SECRET` | ConfigMap | `contestgrid-local-dev-secret-do-not-use-in-prod` |
| `CORS_ORIGIN` | Deployment YAML | `https://api.contestgrid.local,...` |

### BFF

| Env Var | Source | Example Value |
|---------|--------|---------------|
| `CORE_SYS_URL` | ConfigMap `bff-config` | `http://contestgrid-core-sys` |
| `OFFICIALS_SYS_URL` | ConfigMap | `http://contestgrid-officials-sys` |
| `BILLING_SYS_URL` | ConfigMap | `http://contestgrid-billing-sys` |
| `SCHEDULING_PROC_URL` | ConfigMap | `http://contestgrid-scheduling-proc` |
| `BILLING_PROC_URL` | ConfigMap | `http://contestgrid-billing-proc` |
| `CORS_ORIGIN` | ConfigMap | `https://app.contestgrid.local:8443,http://localhost:5173` |
| `JWT_SECRET` | ConfigMap | `contestgrid-local-dev-secret-do-not-use-in-prod` |
| `CACHE_TTL_SECONDS` | Deployment YAML | `300` |
| `CACHE_MAX_KEYS` | Deployment YAML | `1000` |

### Updating config

```bash
# Edit the configmap
kubectl edit configmap bff-config -n contestgrid

# Restart pods to pick up changes
kubectl rollout restart deployment/contestgrid-bff -n contestgrid
```

Or edit the YAML file and re-apply:

```bash
kubectl apply -f k8s/configmap.yaml
kubectl rollout restart deployment/contestgrid-bff -n contestgrid
```

---

## Troubleshooting

### Image not updating after build

Make sure you're using `nerdctl` (not `docker`):
```bash
nerdctl build -t contestgrid-bff:latest .
```

Verify the image exists in containerd:
```bash
nerdctl images | grep contestgrid-bff
```

### Pod stuck in CrashLoopBackOff

```bash
# Check logs for the crash reason
kubectl logs deployment/contestgrid-bff -n contestgrid -c contestgrid-bff --previous

# Check events
kubectl describe pod -l app=contestgrid-bff -n contestgrid
```

Common causes:
- Missing environment variables (ConfigMap/Secret not applied)
- Database unreachable (check `DB_HOST` is accessible from the cluster)
- Port conflict (another process on the same port)

### Port-forward keeps dying

```bash
# Check if port-forward is running
ps aux | grep port-forward | grep -v grep

# Kill stale processes and restart
pkill -f "port-forward"
kubectl port-forward -n istio-system svc/istio-ingressgateway 8080:80 8443:443 &
```

### VirtualService not routing correctly

```bash
# Verify VirtualService exists
kubectl get virtualservice -n contestgrid

# Check Istio proxy config
kubectl exec -it deployment/contestgrid-bff -n contestgrid -c istio-proxy -- pilot-agent request GET config_dump | grep -A5 "route_config"
```

### DNS not resolving api.contestgrid.local

Ensure your `/etc/hosts` file has:
```
127.0.0.1  api.contestgrid.local
127.0.0.1  app.contestgrid.local
```

---

## Quick-Reference Commands

### Build & deploy (one service)

```bash
cd <service-dir>
nerdctl build -t <service-name>:latest .
kubectl rollout restart deployment/<service-name> -n contestgrid
kubectl rollout status deployment/<service-name> -n contestgrid
```

### Status checks

```bash
kubectl get pods -n contestgrid                        # All pods
kubectl get svc -n contestgrid                         # All services
kubectl get vs -n contestgrid                          # All VirtualServices
kubectl top pods -n contestgrid                        # Resource usage
```

### Logs

```bash
kubectl logs -f deploy/<name> -n contestgrid -c <name> # Follow logs
kubectl logs deploy/<name> -n contestgrid --tail=100   # Last 100 lines
```

### Port-forward for direct access

```bash
# Istio ingress (external-facing)
kubectl port-forward -n istio-system svc/istio-ingressgateway 8080:80 8443:443

# Direct to a service (bypass Istio)
kubectl port-forward svc/contestgrid-core-sys -n contestgrid 3001:80
```

### Restart everything

```bash
kubectl rollout restart deployment -n contestgrid
```

### Nuclear option (re-apply all manifests)

```bash
cd ~/projects/contestgrid
for svc in contestgrid-core-sys contestgrid-officials-sys contestgrid-billing-sys \
           contestgrid-scheduling-proc contestgrid-billing-proc contestgrid-bff; do
  kubectl apply -f "$svc/k8s/"
done
kubectl apply -f contestgrid-fe/k8s/ingress/
```
