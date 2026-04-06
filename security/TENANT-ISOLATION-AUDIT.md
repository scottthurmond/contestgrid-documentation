# Tenant Isolation Audit

**Date:** 2026-03-11 (updated with owner decisions)  
**Database:** contest_lab (PostgreSQL 16.13)  
**Schema:** app  
**Total tables:** 54

---

## Owner Decisions (2026-03-11)

> **"Everything should be tenant aware except subscription tables, flyway tables, and discount tables."**

- Venue/sub-venue: Everyone reads shared data; tenants can customize names via an alias/override layer. **DEFERRED** — requires custom design.
- All enum/lookup tables: Tenant-aware (each tenant gets their own set).

---

## Summary

| Category | Count | Tables |
|----------|-------|--------|
| ✅ Already isolated (tenant_id + RLS + forced) | 20 | See Section 1 |
| 🔧 Has tenant_id, needs RLS added | 5 | See Section 2 |
| 🔧 Needs tenant_id + RLS added | 22 | See Section 3 |
| 🔐 Platform-admin only (needs RLS, no tenant access) | 6 + flyway | See Section 4 |
| 🔒 Deferred — venue customization layer | 3 | See Section 5 |

**Total migration work:** 33 tables (5 add RLS + 22 add tenant_id + RLS + 6 add platform-admin-only RLS)

---

## Section 1: Already Fully Isolated (20 tables) ✅

Have `tenant_id`, RLS enabled, and `FORCE ROW LEVEL SECURITY` (V024). No changes needed.

| Table | Rows | Notes |
|-------|------|-------|
| `address` | 4 | ⚠️ See Section 5 — venue-related addresses need special handling |
| `bookings` | 0 | |
| `contest_league` | 4 | FK → officials_association |
| `contest_level` | 2 | FK → officials_association |
| `contest_rates` | 2 | FK → officials_association, sport, contest_level, contest_league |
| `contest_schedule` | 4 | FK → officials_association, sport, venue, teams |
| `contest_season` | 2 | |
| `official` | 350 | FK → person, official_config |
| `official_association_membership` | 350 | FK → official, officials_association |
| `official_config` | 350 | |
| `official_contest_assignment` | 6 | FK → contest_schedule, official |
| `officials_association` | 2 | |
| `payment` | 11 | FK → contest_schedule, official |
| `person` | 352 | |
| `team` | 13 | FK → contest_league, contest_level |
| `tenant_config` | 2 | FK → tenant |
| `tenant_person_map` | 6 | FK → tenant, person |
| `venue` | 1 | ⚠️ See Section 5 — needs venue customization layer |
| `phone` | 0 | FK → person. Has RLS but no tenant_id (inherits via person FK) |
| `venue_sub` | 4 | ⚠️ See Section 5 — needs venue customization layer |

---

## Section 2: Has tenant_id — Needs RLS Added (5 tables) 🔧

These already have `tenant_id` as a column. Need: `ENABLE ROW LEVEL SECURITY` + `FORCE ROW LEVEL SECURITY` + policies.

| # | Table | Rows | Backfill needed? |
|---|-------|------|-----------------|
| 1 | `tenant` | 5 | No — tenant_id is PK, policy: `tenant_id = current_setting(...)` |
| 2 | `tenant_license` | 2 | No — already has tenant_id |
| 3 | `tenant_pay_rate_map` | 1 | No — already has tenant_id |
| 4 | `tenant_sport_map` | 3 | No — already has tenant_id |
| 5 | `officials_tenant_map` | 1 | No — already has tenant_id |

---

## Section 3: Needs tenant_id + RLS Added (22 tables) 🔧

These currently have NO tenant_id and NO RLS. Need: `ADD COLUMN tenant_id`, backfill from FK chains, `NOT NULL`, RLS + policies.

### 3A. Billing data tables (6 tables)

| # | Table | Rows | Backfill strategy |
|---|-------|------|-------------------|
| 1 | `association_subscription` | 3 | Via FK `officials_association_id` → `officials_association.tenant_id` |
| 2 | `invoice` | 1 | Already has `officials_association_id` → backfill via FK |
| 3 | `invoice_line_item` | 2 | Via FK `invoice_id` → `invoice.tenant_id` (after invoice backfilled) |
| 4 | `invoice_payment` | 0 | Via FK `invoice_id` → `invoice.tenant_id` (empty, no backfill needed) |
| 5 | `billing_notification_config` | 9 | Via FK `officials_association_id` → `officials_association.tenant_id` |
| 6 | `billing_notification_log` | 0 | Via FK → billing_notification_config (empty, no backfill needed) |

### 3B. Person / role tables (2 tables)

| # | Table | Rows | Backfill strategy |
|---|-------|------|-------------------|
| 7 | `person_roles` | 7 | Via FK `person_id` → `person.tenant_id` |
| 8 | `person_type` | 3 | Enum — seed per-tenant copies or assign to platform tenant |

### 3C. Officials domain (1 table)

| # | Table | Rows | Backfill strategy |
|---|-------|------|-------------------|
| 9 | `official_slots` | 2 | Via FK `official_association_id` → `officials_association.tenant_id` |

### 3D. Contest / scheduling enums (3 tables)

| # | Table | Rows | Backfill strategy |
|---|-------|------|-------------------|
| 10 | `assignment_status` | 5 | Enum — seed per-tenant copies or assign to platform tenant |
| 11 | `contest_status` | 5 | Enum — seed per-tenant copies or assign to platform tenant |
| 12 | `contest_type` | 3 | Enum — seed per-tenant copies or assign to platform tenant |

### 3E. Billing enums (6 tables)

| # | Table | Rows | Backfill strategy |
|---|-------|------|-------------------|
| 13 | `invoice_payment_type` | 3 | Enum — seed per-tenant copies or assign to platform tenant |
| 14 | `invoice_status` | 8 | Enum — seed per-tenant copies or assign to platform tenant |
| 15 | `membership_status` | 3 | Enum — seed per-tenant copies or assign to platform tenant |
| 16 | `notification_status` | 4 | Enum — seed per-tenant copies or assign to platform tenant |
| 17 | `notification_type` | 5 | Enum — seed per-tenant copies or assign to platform tenant |
| 18 | `payment_status` | 6 | Enum — seed per-tenant copies or assign to platform tenant |
| 19 | `payment_type` | 2 | Enum — seed per-tenant copies or assign to platform tenant |

### 3F. Other reference tables (3 tables)

| # | Table | Rows | Backfill strategy |
|---|-------|------|-------------------|
| 20 | `roles` | 5 | Enum — seed per-tenant copies or assign to platform tenant |
| 21 | `sport` | 3 | Enum — seed per-tenant copies or assign to platform tenant |
| 22 | `tenant_type` | 2 | Enum — seed per-tenant copies or assign to platform tenant |

---

## Section 4: Platform-Admin Only (7 tables) 🔐

These are **NOT accessible to tenants in any way**. Only platform admins can read/write. Need RLS with platform-admin-only policies.

| Table | Rows | Reason | Needs RLS? |
|-------|------|--------|------------|
| `subscription_plan` | 2 | Subscription — platform-managed pricing plans | Yes |
| `subscription_status` | 5 | Subscription — platform-managed status enum | Yes |
| `subscription_tier` | 13 | Subscription — platform-managed tier definitions | Yes |
| `subscription_tier_date_audit` | 32 | Subscription — audit trail for platform-managed tiers | Yes |
| `discount_code` | 0 | Discount — platform-managed promo codes | Yes |
| `discount_type` | 2 | Discount — platform-managed discount type enum | Yes |
| `flyway_schema_history` | 25 | Flyway internal — not application data | No (system table) |

**RLS policy pattern for these tables (no tenant access):**
```sql
-- Only platform admin can read
CREATE POLICY <table>_platform_admin_select ON app.<table>
  FOR SELECT USING (
    current_setting('app.is_platform_admin', true) = 'true'
  );

-- Only platform admin can write
CREATE POLICY <table>_platform_admin_write ON app.<table>
  FOR ALL USING (
    current_setting('app.is_platform_admin', true) = 'true'
  );
```

---

## Section 5: DEFERRED — Venue Customization Layer 🔒

> **Owner decision:** Everyone should see venue/sub-venue data. Tenants cannot modify the source tables (address, venue, venue_sub). But tenants CAN customize names (aliases) for their own use.

**Current state:** `venue`, `venue_sub`, and `address` are already isolated with tenant_id + RLS. This means tenants can only see their own venues today.

**Required design (DEFERRED — handle later, somewhat complicated):**

1. **Shared read access** — All tenants can read all venue/sub-venue/address records regardless of tenant_id
2. **Write protection** — Tenants cannot INSERT/UPDATE/DELETE the source venue/sub-venue/address rows
3. **Tenant alias layer** — New table(s) like `tenant_venue_alias` and `tenant_venue_sub_alias` where tenants can store custom display names
4. **Read pattern** — API returns `COALESCE(alias.display_name, venue.venue_name)` so tenant sees their custom name or the default

**Possible new tables:**
```
tenant_venue_alias (tenant_id, venue_id, display_name, created_at, updated_at)
tenant_venue_sub_alias (tenant_id, venue_sub_id, display_name, created_at, updated_at)
```

**RLS changes needed:**
- Venue/sub-venue/address: Change SELECT policy to allow all tenants to read; restrict INSERT/UPDATE/DELETE to owner tenant or platform admin
- Alias tables: Standard tenant isolation (each tenant only sees/edits their own aliases)

**Status:** NOT STARTED — deliberately deferred per owner direction.

---

## Migration Execution Order

### Phase 1: Add RLS to tables that already have tenant_id (5 tables)
- V026: Enable RLS + FORCE RLS + policies on `tenant`, `tenant_license`, `tenant_pay_rate_map`, `tenant_sport_map`, `officials_tenant_map`

### Phase 2: Add tenant_id + RLS to billing data tables (6 tables)
- V027: `association_subscription`, `invoice`, `invoice_line_item`, `invoice_payment`, `billing_notification_config`, `billing_notification_log`
- Backfill tenant_id from FK chains → officials_association.tenant_id

### Phase 3: Add tenant_id + RLS to person/role + officials (3 tables)
- V028: `person_roles`, `person_type`, `official_slots`

### Phase 4: Add tenant_id + RLS to enum/lookup tables (13 tables)
- V029: `assignment_status`, `contest_status`, `contest_type`, `invoice_payment_type`, `invoice_status`, `membership_status`, `notification_status`, `notification_type`, `payment_status`, `payment_type`, `roles`, `sport`, `tenant_type`
- **Decision needed:** Seed per-tenant copies of enum data, or assign all existing rows to a platform/system tenant?

### Phase 5: Platform-admin-only RLS on subscription/discount tables (6 tables)
- V030: Enable RLS + FORCE RLS + **platform-admin-only** policies on `subscription_plan`, `subscription_status`, `subscription_tier`, `subscription_tier_date_audit`, `discount_code`, `discount_type`
- No tenant_id column needed — access gated entirely by `app.is_platform_admin = 'true'`
- Tenants get zero visibility into these tables

### Phase 6: Venue customization (DEFERRED)
- Design alias tables and modify RLS policies on venue/sub-venue/address

---

## Platform-Admin Access Pattern

All RLS policies use the two-pronged pattern:

```sql
-- SELECT: platform admin sees all, tenant sees own
CREATE POLICY <table>_select ON app.<table>
  FOR SELECT USING (
    current_setting('app.is_platform_admin', true) = 'true'
    OR tenant_id = current_setting('app.tenant_id', true)::BIGINT
  );

-- INSERT: always requires matching tenant_id
CREATE POLICY <table>_insert ON app.<table>
  FOR INSERT WITH CHECK (
    tenant_id = current_setting('app.tenant_id', true)::BIGINT
  );

-- UPDATE: platform admin or own tenant
CREATE POLICY <table>_update ON app.<table>
  FOR UPDATE USING (
    current_setting('app.is_platform_admin', true) = 'true'
    OR tenant_id = current_setting('app.tenant_id', true)::BIGINT
  );

-- DELETE: platform admin or own tenant
CREATE POLICY <table>_delete ON app.<table>
  FOR DELETE USING (
    current_setting('app.is_platform_admin', true) = 'true'
    OR tenant_id = current_setting('app.tenant_id', true)::BIGINT
  );
```

Service middleware sets session variables per request:
```typescript
// Tenant user
SET app.tenant_id = '1010';
SET app.is_platform_admin = 'false';

// Platform admin reading across tenants
SET app.tenant_id = '0';
SET app.is_platform_admin = 'true';

// Platform admin writing to a specific tenant
SET app.tenant_id = '1010';
SET app.is_platform_admin = 'true';
```
