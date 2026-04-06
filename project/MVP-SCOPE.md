# MVP Scope Definition — Contest Schedule Platform v1.0

## Overview
This document defines the Minimum Viable Product (MVP) scope for the Contest Schedule platform, focusing on a **web-first** approach targeting sports associations and officials organizations. The MVP enables core contest management, officials assignment, scoring, and billing workflows with full multi-tenancy and audit compliance.

**Target timeline**: 3–5 weeks engineering + testing (4–5 months total with backend, frontend, DevOps, QA).

---

## Core Tenants

### Sports Association Tenant
- Manage contest levels, divisions, seasons, leagues, teams, coaches, venues
- Create and import contests; assign officials
- Enter final scores; manage standings and tournament brackets
- Configure rules; manage approvals and acknowledgments
- View analytics (game completion, cost, official punctuality)

### Officials Association Tenant
- Manage official rosters, certifications, availability
- Receive and confirm assignments
- Submit game reports and location tracking
- View earnings, payout status, punctuality metrics
- Generate invoices for downstream customers
- **Configurable access to sports association contest data** (see ADR-0028):
  - Required: date/time, venue, teams, pay rate, contest status
  - Configurable: standings, coach info, venue notes, historical scores
  - Restricted: financial margins, player PII, internal operations
- **Flexible payer model support** (see ADR-0029):
  - Invoice tenants, sub-organizations, cost centers, events, third-parties, individuals, or informal groups
  - Support split billing when multiple entities pay for one contest
  - Automatic 1099-NEC generation for individual payers

### Platform Admin (Separate App)
- Provision and manage tenants
- Global configuration (default fees, feature flags, integrations)
- Audit and compliance dashboards
- Support tools (impersonation, issue tracking)

---

## Feature Tier Breakdown

### Tier 1: Core Contest Lifecycle (MUST HAVE)

#### 1.1 Tenant Management
- [x] Tenant provisioning (Platform Admin UI)
- [x] Tenant configuration (domain, branding, initial settings)
- [x] Tenant suspension/deletion (with soft deletes and audit)
- **Effort**: 1–2 weeks (UI + backend scaffolding already in place)

#### 1.2 Foundation Data
- [x] Contest Levels (create, read, update, delete)
- [x] Contest Divisions (hierarchically linked to Levels)
- [x] Seasons (year + timeframe model: Spring/Summer/Fall/Winter)
- [x] Leagues (linked to Seasons)
- [x] Teams (linked to Leagues, include rosters)
- [x] Venues + Sub-venues (geographic, multi-game capacity)
- [x] Coaches (linked to Teams)
- [x] Officials (with certifications, availability)
- [x] Roles (sport-specific: crew chief, umpire, scorer, etc.)
- **Effort**: 2 weeks (forms, validation, list/detail views, Pinia store, mock API)

#### 1.3 Contest Management
- [x] Create contest (native form: teams, divisions, venue, season, type)
- [x] Import contests (CSV/Excel with validation + error reporting)
- [x] Edit contest (status, teams, venue, date, type)
- [x] Delete/archive contest
- [x] Contest view (detail page with teams, schedule, officials assigned)
- [ ] Bulk import with async processing (Phase 2)
- **Effort**: 1.5 weeks (form builder, import validation, preview + confirmation)

#### 1.4 Officials Assignment (Basic)
- [x] Manual assignment (select officials per contest; role-based)
- [x] Assignment confirmation workflow (officials accept/decline)
- [x] Conflict detection (same official assigned twice)
- [ ] Location-based recommendation (Phase 2)
- [ ] Assignment algorithm (distance, workload, availability matching—Phase 2)
- **Effort**: 1 week (assignment modal, confirmation status tracking, notifications)

#### 1.5 Score Entry & Standings
- [x] Coach score entry form (final score, optional notes)
- [x] Two-coach approval workflow (confirm/dispute)
- [x] League director dispute resolution (approve/reject/request revision)
- [x] Post-finalization corrections (amendment requests + approval)
- [x] Standings calculation (update after approval, feed tournament brackets)
- [ ] Bracket advancement automation (Phase 2)
- **Effort**: 1.5 weeks (forms, state machine for approval, standings recalc)

#### 1.6 Game Reports (Officials)
- [x] Officials game report form (template selector + free-form text)
- [x] Evidence upload (photo/video)
- [x] Single-official vs. crew-wide signatory configuration
- [x] League director approval workflow
- [x] Immutable finalization + amendment requests
- [ ] Dispute mechanism (optional, Phase 2 if enabled)
- **Effort**: 1.5 weeks (form, approval queue, amendment panel, immutability logic)

### Tier 2: Tracking & Compliance (HIGH VALUE)

#### 2.1 Location Tracking & Punctuality
- [ ] Officials opt-in to location tracking (per-assignment)
- [ ] Real-time location updates (configurable interval, 1–5 min)
- [ ] ETA calculation (Google Maps API integration)
- [ ] Geofence detection (arrival confirmation)
- [ ] Punctuality alerts (configurable threshold, escalation)
- [ ] Audit metrics (early/on-time/late rates, arrival times)
- [ ] Mobile app or responsive web form for location sharing
- **Effort**: 2 weeks (location service integration, geofencing, mobile optimization)
- **Note**: Can defer to Phase 2 if time-constrained; non-blocking for MVP scoring/assignment.

#### 2.2 Rules Management
- [x] Versioned rules (per level/division/season)
- [x] Rich text editor (sections, formatting)
- [x] PDF generation (branded templates, watermark for drafts)
- [x] Approval workflow (league director → association president)
- [x] Official acknowledgment (org-level + individual official)
- [x] Enforcement (block assignment acceptance if pending)
- **Effort**: 1.5 weeks (editor, approval queue, PDF generation, acknowledgment tracking)

#### 2.3 Audit & Compliance
- [x] Audit trail (all mutations logged with actor, timestamp, change)
- [x] Soft deletes (contest, team, official, rule versions preserved)
- [x] RLS at database level (multi-tenant isolation enforced)
- [x] Data retention policies (configurable per entity)
- [ ] GDPR/regional compliance (data export, right-to-forget—Phase 2)
- **Effort**: 1 week (logging service, audit view, retention policies in DB)

#### 2.4 Background Checks & Renewal Policy (Requirements-Only for MVP)
- Track background checks for officials (officials associations) and coaches/volunteers (sports associations).
- Configurable renewal intervals per org/role; reminder schedule (e.g., 60d/30d/7d); blocking behavior (block/warn/none).
- Provider integration requirements: store provider reference IDs and statuses; no detailed report storage; attach PDFs via `document_url`.
- Cross-tenant visibility follows ADR-0028 presets; detailed reports private to owning org.
- **Effort**: 0.5 week (requirements and documentation); implementation deferred to Phase 2.

### Tier 3: Billing & Payments (REVENUE CRITICAL)

#### 3.1 Officials Association Invoicing
- [x] Track invoiceable entities (games, officials, contests)
- [x] Calculate payables (officials org invoicing sports associations for assigned officials)
- [x] Generate invoices (per-game, per-official, per-period)
- [x] Payment processing (Stripe/Adyen card/ACH)
- [x] Reconciliation (invoice → payment tracking)
- [ ] Tax handling & compliance (Phase 2)
- [ ] Multi-currency support (Phase 2)
- **Effort**: 2 weeks (invoice generator, payment integration, reconciliation UI)

#### 3.2 Tenant Subscriptions
- [ ] Define subscription tiers (Starter, Pro, Enterprise—configurable features/pricing)
- [ ] Monthly billing + usage overage tracking
- [ ] Dunning workflow (failed payment retry logic)
- [ ] Revenue dashboards (MRR, churn, ARPU per tenant)
- **Effort**: 1.5 weeks (subscription API, billing engine, dashboard)
- **Priority**: Defer to Phase 2 if focusing on contest flow; use fixed pricing for MVP.

#### 3.3 Officials Payout
- [x] Define per-tenant default fees (configurable per assignment or per-game)
- [x] Calculate payables (gross earnings − fees)
- [x] Payout scheduling (per-pay-period, auto-generated pay stubs)
- [x] Payout methods (ACH, Stripe Connect)
- [x] Reconciliation (payout → official verification)
- **Effort**: 1.5 weeks (payout engine, pay stub generation, reconciliation)

#### 3.4 1099-NEC Reporting (Phase 2/3)
- Define documentation and requirements only for MVP: W-9 capture flow, `official_tax_profile` schema, annual 1099 generation and delivery.
- Implementation deferred post-MVP; tracked as Phase 2/3 compliance work.
- Requirements:
  - Store only `tax_identifier_last4` and `external_vault_ref`; never store full SSN/EIN in platform DBs.
  - Derive nonemployee compensation from payouts; record issued forms in `form_1099_nec` with delivery/correction lifecycle.
  - Support electronic delivery with explicit consent; paper mailing fallback; audit issuance and delivery.
  - RBAC restrictions for compliance roles; immutable audit trail.
**Effort**: 0.5 week (requirements/doc updates); implementation deferred.

### Tier 4: Public Portal & Reporting (ENGAGEMENT)

#### 4.1 Public Portal (Read-Only)
- [ ] League directory (browse sports associations, leagues)
- [ ] Schedule view (public schedules, games, standings)
- [ ] Team pages (roster, coach info, links to officials orgs)
- [ ] Standings & brackets (live-updating, read-only)
- [ ] Search (find leagues, teams, schedules)
- **Effort**: 1.5 weeks (portal UI, read-only API endpoints)
- **Priority**: Defer to Phase 1.5 (post-MVP polish); not required for internal workflows.

#### 4.2 Reporting & Analytics
- [ ] League admin reports (games, assignments, completion %, cost)
- [ ] Officials admin reports (earnings, acceptance rate, punctuality)
- [ ] Platform admin reports (MRR, churn, tenant health, adoption)
- [ ] CSV/PDF export (for business intelligence, reconciliation)
- **Effort**: 1.5 weeks (report generation, charting, export services)
- **Priority**: Phase 1.5 or 2; MVP can use basic dashboards instead.

#### 4.3 Notifications
- [x] Email notifications (assignment, score entry reminders, approval outcomes)
- [x] SMS notifications (optional, via Twilio/SNS)
- [x] In-app toast/banner (interactive feedback)
- [x] User preferences (notification channels, timing, topics)
- **Effort**: 1 week (notification service, template engine, user preferences UI)

---

## Architecture & Infrastructure

### Backend Foundation (Included in MVP)
- **API**: BFF (Backend for Frontend) + microservices (Processing, Core System)
- **Database**: Aurora PostgreSQL 15+ with RLS, audit triggers, soft deletes
- **Auth**: AWS Cognito (OIDC PKCE), MFA, session management
- **Event Bus**: EventBridge for async processing (imports, payouts, notifications)
- **Storage**: S3 for evidence (photos/videos), PDF generation, templates
- **Search**: OpenSearch for officials/league/game search (Phase 2)

### Frontend Foundation (Vue 3)
- **Router**: Multi-tenant routing with RBAC guards
- **State**: Pinia stores for auth, tenant, resources
- **UI**: Design system (tokens, primitives, modals, forms)
- **Testing**: Unit tests (vitest), E2E tests (Playwright), mock server (MSW)
- **DevOps**: Docker, GitHub Actions (CI/CD), Terraform IaC

### Third-Party Integrations (MVP)
- **Payments**: Stripe or Adyen (cards, ACH)
- **Email**: SES or SendGrid
- **Maps**: Google Maps or Mapbox (geofencing, ETA)
- **Documents**: DocuSign for contract signing (Phase 2)
- **Telemetry**: CloudWatch logs, X-Ray tracing

---

## Week-by-Week Implementation Plan

### Phase 1: Weeks 1–2 (Foundation Data UIs)
**Goal**: Build core CRUD interfaces for sports association setup.

- **Week 1**:
  - Day 1–2: Foundation data forms (Levels, Divisions, Seasons, Leagues)
  - Day 3–4: Teams, Venues, Coaches; Pinia stores + API scaffolding
  - Day 5: Integration testing (list/create/edit/delete); bug fixes

- **Week 2**:
  - Day 1–2: Officials and Certifications forms; availability calendar
  - Day 3–4: Roles and Assignments forms; conflict detection
  - Day 5: End-to-end testing; UI refinement

**Deliverable**: Sports association admin can set up all foundation data (Levels → Divisions → Seasons → Leagues → Teams → Venues/Coaches/Officials).

### Phase 2: Weeks 3–4 (Contest Lifecycle)
**Goal**: Build contest creation, import, scoring, standings.

- **Week 3**:
  - Day 1–2: Contest creation form (teams, divisions, venue, type, season)
  - Day 3–4: CSV import (with validation, error reporting, preview, confirmation)
  - Day 5: Async import processing (EventBridge trigger, error handling)

- **Week 4**:
  - Day 1–2: Score entry form (two-coach approval, dispute resolution, amendments)
  - Day 3–4: Standings recalculation (after approval, feed brackets)
  - Day 5: End-to-end scoring workflow; edge cases (tie disputes, revisions)

**Deliverable**: Sports association can create contests natively or import from CSV; coaches enter scores; league directors resolve disputes; standings update automatically.

### Phase 3: Weeks 5+ (Officials Workflows & Compliance)

#### Subphase 3a: Week 5 (Rules & Assignment)
- **Day 1–2**: Rules versioning + approval workflow + acknowledgments
- **Day 3–4**: PDF generation (branded templates, watermark)
- **Day 5**: Assignment modal (manual selection, confirmation, notifications)

**Deliverable**: League directors manage versioned rules with multi-step approval; officials acknowledge rules; officials confirm/decline assignments.

#### Subphase 3b: Week 5+ (Game Reports & Tracking)
- **Day 1–2**: Game report form (templates + free-form, evidence upload)
- **Day 3–4**: League director approval queue; amendments
- **Day 5**: Location tracking (opt-in, real-time updates, punctuality alerts) — *if time permits; otherwise defer to Phase 2*

**Deliverable**: Officials file game reports with approval workflow; location tracking (optional, configurable).

#### Subphase 3c: Week 5+ (Billing & Payouts)
- **Day 1–2**: Invoice generation (per-game/per-official/per-period)
- **Day 3–4**: Payment processing (Stripe/Adyen integration)
- **Day 5**: Payout scheduling and reconciliation

**Deliverable**: Officials organizations invoice sports associations; receive payouts; reconciliation reports.

#### Subphase 3d: Week 5+ (Testing & Hardening)
- **Day 1–2**: Full E2E testing (multi-tenant workflows)
- **Day 3–4**: Load testing (1000+ users, 100+ contests)
- **Day 5**: Security audit (auth, RLS, SQL injection, XSS)

**Deliverable**: MVP ready for production deployment.

---

## Post-MVP (Phase 2 & Beyond)

### Phase 2 (Weeks 6–8): High-Value Features
- **Location Tracking & Punctuality**: Full real-time tracking, multi-venue routing, analytics
- **Advanced Assignment**: Algorithm-based matching (location, workload, availability)
- **Bracket Automation**: Auto-advance winners, handle byes/upsets
- **Search & Filtering**: Full-text search (officials, leagues, games)
- **Address Validation & Geocoding**: USPS standardization, timezone detection
- **Public Portal**: League schedules, standings, team pages

### Phase 3 (Weeks 9–12): Monetization & Analytics
- **Subscription Tiers**: Starter/Pro/Enterprise with feature limits
- **Advanced Reporting**: League/officials/platform dashboards, CSV/PDF export
- **Analytics**: Churn prediction, adoption metrics, revenue forecasting
- **Integrations**: DocuSign contracts, background checks, calendar sync

### Phase 4+ (Beyond): Polish & Scale
- **Mobile Apps**: Native iOS/Android for officials
- **Multi-currency & Tax**: Global expansion, regional compliance
- **API Marketplace**: Webhooks, third-party integrations
- **AI/ML**: Dispute resolution hints, rule suggestions, demand forecasting

---

## Success Criteria for MVP

✅ **Functional**:
- Sports association can create/import 1000+ contests with 100+ officials assigned
- Coaches can enter scores; league directors resolve disputes; standings update accurately
- Officials can file game reports with approval workflow; immutable finalization
- Officials organizations can invoice sports associations; receive payouts; reconcile

✅ **Non-Functional**:
- Performance: page load <2s, API response <500ms (p95)
- Availability: 99.9% uptime (SLA)
- Security: RLS enforced, HTTPS everywhere, audit trail for all mutations
- Compliance: GDPR/SOC2 ready; data retention policies enforced

✅ **User Experience**:
- Onboarding: new tenant provisions in <1 hour with guided setup
- Learning curve: league admin can enter first contest within 15 minutes
- Accessibility: WCAG 2.1 AA compliance (color contrast, keyboard nav, screen reader support)

---

## Infrastructure Approach

**Local development and production deployment strategy** (see [ADR-0032](docs/adr/0032-infrastructure-and-api-security.md) for detailed comparison):

### Recommended: Development on Rancher → Production on EKS

#### Local Development (Rancher Desktop with K3s)
- **Setup Time**: 30 minutes
- **Cost**: Free
- **Components**: K3s, Istio, Flux, Helm, cert-manager (self-signed), PostgreSQL container
- **Benefits**: 
  - ✅ **Infrastructure parity** with production
  - ✅ Identical Helm charts and Kubernetes manifests
  - ✅ Test entire stack locally with mTLS and service mesh
  - ✅ Work offline without AWS costs
  - ✅ Reproduce production issues on your laptop

#### Production Deployment (Amazon EKS)
- **Setup Time**: 3-4 weeks
- **Cost**: $800-1500/month
- **Components**: EKS, Istio, Flux, Helm, cert-manager (Let's Encrypt), Aurora PostgreSQL
- **Benefits**:
  - ✅ Same Helm charts as local (just different values files)
  - ✅ Portable, industry-standard, no vendor lock-in
  - ✅ Comprehensive security (automatic mTLS between all services)
  - ✅ Full observability (Prometheus, Grafana, Jaeger)
  - ✅ GitOps with Flux CD (declarative, auditable deployments)

### Development Workflow
```
Developer workstation (Rancher Desktop with K3s)
  ↓
Build Docker images locally
  ↓
Test with Istio mTLS, Flux GitOps (identical to production)
  ↓
Push to GitHub → GitHub Actions builds and pushes to ECR
  ↓
Flux CD detects new image tag → Deploys to EKS automatically
  ↓
Production (EKS with same Helm charts)
```

### Alternative: AWS-Native (Serverless)
- **Pros**: Faster initial setup (1-2 weeks), fully managed, lower operational overhead
- **Cons**: 
  - ❌ Vendor lock-in to AWS
  - ❌ Different from local development (Lambda vs Kubernetes)
  - ❌ Limited service mesh capabilities
  - ❌ Harder to reproduce production issues locally
- **Components**: Lambda, API Gateway, CloudFront, RDS Aurora, S3, Cognito
- **Note**: Not recommended due to lack of infrastructure parity with Rancher Desktop local development

### Why Rancher Desktop + EKS?
1. **Infrastructure Parity**: Same Kubernetes everywhere (local laptop = production cloud)
2. **Faster Development**: Test full stack locally, no deploy → test → debug cycle in AWS
3. **Cost Efficiency**: Develop entirely offline; only pay for AWS when deploying
4. **Industry Standard**: Kubernetes skills are portable across clouds (AWS, GCP, Azure)
5. **Modern Best Practices**: Service mesh with automatic mTLS, GitOps, observability built-in

### API Security Standards (Both Options)
- **TLS 1.3** for all external traffic; mTLS for service-to-service (automatic with Istio)
- **JWT authentication** via AWS Cognito with JWKS validation
- **API rate limiting**: Per-tenant quotas (100-1000 req/min based on plan)
- **Certificate management**: AWS ACM (Option A) or cert-manager with Let's Encrypt (Option B)
- **Secrets management**: AWS Secrets Manager with rotation policies (90 days)
- **HTTPS everywhere**: No unencrypted traffic; automatic redirects from HTTP to HTTPS

---

## Resource Allocation

### Team Composition (Suggested)
- **Backend Engineers**: 2 (API, database, auth, async processing)
- **Frontend Engineers**: 2 (Vue 3, design system, forms, state management)
- **DevOps/Infrastructure**: 1 (AWS, Docker, CI/CD, monitoring)
- **QA/Testing**: 1 (test automation, E2E, load testing, security)
- **Product Manager**: 1 (requirements, prioritization, stakeholder communication)
- **Designer**: 0.5 (design system already in place; maintenance + refinement)

**Total**: ~6–7 FTEs for 5–8 weeks = ~240–280 person-days.

---

## Known Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|-----------|
| CSV import validation complexity | High | Start with simple CSV structure; allow template download; iteratively expand supported columns |
| Multi-tenant isolation (RLS bugs) | Critical | Comprehensive test suite for RLS; monthly security audit; customer data sensitivity training |
| Payment processing reliability | High | Use Stripe/Adyen SDKs; implement retry logic; customer payment support team |
| Geo-location data privacy | Medium | GDPR consent flow; 90-day deletion; audit trail; opt-out mechanism |
| Scale (1000+ officials, 100+ games) | Medium | Database indexing on gameId/officialId; async processing for imports; caching strategy |
| Browser compatibility | Low | Vue 3 + modern ES2020; test on Chrome, Safari, Firefox, Edge; polyfills for older browsers |

---

## MVP Scope Checklist

### Foundation Data
- [ ] Contest Levels (CRUD)
- [ ] Contest Divisions (CRUD, hierarchical)
- [ ] Seasons (CRUD, year + timeframe)
- [ ] Leagues (CRUD)
- [ ] Teams (CRUD, rosters)
- [ ] Venues + Sub-venues (CRUD, capacity, geocoding)
- [ ] Coaches (CRUD, linked to teams)
- [ ] Officials (CRUD, certifications, availability)
- [ ] Roles (CRUD, sport-specific)

### Contest Management
- [ ] Native contest creation
- [ ] CSV/Excel import with validation
- [ ] Contest editing (status, teams, venue, date)
- [ ] Contest view (detail page)
- [ ] Contest deletion/archival

### Officials Assignment
- [ ] Manual assignment (select officials per contest)
- [ ] Conflict detection (same official assigned twice)
- [ ] Assignment confirmation (accept/decline)
- [ ] Assignment notifications (email/SMS)

### Scoring & Standings
- [ ] Coach score entry (two-coach approval)
- [ ] Dispute resolution (league director arbitration)
- [ ] Post-finalization corrections (amendments)
- [ ] Standings recalculation (after approval)
- [ ] Bracket integration (feed tournament advancement)

### Game Reports
- [ ] Report form (templates + free-form)
- [ ] Evidence upload (photos/videos)
- [ ] League director approval workflow
- [ ] Immutable finalization
- [ ] Amendment requests

### Rules Management
- [ ] Versioned rules (per level/division/season)
- [ ] Rich text editor
- [ ] PDF generation (branded templates)
- [ ] Multi-step approval (league director → association president)
- [ ] Official acknowledgment (org-level + individual)

### Billing & Payouts
- [ ] Invoice generation (per-game/official/period)
- [ ] Payment processing (Stripe/Adyen)
- [ ] Payout scheduling
- [ ] Reconciliation reports

### Audit & Compliance
- [ ] Audit trail (all mutations logged)
- [ ] Soft deletes (data preserved)
- [ ] RLS enforcement (multi-tenant isolation)
- [ ] Data retention policies

### Notifications
- [ ] Email (assignment, reminders, outcomes)
- [ ] SMS (optional)
- [ ] In-app notifications (toast/banner)
- [ ] User preferences

### Testing
- [ ] Unit tests (vitest, >80% coverage)
- [ ] E2E tests (Playwright, critical paths)
- [ ] Load testing (1000+ users, 100+ contests)
- [ ] Security audit (auth, RLS, injection)

### Documentation
- [ ] API documentation (OpenAPI/Swagger)
- [ ] User guide (onboarding, workflows)
- [ ] Admin guide (configuration, troubleshooting)
- [ ] Architecture documentation (ADRs, data model)

---

## Decision Points & Trade-Offs

### Location Tracking (Include or Defer?)
- **Include**: Real-time geofencing, ETA alerts, punctuality audit—high value for officials org, adds 2 weeks.
- **Defer**: Focus on core scoring/assignment first; add location in Phase 2.
- **Recommendation**: **Defer to Phase 2** if timeline is tight; non-blocking for MVP scoring workflows.

### Advanced Assignment Algorithm
- **Include**: Auto-match officials based on location, workload, availability—high value, 2+ weeks.
- **Defer**: Use manual assignment in MVP; add algorithm in Phase 2.
- **Recommendation**: **Defer to Phase 2**; manual assignment sufficient for MVP validation.

### Public Portal
- **Include**: Public schedules, standings, team pages—engagement & marketing benefit, 1.5 weeks.
- **Defer**: MVP is for internal league/officials workflows; add public portal in Phase 1.5.
- **Recommendation**: **Defer to Phase 1.5**; internal workflows first, then polish with public access.

### Subscription Tiers vs. Fixed Pricing
- **Include**: Configurable pricing, feature limits, usage overage—monetization, 1.5 weeks.
- **Defer**: Use fixed per-game or per-official pricing in MVP; add tiers in Phase 2.
- **Recommendation**: **Defer to Phase 2**; simpler pricing model for MVP launch.

---

## Next Steps

1. **Confirm scope**: Review checklist; confirm Defer items (location tracking, assignment algorithm, public portal, subscription tiers).
2. **Prioritize backlog**: Create detailed epics + stories for Phase 1 (foundation data); estimate story points.
3. **Assign team**: Allocate engineers to backend/frontend/DevOps; assign tech leads.
4. **Set up infrastructure**: AWS account, RDS (Aurora), S3, Cognito, EventBridge, GitHub Actions CI/CD.
5. **Begin Phase 1**: Week 1 kickoff with foundation data UI development.

---

**Document Version**: 1.0  
**Last Updated**: December 26, 2025  
**Status**: Ready for Team Review
