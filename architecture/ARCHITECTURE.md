# ContestGrid — Multi-Tier Architecture

## Project Structure (Updated April 6, 2026)

```
/home/scott/projects/contestgrid/
├── contestgrid-fe/                    # Frontend (Vue 3 + Vuetify 4)
│   ├── Port: 5173 (Vite dev server)
│   └── Connects to: BFF (port 3000)
│
├── contestgrid-bff/                   # Backend for Frontend
│   ├── Port: 3000
│   ├── Auth: JWT validation (jose — HMAC mock + Cognito JWKS fallback)
│   ├── Caching: In-memory cache (node-cache)
│   ├── Aggregation: Combines downstream APIs
│   └── Calls: All System APIs + Proc APIs
│
├── PROC APIS (Business Workflows)
│   ├── contestgrid-scheduling-proc/   # Scheduling orchestration
│   │   ├── Port: 3004
│   │   ├── Workflows: Contest creation, official assignment
│   │   └── Calls: core-sys, officials-sys, billing-sys
│   │
│   └── contestgrid-billing-proc/      # Billing workflows
│       ├── Port: 3005
│       ├── Workflows: Payments, payroll, 1099 generation
│       ├── External: Stripe integration (mock)
│       └── Calls: core-sys, officials-sys, billing-sys
│
├── SYSTEM APIS (Data Ownership)
│   ├── contestgrid-core-sys/          # Core domain data
│   │   ├── Port: 3001
│   │   ├── Tables: tenant, person, contest_*, team, venue, address, sport, etc.
│   │   ├── RLS: Tenant isolation via app.tenant_id
│   │   └── Database: PostgreSQL 16
│   │
│   ├── contestgrid-officials-sys/     # Officials domain
│   │   ├── Port: 3002
│   │   ├── Tables: official, officials_association, official_config,
│   │   │          official_slots, official_contest_assignment, bookings, etc.
│   │   └── Database: Same PostgreSQL (shared schema)
│   │
│   └── contestgrid-billing-sys/       # Billing domain
│       ├── Port: 3003
│       ├── Tables: contest_rates, tenant_pay_rate_map, invoice, payments, etc.
│       └── Database: Same PostgreSQL (shared schema)
│
├── contestgrid-flyway/                # Flyway database migrations
│   └── V001–V064 (66 applied migrations)
│
└── contestgrid-documentation/         # Centralized documentation
    ├── architecture/                  # Architecture docs + this file
    │   └── adr/                       # 40 Architecture Decision Records
    ├── api/                           # 6 OpenAPI/Swagger specs
    ├── guides/                        # Implementation guides
    ├── database/                      # Schema & migration docs
    ├── project/                       # MVP scope, roadmap, summaries
    ├── security/                      # Security & API quickrefs
    ├── billing/                       # Billing model docs
    ├── flows/                         # Workflow documentation
    ├── services/                      # Per-service README copies
    └── requirements/                  # Requirements docs
```

## Request Flow

```
User Browser
    │
    ▼
Frontend (Vue 3 + Vuetify 4 @ :5173)
    │ HTTP + JWT token
    ▼
BFF @ :3000
    │ ├─ Auth: Extract tenant_id from JWT
    │ ├─ Cache: Check cache for data (node-cache)
    │ └─ Aggregate: Call multiple downstream APIs
    │
    ├─────────────┬─────────────┬─────────────┬─────────────┐
    ▼             ▼             ▼             ▼             ▼
Proc Sched    Proc Bill    Sys Core     Sys Officials  Sys Billing
  :3004         :3005         :3001          :3002         :3003
    │             │             │              │             │
    └─────────────┴─────────────┴──────────────┴─────────────┘
                                │
                                ▼
                      PostgreSQL 16 @ localhost:5432
                      (contest_lab database, schema: app)
                      - Row-Level Security (RLS) enabled
                      - app.tenant_id session variable
                      - 64 Flyway migrations applied (V001–V064)
```

## Technology Stack

| Layer | Tech Stack |
|-------|-----------|
| **Frontend** | Vue 3, TypeScript, Vuetify 4, Vite, Pinia, Vue Router |
| **BFF** | Node.js 18, Express, TypeScript, Zod, jose (JWT), node-cache |
| **Proc APIs** | Node.js 18, Express, TypeScript, Axios, Zod |
| **System APIs** | Node.js 18, Express, TypeScript, pg (PostgreSQL), Zod |
| **Database** | PostgreSQL 16, Flyway migrations, Row-Level Security |
| **Auth** | AWS Cognito (JWT tokens, RBAC) — mock HMAC in dev |
| **Infrastructure** | Rancher Desktop (k3s), Istio 1.20.8 service mesh, Docker |
| **Testing** | Vitest (unit/integration), Playwright (E2E), Restfox (API) |

## Multi-Tenancy Architecture

All System APIs enforce tenant isolation via PostgreSQL Row-Level Security:

```sql
-- Set tenant context per request
SET app.tenant_id = '1010';

-- RLS policy example
CREATE POLICY person_tenant_isolation ON person
  USING (tenant_id = current_setting('app.tenant_id')::BIGINT);
```

JWT token contains `custom:tenant_id` claim:
```json
{
  "sub": "user-uuid",
  "email": "admin@league.example.com",
  "custom:tenant_id": "1010",
  "cognito:groups": ["Admin"]
}
```

BFF extracts `tenant_id` and propagates to System APIs via `X-Tenant-ID` header.

## Database Schema (app schema — 77 tables)

Key table groups:

| Domain | Tables |
|--------|--------|
| **Core** | tenant, person, person_type, person_roles, roles, sport, team, venue, venue_sub, address, phone |
| **Contests** | contest_schedule, contest_status, contest_type, contest_league, contest_level, contest_season, contest_pack, contest_pack_member |
| **Officials** | official, officials_association, official_config, official_slots, official_contest_assignment, assignment_status, assignment_status_history, bookings |
| **Billing** | contest_rates, tenant_pay_rate_map, pay_classification, invoice, invoice_line_item, invoice_payment, payment, payment_status, payment_type |
| **Audit** | assignment_financial_audit, contest_billing_audit, contest_billing_split |
| **Subscriptions** | subscription_plan, subscription_tier, subscription_status, association_subscription, tenant_license |
| **Config** | tenant_config, billing_notification_config, self_assign_restriction, appearance_check, certification_type |

## Development Workflow

### Running All Services

All services run in Kubernetes (Rancher Desktop k3s) with Istio service mesh. Access via `kubectl port-forward`:

```bash
# BFF (main entry point for frontend)
kubectl -n contestgrid port-forward deployment/contestgrid-bff 3000:3000

# Frontend (Vite dev server — runs locally, not in k8s)
cd contestgrid-fe && npm run dev  # Port 5173

# Individual system APIs (for direct testing)
kubectl -n contestgrid port-forward deployment/contestgrid-core-sys 3001:3001
kubectl -n contestgrid port-forward deployment/contestgrid-officials-sys 3002:3002
kubectl -n contestgrid port-forward deployment/contestgrid-billing-sys 3003:3003
```

### Build & Deploy (per service)

```bash
cd contestgrid-<service>
./build-and-deploy.sh   # Docker build + kubectl rollout
```

### Database Migrations

```bash
cd contestgrid-flyway
# Flyway migrations in db/migrations/ (V001–V064)
# Applied via Flyway CLI against contest_lab database
```

### Testing

```bash
# Type-check frontend
cd contestgrid-fe && npx vue-tsc --noEmit

# Type-check backend service
cd contestgrid-bff && npx tsc --noEmit

# API testing via Restfox collections (173 requests across 6 collections)
```

## Repository Status

| Repository | GitHub | Branch | Description |
|-----------|--------|--------|-------------|
| contestgrid-fe | scottthurmond/contest-schedule-fe | initial-design | Vue 3 + Vuetify 4 frontend |
| contestgrid-bff | scottthurmond/contestgrid-bff | main | JWT auth + aggregation + caching + proxy |
| contestgrid-core-sys | scottthurmond/contestgrid-core-sys | main | 40+ endpoints, core domain CRUD |
| contestgrid-officials-sys | scottthurmond/contestgrid-officials-sys | main | Officials, associations, assignments |
| contestgrid-billing-sys | scottthurmond/contestgrid-billing-sys | main | Rates, invoices, payments |
| contestgrid-scheduling-proc | scottthurmond/contestgrid-scheduling-proc | main | Contest creation + auto-assign workflows |
| contestgrid-billing-proc | scottthurmond/contestgrid-billing-proc | main | Payment processing + payroll workflows |
| contestgrid-flyway | scottthurmond/contestgrid-flyway | main | V001–V064 database migrations |

## Per-Assignment Pay/Bill Overrides (V052)

### Schema Change
`official_contest_assignment` has four nullable override columns:
- `pay_multiplier_override` — NULL = use `contest_rates.pay_multiplier`
- `pay_flat_adjustment_override` — NULL = use `contest_rates.pay_flat_adjustment`
- `bill_multiplier_override` — NULL = use `contest_rates.bill_multiplier`
- `bill_flat_adjustment_override` — NULL = use `contest_rates.bill_flat_adjustment`

Pay and bill overrides are **fully independent**.

### Effective Rate Calculation
```
effective_pay_multiplier   = COALESCE(oca.pay_multiplier_override, cr.pay_multiplier)
effective_pay_adjustment   = COALESCE(oca.pay_flat_adjustment_override, cr.pay_flat_adjustment)
effective_bill_multiplier  = COALESCE(oca.bill_multiplier_override, cr.bill_multiplier)
effective_bill_adjustment  = COALESCE(oca.bill_flat_adjustment_override, cr.bill_flat_adjustment)

official_pay  = (cr.contest_umpire_rate * effective_pay_multiplier) + effective_pay_adjustment
official_bill = (cr.contest_bill_amount * effective_bill_multiplier) + effective_bill_adjustment
```

### TODO: Invoicing & Pay Sheet Integration

1. **Invoice generation (`billing-proc`):** JOIN `official_contest_assignment` with `contest_rates`, use COALESCE logic for per-official bill amounts, show per-official breakdowns when overrides exist.

2. **Pay sheet generation (`billing-proc`):** Same JOIN with pay columns. Flag assignments where overrides differ from rate card default.

3. **UI — Invoice review screen:** Show per-official bill breakdown with override indicator. Allow last-minute adjustment before finalizing.

4. **UI — Pay sheet review screen:** Show each official's effective pay with override indicator. Allow adjustment before payroll finalization. Consider "batch adjust" option.

5. **`pay_classification` integration (future):** `official_config.pay_classification_id` → `pay_classification.rate_modifier` as baseline tier multiplier. Calculation: `base × classification_modifier × assignment_override`.

---

### TODO: Contest Schedule Import (CSV / Excel / Word)

1. **Supported formats:** CSV, Excel (.xlsx — multiple sheets), Word (.docx — table parsing)

2. **Import flow:** Upload → parse & preview → auto-match columns → fuzzy resolve names to IDs → manual fix-up UI → validate (no duplicates/conflicts) → bulk POST to core-sys

3. **Name resolution:** Exact match → case-insensitive → Levenshtein ≤ 2. Cache resolved mappings per session. Optionally create missing entities.

4. **Architecture:** Parsing in BFF (`xlsx` + `mammoth` libraries). Preview: `POST /api/contests/import/preview`. Commit: `POST /api/contests/import/commit`. Frontend: `ContestImportView.vue`.

5. **Edge cases:** Multi-customer imports, date/time format variations, "TBD" placeholders.

---

## Related Documentation

- [Architecture Decision Records](adr/) — 40 ADRs covering all major decisions
- [INDEX.md](INDEX.md) — Complete documentation index with reading order
- [OVERVIEW.md](OVERVIEW.md) — Feature overview for stakeholders
- [Flyway Migrations](../../contestgrid-flyway/db/migrations/) — V001–V064

---

**Created**: March 5, 2026
**Updated**: April 6, 2026
**Flyway**: V001–V064 (66 migrations applied)
**Database**: contest_lab (PostgreSQL 16, schema: app, 77 tables)
