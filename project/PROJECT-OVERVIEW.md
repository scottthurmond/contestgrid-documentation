# Contest Schedule Platform — Project Overview

## Platform Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         Contest Schedule Platform                           │
└─────────────────────────────────────────────────────────────────────────────┘

FRONTEND (Vue 3 + TypeScript + Vite + Vuetify 4)
  ├─ Sports Association Admin
  │  ├─ Foundation Data (Levels, Divisions, Seasons, Leagues, Teams, Venues)
  │  ├─ Contest Management (Create, Import, Edit, View)
  │  ├─ Officials Assignment (Manual, Confirmation, Tracking)
  │  ├─ Background Checks (Tracking, Renewal Policies, Alerts, Blocking)
  │  ├─ Rules Management (Versioning, Approval, Acknowledgments, PDF)
  │  ├─ Score Management (Entry, Dispute Resolution, Amendments, Standings)
  │  ├─ Background Checks (Coaches/Volunteers; Renewal Policies, Alerts)
  │  ├─ Game Reports (Approval Queue, Immutable Finalization)
  │  └─ Analytics (Completion Rates, Official Metrics, Costs)
  │
  ├─ Officials Association Admin
  │  ├─ Official Rosters (CRUD, Certifications, Availability)
  │  ├─ Assignment Confirmation (Accept/Decline, Escalation)
  │  ├─ Game Reports (File Reports, View Status)
  │  ├─ Location Tracking (Opt-in, Real-time ETA, Punctuality Alerts)
  │  ├─ Invoicing (Track Payables, Generate Invoices)
  │  ├─ Payouts (Payout Scheduling, Pay Stubs, Reconciliation)
  │  ├─ 1099-NEC (Tax Reporting, Electronic/Paper Delivery, Corrections)
  │  └─ Analytics (Earnings, Punctuality, Acceptance Rate)
  │
  ├─ Platform Admin
  │  ├─ Tenant Management (Provision, Configure, Suspend, Delete)
  │  ├─ Global Configuration (Fees, Feature Flags, Integrations)
  │  ├─ Audit & Compliance (Audit Logs, Data Retention)
  │  ├─ Support Tools (Impersonation, Issue Tracking)
  │  └─ Analytics (MRR, Churn, Adoption, Billing Health)
  │
  └─ Public Portal
     ├─ League Directory
     ├─ Schedule View
     ├─ Standings & Brackets
     ├─ Team Pages
     └─ Search

BACKEND (BFF + Microservices)
  ├─ BFF (Backend for Frontend)
  │  ├─ Request validation & transformation
  │  ├─ Auth token injection (Cognito JWT)
  │  ├─ Multi-tenant routing (RLS enforcement)
  │  └─ Rate limiting & caching
  │
  ├─ Core System Service
  │  ├─ Contest, Team, Venue, Coach, Official management
  │  ├─ Rules versioning & approval
  │  └─ Audit logging
  │
  ├─ Processing Service
  │  ├─ Async import (CSV/Excel validation, error handling)
  │  ├─ Score calculation & standings update
  │  ├─ Bracket advancement
  │  ├─ Invoice generation
  │  ├─ Payout scheduling
  │  └─ Notification dispatch
  │
  └─ Search Service (OpenSearch)
     ├─ Full-text search (officials, leagues, games, teams)
     └─ Faceted filtering & analytics read model

INFRASTRUCTURE
  ├─ Container Orchestration: Kubernetes (EKS) with Flux GitOps
  ├─ Service Mesh: Istio (mTLS, traffic management, observability)
  ├─ Package Management: Helm charts for all applications
  ├─ TLS/Certificates: cert-manager with Let's Encrypt + AWS ACM
  ├─ Secrets: External Secrets Operator + AWS Secrets Manager
  ├─ Auth: AWS Cognito (OIDC PKCE, MFA) + Istio JWT validation
  ├─ Database: Aurora PostgreSQL 15+ (RLS, Audit, Soft Deletes)
  ├─ Event Bus: EventBridge (async processing, fan-out)
  ├─ Storage: S3 (evidence, PDFs, templates)
  ├─ Search: OpenSearch (full-text, aggregations)
  ├─ Email: SES (notifications, invoices, reminders)
  ├─ SMS: Twilio/SNS (urgent alerts)
  ├─ Maps: Google Maps/Mapbox (geofencing, ETA, routing)
  ├─ Payments: Stripe/Adyen (invoices, payouts)
  ├─ Documents: DocuSign (contracts, e-signatures)
  ├─ Monitoring: Prometheus + Grafana + Jaeger (metrics, traces, logs)
  └─ CI/CD: GitHub Actions + Flux CD (automated testing, GitOps deployment)
```

---

## MVP Timeline (3–5 Weeks Engineering)

```
PHASE 1: Foundation Data UIs (Weeks 1–2)
┌──────────────────────────────────────────────────────────────┐
│ Week 1                          │ Week 2                      │
├─────────────────────────────────┼─────────────────────────────┤
│ • Levels, Divisions             │ • Teams, Venues, Sub-venues │
│ • Seasons, Leagues              │ • Coaches, Officials, Roles │
│ • Pinia stores + mock API       │ • Certification management  │
│ • Unit tests                    │ • E2E testing               │
│ • Routes & nav                  │ • UI polish                 │
└──────────────────────────────────────────────────────────────┘

PHASE 2: Contest Lifecycle (Weeks 3–4)
┌──────────────────────────────────────────────────────────────┐
│ Week 3                          │ Week 4                      │
├─────────────────────────────────┼─────────────────────────────┤
│ • Contest creation              │ • Score entry form          │
│ • CSV import with validation    │ • Two-coach approval        │
│ • Error reporting & preview     │ • Dispute resolution        │
│ • Async processing simulation   │ • Standings recalculation   │
│ • Integration tests             │ • Bracket integration       │
└──────────────────────────────────────────────────────────────┘

PHASE 3: Compliance & Workflows (Week 5+)
┌──────────────────────────────────────────────────────────────┐
│ Week 5a: Rules & Assignment     │ Week 5b–5d: Reports & Billing
├─────────────────────────────────┼─────────────────────────────┤
│ • Rules versioning              │ • Game report form          │
│ • Multi-step approval           │ • Signatory workflow        │
│ • Acknowledgments               │ • League director queue      │
│ • PDF generation                │ • Amendment tracking        │
│ • Assignment confirmation       │ • Location tracking (opt)   │
│ • Escalating reminders          │ • Invoice generation        │
│                                 │ • Payout scheduling         │
│                                 │ • Reconciliation UI         │
└──────────────────────────────────────────────────────────────┘

PHASE 4: Testing & Hardening (Week 5+)
┌──────────────────────────────────────────────────────────────┐
│ • E2E tests (Playwright)        │ • Security audit            │
│ • Load testing (1000 users)     │ • Accessibility (WCAG AA)   │
│ • Performance profiling         │ • Data integrity            │
└──────────────────────────────────────────────────────────────┘
```

---

## Feature Hierarchy (Multi-Tenant)

```
SPORTS ASSOCIATION TENANT
  └─ Levels (College, HS, Travel, Recreation, etc.)
     └─ Divisions (Varsity, JV, 8U, 9U, etc.)
        └─ Seasons (2025 Spring, 2025 Summer, etc.)
           └─ Leagues (Division 1, Division 2, etc.)
              ├─ Teams (with coaches & rosters)
              ├─ Venues (with sub-venues, capacity)
              ├─ Contests (teams, dates, officials assigned)
              │  ├─ Scores (final, two-coach approval, standings impact)
              │  ├─ Game Reports (officials filing, league director approval)
              │  └─ Audit Trail (all mutations, soft deletes, immutable)
              └─ Rules (versioned, approved, acknowledged)

OFFICIALS ASSOCIATION TENANT
  └─ Officials (with certifications, availability, preferences)
     ├─ Assignments (to contests, confirmation workflow)
     ├─ Game Reports (filed by officials, approved by league director)
     ├─ Location Tracking (opt-in, real-time ETA, punctuality alerts)
     ├─ Invoices (to flexible payers: tenants, sub-orgs, third-parties, etc.)
     ├─ Payouts (scheduled, pay stubs, reconciliation)
     └─ Cross-Tenant Data Access (configurable access to sports association contests)
        ├─ Required: date/time, venue, teams, pay rate, status
        ├─ Configurable: standings, coach info, venue notes, historical data
        └─ Restricted: financial margins, player PII, internal communications

FLEXIBLE PAYER MODEL (see ADR-0029)
  └─ Billing Entities (who pays for contests)
     ├─ Tenant (primary organization, backward compatible)
     ├─ Sub-Organization (division, league, branch)
     ├─ Cost Center (department, event, budget line)
     ├─ Third-Party Organization (non-tenant customer)
     ├─ Individual (coach, parent, eligible for 1099)
     └─ Informal Group (parent committee, booster club)
        ├─ Hierarchical support (divisions under leagues, schools under districts)
        ├─ Split billing (multiple entities pay for one contest)
        └─ Automatic invoicing and 1099 generation
```

---

## Key Features by Tier

| Tier | Feature | MVP | Phase 2 |
|------|---------|-----|---------|
| **Tier 1: Core** | Foundation Data | ✅ | - |
| | Contest Creation | ✅ | - |
| | CSV Import | ✅ | - |
| | Officials Assignment | ✅ (manual) | 🔄 (algorithm) |
| | Score Entry & Dispute | ✅ | - |
| | Game Reports | ✅ | - |
| | Rules Management | ✅ | - |
| | Audit & Compliance | ✅ | - |
| **Tier 2: High-Value** | Location Tracking | ⏸️ (defer) | ✅ |
| | Punctuality Alerts | ⏸️ (defer) | ✅ |
| | Advanced Assignment | ⏸️ (defer) | ✅ |
| | Bracket Automation | ⏸️ (defer) | ✅ |
| **Tier 3: Revenue** | Invoicing | ✅ | - |
| | Payment Processing | ✅ | - |
| | Payouts & Pay Stubs | ✅ | - |
| | Subscription Tiers | ⏸️ (defer) | ✅ |
| **Tier 4: Engagement** | Public Portal | ⏸️ (defer) | ✅ |
| | Reporting & Analytics | ⏸️ (basic) | ✅ |
| | Search & Filtering | ⏸️ (defer) | ✅ |

---

## Configuration Hierarchy (Granular Control)

```
Global Default
  ↓
Officials Organization Default
  ↓
Sports Organization Default
  ↓
Division Default
  ↓
Per-Game/Per-User Override
  ↓
APPLIED SETTING
```

**Examples**:
- Report requirement: "All games require reports" (global) → "Except recreational league" (org override) → "All tournament games for Div 1" (div override)
- Tracking start window: 60 minutes before game (global) → 90 minutes for HS level → 45 minutes for this venue
- Late alert threshold: 15 minutes before start (global) → 10 minutes for playoff games → no alerts for practice games

---

## Database Schema (Aurora PostgreSQL)

```
├─ contests
│  ├─ id (UUID, PK)
│  ├─ tenant_id (multi-tenant via RLS)
│  ├─ league_id, division_id, level_id (hierarchy)
│  ├─ home_team_id, away_team_id, venue_id
│  ├─ status (draft → scheduled → in_progress → completed → archived)
│  ├─ final_score_home, final_score_away
│  ├─ audit_log (JSONB: mutations, timestamps, actor_id)
│  └─ created_at, updated_at, deleted_at (soft delete)
│
├─ contest_scores
│  ├─ id, contest_id
│  ├─ home_coach_id, away_coach_id
│  ├─ home_score, away_score
│  ├─ status (pending → entered → approved → disputed → resolved)
│  ├─ finalized_at (immutability marker)
│  ├─ score_correction_history (JSONB: amendments with audit)
│  └─ created_at, updated_at, deleted_at
│
├─ game_reports
│  ├─ id, game_id, contest_id
│  ├─ report_type (template | freeform | hybrid)
│  ├─ incident_type, description, attachments
│  ├─ signatories (JSONB: [{ official_id, signed_at, status }])
│  ├─ approval_status (pending → approved → finalized)
│  ├─ amendments (JSONB: [{ requested_by, reason, approved_by }])
│  └─ audit_trail
│
├─ officials
│  ├─ id, organization_id
│  ├─ name, email, phone
│  ├─ certifications (JSONB: [{ cert_id, sport, level, expiry }])
│  ├─ location (lat, lng, address; retention: 90 days; historical)
│  ├─ arrival_times (timestamps for punctuality audit; retention: 3 years)
│  └─ created_at, updated_at, deleted_at
│
├─ invoices
│  ├─ id, from_org_id, to_org_id (invoicing between orgs)
│  ├─ invoice_date, due_date, status (draft → issued → paid → overdue)
│  ├─ line_items (JSONB: [{ contest_id, official_id, qty, rate, amount }])
│  ├─ total_amount, tax, fees, net
│  └─ audit_trail
│
├─ payouts
│  ├─ id, official_id, period (YYYY-MM)
│  ├─ gross_earnings, fees, taxes, net
│  ├─ status (pending → processed → paid → reconciled)
│  ├─ pay_stub (PDF, JSON payroll detail)
│  └─ created_at, paid_at, reconciled_at
│
└─ audit_logs
   ├─ id, entity_type (contest, score, official, etc.)
   ├─ entity_id, action (create, update, delete, approve)
   ├─ actor_id (user who performed action)
   ├─ changes (JSONB: old_value, new_value, field_name)
   ├─ timestamp, ip_address, user_agent
   └─ retention_days (configurable per entity: 90–7 years)

All tables implement:
  • RLS (tenant_id isolation)
  • UUID primary keys (vs. sequential for security)
  • JSONB for extensibility
  • Soft deletes (deleted_at timestamp)
  • Audit triggers (log mutations automatically)
```

---

## Configurability (Contest Reports Example)

**Global Config**:
```
requiredFor: "all"
signatoryModel: "crew_wide"
blockingBehavior: "blocking"
visibilityLevel: "internal_only"
disputeEnabled: false
```

**Sport Association Override**:
```
visibilityLevel: "team_visible"  // Coaches see reports
```

**Division Override**:
```
requiredFor: "playoff_only"  // Only playoff games require reports
signatoryModel: "single_official"  // Crew chief only
```

**Per-Game Override**:
```
blockingBehavior: "informational"  // For friendly matches, don't block close-out
```

**Result**: Game report workflow combines all levels, most specific wins.

---

## Success Criteria (MVP)

✅ **Functional**:
- 1000+ contests created/imported with 100+ officials assigned
- Coaches enter scores; disputes resolved; standings update accurately
- Officials file reports; league directors approve; amendments tracked immutably
- Officials orgs invoice sports orgs; receive payouts; reconcile

✅ **Non-Functional**:
- Page load <2s, API <500ms (p95)
- 99.9% uptime
- RLS enforced, HTTPS, audit trail for all mutations
- GDPR/SOC2 ready

✅ **User Experience**:
- New tenant onboards in <1 hour
- League admin enters first contest in <15 minutes
- WCAG 2.1 AA accessibility

---

## Next Steps

1. ✅ Confirm MVP scope with team
2. ✅ Review deferred items (location tracking, assignment algorithm, public portal, subscription tiers)
3. 🔄 Set up infrastructure (AWS, RDS, S3, Cognito, EventBridge)
4. 🔄 Create Phase 1 backlog in GitHub Issues
5. 🔄 Assign team and kick off Week 1
6. 🔄 Weekly standup and progress reviews
7. 🔄 Launch MVP to closed beta (week 6–8)

---

**Status**: Ready for Implementation  
**Timeline**: 3–5 weeks engineering, 4–5 months total  
**Team Size**: 6–7 FTEs  
**Last Updated**: December 26, 2025

See [docs/MVP-SCOPE.md](docs/MVP-SCOPE.md) and [docs/IMPLEMENTATION-QUICKSTART.md](docs/IMPLEMENTATION-QUICKSTART.md) for detailed plans.
