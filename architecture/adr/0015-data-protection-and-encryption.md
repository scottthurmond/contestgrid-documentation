# ADR 0015: Data Protection & Encryption

## Status
Accepted

## Context
We must protect user data, especially PII and confidential information. Encryption at rest and in motion is required for sensitive data.

## Decision
Adopt strong data protection measures across the stack: classify data, encrypt sensitive data at rest and in transit, minimize PII, and enforce access controls and auditing.

## Data Classification
- Levels: Public, Internal, Confidential (PII/Financial), Restricted (secrets).
- Catalog: maintain a data inventory per service with classification and retention.

## Encryption
- In Transit: TLS 1.3 for all external traffic; mutual TLS or signed requests for service-to-service where applicable.
- At Rest: service-managed encryption (AWS KMS) for databases, object storage, and search indices; per-tenant keys where feasible.
- Field-Level: selective encryption for high-risk fields (e.g., SSN, bank tokens) using envelope encryption and access policies.

## Access Controls
- RBAC: enforce least privilege with roles/scopes; tenant boundaries server-side.
- Secrets: store in managed secrets service; rotate regularly; no secrets in repo.
- Data Access: audit all reads/writes of sensitive records; immutable logs.

## Privacy & Minimization
- Collect only necessary PII; redact from telemetry/logs.
- Regional: respect residency/retention; configurable purge/expiry.
- Exports: secure export tooling; track access and downloads.

## Operational Controls
- Backups: encrypted backups with tested restores; key management procedures.
- Incident Response: playbooks for data incidents; alerting and forensics.
- DPIA: conduct assessments for high-risk processing and new integrations.

## Consequences
- Pros: robust protection, compliance readiness, user trust.
- Cons: added complexity and cost; mitigated by managed services and clear policies.
