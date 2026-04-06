# ADR 0034: Fine-Grained RBAC Entitlement System

## Status

Accepted

## Context

ContestGrid is a multi-tenant platform where different users within an
organization need different levels of access.  The original design stored
flat BFF-level role strings (`platform_admin`, `officials_admin`, etc.)
in an in-memory store and embedded them in JWTs.  This gave coarse-grained
access control but no ability to configure **per-operation** permissions or to
let tenant admins customize what each role can do.

Key requirements:

1. **Fine-grained CRUD control** — every resource area (officials, contests,
   billing, etc.) must support independent create/read/update/delete gates.
2. **Tenant-admin configurable** — each tenant can tailor which entitlements
   are granted to each role without code changes.
3. **Secure by default** — new entitlements are not automatically granted;
   explicit assignment is required.
4. **Auditable** — entitlement changes are traceable via `created_at` /
   `updated_at` timestamps and standard DB audit tooling.
5. **Performance** — entitlement checks must not add a DB round-trip on every
   request.

## Decision

Implement a three-table RBAC model in the `app` schema:

```
┌────────────────────┐         ┌─────────────────────────┐
│   app.entitlement   │         │       app.roles          │
│  (global catalogue) │         │   (tenant-scoped)        │
│────────────────────│         │─────────────────────────│
│ entitlement_id  PK │         │ role_id           PK    │
│ resource_name      │         │ role_description        │
│ operation          │◄────┐   │ tenant_id        FK     │
│ entitlement_key UK │     │   │ is_admin_role  BOOLEAN  │  ◄── V040
│ description        │     │   └──────────┬──────────────┘
│ display_order      │     │              │
└────────┬───────────┘     │   ┌──────────┴──────────────┐
         │                 │   │  app.role_entitlement    │
         │                 │   │  (tenant-scoped)         │
         │                 └───│─────────────────────────│
         │                     │ role_entitlement_id  PK │
         │                     │ role_id           FK    │
         │                     │ entitlement_id    FK    │
         │                     │ tenant_id         FK    │
         │                     │ UK(role,ent,tenant)     │
         │                     └─────────────────────────┘
         │
         │              ┌──────────────────────────────────┐
         │              │ app.person_entitlement_override   │  ◄── V040
         └─────────────►│  (per-person grant/revoke)        │
                        │──────────────────────────────────│
                        │ person_entitlement_override_id PK│
                        │ person_id               FK       │
                        │ entitlement_id          FK       │
                        │ tenant_id               FK       │
                        │ override_type  'grant'|'revoke'  │
                        │ UK(person,ent,tenant)             │
                        └──────────────────────────────────┘

┌──────────────────────────────────┐
│  app.platform_role_assignment     │  ◄── V039 + V041
│  (global — no tenant scope)       │
│──────────────────────────────────│
│ platform_role_assignment_id  PK  │
│ person_id                   FK   │
│ role_name     platform_role_type │
│ is_root_admin          BOOLEAN   │  ◄── V041
│ UK(person_id, role_name)         │
└──────────────────────────────────┘

  platform_role_type ENUM:
    platform_admin | officials_admin | contest_assigner
    | league_director | billing_admin
```

Existing tables (`app.roles`, `app.person_roles`) are re-used. `app.roles`
gained `is_admin_role` (V040) and the new tables above were added in V039–V041.

### Entitlement Key Convention

Keys follow `resource:operation` format:

| Resource       | Operations            | Example Keys                                   |
|----------------|-----------------------|------------------------------------------------|
| tenants        | create/read/update/delete | `tenants:create`, `tenants:read`           |
| persons        | create/read/update/delete | `persons:create`, `persons:read`           |
| customers      | create/read/update/delete | `customers:create`, `customers:read`       |
| sports         | create/read/update/delete | `sports:create`, `sports:read`             |
| levels         | create/read/update/delete | `levels:create`, `levels:read`             |
| seasons        | create/read/update/delete | `seasons:create`, `seasons:read`           |
| leagues        | create/read/update/delete | `leagues:create`, `leagues:read`           |
| teams          | create/read/update/delete | `teams:create`, `teams:read`               |
| venues         | create/read/update/delete | `venues:create`, `venues:read`             |
| officials      | create/read/update/delete | `officials:create`, `officials:read`       |
| contests       | create/read/update/delete | `contests:create`, `contests:read`         |
| assignments    | create/read/update/delete | `assignments:create`, `assignments:read`   |
| billing        | create/read/update/delete | `billing:create`, `billing:read`           |
| rates          | create/read/update/delete | `rates:create`, `rates:read`               |
| roles          | create/read/update/delete | `roles:create`, `roles:read`               |
| entitlements   | create/read/update/delete | `entitlements:create`, `entitlements:read`  |
| imports        | create/read/update/delete | `imports:create`, `imports:read`           |

**Total: 68 entitlements** (17 resources × 4 operations).

### Default Role Entitlements

Seed data assigns default entitlements to the 5 built-in roles:

| Role                     | Entitlement Scope                                          | Count |
|--------------------------|------------------------------------------------------------|-------|
| Primary Assigner Admin   | ALL 68 entitlements                                        | 68    |
| Secondary Assigner Admin | ALL 68 entitlements                                        | 68    |
| Tenant Admin             | ALL 68 entitlements (`is_admin_role = TRUE`)               | 68    |
| League Director          | Full CRUD on leagues/teams/venues/contests/assignments/seasons; read+update on levels/sports/officials/rates; read on billing/persons/customers/imports | 36 |
| Coach                    | Read-only on contests/teams/assignments/venues/leagues/levels/sports/seasons | 8 |
| Official                 | Read-only on contests/assignments/venues/sports/levels/seasons | 6 |

Tenant admins can modify these mappings at any time through the admin UI.
Tenant admins can also grant or revoke individual entitlements per person
(see "Per-Person Entitlement Overrides" below).

### Entitlement Resolution & JWT Flow

```
  User login                  BFF                        Core-sys
  ─────────                   ───                        ────────
  POST /auth/login ──────────►│                          │
                              │  GET /persons/tenants    │
                              │  -by-email ─────────────►│
                              │◄─── tenants[] + personId │
                              │                          │
                              │  GET /persons/:id        │
                              │  /entitlements ─────────►│
                              │◄─── { roles,             │
                              │      entitlements,       │
                              │      isTenantAdmin }     │
                              │                          │
                 ◄── JWT token │                          │
                   (contains   │
                    roles[] +  │
                    entitlements[] +
                    is_tenant_admin)
```

At login time the BFF:

1. Looks up the person's tenant(s) from core-sys.
2. Queries `GET /v1/persons/:personId/entitlements` which resolves
   entitlements using the **override resolution formula**:

   ```
   effective = (role defaults) + (grant overrides) − (revoke overrides)
   ```

   a. Gather all entitlement keys from `person_roles → role_entitlement → entitlement`.
   b. Add any `person_entitlement_override` rows with `override_type = 'grant'`.
   c. Remove any `person_entitlement_override` rows with `override_type = 'revoke'`.
3. If the person holds an `is_admin_role = TRUE` role, sets `isTenantAdmin = true`.
4. Embeds `roles`, `entitlements`, and `is_tenant_admin` in the JWT.

### Per-Person Entitlement Overrides

Stored in `app.person_entitlement_override` (V040), these allow tenant
admins to fine-tune access for individual persons without creating custom
roles:

| Override Type | Effect |
|---------------|--------|
| `grant`       | Adds an entitlement the person's roles don't include |
| `revoke`      | Removes an entitlement the person's roles would normally include |

The unique constraint `(person_id, entitlement_id, tenant_id)` ensures a
person can have at most one override per entitlement per tenant (either
grant **or** revoke, not both).

### Access Control Hierarchy

ContestGrid defines four levels of administrative authority:

```
  Root Admin          (exactly one person — immutable, invisible)
       │
  Platform Admin      (global — manages all tenants & platform roles)
       │
  Tenant Admin        (tenant-scoped — manages roles & entitlements within a tenant)
       │
  Regular User        (tenant-scoped — has role-based + override entitlements)
```

| Level | Scope | Defined By | Capabilities |
|-------|-------|------------|--------------|
| Root Admin | Global | `is_root_admin = TRUE` in `platform_role_assignment` | All platform admin capabilities. Cannot be viewed, modified, or removed by anyone through the API. |
| Platform Admin | Global | `role_name = 'platform_admin'` in `platform_role_assignment` | Full bypass of entitlement checks. Can manage platform roles, view all tenant admins, manage all tenants. |
| Tenant Admin | Per-tenant | `is_admin_role = TRUE` on the person's assigned role in `app.roles` | All 68 entitlements within their tenant. Can configure role-entitlement mappings and per-person overrides. |
| Regular User | Per-tenant | `app.person_roles` → `role_entitlement` → `entitlement` + overrides | Only the entitlements granted by their roles and per-person overrides. |

### Root Admin

The root admin is the "super of all super users." There is exactly one
root admin (bootstrap user), defined by the `is_root_admin` boolean flag
on `app.platform_role_assignment` (added in V041).

**Protections:**

- **Hidden from all API listings** — `listPlatformRoleAssignments()` and
  `listTenantAdmins()` both exclude the root admin via
  `WHERE pra.is_root_admin = FALSE`.
- **Modification blocked at core-sys** — `assignPlatformRole()`,
  `unassignPlatformRole()`, and `setPlatformRoles()` all reject requests
  targeting the root admin with `Error('Cannot modify roles for the root admin')`.
- **Modification blocked at BFF** — `rejectIfRootAdmin` middleware on all
  write routes for platform roles, person roles, and entitlement overrides
  returns HTTP 403 before the request reaches core-sys.
- **No API to change root admin status** — changing the root admin
  designation is a **database-only operation** by design. There is no
  endpoint that can set or clear `is_root_admin`.

**How to change the root admin** (DB-only, intentional):

```sql
-- Remove current root admin flag
UPDATE app.platform_role_assignment
   SET is_root_admin = FALSE
 WHERE is_root_admin = TRUE;

-- Set new root admin (person must already have platform_admin role)
UPDATE app.platform_role_assignment
   SET is_root_admin = TRUE
 WHERE person_id = <new_person_id>
   AND role_name = 'platform_admin';
```

### Platform Roles (V039)

Platform roles are global (not tenant-scoped) and stored in
`app.platform_role_assignment`. The available role types are defined by
the `app.platform_role_type` ENUM:

| Role | Purpose |
|------|---------|
| `platform_admin` | Full system access, bypasses all entitlement checks |
| `officials_admin` | Manages officials across tenants |
| `contest_assigner` | Manages contest assignments across tenants |
| `league_director` | Manages leagues across tenants |
| `billing_admin` | Manages billing across tenants |

A person can hold multiple platform roles. Platform roles are assigned
and managed through the BFF admin routes (gated by `platform_admin` role).

This means entitlement checks are **zero-cost at request time** — the BFF
middleware simply inspects the JWT claims.  Changes to role-entitlement
mappings take effect on the user's next login.

### BFF Middleware

```typescript
// Check entitlement (platform_admin bypasses automatically)
export function requireEntitlement(...keys: string[]) {
  return (req, res, next) => {
    if (req.user.roles.includes('platform_admin')) return next();
    if (keys.some(k => req.user.entitlements.includes(k))) return next();
    res.status(403).json({ error: 'Forbidden', message: `Requires: ${keys.join(' or ')}` });
  };
}
```

`requireEntitlement()` can be composed with `requireRole()`:

```typescript
// Only platform admins can create tenants
router.post('/tenants', requireRole('platform_admin'), tenantProxy);

// Anyone with 'officials:create' entitlement can create officials
router.post('/officials', requireEntitlement('officials:create'), proxy);
```

**Root admin guard** (V041):

```typescript
// rejectIfRootAdmin — applied to all write routes for platform roles,
// person roles, and entitlement overrides.  Caches the root admin's
// person_id from core-sys with a 5-minute TTL.
async function rejectIfRootAdmin(req, res, next) {
  const rootId = await getRootAdminId();          // cached core-sys call
  if (Number(req.params.personId) === rootId) {
    return res.status(403).json({
      error: 'Forbidden',
      message: 'Cannot modify the root admin'
    });
  }
  next();
}
```

**Tenant admin guard** (V040):

```typescript
// requireTenantAdmin() — gates admin operations to tenant admins
// (or platform_admin, who bypasses).  Reads is_tenant_admin from JWT.
export function requireTenantAdmin() {
  return (req, res, next) => {
    if (req.user.roles.includes('platform_admin')) return next();
    if (req.user.is_tenant_admin) return next();
    res.status(403).json({ error: 'Forbidden', message: 'Requires tenant admin' });
  };
}
```

### Frontend

The FE auth store exposes:

```typescript
hasEntitlement(key: string): boolean   // includes platform_admin bypass
hasAnyEntitlement(...keys: string[]): boolean
```

These are used in:
- **Route guards** (`meta: { requiresAuth: true }` — entitlement guards optional)
- **UI element visibility** (`v-if="auth.hasEntitlement('officials:create')"`)
- **Button/action disabling**

### Security Considerations

| Concern | Mitigation |
|---------|------------|
| Stale entitlements in JWT | Token expires in 24h; forced re-login on role change (future: token refresh endpoint) |
| Privilege escalation | `entitlement` table is global (read-only for tenants). Only entitlement *mappings* are configurable. Platform admins bypass all checks. |
| Cross-tenant access | RLS on `role_entitlement` table enforces tenant isolation. `roles` and `person_roles` also have RLS. |
| Entitlement management access | Modifying role-entitlement mappings requires `entitlements:update` entitlement (or platform_admin). |
| Role management access | Creating/deleting roles requires `roles:create`/`roles:delete` entitlement. |
| Platform admin override | `platform_admin` is a BFF-level concept (Cognito group or in-memory store). It is NOT a DB role and cannot be self-assigned by tenant admins. |
| Root admin takeover | The root admin's `is_root_admin` flag can only be changed via direct DB access. No API exposes it. BFF middleware + core-sys both block modification attempts (defense-in-depth). |
| Root admin visibility | Root admin is excluded from all listing queries (`listPlatformRoleAssignments`, `listTenantAdmins`). The FE never sees the root admin's person_id. |
| Tenant admin scope | Tenant admins can only modify role-entitlement mappings and per-person overrides within their own tenant (enforced by RLS). They cannot create platform roles or affect other tenants. |
| Per-person override abuse | Overrides are gated by `requireTenantAdmin()`. The override table uses a unique constraint to prevent conflicting grant+revoke on the same entitlement. |

### API Endpoints

**Core-sys (internal, behind service auth):**

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/v1/entitlements` | List all entitlement definitions |
| GET | `/v1/entitlements/resources` | List distinct resource names |
| GET | `/v1/roles` | List roles for tenant |
| GET | `/v1/roles/:id` | Get single role |
| POST | `/v1/roles` | Create role |
| PATCH | `/v1/roles/:id` | Update role |
| DELETE | `/v1/roles/:id` | Delete role (cascades) |
| GET | `/v1/roles/:roleId/entitlements` | List entitlements for a role |
| PUT | `/v1/roles/:roleId/entitlements` | Replace all entitlements for a role |
| POST | `/v1/roles/:roleId/entitlements` | Add single entitlement to role |
| DELETE | `/v1/roles/:roleId/entitlements/:entId` | Remove entitlement from role |
| GET | `/v1/roles/:roleId/members` | List persons assigned to role |
| GET | `/v1/roles-with-entitlements` | All roles + entitlements (combined view) |
| GET | `/v1/persons/:personId/roles` | List roles assigned to person |
| POST | `/v1/persons/:personId/roles` | Assign role to person |
| PUT | `/v1/persons/:personId/roles` | Replace all roles for person |
| DELETE | `/v1/persons/:personId/roles/:roleId` | Unassign role |
| GET | `/v1/persons/:personId/entitlements` | Resolve entitlement keys for person (with overrides) |
| GET | `/v1/persons/:personId/entitlement-overrides` | List per-person overrides |
| PUT | `/v1/persons/:personId/entitlement-overrides` | Replace all overrides for person |
| GET | `/v1/platform-roles` | List platform role assignments (excludes root admin) |
| GET | `/v1/platform-roles/root-admin-id` | Get root admin person_id (internal) |
| GET | `/v1/platform-roles/tenant-admins` | List all tenant admins across tenants (excludes root admin) |
| PUT | `/v1/platform-roles/persons/:personId` | Set platform roles for person |
| POST | `/v1/platform-roles/persons/:personId` | Assign single platform role |
| DELETE | `/v1/platform-roles/persons/:personId/:roleName` | Unassign platform role |

**BFF (frontend-facing, under `/api/proxy/`):**

All above endpoints are proxied through the BFF with:
- Write operations gated by appropriate entitlements
- `platform_admin` bypasses all entitlement checks
- Tenant context from JWT
- `rejectIfRootAdmin` middleware on all write routes for platform roles, person roles, and entitlement overrides
- `requireTenantAdmin()` gates entitlement override management

**Frontend admin views:**

| Route | View | Purpose |
|-------|------|---------|
| `/admin/roles` | RolesEntitlementsView | CRUD roles, configure entitlement matrix |
| `/admin/person-roles` | PersonRolesView | Three sections: Platform Admins (platform_admin only), Tenant Admins (platform_admin only), Tenant Role Assignments (all authorized users) |

## Database Migrations

| Migration | Description |
|-----------|-------------|
| V037 | Create `app.entitlement` and `app.role_entitlement` tables, seed 68 entitlements |
| V038 | Seed default role↔entitlement mappings (required platform-admin context for RLS bypass) |
| V039 | Create `app.platform_role_type` ENUM and `app.platform_role_assignment` table. Seed bootstrap platform_admin for person_id=1 (Alice). Add RLS policies. |
| V040 | Add `is_admin_role BOOLEAN` to `app.roles`. Create Tenant Admin role (all 68 entitlements, `is_admin_role = TRUE`). Create `app.person_entitlement_override` table for per-person grant/revoke overrides. |
| V041 | Add `is_root_admin BOOLEAN` to `app.platform_role_assignment`. Set `is_root_admin = TRUE` for person_id=1 bootstrap admin. |

## Production Migration: AWS Verified Permissions (Cedar)

The current implementation embeds entitlements in JWTs at login time. This
is pragmatic for local development and early deployments but has known
limitations that a production system must address:

| Local/MVP Limitation | Production Risk |
|----------------------|-----------------|
| Entitlements baked into JWT at login | Revoked roles remain effective until token expires (up to 24h) |
| Authorization logic in BFF middleware | Scattered, hard to audit centrally |
| No audit trail for authorization decisions | Cannot answer "who accessed what and why was it allowed" |
| No policy-as-code | Entitlement rules are data-driven, not version-controlled |

### Recommended Production Architecture: AWS Verified Permissions

**AWS Verified Permissions** (based on the Cedar policy language) is the
recommended production authorization engine. It integrates natively with
Cognito, provides policy-as-code, built-in audit logging, and per-request
authorization decisions.

```
  User request              BFF                     Verified Permissions
  ────────────              ───                     ────────────────────
  GET /api/proxy/           │                       │
   officials ──────────────►│                       │
                            │  isAuthorized({       │
                            │    principal: user,   │
                            │    action: "read",    │
                            │    resource: "officials"
                            │  }) ─────────────────►│
                            │◄── ALLOW / DENY       │
                            │                       │
                            │  (if ALLOW) proxy ──► core-sys
```

### Why Not OpenLDAP?

OpenLDAP is a **directory service** (identity management — users, groups,
organizational units), not an authorization/entitlement engine. It also
represents aging infrastructure with significant operational overhead.
Since ContestGrid already targets **AWS Cognito** for identity, LDAP would
be redundant and add complexity without solving the authorization problem.

### Why Not Other Options?

| Technology | Type | Why Not |
|-----------|------|---------|
| OPA (Open Policy Agent) | Policy-as-code sidecar | Good for K8s-native but requires self-hosting, sidecar management, and policy distribution |
| SpiceDB (Zanzibar) | Relationship-based ACL | Overkill — designed for "user X can edit document Y" granularity, not role-based CRUD gates |
| Keycloak | Identity + authorization server | Would replace Cognito entirely — not aligned with AWS-native direction |
| Cerbos | Policy-as-code, self-hosted | Good middle ground but still requires self-hosting; no managed service yet |

### Migration Path

The migration from local JWT-embedded entitlements to Verified Permissions
is designed to be incremental:

**Phase 1 — Cognito Migration (prerequisite)**

Replace the mock JWT provider with Cognito user pools. Person → Cognito
user mapping. Cognito groups replace BFF in-memory roles. JWT structure
remains the same (custom claims carry tenant_id, person_id).

**Phase 2 — Create Cedar Policy Store**

Convert the 68 entitlement definitions and role-entitlement mappings into
Cedar policies. The `resource:operation` key convention maps directly:

```cedar
// Cedar policy equivalent of "Primary Assigner Admin has officials:create"
permit (
  principal in ContestGrid::Role::"Primary Assigner Admin",
  action == ContestGrid::Action::"create",
  resource == ContestGrid::ResourceType::"officials"
) when {
  principal.tenantId == resource.tenantId
};
```

The DB tables (`app.entitlement`, `app.role_entitlement`) become the
**source of truth for policy generation** — a CI/CD step converts DB
state into Cedar policies and deploys them to the Verified Permissions
policy store.

**Phase 3 — Dual-Mode Authorization**

Run both systems in parallel:
1. BFF still checks JWT claims (existing `requireEntitlement()`)
2. BFF also calls Verified Permissions `isAuthorized()`
3. Log discrepancies between the two decisions
4. When discrepancy rate is zero, cut over to Verified Permissions only

**Phase 4 — Remove JWT Entitlements**

After cut-over:
- Remove entitlement claims from JWT (reduces token size)
- Remove `requireEntitlement()` middleware
- Replace with `requireAuthorization()` that calls Verified Permissions
- All authorization decisions are per-request, audited, and instant
- Role/entitlement changes take effect immediately (no re-login required)

**Phase 5 — Tenant-Admin Policy Management**

Expose a Cedar policy editor in the admin UI (or keep the existing
entitlement matrix UI backed by the DB, with a sync pipeline to Verified
Permissions). This preserves the tenant-admin experience while using Cedar
as the enforcement engine.

### What Stays the Same

| Component | Stays? | Notes |
|-----------|--------|-------|
| `app.entitlement` table | Yes | Remains the entitlement catalogue / source of truth |
| `app.role_entitlement` table | Yes | Remains the role↔entitlement mapping store |
| `app.person_roles` table | Yes | Remains the person↔role assignment store |
| Entitlement key convention (`resource:operation`) | Yes | Maps directly to Cedar actions/resource types |
| Admin UI (RolesEntitlementsView) | Yes | Drives the DB, which feeds Cedar policy generation |
| `hasEntitlement()` in FE store | Yes | Drives UI visibility (can switch to per-request calls later) |

### What Changes

| Component | Change |
|-----------|--------|
| `requireEntitlement()` BFF middleware | Replaced by `isAuthorized()` call to Verified Permissions |
| JWT entitlement claims | Removed — authorization is per-request |
| Stale entitlement window | Eliminated — changes are instant |
| Audit trail | Built-in via Verified Permissions decision logs → CloudWatch |

## Alternatives Considered

### 1. Attribute-Based Access Control (ABAC)

More flexible but significantly more complex.  RBAC with fine-grained
entitlements provides sufficient granularity for ContestGrid's use cases
without the operational complexity of policy engines.

### 2. Entitlements in Cognito (Production)

Cognito custom attributes have limits (max 50 custom attributes, 2048
character limit per attribute).  Entitlements could be stored as a
comma-separated custom attribute, but this doesn't support tenant-admin
configurability.  The DB-backed approach is more flexible and the JWT
embedding provides the same performance benefit.

### 3. Per-Request DB Lookup

Would allow instant entitlement changes but adds latency to every API
request.  JWT embedding trades freshness for performance — acceptable since
role changes are infrequent.  In production, AWS Verified Permissions
replaces this tradeoff entirely — per-request checks with sub-10ms latency.

### 4. OpenLDAP / Directory-Based Authorization

LDAP is an identity/directory protocol, not an authorization framework.
It cannot express fine-grained CRUD entitlements, has no per-request
policy evaluation, and would duplicate Cognito's identity management role.
Rejected as architecturally inappropriate for this use case.

## Consequences

### Positive

- Tenant admins can fully customize what each role can do without code changes
- Adding new entitlements only requires a Flyway migration + middleware annotation
- Zero-cost runtime checks (JWT claims) for MVP; sub-10ms per-request checks in production
- Backward-compatible — existing `requireRole()` middleware continues to work
- Auditable via standard DB timestamps (MVP) and Verified Permissions decision logs (production)
- Clear migration path from JWT-embedded to externalized authorization
- Entitlement key convention (`resource:operation`) maps directly to Cedar policies

### Negative

- JWT size increases (~1-2 KB for entitlement claims) — resolved in production phase 4
- Role/entitlement changes require re-login to take effect — resolved in production phase 4
- 68+ entitlement definitions to maintain (seed data in Flyway)
- New resources require a migration to add entitlement rows
- Production migration requires AWS Verified Permissions (additional AWS service cost)
- Dual-mode testing period adds temporary complexity
