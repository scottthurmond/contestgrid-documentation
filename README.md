# Documentation

This folder contains planning and decision documents for the Contest Schedule frontend.

- **Quick References**:
  - [Local Development Setup with Rancher Desktop](LOCAL-DEVELOPMENT-SETUP.md) — Complete step-by-step guide for setting up K8s locally
  - [API Security & Infrastructure Quick Reference](API-SECURITY-QUICKREF.md) — Checklists for HTTPS, TLS, JWT, rate limiting, secrets, Kubernetes best practices
  - [SSL/TLS Implementation Standard](SSL-IMPLEMENTATION.md) — Certificate generation, installation locations, and rollout steps
  - [Flyway Database Migrations Quick Reference](FLYWAY-QUICKREF.md) — Complete guide to database-as-code with Flyway (installation, commands, best practices)
  - [Database Modeling Workflow](DB-MODELING-WORKFLOW.md) — Standard open source/free toolchain and team workflow for ER design + migrations + docs
- Roadmap: see [roadmap.md](roadmap.md)
- Architecture Decisions (ADRs): see [adr/](adr/)
  - Platform Admin separation: [adr/0001-platform-admin-separate-app.md](adr/0001-platform-admin-separate-app.md)
  - Telemetry & Audit: [adr/0002-telemetry-and-audit.md](adr/0002-telemetry-and-audit.md)
  - Billing & Payroll: [adr/0003-billing-and-payroll.md](adr/0003-billing-and-payroll.md)
  - Authentication & Authorization (AWS): [adr/0004-auth-aws-rbac.md](adr/0004-auth-aws-rbac.md)
  - API Standards (Pagination/Rate Limits): [adr/0005-api-standards.md](adr/0005-api-standards.md)
  - Design System: [adr/0007-design-system.md](adr/0007-design-system.md)
  - Tenant Branding & Theming: [adr/0008-tenant-branding-and-theming.md](adr/0008-tenant-branding-and-theming.md)
  - Tenant Invitations & Onboarding: [adr/0009-tenant-invitations-onboarding.md](adr/0009-tenant-invitations-onboarding.md)
  - Notifications & Messaging: [adr/0010-notifications-and-messaging.md](adr/0010-notifications-and-messaging.md)
  - Officials Payment Workflow: [adr/0011-officials-payment-workflow.md](adr/0011-officials-payment-workflow.md)
  - Officials Subscription & Fees: [adr/0012-officials-subscription-and-fees.md](adr/0012-officials-subscription-and-fees.md)
  - Testing Strategy & Tooling: [adr/0013-testing-strategy-and-tooling.md](adr/0013-testing-strategy-and-tooling.md)
  - Payments Provider & Convenience Fees: [adr/0014-payments-provider-and-convenience-fees.md](adr/0014-payments-provider-and-convenience-fees.md)
  - Data Protection & Encryption: [adr/0015-data-protection-and-encryption.md](adr/0015-data-protection-and-encryption.md)
  - Tenant Onboarding & Provisioning: [adr/0016-tenant-onboarding-and-provisioning.md](adr/0016-tenant-onboarding-and-provisioning.md)
  - Contract Lifecycle Management & E-Signature: [adr/0017-contract-lifecycle-management.md](adr/0017-contract-lifecycle-management.md)
  - Platform Monetization Strategy: [adr/0018-platform-monetization-strategy.md](adr/0018-platform-monetization-strategy.md)
  - Officials Subscription Model & Multi-Association Membership: [adr/0019-officials-subscription-model.md](adr/0019-officials-subscription-model.md)
  - Non-Intrusive Advertising Platform (Public Portal): [adr/0020-advertising-platform.md](adr/0020-advertising-platform.md)
  - Data Storage Architecture (Aurora PostgreSQL): [adr/0021-data-storage-architecture.md](adr/0021-data-storage-architecture.md)
  - SMS Communication Strategy (Tenant Invites & Notifications): [adr/0022-sms-communication-strategy.md](adr/0022-sms-communication-strategy.md)
  - Infrastructure & API Security (Kubernetes, Istio, Flux, Helm, TLS): [adr/0032-infrastructure-and-api-security.md](adr/0032-infrastructure-and-api-security.md)

- UI Flows:
  - Platform Admin fees screens: [flows/platform-admin-fees.md](flows/platform-admin-fees.md)

As we gather requirements, we will keep the roadmap updated and record key decisions as ADRs.

