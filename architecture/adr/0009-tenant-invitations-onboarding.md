# ADR 0009: Tenant Invitations and Onboarding

## Status
Accepted

## Context
As the platform owner, we need a secure, auditable workflow to invite tenants, verify identity, and provision their environment with initial admins and settings.

## Decision
Implement an invitation system with expiring tokens sent via email, verification steps (domain/email), and a provisioning process that sets up tenant config (branding, timezone/locale), quotas/plans, and initial admin roles.

## Workflow
1. Create invitation (tenant name/email, optional domain); generate token (time-limited) and send email.
2. Invitee accepts: verifies email/domain, reviews ToS/Privacy, provides required onboarding fields.
3. Provisioning job: create tenant record, apply plan/quotas, seed default settings, assign initial `league-admin`/`officials-admin` users.
4. Confirmation: send onboarding summary; enable login; audit trail recorded for each step.

## Data Models
- `Tenant(id, name, plan, timezone, locale, branding, quotas)`
- `Invitation(id, email, token, status, expiresAt, createdBy)`
- `Verification(id, type: 'email'|'domain', status, details)`
- `RoleAssignment(userId, tenantId, role)`
- `ProvisioningJob(id, tenantId, status, logs)`

## Security & Compliance
- Token expiry and single-use; resend/cancel; anti-spam measures.
- Consent capture (ToS/Privacy); verified email/domain.
- Audit logs for creation, acceptance, provisioning; data retention policies.

## Consequences
- Pros: controlled onboarding, clear auditing, safer provisioning.
- Cons: added workflows and systems; mitigated via automation and templates.
