# Contest Schedule — Feature Overview

A multi-tenant platform for sports associations and officials organizations to plan contests, assign and track officials, manage rules and billing, and share schedules publicly.

## Audience
- Sports Associations — Full support for game schedules, teams, scores, coaches and team rosters
- Officials organizations (assigners, administrators)
- Platform administrators
- Public users (parents, coaches, fans)

## Tenants
- Sports Association tenants — manage levels, divisions, and leagues; full support for game schedules, teams, scores, coaches and team rosters
- Officials Association tenants — assignments, payouts, metrics
- Platform Admin — global configuration, billing, audit

## Core Capabilities

### Contest Management
- Create contests natively with full context (teams, divisions, venue/sub-venue, season, type, status)
- Track payer for officiating costs (home, away, league, venue owner, sponsor, split-exact amounts)
- Required officials and roles per contest; certification and conflict rules

### Foundational Data
- Contest Levels (College, High School, Travel, Recreation, Perfect Game, American Legion)
- Contest Divisions (T‑Ball, Pee Wee, 8U, 9U, 10U, Varsity, JV, etc.)
- Seasons with year + timeframe (Spring, Summer, Fall, Winter); query by year and drill down to timeframe
- Leagues, Teams, Coaches, Venues + Sub‑venues, Sports, Roles, Officials, Certifications

### Import & Templates
- Import contests from CSV/Excel; optional external APIs (e.g., QuickScores) or web page scraping when no API
- Required/optional column definitions; phase-based validation with smart correction suggestions
- Modes: All‑or‑nothing or Partial (import valid rows, skip failed)
- Pre‑populated template export (teams/venues/divisions/leagues loaded) to simplify user input
- Async processing for medium/large/extra‑large files; rollback support; full audit trail

### Officials Assignment & Matching
- Assignment algorithm considers location, availability, certifications, workload balance, preferences
- Role requirements per sport/level; conflict and travel constraints
- Short‑notice (same‑day), mid‑range (≤3 days), normal categorization

### Location Tracking & Punctuality (Configurable)
- Opt‑in location tracking starting configurable minutes before start (default 60), resolved hierarchically: Global → Officials Assoc → Sports Assoc → Venue → Individual Official
- Real‑time updates and ETA calculation using traffic APIs; geofenced arrival detection
- Multi‑venue days: route/ETA across venues; alerts if transit time insufficient
- Punctuality alerts at configurable thresholds (default 15 min); escalation (T‑10, T‑5)
- Audit & metrics: early/on‑time/late rates, minutes early/late, patterns; coordinates retained 90 days, arrival times retained per policy

### Billing & Payments
- Tenant subscriptions and usage‑based billing; dunning workflows; revenue reporting
- Officials association invoicing to downstream customers (sports associations and individuals), even if not tenants; card/ACH/wallets; reconciliation export
- Convenience fees configurable (absorb/pass through); tax handling and compliance

### Rules Management
- Versioned rules per level/division/age group and season; rich text + PDF generation
- Approval workflow (league director → association president) with audit trail
- Acknowledgment: officials association (org‑level) and each individual official (initial + changes)
- Enforcement: block assignment acceptance if acknowledgment pending (configurable)

### Tournament Management
- Formats: single/double elimination, round‑robin, custom brackets
- Seeding, tiebreakers, bracket generation and advancement

### Public Portal
- League directory, schedules, team pages, standings, brackets
- Access control for public/private content per tenant

### Notifications & Messaging
- Email/SMS/in‑app push; user preferences; delivery & retries; suppression lists
- Rule change, assignment, arrival/late, payment confirmations

### Reporting & Analytics
- League reports (games, assignments, completion, cost)
- Officials reports (earnings, acceptance rate, punctuality)
- Platform reports (MRR, churn, billing health, adoption)
- CSV/PDF exports, dashboards

### Integrations
- Payments (Stripe/Adyen), Email/SMS (SES/SNS/Pinpoint/Twilio), Calendar (Google/Outlook/iCal)
- Search/analytics (OpenSearch), Event bus (EventBridge/Kafka)

### Admin & RBAC
- AWS Cognito (OIDC PKCE), MFA, session policies
- Route roles and guards; Forbidden flows; mock provider for dev

### Security & Compliance
- Aurora PostgreSQL with RLS for multi‑tenancy; encryption in transit/at rest
- GDPR/regional compliance; PII minimization; audit logging with retention policies

### Configuration & Policies (Hierarchical)
- Validation rules (past dates, duplicates, auto‑create teams/venues)
- Requirement policies: turn‑back reason, response SLA, tracking start window, late alert threshold
- Hierarchy: Individual Official → Venue → Sports Association → Officials Association → Global

## Key Differentiators
- Hierarchical, granular configuration for tracking and alerts
- Split‑payer billing with exact amounts and direct‑pay flag
- Versioned rules with approval and acknowledgments
- Punctuality analytics and multi‑venue routing visibility
- Robust import with smart correction, rollback, and auditing

## Roadmap Highlights
- Foundation data UIs (leagues/divisions/teams/venues/coaches)
- Template export → import wizard
- Assignment + tracking dashboards
- Rules editor + approvals + acknowledgments
- Billing dashboards and invoicing flows

## Glossary
- Contest Level: highest tier (e.g., College, High School, Travel, Recreation)
- Contest Division: age/skill tier within a level (e.g., 8U, Varsity)
- Season: separate fields for year and timeframe (e.g., 2025 + Fall)
