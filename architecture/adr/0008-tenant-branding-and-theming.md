# ADR 0008: Tenant Branding and Theming

## Status
Accepted

## Context
Tenants want to brand their portals with their name, logo, and color scheme. A default design system theme must be used when branding is absent while preserving accessibility and performance across apps.

## Decision
Support per-tenant branding via configuration delivered by the BFF: `displayName`, `logoUrl(s)`, `faviconUrl`, and design tokens (`primary`, `secondary`, `accent`, `neutral`). Apply branding at runtime using CSS variables with validated contrast and reserved semantic tokens.

## Scope
- Applies to `league-admin`, `officials-admin`, and `public-portal` apps.
- Platform Admin uses platform theme; may show tenant visuals sparingly.
- Branding extends to emails and PDFs when permitted (invoices, pay stubs).

## Implementation
- Config Delivery: BFF returns branding config in session/tenant bootstrap (`/me` or `/tenant` endpoint) with versioned asset URLs.
- Assets: store logos/favicons in S3, serve via CloudFront; cache-bust with version parameters.
- CSS Variables: map tokens to CSS variables; update document root on load; avoid FOUC with early inline style or SSR hydration.
- Validation: enforce WCAG contrast, reserved tokens for semantic states (success/warn/error/info), and dark/light theme compatibility.
- Linting: rule to prevent hard-coded colors; require tokens via `@contest/ui`.
- Fallbacks: default design system theme when branding missing/invalid.

## Data Model (indicative)
`TenantBrand(displayName, logoUrl, logoAlt, faviconUrl, colors: { primary, secondary, accent, neutral }, updatedAt, version)`

## Consequences
- Pros: tailored tenant experiences with consistent UX; safe defaults and accessibility.
- Cons: extra complexity for asset management and validation; mitigated via shared UI and BFF delivery.
