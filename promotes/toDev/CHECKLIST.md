# Promote to Dev — Checklist

## Overview
Steps required to set up a fresh Dev environment from scratch.

## Prerequisites
- PostgreSQL instance accessible from the cluster
- Kubernetes cluster (EKS or local K3s) with Istio, cert-manager, and MetalLB (if local)
- Container registry access (ECR for AWS, or local `nerdctl` for K3s)
- Flyway migrations applied up to the current version

## 1. Database — Flyway Migrations
Run all Flyway migrations to create the schema:
```bash
cd contestgrid-flyway
flyway -configFiles=flyway-dev.toml migrate
```

## 2. Database — Reference/Seed Data
After migrations, the following lookup tables must be populated.
Run `seed-data.sql` in this folder against the target database.

### Global (no tenant_id / shared across tenants)
| Table | Rows | Notes |
|-------|------|-------|
| `phone_type` | 3 | Mobile, Home, Work (with aliases) |
| `platform_role_type` | 5 | platform_admin, officials_admin, etc. |

### Per-Tenant Lookup Data
These tables have a `tenant_id` column — each tenant needs its own rows:

| Table | Rows | Notes |
|-------|------|-------|
| `tenant_type` | 2 | Officials Association, Sports League |
| `tenant` | 1+ | At least one tenant |
| `person_type` | 3 | Payer, Contact, Official |
| `assignment_status` | 5 | Pending, Confirmed, Declined, Cancelled, Completed |
| `contest_status` | 5 | Normal, Cancelled, Rainout, Forfeit, Suspended |
| `contest_type` | 5 | Regular Season, Playoff, Tournament, Pre-Season, Scrimmage |
| `membership_status` | 3 | Active, Inactive, Suspended |
| `roles` | 6 | Primary Assigner Admin, Secondary Assigner Admin, League Director, Coach, Official, Tenant Admin |
| `pay_classification` | 1+ | At least "Standard" (rate_multiplier = 1.0) |
| `invoice_status` | 8 | Draft, Sent, Paid, Past Due, Void, Partially Paid, Refunded, Partially Refunded |
| `invoice_payment_type` | 3 | Charge, Full Refund, Partial Refund |
| `notification_status` | 4 | Queued, Sent, Failed, Bounced |
| `notification_type` | 5 | Payment Due Reminder, Payment Past Due, Payment Received, Subscription Renewed, Subscription Cancelled |
| `payment_status` | 6 | Pending, Processing, Completed, Failed, Refunded, Cancelled |
| `payment_type` | 2 | Contest Bill, Official Payout |
| `sport` | 3 | Baseball, Softball, Basketball |
| `officials_association` | 1+ | Needs an address_id (create address first) |

### Per-Tenant Operational Setup (after seed data)
These are set up by tenant admins but needed for initial testing:

| Table | Notes |
|-------|-------|
| `officials_association` | At least one per tenant (required for official import) |
| `contest_season` | At least one season to create contests |
| `contest_league` | Leagues for the tenant |
| `contest_level` | Levels within leagues |
| `venue` / `venue_sub` | Venues and sub-venues |
| `team` | Teams for contest scheduling |
| `customer` / `customer_sport_map` | Customers linked to sports |
| `contest_rates` | Rate definitions per league/level/sport/association |
| `entitlement` / `role_entitlement` | Feature entitlements per role |

## 3. Kubernetes — Namespace & Secrets
```bash
kubectl create namespace contestgrid
kubectl label namespace contestgrid istio-injection=enabled

# Create database secret
kubectl create secret generic contestgrid-db-credentials \
  -n contestgrid \
  --from-literal=DB_HOST=<host> \
  --from-literal=DB_PORT=5432 \
  --from-literal=DB_NAME=<dbname> \
  --from-literal=DB_USER=<user> \
  --from-literal=DB_PASSWORD=<password> \
  --from-literal=PII_ENCRYPTION_KEY=<key>

# Create JWT secret
kubectl create secret generic contestgrid-jwt-secret \
  -n contestgrid \
  --from-literal=JWT_SECRET=<secret>
```

## 4. Code — Merge Feature Branches to Main
Ensure all feature branches are merged before building:
```bash
# Frontend — merge initial-design branch to main
cd contestgrid-fe
git checkout main
git merge initial-design
git push origin main

# All other services should already be on main
```

## 5. Build & Deploy All Services
Apply K8s configs and build/deploy each service. For Rancher Desktop (local K3s):
```bash
# Apply K8s manifests for each service
for svc in contestgrid-core-sys contestgrid-officials-sys contestgrid-billing-sys \
           contestgrid-scheduling-proc contestgrid-billing-proc contestgrid-bff contestgrid-fe; do
  cd /path/to/$svc
  kubectl apply -f k8s/
done

# Build and deploy each service (uses nerdctl for local, docker for remote)
for svc in contestgrid-core-sys contestgrid-officials-sys contestgrid-billing-sys \
           contestgrid-scheduling-proc contestgrid-billing-proc contestgrid-bff contestgrid-fe; do
  cd /path/to/$svc
  ./build-and-deploy.sh
done
```

### Service Build Order & Ports
| Service | Container Port | K8s Service Port |
|---------|---------------|-----------------|
| `contestgrid-core-sys` | 3001 | 80 |
| `contestgrid-officials-sys` | 3002 | 80 |
| `contestgrid-billing-sys` | 3003 | 80 |
| `contestgrid-scheduling-proc` | 3004 | 80 |
| `contestgrid-billing-proc` | 3005 | 80 |
| `contestgrid-bff` | 3000 | 80 |
| `contestgrid-fe` | 8080 | 80 |

### Frontend-Specific Notes
- The FE container serves static assets via nginx on port 8080
- The nginx config proxies `/api/` requests to `contestgrid-bff.contestgrid.svc.cluster.local`
- For local development (without K8s): `npm run dev` on port 5173 with Vite proxy to `localhost:3000`
- For local access via K8s: `kubectl port-forward -n contestgrid svc/contestgrid-fe 8080:80`

## 6. Verify
- All pods running: `kubectl get pods -n contestgrid`
- Health checks passing: `kubectl logs -n contestgrid deployment/<svc> | grep "listening"`
- Istio sidecars injected: all pods show 2/2 READY
- Port-forward or ingress configured for BFF access

## Known Issues / Gotchas
- **RLS**: All queries require `set_config('app.tenant_id', ...)` — tables appear empty without it
- **`official_config`**: Columns `service_start_month` and `service_start_year` are NOT NULL — import service derives them from `association_joined_date`
- **`officials_association.address_id`**: NOT NULL — must create an address row first
- **`phone_type`**: Not tenant-scoped — shared globally
