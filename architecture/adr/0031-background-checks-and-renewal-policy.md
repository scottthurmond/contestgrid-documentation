# ADR 0031: Background Checks & Renewal Policy (Officials and Sports Associations)

Status: Accepted
Date: 2025-12-27
Owners: Compliance & Platform

## Context
Both officials associations and sports associations need the ability to track background checks for their personnel (officials, coaches, volunteers) and configure renewal policies (e.g., annual, biennial). The platform must support recording check details, setting renewal intervals per organization, issuing reminders before expiry, and optionally blocking assignments/roles when checks are expired or missing.

This ADR defines requirements and configuration patterns. Implementation and schema changes may be deferred.

## Requirements
- Entities & Scope:
  - Officials Associations: track background checks for `officials`.
  - Sports Associations: track background checks for `coaches`, `volunteers`, and optionally `officials` shared via access policies (see ADR-0028).
- Data Fields (per check record):
  - `subject_id` (person), `association_id` (owning org), `subject_role` (official|coach|volunteer), `provider` (Checkr|Sterling|other), `check_type` (criminal, sex-offender, identity, etc.), `result` (clear|review|disqualify), `status` (pending|in_progress|completed|expired), `issued_at`, `expires_at`, `document_url` (PDF), `notes`.
  - Minimal PII; store provider reference IDs and status only; sensitive details held by provider.
- Configuration (hierarchical):
  - Renewal Interval: global default (e.g., 12 months) → officials association override → sports association override → division/role override.
  - Reminder Policy: e.g., 60d, 30d, 7d before `expires_at`; escalations to admins.
  - Blocking Policy: choose behavior when expired/missing: `block_assignments`, `warn_only`, `no_block`. Scoped per org/role.
- Workflows:
  - Onboarding: request background check via provider; track `status`; attach `document_url` when completed.
  - Renewal: auto-create renewal tasks per policy; send reminders; optionally block assignments until renewed.
  - Verification: admin reviews `result` and sets `status` (completed|review|disqualify); audit decision.
  - Cross-Tenant Access: sports associations may read officials' check state if permitted (see ADR-0028 presets); detailed reports remain private.
- Notifications & Audit:
  - Notifications: reminders to personnel and admins per policy; escalation for overdue renewals.
  - Audit: log creation, updates, verification decisions, blocking actions, and delivery of reminders.
- Privacy & Security:
  - Do not store detailed report data; store provider reference and high-level result/status.
  - RBAC: only compliance/admin roles can view/modify check status; cross-tenant visibility is limited to the minimal state needed.

## UI/UX
- Admin views: list of personnel with check status, expiry date, filters (expiring soon, overdue).
- Detail view: provider, type, issued/expires, result/status, notes, `document_url`.
- Configuration: renewal interval selector, reminder schedule, blocking behavior; inheritance preview.
- Assignment gating: visual indicators on assignment screens; block/warn per policy.

## Integration
- Providers: Checkr, Sterling, or custom workflow; store `provider_ref_id` and webhook statuses.
- Webhooks: ingest provider status updates; update check records; trigger notifications.

## Deferred Implementation Plan (Schema outline)
- `background_check` table: subject, association, role, provider, type, result, status, issued_at, expires_at, document_url, notes, audit columns.
- `background_check_policy` table: association_id, role, renewal_interval_months, reminder_days[], blocking_behavior.
- Indexes for expiry and status; RLS scoped by association.

## Related ADRs
- **ADR-0028**: Cross-Tenant Data Access (configurable visibility)
- **ADR-0003**: Billing & Payroll (compliance context)

## Decision
Adopt hierarchical configuration for renewal, reminders, and blocking; track high-level results with provider references; implement UI indicators and auditability. Defer full integration and schema changes to a later phase.
