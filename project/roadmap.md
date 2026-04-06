# Contest Schedule Frontend Roadmap

## Requirements Log (ongoing)

### Current Priorities
- Priority 1: **COMPLETE** — MVP scope finalized. See [MVP-SCOPE.md](MVP-SCOPE.md) for detailed feature list, week-by-week implementation plan, resource allocation, and success criteria. MVP targets 3–5 weeks engineering + 4–5 months total (with backend, frontend, DevOps, QA).

### TODO
- **Officials Manual Entry Screen** — Officials associations need a form to manually add a single official (person + address + phone + official_config + association membership) from the Officials view. Should create the full composite record in one submission, same as the import but for a single official via a dialog/form. Route: Officials view dialog or `/officials/new`.
- **Platform Config Page** — Under the Platform nav section (platform_admin only), add a Platform Config view to configure base system settings (e.g., feature flags, global defaults, system parameters). Route: `/admin/platform-config`. Guard: `requireRole('platform_admin')`.
- **Tier Expiration Cron Job** — Nightly cron (billing-proc or dedicated K8s CronJob) that checks `subscription_tier.stop_date`. If `stop_date < CURRENT_DATE`, set `is_active = false` and write an audit row to `subscription_tier_date_audit` with `changed_by = 'system:tier-expiry-cron'`.
- **Tenant Dashboard** — Per-tenant deep-dive dashboard accessible from the Tenants list (platform_admin only). The current Tenants page serves as a summary/list view; this dashboard provides a holistic management interface for a single tenant. Route: `/admin/tenants/:id/dashboard`. Sections:
  - **Overview**: tenant name, status (active/inactive), created date, primary contact, branding preview.
  - **Subscription History**: timeline of all subscriptions (active, cancelled, suspended) with tier changes, proration invoices, and effective dates. Shows the full lifecycle — not just the current subscription.
  - **Billing History**: all invoices for the tenant's associations — draft, sent, paid, past due, voided. Drill into invoice detail with line items (including proration credits/charges from tier changes). Running totals, outstanding balance, payment history.
  - **Associations**: list of officials associations under the tenant with membership counts, subscription status per association, and links to association detail.
  - **Usage & Activity**: active official counts over time, assignment volume, contest counts — key operational metrics for the tenant.
  - **Audit Log**: aggregated audit trail for tenant-scoped actions (subscription changes, tier changes, status changes, role changes).
  - **Notes / Admin Actions**: platform admin can add internal notes, trigger manual actions (suspend, reactivate, change tier, issue credit), and view action history.

### Core Platform
- Multi-tenant: League tenants (scheduling/tournaments), Officials tenants (assignments), Public users (parents/coaches/fans).
- Responsiveness: all screens function beautifully on phones, tablets, desktops; some optimized for larger screens.
- Platform Admin: separate application for platform-level administration and analytics.
- Telemetry & Audit: track clicks, API requests, data displayed with privacy safeguards; dashboards for product and ops metrics.
- Dashboards: League, Officials, Platform, and lightweight Public dashboards with shared charting primitives and RBAC.
- Authentication & Authorization: AWS Cognito for identity; **AWS Verified Permissions** (Cedar) for production authorization. Local dev uses JWT-embedded entitlements via DB-backed RBAC (see ADR-0034). 68 fine-grained entitlements (17 resources × 4 CRUD operations) with tenant-scoped role mappings. Migration path: Phase 1 — Cognito user pools replace mock JWT; Phase 2 — Cedar policy store from DB entitlements; Phase 3 — dual-mode (JWT + Cedar); Phase 4 — remove JWT entitlements, per-request Cedar authorization; Phase 5 — tenant-admin Cedar policy management. Production benefits: instant role revocation, per-request audit logging, policy-as-code in version control.
- MFA: multi-factor authentication enabled by default for all users.
- SSO: optional future support (Google/Microsoft/SAML) via Cognito federation.
- Session Policies: define session duration, idle timeout, refresh lifetimes, and token rotation.
- APIs: pagination required and rate limits enforced per tenant/app.
- Tenant Branding: tenants can brand portals with name, logo, and color scheme; default design system branding provided when absent.
- Tenant Invitations & Onboarding: owner invites tenants, verifies identity, provisions environments and roles.
- Notifications & Messaging: email/SMS for officials, leagues, and public; user preferences for delivery timing/channels; owner override with audit.
- Officials Subscription & Fees: charge officials for system use with per-tenant default fees and owner-controlled discounts/surcharges.
- **Cross-Tenant Data Access** (see ADR-0028): Officials associations require configurable access to sports association contest data for assignments and game execution. Three-tier model: Required (always accessible: date/time, venue, teams, pay rate), Configurable (sports association controls: standings, coach info, venue notes, historical data), Restricted (never shared: financial margins, player PII, internal operations). Configuration stored per relationship with presets (Minimal, Standard, Full) and field-level filtering enforced in API layer.
- **Flexible Payer Model** (see ADR-0029): Contest payers can be tenants, sub-organizations, cost centers, events, third-party organizations, individuals, or informal groups. Billing entity model supports hierarchies, split billing for multi-payer contests, and 1099 reporting for individuals. Backward compatible with existing tenant-based billing.

### Contest Loading (see ADR-0024)
- **Native Creation**:
  - Single contest form with all required/optional fields
  - Bulk contest entry (multi-row editor, copy/paste from Excel)
  - Pre-loaded teams, venues, leagues, divisions, coaches with option to add new inline
- **Import**:
  - File formats: CSV, Excel (.xlsx) with required/optional column definitions
  - Data sources: spreadsheet upload, external API (QuickScores, etc.), web scraping if no API
  - Validation: required/optional columns, data types, business rules (team exists, division in league, no past dates, no duplicates); phase-based with detailed error messages and smart correction suggestions
  - Error handling: all-or-nothing (reject entire file if any fail) or partial (import successful rows, skip failed ones); inline edit suggestions during preview
  - Data mapping: team/venue/coach matching (exact, fuzzy, create new) with user confirmation; league/division must exist
  - Conflict resolution: detect existing contests, guide user to skip/update/duplicate with configurable rules
  - Async processing: small imports (≤100) sync; medium (100–1K) async with progress; large (1K–10K) background jobs; extra-large (>10K) batch processing
  - Rollback: post-import undo capability to revert imported contests with linked data cleanup
  - Audit: full trail (source, uploader, timestamp, counts, external IDs for sync tracking)
- **Configuration**: allow/disable past dates, duplicate games, auto-create teams/venues; timezone handling

### Rules Management (see ADR-0025)
- **Scope**: rules defined per contest level, division, age group; scoped to season
- **Versioning**: version control with change tracking; old versions archived but accessible
- **Content**: rich text editor with sections, numbering; on-screen display and PDF download
- **Approval Workflow**: multi-step (league director → association president); comments, rejections, audit trail
- **Officials Association Acknowledgment**: association admin acknowledges rule changes on behalf of organization
- **Individual Official Acknowledgment**: each official must acknowledge initial rules and any changes; block assignment acceptance if pending (configurable)
- **Notifications**: rule change notifications with change summary (minor/major); reminder escalation (7d → 3d → 1d)
- **Audit Trail**: all acknowledgments, approvals, timestamps, versions logged for compliance
- **PDF Generation**: branded templates with version, effective date; watermark for draft/pending status

### League Scheduling & Constraints
- Blackout dates: league owners define periods when games cannot be scheduled (holidays, tournament breaks).
- Venue constraints: set availability windows, max concurrent games per venue, setup/teardown times.
- Official rosters: manage certified officials per division/sport, certification expiry, availability calendars.
- Scheduling rules: enforce divisional separation, geographic bounds, official rest periods, rotation policies.

### Tournament Management
- Tournament formats: single elimination, double elimination, round-robin, custom brackets.
- Seeding algorithms: auto-seed by ranking or user-selected, handle byes and uneven participant counts.
- Bracket generation: auto-generate or manually configure; handle game sequencing and advancement logic.
- Tiebreaker rules: define per-sport (head-to-head, point differential, strength of schedule, etc.).

### Officials Assignment & Matching
- Assignment algorithm: recommend best officials based on location, availability, certifications, workload balance, preferences.
- Travel distance: calculate distances, enforce distance limits, optimize crew assignments (minimize travel).
- Certification matching: ensure officials have required sport/level certification; enforce specialization (crew chief, umpire, etc.).
- Preferences & constraints: officials mark preferred/unavailable times, games, venues; track no-show history and reliability.
- Workload balancing: ensure fair distribution across officials; prevent over/under-utilization per season.
- **Location Tracking & Arrival ETA** (see ADR-0023):
  - Officials opt-in to location tracking (per-assignment or global); tracking window configurable (default 60 min before game start) with hierarchical overrides (global → officials assoc → sports assoc → venue → individual official)
  - Real-time location updates (1–5 min intervals when enroute); ETA calculation using traffic APIs (Google Maps/Mapbox) with dynamic updates
  - Status tracking: not_started, enroute, arrived, departed (for multi-venue days); geofence detection within 100m of venue
  - Multi-venue support: track official across multiple venues on same day with per-venue arrival/departure times; alert if insufficient transit time between venues
  - Punctuality alerts: configurable threshold via hierarchy (default 15 min before start, overridable per assoc/venue/official); escalation at T-10, T-5; alert sports/officials associations and official if not at venue
  - Notifications: sports/officials associations notified when official enroute, ETA < 15 min, arrived, late alert; multi-venue routing updates with ETAs
  - Punctuality audit: track arrival time vs game start; metrics (early/on-time/late rate, avg early arrival, late incidents count, trend); retention: arrival times indefinitely, coordinates 90 days
  - Dashboard views: officials association map/list of all active officials with locations/ETAs/late alerts; sports association per-game official status with multi-venue schedules
  - Privacy: location coordinates deleted after 90 days; arrival/departure times retained for audit (3 years); explicit consent required; no tracking outside assignment window; GDPR-compliant
  - Mobile app: officials enable/disable tracking, view own ETA and multi-venue route, geofence arrival/departure confirmation, punctuality feedback
  - Battery optimization: geofencing and significant location change APIs to minimize drain; reduce frequency if stationary
  - Punctuality reports: per-official summary (rate, avg early time, late incidents) filterable by date/venue/level; export CSV/PDF
  - Configuration UI: admins set tracking start window and late alert thresholds at global/association/venue/official levels with inheritance preview

### Officials Game Report Workflow (see ADR-0027)
- **Configurability**: all aspects hierarchically configurable (global → officials org → sports org → division → per-game override):
  - Required scope: all games, none, or specific types (playoff, tournament, custom)
  - Signatory model: single-official, crew-wide, or hybrid
  - Blocking behavior: blocks contest close-out, informational only, or delayed blocking (24–48 hours)
  - Visibility level: internal (officials/admin only), team-visible (coaches see reports), or public
  - Dispute mechanism: optional flag for disagreements on report content; league director reviews and resolves
  - Templates & free-form: pre-defined incident types + optional notes, or free-form text, or both
- **Report entry**: officials select template or free-form; attach evidence (photos/videos); crew-wide model requires acknowledgment from all signatories
- **Approval workflow**: league director approves, rejects, or requests revisions; responds to dispute flags with contact/decision
- **Immutable finalization**: once approved, reports read-only; amendments create new records (never overwrite); audit trail immutable for compliance
- **Post-finalization amendments**: officials/admins request corrections; league director approves/denies with notes; side-by-side view of original vs. amended
- **Privacy & access controls**: officials see own reports; league director sees all; coaches/public see based on visibility config; compliance always has access
- **Notifications**: initial reminder on contest completion, follow-ups (2h, 24h, 48h, 72h), dispute escalation, approval notification with summary
- **UI features**: dashboard (pending reports, due dates), entry form (template selector, free-form editor, evidence uploader), review modal (crew acknowledgment), approval queue (league director), amendment panel, analytics (incident patterns, dispute rate, SLA tracking)
- **Mobile**: responsive form design; voice input option for free-form; in-app evidence capture

### Coach Score Entry & Dispute Resolution (see ADR-0026)
- **Workflow**: coaches from both teams enter final scores post-game; two-coach approval with auto-finalize if both agree or both dispute same reason
- **Dispute resolution**: league director reviews both submissions and coach notes; selects correct score or requests re-entry; dispute documented in audit
- **Post-finalization edits**: coaches/admins request corrections with reason; league director approves/denies; all changes logged (old/new/who/when/why)
- **Escalating reminders**: T+0 (immediate), T+1 day, T+2 days, T+3 days with configurable message and channels (email/SMS)
- **Standings integration**: update standings after approval (not retroactively); supports brackets and tournament advancement
- **Notifications**: reminders to coaches, notifications to league admin on entry/dispute/resolution, dispute outcome to coaches
- **Data models**: ContestScore (with finalizedAt, status, scoreCorrectionHistory audit), ScoreEntryReminders, ScoreReminderPolicy
- **UI features**: entry form, review modal, admin dashboard, dispute panel, correction audit trail, standings view

### Billing & Monetization
- Subscription plans: define tiers for league tenants (starter, pro, enterprise); include feature limits and pricing.
- Usage-based billing: track game counts, official assignments, tournament creation; charge based on overage thresholds.
- Officials fees: per-tenant default fees with owner discounts/surcharges; monthly invoicing and proration.
- Refund & dispute handling: process refunds, credits, and chargebacks; dispute resolution workflow and audit.
- Revenue reporting: dashboards for MRR, churn, ARPU, customer lifetime value; per-tenant and segment analytics.

### User Roles & Access Control
- League admin: full control over leagues, teams, schedules, tournaments, rosters, invitations, settings.
- League coordinator: limited scheduling and team management, cannot modify billing or users.
- Officials admin (tenant): manage official rosters, availability, assignments, assignments confirmation, payout status.
- Official: confirm assignments, view earnings, manage availability, submit pay stub requests.
- Viewer (parent/coach/fan): read-only access to standings, schedules, rankings, team pages.
- Platform admin: global control over tenants, billing, RBAC, audit, feature flags, support tools.

### Public Portal & Visibility
- Leagues directory: searchable list of public leagues and tournaments.
- Team pages: view team roster, schedule, standings, past results.
- Game/schedule pages: public game details (teams, venue, time); live score updates if enabled.
- Standings & rankings: division standings, individual rankings, leaderboards.
- Tournament brackets: public bracket visibility with advancement tracking.
- Access control: tenants can set leagues/tournaments as public or private; restrict data by role.

### Data Protection & Compliance
- Data residency: support per-region deployments (US, EU); configurable per tenant.
- Data retention: define retention policies (active data, archival, deletion); audit deletion history.
- PII handling: minimize collection; mask in reports/exports; separate storage for sensitive fields (SSN, bank details).
- GDPR/regional: support data export, deletion, and right-to-be-forgotten; consent/opt-in records.
- Encryption: TLS 1.3 in transit; KMS-backed encryption at rest; field-level encryption for high-risk PII.

### 1099-NEC Reporting (see ADR-0030)
- W-9 collection & verification: capture via secure flow; store only last4 + `external_vault_ref` to full TIN; `w9_status` and `backup_withholding_required` tracked.
- Official tax profiles: one per official per association using `official_tax_profile` (legal name, TIN type, last4, vault ref, delivery prefs, mailing address).
- Annual aggregation: compute `nonemployee_compensation` from payouts for each official per tax year.
- Form generation: produce IRS-compliant 1099-NEC PDF; store `document_url`; support corrections via `corrected_from_id`.
- Delivery: electronic (with explicit consent) or paper mailing; track `issued_at` and `delivered_at`.
- Privacy: never store full SSN/EIN in platform DBs; KMS/tokenization or third-party vault custody.
- Audit: log issuance, delivery, corrections in `audit_log`; configurable retention.

### Audit & Logging
- Audit scope: log all user actions (create/update/delete), RBAC changes, payment events, data access, admin overrides.
- Immutable logs: audit records append-only and time-stamped; tamper-evident with hashing/signing.
- Retention: configurable retention (7 years for financial, 3 years for general) by policy.
- Export & reporting: audit exports for compliance reviews; dashboards for access patterns and anomalies.
- Alerts: detect suspicious patterns (bulk downloads, privilege escalation, unusual API usage).

### Reporting & Analytics
- League reports: games scheduled, officials assigned, completion rate, no-shows, cost per game.
- Officials reports: earnings by period, assignment acceptance rate, no-show rate, utilization.
- Platform reports: tenant growth, DAU/MAU, feature adoption, billing health, support ticket volume.
- Custom exports: CSV/PDF for schedules, rosters, pay stubs, invoices; RBAC-controlled access.
- Performance dashboards: real-time API latency, error rates, ingestion health; per-tenant metrics.

### Integrations
- Calendar integrations: export schedules to Google Calendar, Outlook, iCal; bi-directional sync where feasible.
- Email/SMS providers: SES (email), SNS/Pinpoint/Twilio (SMS); template engine with variable substitution.
- Payment providers: Stripe or Adyen for card/ACH; tokenization and webhook reconciliation.
- Search/analytics: OpenSearch for schedule/team/official search; read models for fast queries.
- Event bus: EventBridge or Kafka for domain events; enable async processing and event replay.

### Notification & Communication
- Notification channels: email, SMS, in-app push; per-user preferences for timing (real-time, digest, quiet hours).
- Notification topics: game updates, assignment changes, payment confirmations, official confirmations, announcements.
- Suppression lists: opt-out management, unsubscribe links, regional compliance (CAN-SPAM, TCPA).
- Owner override: platform admin can force-send notifications for critical updates; audit trail and time-bounded.
- Delivery & retries: exponential backoff, idempotency keys, delivery status tracking, bounce handling.

### Billing & Payments
- **Tenant Subscriptions & Usage-Based Billing** (see ADR-0018):
  - Tiered plans: Starter ($99/mo), Pro ($299/mo), Enterprise (custom)
  - Usage overages: games ($0.50), officials ($1.00/mo), API calls, storage
  - Billing cycles: monthly or annual (15% discount); pro-ration for mid-cycle changes
  - Dunning workflow: failed payment retries over 7 days; suspension after
- **Officials Association Fees** (see ADR-0018):
  - Per-official subscription: configurable default (e.g., $8–15/mo), per-tenant adjustable
  - Per-official adjustments: discounts, surcharges, coupons with stacking rules
  - Payment paths: deduct from payouts or direct payment (card/ACH)
- **Officials Subscription & Multi-Association** (see ADR-0019):
  - **Yearly subscription** (not monthly) for officials (e.g., $15–50/year)
  - Officials association invites officials to join their tenant
  - **Multi-association support** with flexible billing strategies:
    - **Per-Association**: charge separately for each association membership
    - **Flat-Rate Unbounded**: single fee covers all associations official joins
    - **Hybrid/Tiered**: first free/base rate, additional associations charged per-add-on (capped)
    - **Association-Specific**: each association sets own fee rate
  - **Tenant-level configuration**: choose billing strategy per tenant; audit changes
  - Annual invoicing: consolidated or per-association (configurable)
  - Renewal cycle: 60d reminder → 30d notice → 7d final → auto-charge → 3 retries if fail
  - Proration: officials joining mid-year charged pro-rated amount; full renewal next cycle
  - Grace period & suspension: overdue but readable (14d); suspended if unpaid beyond grace
  - Future flexibility: support monthly, multi-year discounts, family plans
- **Convenience Fees** (see ADR-0014):
  - Card/wallet: +2.9% + $0.30; ACH included (no fee)
  - Tenant absorbs or passes to customer (configurable)
- **Downstream Invoicing for Officials Organizations**:
  - Officials organizations (as tenants) serve sports associations and individual customers.
  - They must issue invoices to those customers and receive payments on those invoices (card/ACH/wallets).
  - Customers may or may not be tenants in the platform; invoicing must work for external orgs/individuals without tenant records.
  - Require reconciliation status (paid/partial/failed) and export for finance.
- **Customer Administration Fee**:
  - Per-customer toggle: officials association designates whether a customer is billed an admin fee.
  - Fee types: `percentage`, `fixed`, or `percentage_plus_fixed` (percentage of subtotal plus a flat dollar amount on top).
  - Customer-level defaults stored on the customer record (`charge_admin_fee`, `admin_fee_type`, `admin_fee_percent`, `admin_fee_amount`).
  - Invoice-time override: defaults pre-populated on invoice; association can keep, adjust percentage, change dollar amount, combine percentage + fixed, or waive for a single invoice.
  - Admin fee rendered as a distinct invoice line item (`reference_type = 'admin_fee'`) for transparency.
  - Audit: overrides from default logged with original and changed values.
  - See [CUSTOMER-MANAGEMENT.md — Administration Fee](CUSTOMER-MANAGEMENT.md#administration-fee-per-customer-billing-add-on) for full specification.
- **Contract Lifecycle Management Fees** (see ADR-0017):
  - Setup fee: $25–50 per contract
  - Annual subscription: $100–300/year (unlimited contracts)
  - Per-renewal fee: $15–25
  - Hybrid models supported; renewal failure handling with retries
- **Payment Methods**: cards, ACH, wallets, PayPal, manual (Venmo/Zelle/checks)
- **Tax Handling**: auto-calculate based on address; tax-exempt support; regional VAT/GST
- Scope: subscriptions, plans, usage-based charges (e.g., game volume), invoices, payments, dunning, tax.
- Data model: `Invoice`, `LineItem`, `Subscription`, `Plan`, `UsageRecord`, `TaxRate`, `Payment`, `Refund`, `CreditNote`.
- Features:
  - Generate monthly invoices with usage snapshots and taxes; pro-ration for mid-cycle changes.
  - Send invoices (PDF/email) with payment links; record payment status and retries.
  - Dunning workflows (reminders, suspension rules); finance exports.
  - Platform Admin dashboards for MRR, churn, AR aging, failed payments.
- Compliance: tax calculation integrations; PCI handled by provider; PII minimized.
- Payment methods (tenants): credit/debit cards (Visa/Mastercard/Amex), ACH bank transfer, digital wallets (Apple Pay/Google Pay), optional PayPal; support manual reconciliation for Zelle/Venmo/checks if policy allows.

### Support & SLA Tiers (see ADR-0018)
- **Community** (included): email support 48h response; help center access; no SLA
- **Standard** (+$50/mo or Pro/Enterprise): email + chat support 24h response; 99.5% uptime SLA
- **Premium** (+$150/mo or Enterprise): phone/chat/email 2h response; dedicated specialist; 99.9% uptime SLA; QBRs
- **Enterprise**: included; 24/7 support; 99.95% uptime SLA with credits; success manager

### Premium Add-Ons & Features (see ADR-0018)
- **White-Label Branding** (+$100–200/mo): custom domain, branded emails/PDFs, remove platform branding
- **Advanced Analytics & Reporting** (+$75/mo): custom dashboards, cohort analysis, predictive insights, BI export, scheduled delivery
- **Custom Integrations & Webhooks** (+$50/mo + $500 setup): webhook delivery to external systems, custom API endpoints, bulk import/export
- **Enhanced Security & Compliance** (+$200/mo): SAML/SSO setup, BYOK, compliance audit prep
- **AI-Driven Assignment & Scheduling** (+$150/mo): ML-based official matching, constraint solving, no-show prediction
- **Premium Report Templates** ($30/template/mo): custom financial/compliance reports, drag-and-drop designer
- **Advanced Forecasting** (+$200/mo): demand forecasting, churn prediction, revenue scenario modeling
- **Mobile App Premium** (+$25/official/mo): offline mode, push notifications, GPS navigation, biometric auth
- **Data Export & Premium API** (+$50/mo): SQL exports, real-time API with webhooks

### Marketplace & Partner Program (see ADR-0018)
- **Third-Party App Store**: plugin marketplace; 70/30 revenue split; 15% in-app purchase fee; featured listings $500/mo
- **Referral Program**: 20% of first-year MRR for referred customers
- **Channel Partners**: dedicated support, margin discounts, co-marketing

### Professional Services (Optional) (see ADR-0018)
- **Implementation**: onboarding consultation ($1K–5K), data migration ($500–2K), workflow config ($200/hr), training ($1.5K/day)
- **Consulting**: scheduling optimization ($2K–10K), business process ($2.5K/day), compliance prep ($3K–10K)

### Billing & Invoicing (Tenants)
- Scope: subscriptions, plans, usage-based charges (e.g., game volume), invoices, payments, dunning, tax.
- Data model: `PayRate`, `AssignmentEarning`, `PayPeriod`, `PayStub`, `Withholding`, `Payout`, `Adjustment`.
- Features:
  - Compute earnings per assignment with divisional/venue/time modifiers; batch per pay period.
  - Generate pay stubs (PDF/HTML) with line items, taxes, net pay; deliver via portal/email.
  - Payouts via provider (ACH); track statuses and reconcile.
  - Officials Admin dashboards for coverage %, earnings by period, payout statuses.
- Compliance: handle sensitive data with masking/encryption; regional rules; export auditing.
- Payout methods (officials): ACH direct deposit (primary), mailed checks (fallback), instant debit payouts (optional via provider); Zelle/Venmo only if policy permits, with manual reconciliation and compliance review.

### Payment Reconciliation
- Tenant payment reconciliation: track invoice payment status (sent, viewed, partial, paid, overdue, failed); retry policies.
- Payout reconciliation: ACH status tracking (pending, settled, returned, failed); investigate returns/NSFs; reversal handling.
- Manual payment reconciliation: log Venmo/Zelle/check payments; match to invoices/payouts; operator approval workflow.
- Discrepancy handling: flag missing reconciliation; escalate for investigation; audit trail of resolutions.

### Contract Lifecycle Management & E-Signature
- Scope: manage contracts between leagues and officials associations with e-signature, renewal reminders, and fee-based monetization.
- Platform templates and custom uploads: support pre-built and tenant-specific contract templates with variable substitution and branding.
- E-signature via DocuSign: create envelopes, send for signature, track signatories, store signed documents securely.
- Renewal automation: configure renewal policy (auto-renew, manual, hybrid); send expiration reminders (90d, 30d, 7d before expiry).
- Fee models: per-contract setup fee, annual subscription add-on, per-renewal fee, or hybrid; configurable per tenant.
- Billing integration: contract fees added to monthly/annual invoice; failed billing blocks renewal.
- Audit & compliance: immutable audit trail, signature non-repudiation, encrypted storage, retention per policy.
- See ADR-0017 for detailed workflow, data models, and extensibility patterns (support for other e-sign providers).

## Revenue Model Summary (see ADR-0018 & ADR-0019)
- **Tenant Subscriptions**: Starter ($99/mo), Pro ($299/mo), Enterprise (custom); 15% annual discount; pro-ration
- **Usage Overages**: games ($0.50), officials ($1.00/mo), API ($0.001 per 1000 calls), storage ($0.05/GB/mo over 10GB)
- **Officials Subscriptions (Yearly)**: $15–50/year per official; configurable multi-association billing:
  - Per-association (charge for each association official joins)
  - Flat-rate unbounded (single fee covers unlimited associations)
  - Hybrid/tiered (first free/base, additional charged per-add-on, capped)
  - Association-specific (each association sets own fee)
- **Officials Association Invitations**: admins invite officials → officials accept + subscribe yearly
- **Contract Management**: setup fee ($25–50), annual subscription ($100–300/year), per-renewal ($15–25)
- **Support Tiers**: Community (included), Standard (+$50/mo, 99.5% SLA), Premium (+$150/mo, 99.9% SLA), Enterprise (custom)
- **Premium Add-Ons**: white-label (+$100–200/mo), analytics (+$75/mo), integrations (+$50/mo + $500), security (+$200/mo), AI assignment (+$150/mo), mobile premium (+$25/official/mo), forecasting (+$200/mo)
- **Convenience Fees**: card/wallet 2.9% + $0.30; ACH included
- **Marketplace**: 70/30 plugin split; 15% in-app purchase fee; referral 20% first-year MRR
- **Professional Services**: onboarding, data migration, consulting, training
- **Target Mix**: 70% subscription, 10% overages, 8% contract/officials, 8% premium add-ons, 3% payment margins, 1% other (ads, marketplace)
- **Financial Metrics**: track MRR, ARR, ARPU, LTV, CAC, churn, expansion revenue, ad revenue per user
- **Public Portal Advertising** (see ADR-0020): Non-intrusive ads on public portal only (not in paid portals)
  - Ad types: sidebar banners, below-fold, sponsored listings, contextual search results
  - Pricing: CPM ($2–5), CPC ($0.10–0.50), CPA (5–15% commission), sponsorship ($1–5K/mo)
  - Advertiser categories: sports equipment, apparel, local restaurants/venues, sports services
  - Year 1 projection: $150–300/mo, Year 2: $750–1.5K/mo, Year 3: $3–6K/mo
  - Frequency caps & brand safety to avoid annoying users; zero ads in paid tenant portals

## Additional Features & Enhancements (Prioritized)

### Priority 1: High-Impact Core Features (implement early)

**Help Center & Knowledge Base**
- Searchable FAQs, video tutorials, tenant-specific documentation.
- In-app contextual help (tooltips, guided tours, inline docs).
- Self-service articles reduce support burden; analytics track popular topics.

**Full-Text Search & Advanced Filtering**
- Search officials (by name, location, certification), leagues, teams, schedules, results.
- Faceted filtering: sport, division, location, certification, availability, rating.
- Saved searches & alerts: officials track games in their area; leagues monitor high-demand periods.
- Elasticsearch/OpenSearch for fast, scalable search; read models for analytics.

**Address Validation & Geocoding**
- Validate addresses for tenants, officials, and venues during onboarding/data entry.
- Geocoding service integration: Google Maps API, USPS, Mapbox, or SmartyStreets.
- Standardize addresses to USPS format; populate latitude/longitude for distance calculations.
- Automated geocoding on address save; batch geocode for imported data.
- Address deduplication: detect and merge duplicate addresses across entities.
- Timezone detection: automatically set timezone based on address for scheduling across regions.
- Distance calculations: "Find officials within X miles of venue" using geospatial queries.
- Address validation during invoice/payment flows to ensure proper billing.
- Validation indicators in UI: show verified checkmark, suggest corrections for invalid addresses.

**Rules Engine & Workflow Automation**
- Auto-generate officials assignments based on configurable rules (location, availability, certification, workload).
- Event-driven triggers: send reminders (game day -24h, confirm -48h), escalate overdue confirmations.
- Cron jobs: process billing runs, archive old data, send batch notifications.
- Webhooks for custom integrations: tenants hook into events (game created, official assigned, payment made).

**Anomaly Detection & Alerting**
- Flag unusual patterns: sudden no-shows, payment failures, access spikes, unusual API usage.
- Auto-escalate high-severity issues (revenue impacts, security events) to support/ops.
- Machine learning: predict churn risk, identify certification expiry gaps, recommend pricing optimizations.

**Support Tooling & Impersonation**
- Support ticketing: issue reporting, queue management, SLA tracking, agent dashboards.
- Platform admin impersonation: log in as tenant/user for troubleshooting without revealing passwords.
- Session audit: track all impersonation with justification and audit trail.

**Document Signing & E-Signature (DocuSign Integration)**
- E-sign agreements during onboarding: Terms of Service, DPA, liability waivers, contracts.
- Auto-generate documents from templates; tenant customization support.
- Signature tracking and tamper-proof records; audit trail of signatories and timestamps.
- Send reminders for unsigned documents; track completion status.
- Compliance: signed documents stored securely; GDPR/CCPA compliant.

### Priority 2: Important (implement mid-phase)

**Background Checks & Compliance**
- Track background checks for officials (officials associations) and coaches/volunteers (sports associations).
- Configurable renewal policy: hierarchical intervals (global → org → division/role), reminder schedule (60d/30d/7d), blocking options (block/warn/none).
- Provider integration: Checkr/Sterling; store provider reference IDs, status, `document_url`; avoid storing detailed report data.
- Admin dashboards: filters for expiring soon/overdue; assignment gating indicators per policy.
- Compliance tracking: certifications, insurance requirements, verification status.
- Liability & waivers: track signed waivers, insurance coverage, eligibility.
- Document management: store contracts, NDAs, certifications, insurance docs with encryption.

**Mobile-First & Offline Capabilities**
- Responsive web app design or native iOS/Android apps for officials.
- Offline sync: view/confirm assignments, manage availability without connectivity; sync on reconnect.
- Push notifications: game alerts, assignment updates, payment notifications.
- Location-aware features: show nearby games, calculate travel times, navigate to venues.

**Synthetic Monitoring & Reliability**
- Automated health checks for critical paths (login, schedule view, payment); alerting on failures.
- Error budgets & SLOs: define uptime targets (e.g., 99.9%); track error budgets per tenant.
- Incident playbooks: documented responses for common scenarios; post-mortem culture.
- Chaos engineering: test failure modes (DB failover, cache failures, provider outages).

**Feature Flags & Gradual Rollouts**
- Tenant-level feature toggles: gradually roll out new features; A/B testing for experimentation.
- Kill switches for emergency feature disables; tenant-specific overrides.
- Experiment tracking and analytics: measure adoption and impact of new features.

**Analytics & Insights**
- Cohort analysis: group officials/leagues by behavior; track retention and engagement.
- Predictive insights: forecast demand, identify churn risk, recommend optimizations.
- Recommendations engine: suggest best officials for upcoming games; highlight high-demand divisions.
- Dashboards: per-tenant/per-role analytics; exportable reports.

### Priority 3: Nice-to-Have (implement later as polish)

**Community & Social Features**
- Official profiles & portfolios: showcase certifications, game history, reliability scores, ratings.
- Leaderboards & achievements: top officials, badges (reliable, punctual, veteran), gamification.
- Reviews & ratings: league coordinators rate officials post-game; aggregate ratings and feedback.
- In-app messaging & comments: direct messaging, comments on schedules/results, announcements.

**Deep Customization & Extensibility**
- Custom fields: allow tenants to add sport/org-specific metadata (player positions, official specializations).
- Custom workflows: non-code configuration of approval chains, notification rules, scoring systems.
- UI theming beyond branding: terminology/label customization per sport/org.
- Plugin/extension marketplace: third-party integrations, scheduling plugins, templates.

**Content & Localization**
- Multi-language UI (Spanish, French, etc.); right-to-left support for Arabic/Hebrew.
- Date/time/number localization per timezone and locale; regional currency.
- I18n translations for notifications, reports, and help content.

**Gamification (Optional Engagement)**
- Official streaks: track consecutive games without cancellation, personal stats.
- Certification levels: rank officials by expertise; unlock new assignment types.
- Team/league milestones: celebrate achievements (100th game, 5-year anniversary).
- In-app notifications for badges/achievements: motivate officials, build community.

### Priority 4: Infrastructure & Operations (concurrent with features)

**Modern Infrastructure** (see ADR-0032):
- Kubernetes (EKS): Container orchestration with autoscaling and multi-AZ deployment
- Flux CD: GitOps-based continuous deployment with automatic drift reconciliation
- Helm: Package management for all applications with versioned chart releases
- Istio: Service mesh with automatic mTLS, traffic management, and observability
- cert-manager: Automated TLS certificate management with Let's Encrypt + AWS ACM
- External Secrets Operator: Secure secrets synchronization from AWS Secrets Manager

**Performance & Scalability Hardening**
- Caching strategy: define cached entities (rosters, standings, search indices); cache invalidation policies.
- Database optimization: indexes on common queries, materialized views for slow reports, query analysis.
- CDN for assets: serve logos, PDFs, images globally; cache-busting via versioned URLs.
- Async job queue: bulk imports, report generation, payout batching; worker pools and retries.

**Versioning & Change Management**
- API versioning: deprecation windows (e.g., 6–12 months), migration guides, breaking change communication.
- Data schema versioning: handle evolution (add fields, rename); backward compatibility; migration scripts.
- Feature deprecation: sunset policies; customer notification; migration paths.
- Release notes & changelogs: transparent communication of features, fixes, breaking changes.

**Cost Optimization & Resource Management**
- Usage monitoring dashboard: track API calls, storage, compute per tenant; cost attribution.
- Rate limiting policies: tiered limits by subscription; burst allowances; fairness algorithms.
- Data lifecycle: archive old games/results; compress storage; delete per retention policy.
- Infrastructure as code: Terraform/CDK for repeatable deployments; multi-region setup; cost modeling.

**Disaster Recovery & Business Continuity**
- Automated backups with tested restore procedures; RTO/RPO definitions per criticality.
- Multi-region failover: replicate data; active-passive or active-active setup; regional redundancy.
- Data export & portability: tenants can export all data for migration or compliance.
- SLA guarantees: uptime credits, communication playbooks for outages, incident response plans.

**Regulatory & Compliance Reporting**
- Regulatory exports: data for league/federation reporting, eligibility verification, audit trails.
- GDPR/CCPA compliance: data subject requests, deletion workflows, consent management.
- Tax & financial reporting: export invoices/pay stubs in regional formats; tax-form integration.
- Audit exports: comprehensive audit logs for compliance reviews; immutable timestamped records.

## Prioritization Strategy
- **Phase 1 (MVP + Core Value)**: Core scheduling, officials assignment, basic billing, tenant invitations, RBAC, telemetry.
- **Phase 1.5 (First Improvement Cycle)**: Search, rules engine, help center, anomaly detection, support tooling (Priority 1).
- **Phase 2 (Depth)**: Background checks, mobile, monitoring, feature flags, analytics (Priority 2).
- **Phase 3 (Scale & Polish)**: Social features, customization, gamification (Priority 3).
- **Concurrent (Always)**: Performance hardening, versioning, cost optimization, disaster recovery (Priority 4).

Success metrics:
- Phase 1: <10s page load, >95% uptime, <5% official no-show rate, first paying tenant.
- Phase 1.5: search adoption >70%, support ticket volume -30%, rule-based assignments >80% success.
- Phase 2: mobile app >10k installs, churn <5%, NPS >40.

## Architecture
- Monorepo using `pnpm` workspaces + Turborepo/Nx
- Apps: `league-admin`, `officials-admin`, `public-portal`
 - Shared packages: `ui`, `types`, `api`, `config`, `telemetry`

### Recommended Runtime Architecture
- Frontend → BFF: Each app communicates only with its dedicated Backend-for-Frontend (BFF). The BFF tailors endpoints, enforces auth/tenant context, normalizes pagination/errors, aggregates data, and applies caching.
- BFF → Proc Layer: The BFF forwards requests to "processing/orchestration" domain services that implement business workflows (e.g., schedule generation, official assignment, billing runs). These services coordinate multiple system APIs.
- Proc Layer → System APIs: System-level microservices own data models and CRUD (e.g., leagues, teams, schedules, officials, assignments, billing, telemetry). They expose stable, versioned APIs and events.
- Eventing & Read Models: Use an event bus (AWS EventBridge/Kafka) to publish domain events; build read models/search indices (OpenSearch/Elasticsearch) for fast queries and dashboards (CQRS where useful).
- API Gateway & Security: AWS API Gateway fronting BFF and/or proc services with Cognito JWT authorizers, WAF, usage plans, and rate limits. Services verify roles/scopes and tenant boundaries server-side.
- Observability: Distributed tracing (X-Ray/OpenTelemetry), structured logs with `requestId/tenantId`, metrics, and SLO dashboards.
- Data Boundaries: Clear ownership per service; cross-service contracts via APIs and events; avoid shared DBs.

### Why BFF + Proc Layer
- Pros: UI-specific aggregation without leaking internal complexity; cleaner separation of orchestration from data ownership; better performance/caching; simpler FE contracts.
- Cons: More services to operate; mitigated by strong automation and shared libraries.

### Alternatives Considered

## Design System
- Goals: consistent look-and-feel across all apps, accessibility-first, responsive by default, and performance-conscious.
- Tokens: color, typography, spacing, radii, shadows, z-index, motion; defined as CSS variables and TypeScript enums for runtime/compile-time use.
- Components: buttons, inputs, selects, date/time pickers, dialogs, drawers, tabs, tables, pagination, cards, alerts, toasts, steppers, breadcrumbs.
- Patterns: list→detail, wizard/stepper, filter panels, bulk actions, inline editing, sticky action bars; mobile-first adaptations.
- Theming: light/dark + tenant branding (primary/secondary); theme switch via CSS variables and prefers-color-scheme.
- Tenant Branding
  - Config: per-tenant `displayName`, `logo` (SVG/PNG), `favicon`, and color tokens (`primary`, `secondary`, `accent`, `neutral`).
  - Defaults: fall back to design system defaults when tenant branding is not configured.
  - Application: load tenant theme from BFF on session init; apply via CSS variables; persist across routes; no FOUC (flash of unstyled content).
  - Assets: store logos/favicons in S3 with CloudFront CDN; cache-busting via versioned URLs.
  - Constraints: enforce contrast ratios, reserved semantic colors, and accessibility checks; lint rule to prevent hard-coded colors in apps.
  - Scope: branding applies to portals (league-admin, officials-admin, public-portal); platform-admin uses platform theme with minimal tenant visuals.
  - Emails & PDFs: use branding in email templates and PDF (invoices, pay stubs) when permitted.

- Accessibility: WCAG 2.2, focus rings, ARIA roles/labels, keyboard navigation, reduced motion support; lint rules and automated checks.
- Motion & Icons: standardized durations/easings; icon set with clear semantics; avoid non-informative animations.
- Documentation: living Storybook with usage examples, do/don'ts, accessibility notes, and code snippets.
- Implementation: shared package `@contest/ui` providing tokens, utilities, and Vue components; used across all apps.
- Governance: review process for new components; versioning and changelog; deprecation policy.
- FE → System APIs directly: fewer layers, but leaks domain complexity to FE, increases coupling, and hurts performance/caching opportunities.

## Scaffolding
- Base stack: Vue 3, TypeScript, Vite, Pinia, Vue Router, Axios
- Shared setup: path aliases, env handling, axios interceptors
- UI tokens: color system, spacing, typography
- Base layout components: header, sidebar, shell

## Domains & Models
- Tenants: `LeagueTenant`, `OfficialsTenant` (branding, timezone, locale, plan, contacts)
- Users: Admins, Coordinators, Officials, Viewers (parents/coaches/fans)
- Core models: `League`, `Season`, `Division`, `Team`, `Venue`, `Game`, `Tournament`, `Bracket`, `Official`, `Assignment`, `Availability`, `Ranking`, `Standing`

## Routing & Access
- Tenant-aware route guards
- Route modules per app
  - League Admin: `dashboard`, `leagues`, `teams`, `schedules`, `tournaments`, `venues`, `settings`
  - Officials Admin: `dashboard`, `officials`, `availability`, `assignments`, `pay`, `settings`
  - Public: `home`, `leagues`, `teams`, `standings`, `rankings`, `schedules`, `game`, `tournaments`

## MVP Page Sets
- League Admin (first 8)
  - Dashboard
  - League Setup
  - Teams CRUD
  - Venues CRUD
  - Blackout Dates
  - Schedule Builder
  - Conflict Resolver (basic)
  - Tournament Builder (seeding + bracket)
- Officials Admin (first 6)
  - Dashboard
  - Officials Roster CRUD
  - Availability Calendar
  - Assignment Planner
  - Assignment Review
  - Messaging (basic)
- Public Portal (first 6)
  - Leagues Directory
  - League Schedule
  - Team Directory
  - Team Page
  - Standings
  - Tournament Brackets

## State Management
- Pinia stores: `tenantStore`, `authStore`, `leagueStore`, `teamStore`, `scheduleStore`, `tournamentStore`, `officialsStore`, `assignmentStore`

## API & BFF
- Shared `packages/api`: axios client, interceptors, DTOs, error handling
- Domain-based endpoints and contracts
- Optional per-app BFF (later)

## API Standards (Pagination, Errors, Rate Limits)
- Resource Naming & Verbs:
  - RESTful routes use plural nouns (`/v1/leagues`, `/v1/teams`, `/v1/games`).
  - HTTP methods: GET (read), POST (create), PUT (replace), PATCH (partial update), DELETE (remove).
  - Action endpoints sparingly (e.g., `/v1/schedules/:id/publish`), prefer state changes via PATCH when feasible.
- Status Codes: 200/201/202, 204 for no-content; 400/401/403/404/409/422; 429 for throttling; 500/503 with `requestId`.
- Filtering/Sorting: query params (`?filter[division]=U14&sort=-startDate`); consistent operators and documented allowed fields.
- Caching & Concurrency: ETag/If-None-Match for GET; If-Match for conditional updates; server-side caching at BFF with cache keys including tenant/scope.
- Idempotency: idempotency keys for POST where side effects exist; retries safe.
- Pagination: prefer cursor-based (`cursor`, `limit`) for stability; support page/limit as fallback where appropriate.
  - Responses include `data`, `nextCursor`, `prevCursor`, `total` (when feasible), and `links` with RFC5988 `Link` headers.
  - Consistent caps on `limit` (e.g., max 200), default 25.
- Errors: standardized problem+json shape `{ type, title, status, detail, instance, code }`; include `requestId` for tracing.
- Rate Limits: per-tenant/app quotas and per-IP safeguards using API Gateway usage plans + WAF rate-based rules.
  - Expose `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset` headers.
  - Backoff guidance for 429 responses; telemetry captures throttling events.
- Versioning: prefix routes with `/v1`; additive changes only; breaking changes via new version.

## Authentication & Authorization (AWS)
- Approach: AWS Cognito (User Pools + Hosted UI) for OAuth2/OIDC with PKCE; federated SSO (Google/Microsoft/SAML) as needed.
- Multi-tenant: tenant context embedded via claims (e.g., `tenantId`, `roles`) and enforced server-side; per-tenant RBAC policies.
- Roles: `platform-admin`, `league-admin`, `league-coordinator`, `officials-admin`, `official`, `viewer`.
- Scopes: define resource-level scopes (e.g., `leagues:read`, `leagues:write`, `schedules:manage`, `assignments:manage`, `billing:view`, `billing:manage`).
- API protection: API Gateway/Lambda with JWT authorizer validating Cognito tokens and checking scopes/roles; fine-grained checks in services.
- Tokens: use access tokens (short-lived) and refresh flow via Cognito; store tokens in memory or secure cookies; avoid localStorage for security.
- Frontend: route guards enforce role/scope access; Axios interceptors attach bearer tokens and handle 401/refresh.
- Auditing: include `userId`, `tenantId`, `roles`, `scopes` in telemetry events for traceability.
- Compliance: least-privilege access, rotation policies, PII minimization.
 - Encryption: TLS 1.3 in transit; KMS-backed encryption at rest across databases and storage; selective field-level encryption for high-risk PII; see ADR-0015.

### MFA & Session Policies
- MFA: enable MFA by default (TOTP preferred; SMS as backup); enforce at user pool level with step-up options for sensitive actions.
- Session Policies: define and document
  - Session duration (e.g., 12h), idle timeout (e.g., 30m), refresh token lifetime (e.g., 30d), token rotation enabled.
  - Device remember settings and re-auth triggers for privileged operations (billing, payouts, RBAC changes).
  - Regional considerations and conditional policies for elevated risk.

## Quality
- Testing: Vitest (unit), Vue Test Utils (components), Playwright (E2E), MSW (HTTP mocks), Newman (Postman API tests), Pact (contract), Artillery/k6 (load), coverage via c8
- Linting/formatting: ESLint + Prettier + TypeScript strict

## DevOps
- CI pipelines: build, lint, test, type-check
- Preview deploys per app
- `.env` per app; secrets via CI
- Observability: Sentry (errors), basic logs
 - API Testing: commit Postman collections and run via Newman in CI; performance smoke via Artillery/k6

## Billing & Invoicing (Tenants)
- Scope: subscriptions, plans, usage-based charges (e.g., game volume), invoices, payments, dunning, tax.
- Data model: `Invoice`, `LineItem`, `Subscription`, `Plan`, `UsageRecord`, `TaxRate`, `Payment`, `Refund`, `CreditNote`.
- Features:
  - Generate monthly invoices with usage snapshots and taxes; pro-ration for mid-cycle changes.
  - Send invoices (PDF/email) with payment links; record payment status and retries.
  - Dunning workflows (reminders, suspension rules); finance exports.
  - Platform Admin dashboards for MRR, churn, AR aging, failed payments.
- Compliance: tax calculation integrations; PCI handled by provider; PII minimized.
 - Payment methods (tenants): credit/debit cards (Visa/Mastercard/Amex), ACH bank transfer, digital wallets (Apple Pay/Google Pay), optional PayPal; support manual reconciliation for Zelle/Venmo/checks if policy allows.

  ## Officials Subscription & Fees
  - Scope: per-tenant default subscription fee for officials, with owner ability to apply discounts (percentage/fixed) and surcharges/fees.
  - Models: `OfficialSubscription(officialId, tenantId, plan, feeAmount, currency, status)`, `FeeSchedule(tenantId, defaultFee, currency, effectiveFrom)`, `Adjustment(type: 'discount'|'surcharge', amount, reason, appliedBy, expiresAt)`, `Coupon(code, percentOff|amountOff, maxRedemptions, expiresAt)`.
  - Features:
    - Apply tenant-level default fees to officials under that tenant; allow per-official overrides.
    - Discounts: percentage or fixed amount; stack rules (define precedence) and expiry dates; audit who applied and why.
    - Surcharges/fees: late fees, service fees; configurable per policy.
    - Billing cadence: monthly (default) with proration on join/exit; option to deduct from payouts vs direct payment.
    - Invoices/receipts for officials; payment methods via card/ACH; reconcile deductions from payouts when chosen.
  - Compliance: clear disclosure of fees; consent and ToS; refund/chargeback handling policies.

## Officials Payroll & Pay Stubs
- Scope: pay rates, assignments → earnings, withholds (tax), payouts, pay stubs, adjustments.
- Data model: `PayRate`, `AssignmentEarning`, `PayPeriod`, `PayStub`, `Withholding`, `Payout`, `Adjustment`.
- Features:
  - Compute earnings per assignment with divisional/venue/time modifiers; batch per pay period.
  - Generate pay stubs (PDF/HTML) with line items, taxes, net pay; deliver via portal/email.
  - Payouts via provider (ACH); track statuses and reconcile.
  - Officials Admin dashboards for coverage %, earnings by period, payout statuses.
- Compliance: handle sensitive data with masking/encryption; regional rules; export auditing.
 - Payout methods (officials): ACH direct deposit (primary), mailed checks (fallback), instant debit payouts (optional via provider); Zelle/Venmo only if policy permits, with manual reconciliation and compliance review.

## Payments & Payouts Milestones
- Phase A: Providers & Payment Methods
  - Select provider (e.g., Stripe/Adyen), enable cards, ACH, wallets; document manual methods (Venmo/Zelle/checks) and reconciliation.
  - Acceptance: tenants can pay via card/ACH/wallet; PCI offloaded; ledger records created.
  - Convenience Fee: configurable percentage/fixed fee applied to card/wallet payments with clear disclosure; see ADR-0014.
- Phase B: Bank Onboarding & Verification
  - Officials onboarding: collect bank details securely; verify via micro-deposits or Plaid; handle W-9 collection if applicable.
  - Acceptance: verified payout accounts; secure storage of tokens/refs; audit trail.
- Phase C: Payouts & Pay Stubs
  - Automate ACH payouts per pay period; generate and deliver pay stubs; reconcile payout statuses.
  - Acceptance: successful payouts with traceability; pay stubs accessible; dashboard KPIs populate.
- Phase D: Reconciliation & Reporting
  - AR aging, payout reconciliation, exception handling (returns/NSFs); exports for finance.
  - Acceptance: reconciliation reports complete; exceptions tracked and resolved.

## Tenant Invitations & Onboarding
- Scope: invite tenants by email, verification, provisioning, initial admin setup, ToS/Privacy acceptance, seat allocation.
- Data model: `Tenant`, `Invitation(token, status, expiresAt)`, `User`, `RoleAssignment`, `Verification(domain/email)`, `ProvisioningJob(status)`.
- Features:
  - Send invitation with expiring token; resend/cancel; track status (sent, opened, accepted, expired).
  - Verify tenant identity (domain/email), collect required onboarding details, set initial admin users and roles.
  - Provision tenant config (branding, timezone, locale), quotas/plans, and default settings.
  - Audit trail of invitation lifecycle and provisioning steps; suspension/reactivation flows.
- Compliance: consent records, email verification, anti-spam protections, data retention and export.
- **Multi-step onboarding with payment upfront**: see ADR-0016 for detailed workflow (info collection → payment → verification → provisioning → go-live).
- Branding optional: use defaults if not provided; can update anytime post-onboarding.
- SSO/login setup mandatory during onboarding; designed for flexibility to support SAML, OIDC, and future auth methods.
- DocuSign integration: auto-generate and e-sign agreements (ToS, DPA, contracts) as part of onboarding workflow (roadmap item).

## Notifications & Messaging
- Providers: Email via AWS SES; SMS via AWS Pinpoint/SNS or Twilio; templating engine with localization and tenant branding.
- Eventing: domain events (game change, venue change, assignment update) routed to Notification Service; dedupe and batching.
- Preferences: per-user channel preferences (email, SMS, push later), frequency (real-time, digest, quiet hours), topic subscriptions (teams, leagues, officials).
- Delivery: rate limits, retries/backoff, idempotency; unsubscribe and opt-out management; branded templates; per-tenant sender identities.
- Overrides: owner can override tenant/user preferences for urgent/emergency notifications; require justification and audit, time-bound scope.
- Compliance: CAN-SPAM, TCPA; opt-in/out records; regional messaging rules; suppression lists; deliverability monitoring.
 
## Officials Payment Workflow (Confirmation → Approval → Payment)
- Objective: each official independently confirms they worked the game; officials tenant performs final approval and marks for payment.
- Roles:
  - Officials (per assignment): confirm attendance and role for the specific game.
  - Crew Chief (optional): reconcile minor discrepancies within the crew.
  - Officials Tenant Admin: final approver; confirms game integrity and marks eligible assignments for payment.
- Statuses:
  - Game: `scheduled` → `played`
  - Assignment: `assigned` → `confirmed-by-official` → `approved-by-tenant` → `marked-for-payment` → `paid`
  - Disputes: `disputed` → `resolved` | `void`
- Steps:
  1. Post-game event (`game.played`) starts a confirmation window (e.g., 48h).
  2. Each assigned official receives notification; submits confirmation (attendance, role, notes).
  3. System flags conflicts (no-show vs confirmed, role mismatch) and opens dispute records.
  4. Optional crew chief review; unresolved disputes escalate to tenant admin.
  5. Tenant admin reviews confirmations; approves assignments.
  6. Approved assignments are `marked-for-payment` and included in the next pay period batch.
  7. Payout run executes; pay stubs generated/delivered; assignment status updates to `paid` with receipt.
- Deadlines & Reminders: configurable confirmation window with reminders; overdue confirmations escalate; policy-driven auto-void.
- Audit & Telemetry: record all confirmations, approvals, disputes, overrides with `userId`, `tenantId`, timestamps; dashboards for confirmation/dispute rates and payout readiness.
- Edge Cases: no-shows (void/penalties per policy), partial cancellations (pro-rating), replacement officials (explicit confirmation + admin approval).
## Telemetry & Audit
- Goals: audit user interactions (clicks), API requests, and data displayed across apps with strong privacy and compliance.
- Event schema (core fields): `eventId`, `timestamp`, `sessionId`, `userId`, `tenantId`, `appId`, `route`, `component`, `action`, `element`, `meta` (safe key/value), `env`.
- Client instrumentation:
  - Global click tracking with delegated listeners and component-level emits.
  - Router hooks (`beforeEach/afterEach`) for navigation events.
  - Axios interceptors logging method, URL, status, latency, payload size with redaction rules.
  - Data displayed telemetry: record counts, field sets, view identifiers, hashed sample payload (non-reversible).
- Privacy & compliance:
  - PII redaction and allow-lists at source; never log secrets or full payloads.
  - Configurable sampling, opt-in/out controls, regional retention policies, anonymization.
  - Document DPA/ToS impacts; provide export/delete tooling.
- Ingestion & storage:
  - Lightweight client SDK posts to telemetry ingestion service with batching/backoff.
  - Stream processing (e.g., Kafka/Pulsar) to durable storage (warehouse + object store).
  - Real-time metrics pipeline for dashboards (latency, error rates, DAU/MAU, tenant usage).
- Dashboards & access:
  - Product analytics: top routes, feature adoption, click maps, funnels.
  - Ops dashboards: API volumes, latencies, failures, retries.
  - Role-based access, immutable audit logs, export capabilities.
- Testing:
  - Unit tests to enforce redaction; synthetic events in CI.
  - Load tests for ingestion endpoints; Lighthouse budgets include telemetry cost.

## Dashboards
- League Admin dashboards:
  - Scheduling status (scheduled vs. unscheduled), upcoming games, conflicts heatmap, team participation, venue utilization, tournament progress.
  - Reports: exportable CSV/PDF for schedules, conflicts, venue usage.
- Officials Admin dashboards:
  - Availability heatmaps, assignment coverage %, travel distance estimates, pay status, certification expirations, incident reports.
  - Operational KPIs: fill rates by date/division/venue, late changes, no-shows.
- Platform Admin dashboards:
  - Tenant growth, DAU/MAU, feature adoption, API latency/error rates, ingestion health, billing status, email/SMS deliverability.
  - Compliance: audit log volumes, export activity, retention warnings.
- Public portal (lightweight):
  - Trending teams/leagues, upcoming marquee games, leaderboard snapshots.
- Implementation notes:
  - Shared charting primitives in `@contest/ui` (e.g., ECharts/Chart.js wrappers), widget framework with standardized cards and filters.
  - RBAC-controlled visibility; per-tenant scoping and caching; near real-time updates via telemetry stream or scheduled aggregates.

### Telemetry Milestones & Acceptance Criteria
- Phase 1: Client SDK & Baseline Instrumentation
  - Deliverables: `packages/telemetry` SDK, event schema, router/axios hooks, global click tracking, PII redaction allow-list.
  - Acceptance: events emitted for navigation, clicks, API requests in all apps; redaction tests passing; sampling configurable via env.
- Phase 2: Ingestion & Basic Dashboards
  - Deliverables: ingestion endpoint with batching/backoff, durable storage, dashboards for DAU/MAU, route views, API latency/error rates.
  - Acceptance: <200ms median ingestion latency under load; dashboards show per-tenant/app metrics; access controlled via RBAC.
- Phase 3: Advanced Analytics & Admin Integration
  - Deliverables: funnels, feature adoption, click maps; Platform Admin screens for analytics with export; incident/audit views.
  - Acceptance: analytics usable in `apps/platform-admin`; exports adhere to privacy rules; audit trails immutable/read-only.
- Phase 4: QA & CI Gates
  - Deliverables: Playwright synthetic interaction suite generating telemetry, CI checks for telemetry coverage, error budgets and alerts.
  - Acceptance: CI fails when telemetry coverage drops below threshold; alerting integrated for ingestion failures.

## Documentation
- Workspace README, per-app README, contribution guide
- Coding standards
- ADRs for key decisions (repo strategy, routing, theming)

## Responsive Design & Accessibility
- Mobile-first: fluid spacing, `rem` units, and `clamp()` for typography; prioritize core interactions on small screens.
- Breakpoints: `xs/sm/md/lg/xl` plus container queries for component-level responsiveness.
- Layout: CSS Grid/Flex, responsive columns, sticky action bars, collapsible navigation; tables degrade to cards on mobile.
- Components: responsive data tables, stepper/wizard, date/time pickers, calendars, list→detail patterns; full keyboard and screen-reader support.
- Performance: route-level code splitting, lazy-load heavy widgets, responsive images (`srcset`), GPU-friendly transitions.
- Accessibility: WCAG 2.2 compliance, landmarks, focus management, color contrast, and form semantics.
- Testing: Playwright device profiles (iPhone, iPad, Pixel, common desktops) and Lighthouse CI for performance/accessibility budgets.

## Quick Start (Monorepo)
```bash
# Install pnpm	npm i -g pnpm

# Initialize workspace
pnpm init
pnpm dlx turbo@latest init

# Apps
pnpm create vite apps/league-admin --template vue-ts
pnpm create vite apps/officials-admin --template vue-ts
pnpm create vite apps/public-portal --template vue-ts

# Shared packages
pnpm create vite packages/ui --template vue-ts
pnpm create vite packages/types --template vue-ts
pnpm create vite packages/api --template vue-ts
pnpm create vite packages/config --template vue-ts
```

## Next Steps
1. Decide UI approach (Tailwind recommended) and define shared design tokens & breakpoints
2. Scaffold monorepo directories and workspace config; add `apps/platform-admin`
3. Wire path aliases and shared TypeScript config across apps/packages
4. Create baseline Pinia stores and shared axios client in `packages/api`
5. Implement login + tenant selector screens, add tenant-aware route guards
6. Seed MVP routes for league-admin, officials-admin, public-portal, platform-admin
7. Configure Playwright device matrix and Lighthouse CI for responsive/accessibility checks
8. Create `packages/telemetry` with event schema, client SDK, and axios/router integrations
9. Stand up telemetry ingestion endpoint and basic dashboards (usage, latency, errors)
10. Build initial dashboard widgets for League Admin and Officials Admin (charts, tables, filters)
11. Add Platform Admin dashboards for tenant growth, usage analytics, and ingestion health
12. Define billing models and invoice templates; integrate payment provider; build Platform Admin billing screens
13. Define payroll models and pay stub templates; integrate payout provider; build Officials Admin payroll screens
14. Define RBAC roles/scopes, Cognito configuration, and JWT authorizer rules; document token handling strategy
15. Add auth route guards and Axios token interceptor patterns to shared docs; ensure telemetry logs include auth context
16. Select payments provider(s); enable card/ACH/wallet methods; design reconciliation for Zelle/Venmo/checks
17. Implement officials bank onboarding and verification; secure storage of payout tokens
18. Automate pay period payouts and pay stub generation; add reconciliation dashboards
19. Configure Cognito MFA policies as default, and document session duration/idle timeout/refresh rotation
20. Define API pagination contract (cursor/page) and error shapes; add client helpers in `packages/api`
21. Implement API rate limits and usage plans; expose rate-limit headers; add telemetry for throttling events
22. Define tenant branding model and validation rules (contrast, reserved tokens)
23. Build branding admin screens (Platform Admin) and per-tenant settings; S3/CloudFront asset pipeline
24. Implement runtime theme loader in `@contest/ui`; add lint rule to prevent hard-coded colors
25. Build Tenant Invitation workflow (Platform Admin): tokens, email templates, status tracking, verification & provisioning
26. Stand up Notification Service: providers (SES/SNS/Twilio), templates, localization, deliverability metrics
27. Implement user preference model (channels, timing, topics) and UI; add owner override workflow with audit trail
28. Define officials fee models (FeeSchedule, OfficialSubscription, Adjustment) and governance (stacking, expiry) — see ADR-0012
29. Build Platform Admin screens to set per-tenant default fees, apply discounts/surcharges, and view audit — see ADR-0012
30. Wire officials billing: choose deduction from payouts vs direct payment; generate invoices/receipts — see ADR-0012
31. Implement officials confirmation workflow (statuses, policies, reminders, dispute handling) — see ADR-0011
32. Add tenant admin approval UI and batch marking for payment — see ADR-0011
33. Integrate payout batching by pay period and pay stub delivery with audit receipts — see ADR-0011

## Platform Admin Application
- Decision: build a separate Platform Admin app (`apps/platform-admin`) within the monorepo.
- Rationale: isolation for RBAC and audit, independent release cadence, reduced blast radius, clearer UX boundaries, dedicated admin API.
- Scope (initial screens): tenant lifecycle (provision/suspend/delete), billing & plans, user directory & RBAC, audit & compliance, config & feature flags, notifications, ops dashboards, telemetry analytics, support tools (impersonation).
