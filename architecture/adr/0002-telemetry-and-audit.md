# ADR 0002: Telemetry and Audit Strategy

## Status
Accepted

## Context
We require auditing of user clicks, data requests (API), and data displayed, with strong privacy controls. Telemetry supports product analytics, operational health, and compliance.

## Decision
Implement a shared `packages/telemetry` client SDK with event schema, router and axios integrations, global click tracking, and PII redaction. Ingest events via a telemetry service with batching/backoff, store in durable systems, and provide dashboards.

## Event Schema (core fields)
`eventId`, `timestamp`, `sessionId`, `userId`, `tenantId`, `appId`, `route`, `component`, `action`, `element`, `meta` (safe key/value), `env`.

## Privacy & Compliance
- Redaction allow-lists; never log secrets or full payloads.
- Configurable sampling, opt-in/out, regional retention policies, anonymization.
- Export/delete tooling; documented DPA/ToS impacts.

## Milestones & Acceptance Criteria
- Phase 1: Client SDK & Baseline Instrumentation → events for navigation, clicks, API requests; redaction tests passing; sampling via env.
- Phase 2: Ingestion & Basic Dashboards → <200ms median ingestion latency; per-tenant/app metrics; RBAC-controlled dashboards.
- Phase 3: Advanced Analytics & Admin Integration → funnels, feature adoption, click maps; analytics in Platform Admin; immutable audit trails.
- Phase 4: QA & CI Gates → Playwright synthetic interactions generating telemetry; CI coverage checks and alerts on failures.

## Consequences
- Pros: Deep visibility, auditability, data-informed product decisions.
- Cons: Added complexity and cost; mitigated via sampling and strict redaction.
