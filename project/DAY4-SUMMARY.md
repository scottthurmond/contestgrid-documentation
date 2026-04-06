# Scheduling Proc API - Day 4 Implementation Summary

**Date**: March 7, 2026  
**Status**: ✅ COMPLETE  
**Milestone**: Scheduling orchestration service deployed with contest creation and auto-assign workflows

---

## Overview

Day 4 of the ContestGrid backend implements the scheduling-proc service — the first process/orchestration layer that coordinates calls across the three system APIs (core-sys, officials-sys, billing-sys). This service handles contest creation with automatic rate lookup and intelligent auto-assignment of officials to contests using round-robin load balancing with time-conflict detection.

## Completed Tasks

### ✅ 1. Prerequisites — Core-Sys Contest Schedule CRUD

Added full CRUD for the `contest_schedule` table to core-sys:

- **GET /v1/contests** — List contests (10-table JOIN for enriched data)
- **GET /v1/contests/:id** — Get contest by ID with full details
- **POST /v1/contests** — Create contest with Zod validation
- **PATCH /v1/contests/:id** — Update contest (dynamic field mapping)
- **DELETE /v1/contests/:id** — Delete contest

**Files created:**
- `contestgrid-core-sys/src/services/contestScheduleService.ts`
- `contestgrid-core-sys/src/routes/contests.ts`

### ✅ 2. V013 Migration — Official Contest Assignment Table

Created and applied the `official_contest_assignment` table migration:

- **`assignment_status`** reference table (Pending, Confirmed, Declined, Cancelled, Completed)
- **`official_contest_assignment`** table with FKs to contest_schedule, official, assignment_status
- UNIQUE constraint on (contest_schedule_id, official_id)
- 4 indexes for efficient lookups

**Files:**
- `flyway/db/migration/V013__create_official_contest_assignment_table.sql`
- `flyway/db/migration/U013__create_official_contest_assignment_table.sql`

### ✅ 3. Prerequisites — Officials-Sys Assignment CRUD

Added full CRUD for official contest assignments to officials-sys:

- **GET /v1/assignments** — List assignments (5-table JOIN, filterable by contestScheduleId)
- **GET /v1/assignments/:id** — Get assignment by ID with details
- **POST /v1/assignments** — Create single assignment
- **POST /v1/assignments/bulk** — Bulk create with ON CONFLICT DO NOTHING
- **PATCH /v1/assignments/:id** — Update assignment status/notes
- **DELETE /v1/assignments/:id** — Delete assignment (tenant check via JOIN)

**Files created:**
- `contestgrid-officials-sys/src/types/assignment.ts`
- `contestgrid-officials-sys/src/services/assignmentService.ts`
- `contestgrid-officials-sys/src/routes/assignments.ts`

### ✅ 4. Scheduling Proc — New Service (Port 3004)

Built the complete scheduling-proc orchestration service:

```
contestgrid-scheduling-proc/src/
├── index.ts                          # Express server (port 3004)
├── config/
│   ├── env.ts                        # Zod-validated environment config
│   └── apiClients.ts                 # Axios clients for 3 downstream services
├── middleware/
│   ├── tenantContext.ts              # X-Tenant-ID extraction
│   └── errorHandler.ts              # ZodError, AxiosError, generic handling
├── types/
│   └── workflow.ts                   # Workflow input/output types
├── services/
│   ├── contestWorkflowService.ts    # Contest creation orchestration
│   └── assignWorkflowService.ts     # Auto-assign orchestration
└── routes/
    ├── health.ts                     # Health check endpoint
    ├── workflows.ts                  # Workflow endpoints with Zod validation
    └── index.ts                      # Route mounting
```

### ✅ 5. Workflow: Contest Creation

**POST /v1/workflows/contests/create**

Orchestration flow:
1. **Rate Lookup** — Queries billing-sys for the association/sport/level rate
2. **Officials Count** — Uses `contest_num_officials_contracted` from rate (or input override, or default 1)
3. **Team Validation** — Verifies home and visiting teams exist via core-sys
4. **Contest Creation** — Creates the contest schedule via core-sys
5. **Response** — Returns created contest + matched rate + summary message

### ✅ 6. Workflow: Auto-Assign Officials

**POST /v1/workflows/assignments/auto-assign**

Orchestration flow:
1. **Fetch Contests** — Gets contests from core-sys (filterable by IDs or date)
2. **Fetch Existing Assignments** — Gets current assignments from officials-sys
3. **Find Understaffed** — Identifies contests needing more officials
4. **Fetch Available Officials** — Gets officials from the association's tenant
5. **Round-Robin Assignment** — Assigns by lowest workload with time-conflict detection
6. **Bulk Create** — Posts assignments to officials-sys in batch

**Features:**
- Cross-tenant support (association officials belong to different tenant than league contests)
- Time-conflict detection prevents double-booking officials
- Round-robin load balancing for fair distribution
- Handles response shape differences between services

### ✅ 7. Kubernetes Deployment

Created K8s manifests for scheduling-proc:

- `k8s/configmap.yaml` — Service URLs for core-sys, officials-sys, billing-sys
- `k8s/deployment.yaml` — 2 replicas, resource limits, liveness/readiness probes
- `k8s/service.yaml` — ClusterIP 80→3004
- `k8s/virtualservice.yaml` — Istio routes for /v1/scheduling and /v1/workflows

Updated officials-sys VirtualService to add /v1/assignments prefix route.

### ✅ 8. Restfox Collections

Created Restfox request collections for all new endpoints:

- **ContestGrid Scheduling API** — Health, Contest Create, Auto-Assign workflows
- **ContestGrid Core API / Contests** — Full CRUD (5 requests)
- **ContestGrid Officials API / Assignments** — Full CRUD + Bulk (6 requests)
- Updated all environments with `contestgrid-scheduling-proc-url` variable

### ✅ 9. Bug Fixes

| Bug | Root Cause | Fix |
|-----|-----------|-----|
| `column cl.level_name does not exist` | Wrong column names in contest JOIN | Changed to `cl.contest_level_name AS level_name` |
| Officials not found during auto-assign | Officials belong to association tenant, not league tenant | Added `associationTenantId` parameter |
| `Expected number, received string` on assignments | PostgreSQL BIGINT returns as string | Changed to `z.coerce.number()` |
| Rate lookup returning 1 instead of 2 officials | `rateRes.data?.data` but billing returns flat object | Fixed to `rateData?.data ?? rateData` |
| Teams endpoint `ORDER BY ambiguous` | `CONTEST_LEAGUE_ID` aliased as `team_name` (duplicate) | Rewrote all team queries with correct column names |

---

## Deployed Services Summary

| Service | Port | Replicas | Status |
|---------|------|----------|--------|
| contestgrid-core-sys | 3001 | 2 | ✅ Running (2/2) |
| contestgrid-officials-sys | 3002 | 2 | ✅ Running (2/2) |
| contestgrid-billing-sys | 3003 | 2 | ✅ Running (2/2) |
| contestgrid-scheduling-proc | 3004 | 2 | ✅ Running (2/2) |

**Total: 8 pods, all 2/2 Ready with Istio sidecar**

## Verified Outcomes

```bash
# Health
curl -sk https://api.contestgrid.local:8443/v1/scheduling/health
# → {"status":"ok","service":"contestgrid-proc-scheduling"}

# Contests with full joined details
curl -sk https://api.contestgrid.local:8443/v1/contests -H "X-Tenant-ID: 2"
# → 4 seeded contests with sport, level, league, venue, team, association names

# Auto-assign — all contests fully staffed
curl -sk https://api.contestgrid.local:8443/v1/workflows/assignments/auto-assign \
  -X POST -H "Content-Type: application/json" -H "X-Tenant-ID: 2" \
  -d '{"associationTenantId": 1}'
# → {"totalContests":4,"totalAssigned":6,"fullyStaffed":4,"understaffed":0}

# Contest creation with rate-driven official count
curl -sk https://api.contestgrid.local:8443/v1/workflows/contests/create \
  -X POST -H "Content-Type: application/json" -H "X-Tenant-ID: 2" \
  -d '{"sportId":1,"contestTypeId":1,"contestLevelId":2,...}'
# → "Contest created with 2 official(s) per rate schedule"

# Teams now return correct fields
curl -sk https://api.contestgrid.local:8443/v1/teams -H "X-Tenant-ID: 2"
# → team_name, contest_league_id, contest_level_id (no duplicate aliases)
```

## Database State

- **Flyway**: 13 migrations applied (V001–V013)
- **Schema**: `app` in `contest_lab` database
- **Seed data**: V012 with 2 tenants, 4 officials, 8 teams, 4 contests, 2 venues, rates

## Next Steps

- **Day 5**: Billing Proc API (contestgrid-billing-proc, port 3005)
  - POST /workflows/payments/process
  - POST /workflows/payroll/calculate
- **Week 2**: BFF layer + end-to-end testing
