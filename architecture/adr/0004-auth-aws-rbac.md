# ADR 0004: Authentication & Authorization (AWS RBAC with Tokens & Scopes)

## Status
Accepted

## Context
The platform must support role-based access control (RBAC) for multi-tenant users and protect APIs using tokens and scopes. We are hosting on AWS and want to leverage AWS-managed security.

## Decision
- Use AWS Cognito User Pools + Hosted UI for OAuth2/OIDC with PKCE. Support federated identity (e.g., Google/Microsoft/SAML) via Cognito.
- Encode tenant context and roles in token claims (e.g., `tenantId`, `roles`). Enforce authorization server-side with least-privilege policies.
- Protect APIs via API Gateway/Lambda JWT authorizer (or ALB auth) validating tokens, checking scopes and roles; fine-grained checks in services.
- Use short-lived access tokens and refresh tokens via Cognito; store tokens in memory or secure HttpOnly cookies (avoid localStorage).

## RBAC Model
Roles: `platform-admin`, `league-admin`, `league-coordinator`, `officials-admin`, `official`, `viewer`.
Scopes (examples): `leagues:read`, `leagues:write`, `teams:manage`, `schedules:manage`, `assignments:manage`, `billing:view`, `billing:manage`.

## Frontend Integration
- Route guards check roles/scopes and tenant context; redirect unauthorized users.
- Axios interceptors attach bearer tokens; handle 401 with refresh or re-auth.
- Telemetry includes `userId`, `tenantId`, `roles`, `scopes` for audit traceability (redacted where needed).

## Security Considerations
- Least privilege, scope minimization, rotation policies.
- PII minimization; encrypt sensitive data at rest; avoid storing tokens in localStorage.
- Prevent token leakage via CORS and secure cookie settings.

## Alternatives Considered
- Custom auth: higher maintenance, less secure.
- Third-party auth (Auth0): viable but prefer AWS-native for hosting integration.

## Consequences
- Pros: managed security, scalable auth, native AWS integrations.
- Cons: Cognito complexity; mitigated via Hosted UI and standard flows.
