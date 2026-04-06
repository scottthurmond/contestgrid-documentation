# ADR 0001: Separate Platform Admin Application

## Status
Accepted

## Context
We need platform-level administration for tenant lifecycle, billing, RBAC, audit/compliance, configuration, feature flags, notifications, and operational dashboards. Embedding these screens in tenant-facing apps increases risk (security coupling, UX complexity, blast radius).

## Decision
Build a separate Platform Admin application (`apps/platform-admin`) within the monorepo, sharing core UI, types, and API clients.

## Consequences
- Pros: Isolation for RBAC and audit, independent release cadence, reduced blast radius, clearer UX boundaries, dedicated admin API.
- Cons: Additional auth surface, duplicated shell components; mitigated via shared `@contest/ui` and shared auth.

## Scope
Initial screens: tenant lifecycle (provision/suspend/delete), billing & plans, user directory & RBAC, audit & compliance, config & feature flags, notifications, ops dashboards, telemetry analytics, support tools (impersonation).
