# ADR 0006: FE→BFF→Proc Layer→System APIs Architecture

## Status
Accepted

## Context
We need a multi-tenant enterprise system with clear separation of concerns, strong security, and scalable performance. The frontend should avoid coupling to internal microservice complexity while supporting tailored endpoints, pagination, rate limits, and RBAC.

## Decision
Adopt an architecture where each frontend app talks only to a Backend-for-Frontend (BFF). The BFF proxies and aggregates requests to a processing/orchestration layer, which coordinates system-level microservices (data owners). Domain events are published for read models/search and analytics.

```
Frontend (Apps)
   │
   ▼
BFF (per app)  ──► Auth/RBAC, tenant context, aggregation, caching, pagination normalization
   │
   ▼
Proc/Orchestration Services  ──► Business workflows (scheduling, assignments, billing)
   │
   ▼
System APIs (Microservices)  ──► Data ownership (leagues, teams, schedules, officials, billing, telemetry)
   │
   └─► Event Bus (EventBridge/Kafka) → Read models/Search (OpenSearch), Dashboards
```

## Rationale
- Keeps FE contracts stable and tailored to UX without exposing internal services.
- Separates orchestration from data ownership, enabling clearer domains and scaling.
- Enables caching and performance optimizations at BFF level.
- Supports event-driven read models for dashboards and analytics.

## Implications
- API Gateway fronts BFF/proc with Cognito JWT authorizers, WAF, usage plans, rate limits.
- Services enforce tenant isolation, roles/scopes, and pagination contracts.
- Observability via tracing, metrics, structured logs; telemetry integrated.

## Alternatives
- FE directly to microservices: simpler on paper but higher coupling, harder auth/pagination normalization, and poorer UX aggregation.

## Open Questions
- Where to place certain cross-cutting concerns (e.g., caching): BFF first, with selective service-level caches.
- Granularity of proc services (per domain vs workflow): start with domain-based orchestration.
- Shared schemas vs API contracts: prefer versioned contracts + events over shared DB.
