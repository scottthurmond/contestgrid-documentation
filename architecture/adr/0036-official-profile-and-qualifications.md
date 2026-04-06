# ADR 0036: Official Profile & Qualifications

## Status
Proposed

## Context
The current `official` and `official_config` tables store only basic data: `person_id`, `official_config_id`, `uniform_number`, `association_joined_date`, and `contest_schedule_joined_ts`. Officials associations need a much richer profile to manage their workforce effectively. This ADR covers the static/semi-static profile attributes that describe who an official is, what they're qualified to do, and how they prefer to work.

Existing ADRs already address some adjacent topics:
- **ADR-0031**: Background checks & renewal policy (accepted; schema deferred)
- **ADR-0030**: 1099-NEC tax reporting
- **ADR-0003**: Billing & payroll models
- **ADR-0035**: Availability & blocking (schedule entry)

This ADR fills the gaps for certifications, years of service, appearance compliance, travel preferences, schedule limits, and pay/admin classification — all anchored to the official profile.

## Decision

### 1. Certifications & Training

#### `app.certification_type` (reference table)
| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `certification_type_id` | `integer` (PK) | NO | Auto-generated |
| `certification_type_name` | `varchar(100)` | NO | e.g., "NFHS", "NCAA", "State HS Mechanics", "Little League" |
| `issuing_body` | `varchar(200)` | YES | e.g., "National Federation of State HS Associations" |
| `sport_id` | `integer` (FK → sport) | YES | NULL = applies to all sports |
| `requires_renewal` | `boolean` | NO | Whether this cert expires and must be renewed |
| `default_validity_months` | `integer` | YES | Default validity period (NULL = indefinite if not renewed) |
| `tenant_id` | `bigint` (FK → tenant) | NO | Tenant isolation |
| `created_at` | `timestamptz` | NO | |
| `updated_at` | `timestamptz` | NO | |

#### `app.official_certification`
| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `official_certification_id` | `bigint` (PK) | NO | Auto-generated identity |
| `official_id` | `bigint` (FK → official) | NO | |
| `certification_type_id` | `integer` (FK → certification_type) | NO | |
| `certificate_number` | `varchar(100)` | YES | Cert/license number if applicable |
| `issued_date` | `date` | YES | When the certification was earned |
| `expiry_date` | `date` | YES | NULL = no expiration |
| `status` | `varchar(20)` | NO | `active`, `expired`, `revoked`, `pending` |
| `document_url` | `text` | YES | Link to uploaded certificate image/PDF |
| `notes` | `text` | YES | Free-text notes |
| `tenant_id` | `bigint` (FK → tenant) | NO | Tenant isolation |
| `created_at` | `timestamptz` | NO | |
| `updated_at` | `timestamptz` | NO | |

**Indexes**: `(official_id, certification_type_id)` unique per active cert; `(tenant_id, status, expiry_date)` for admin expiration queries.

**Expiration workflow**: A scheduled job (or scheduling-proc cron) checks certs approaching expiration. Notifications sent at configurable intervals (60d, 30d, 7d) — same reminder model as ADR-0031 background checks. Expired certs auto-transition to `expired` status and can optionally block assignments (configurable per certification type).

### 2. Background Check Tracking (Extends ADR-0031)

ADR-0031 defines the full background-check model. Per the user's requirement, we store **no details** of the check itself — only:
- When the last check was completed (`last_check_date`)
- When the next check is due (`next_check_due_date`)

These two fields are **derived** from the `background_check` table defined in ADR-0031 (`issued_at`, `expires_at`). The official profile UI shows them as computed/read-only fields. No additional schema is needed beyond what ADR-0031 proposes. The official profile page surfaces:
- **Last background check**: date, result (clear/review), provider
- **Next due**: computed from `expires_at` or policy renewal interval
- **Status badge**: ✅ Current | ⚠️ Expiring Soon | 🚫 Expired/Missing

### 3. Years of Service

Add columns to `app.official_config`:

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `service_start_month` | `smallint` | NO | Month (1–12) the official began officiating |
| `service_start_year` | `smallint` | NO | Four-digit year |

**Validation**: `service_start_month` between 1 and 12; `service_start_year` between 1950 and current year. Both fields required.

**Computed**: `years_of_service` is calculated at read time: `current_year - service_start_year` (adjusted down by 1 if current month < `service_start_month`). Not stored — always derived.

**Migration**: Existing `association_joined_date` (date, NOT NULL) can be used to backfill: `service_start_month = EXTRACT(MONTH FROM association_joined_date)`, `service_start_year = EXTRACT(YEAR FROM association_joined_date)`. After migration, `association_joined_date` is retained for association-specific tracking (when they joined *this* association) while `service_start_month/year` tracks total career service.

### 4. Appearance Compliance

#### `app.appearance_checklist_item` (reference table)
| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `checklist_item_id` | `integer` (PK) | NO | Auto-generated |
| `item_name` | `varchar(150)` | NO | e.g., "Correct jersey color", "Hat/cap worn", "Proper belt", "Clean shoes" |
| `sport_id` | `integer` (FK → sport) | YES | NULL = applies to all sports |
| `is_required` | `boolean` | NO | Whether failure is a violation or just advisory |
| `display_order` | `integer` | NO | Sort order on the checklist form |
| `tenant_id` | `bigint` (FK → tenant) | NO | Tenant isolation |
| `created_at` | `timestamptz` | NO | |
| `updated_at` | `timestamptz` | NO | |

#### `app.appearance_check`
| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `appearance_check_id` | `bigint` (PK) | NO | Auto-generated identity |
| `official_id` | `bigint` (FK → official) | NO | |
| `contest_schedule_id` | `bigint` (FK → contest_schedule) | YES | NULL = spot check not tied to a game |
| `checked_by` | `bigint` (FK → person) | NO | Person who performed the inspection |
| `check_date` | `date` | NO | |
| `overall_pass` | `boolean` | NO | Did the official pass overall? |
| `notes` | `text` | YES | |
| `tenant_id` | `bigint` (FK → tenant) | NO | |
| `created_at` | `timestamptz` | NO | |
| `updated_at` | `timestamptz` | NO | |

#### `app.appearance_check_detail`
| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `appearance_check_detail_id` | `bigint` (PK) | NO | |
| `appearance_check_id` | `bigint` (FK → appearance_check) | NO | |
| `checklist_item_id` | `integer` (FK → appearance_checklist_item) | NO | |
| `passed` | `boolean` | NO | |
| `notes` | `text` | YES | |

### 5. Travel Preferences

Officials often travel to games from different locations depending on the day/time — home on weekends, work on weekday evenings, a partner's house on certain nights, etc. Rather than a single travel origin, the system supports **multiple origin addresses**, each with its own travel-distance limit and optional schedule context.

#### `app.official_travel_origin`
| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `travel_origin_id` | `bigint` (PK) | NO | Auto-generated identity |
| `official_id` | `bigint` (FK → official) | NO | |
| `address_id` | `bigint` (FK → address) | NO | The physical address (reuses existing `app.address` table) |
| `label` | `varchar(50)` | NO | User-friendly name: e.g., "Home", "Work", "Partner's house" |
| `max_travel_distance_miles` | `numeric(6,1)` | YES | Maximum one-way travel distance **from this address** (NULL = no limit) |
| `is_default` | `boolean` | NO | If `true`, used when no day/time context matches. Exactly one row per official must be default. |
| `applies_days` | `smallint[]` | YES | ISO day-of-week numbers this origin applies to (1 = Mon … 7 = Sun). NULL = all days. e.g., `{1,2,3,4,5}` for weekdays |
| `applies_after_time` | `time` | YES | If set, this origin is used for games starting **at or after** this time (e.g., `17:00` for "after work"). Combined with `applies_days`. |
| `applies_before_time` | `time` | YES | If set, this origin is used for games starting **before** this time. |
| `display_order` | `smallint` | NO | Sort order in the UI |
| `tenant_id` | `bigint` (FK → tenant) | NO | |
| `created_at` | `timestamptz` | NO | |
| `updated_at` | `timestamptz` | NO | |

**Constraint**: `CHECK (is_default = true OR applies_days IS NOT NULL OR applies_after_time IS NOT NULL OR applies_before_time IS NOT NULL)` — non-default origins must have at least one scheduling qualifier.

**Unique**: `(official_id, is_default) WHERE is_default = true` — partial unique index ensures exactly one default per official.

**Origin resolution** (at assignment time):
1. Load all `official_travel_origin` rows for the official
2. For the contest's `contest_start_date` (day of week) and `contest_start_time`:
   - Find origins where `applies_days` contains the day AND `applies_after_time`/`applies_before_time` bracket the start time
   - If multiple match, use the one with the smallest `max_travel_distance_miles` (most restrictive)
   - If none match, fall back to the `is_default = true` origin
3. Compute great-circle distance from the resolved origin to the venue
4. If distance > `max_travel_distance_miles`, exclude from auto-assignment and flag in manual assignment UI
5. NULL `max_travel_distance_miles` = no distance restriction from that origin

**Examples**:
| Label | Days | Time | Max Distance | Usage |
|-------|------|------|-------------|-------|
| Home | — (default) | — | 25 mi | Weekend games, fallback |
| Work | Mon–Fri | after 17:00 | 15 mi | Weekday evening games |
| Partner's house | Fri, Sat | — | 30 mi | Friday/Saturday games |

**Migration**: If an official previously had a single address via `person.address_id`, a migration creates one `official_travel_origin` row with `is_default = true` and that address.

### 6. Venue & Team Preferences / Restrictions

#### `app.official_venue_preference`
| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `official_venue_pref_id` | `bigint` (PK) | NO | |
| `official_id` | `bigint` (FK → official) | NO | |
| `venue_id` | `bigint` (FK → venue) | NO | |
| `preference_type` | `varchar(20)` | NO | `preferred`, `restricted` |
| `reason` | `text` | YES | Free-text reason |
| `tenant_id` | `bigint` (FK → tenant) | NO | |
| `created_at` | `timestamptz` | NO | |
| `updated_at` | `timestamptz` | NO | |

#### `app.official_team_preference`
| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `official_team_pref_id` | `bigint` (PK) | NO | |
| `official_id` | `bigint` (FK → official) | NO | |
| `team_id` | `bigint` (FK → team) | NO | |
| `preference_type` | `varchar(20)` | NO | `preferred`, `restricted` |
| `reason` | `text` | YES | Free-text reason |
| `tenant_id` | `bigint` (FK → tenant) | NO | |
| `created_at` | `timestamptz` | NO | |
| `updated_at` | `timestamptz` | NO | |

**Unique**: `(official_id, venue_id)` and `(official_id, team_id)` — one preference per entity.

**Assignment behavior**:
- `preferred`: boost ranking score; official sees the game highlighted
- `restricted`: block assignment; manual override with acknowledgment by assigner

### 7. Schedule Limits

Add columns to `app.official_config`:

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `max_games_per_day` | `smallint` | YES | Maximum contests in a single day (NULL = no limit) |
| `max_games_per_week` | `smallint` | YES | Maximum contests Monday–Sunday (NULL = no limit) |

**Enforcement**: Scheduling-proc checks these limits before confirming assignments. If the limit would be exceeded, the official is excluded from auto-assignment and the assigner sees a warning on manual assignment.

### 8. Pay Rate & Classification

The existing `app.contest_rates` table stores per-tenant/sport/level billing and pay rates. To support per-official pay classification:

#### `app.pay_classification` (reference table)
| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `pay_classification_id` | `integer` (PK) | NO | |
| `classification_name` | `varchar(100)` | NO | e.g., "Standard", "Senior", "Trainee", "Premium" |
| `rate_modifier` | `numeric(5,4)` | YES | Multiplier applied to base rate (e.g., 1.25 for Senior = base × 1.25) |
| `tenant_id` | `bigint` (FK → tenant) | NO | |
| `created_at` | `timestamptz` | NO | |
| `updated_at` | `timestamptz` | NO | |

Add to `app.official_config`:

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `pay_classification_id` | `integer` (FK → pay_classification) | YES | NULL = uses standard base rate |

**Rate resolution**: `effective_rate = contest_rates.contest_umpire_rate × pay_classification.rate_modifier`. If `rate_modifier` is NULL, use 1.0.

### 9. Payment Method

Add to `app.official_config`:

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `preferred_payment_method` | `varchar(30)` | YES | `check`, `direct_deposit`, `venmo`, `zelle`, `cash_app`, `paypal` |

**Note**: Actual bank account / routing details are stored in the payment provider (Stripe Connect, etc.) — NOT in our database. This field captures the official's stated preference for the admin to process payments accordingly.

### 10. Tax Info (Extends ADR-0030)

ADR-0030 fully defines the 1099-NEC model. The official profile surfaces:
- **1099 applicable**: boolean (derived from `tax_profile` in ADR-0030)
- **W-9 on file**: status badge
- **TIN status**: verified / pending / missing

No additional schema needed — ADR-0030 covers it.

## API Surface

### officials-sys
```
GET    /v1/officials/:id/certifications
POST   /v1/officials/:id/certifications
PATCH  /v1/officials/:id/certifications/:certId
DELETE /v1/officials/:id/certifications/:certId

GET    /v1/officials/:id/appearance-checks
POST   /v1/officials/:id/appearance-checks
GET    /v1/officials/:id/appearance-checks/:checkId

GET    /v1/officials/:id/travel-origins
POST   /v1/officials/:id/travel-origins
PATCH  /v1/officials/:id/travel-origins/:originId
DELETE /v1/officials/:id/travel-origins/:originId

GET    /v1/officials/:id/venue-preferences
PUT    /v1/officials/:id/venue-preferences        (bulk replace)
GET    /v1/officials/:id/team-preferences
PUT    /v1/officials/:id/team-preferences          (bulk replace)

GET    /v1/certification-types
POST   /v1/certification-types
PATCH  /v1/certification-types/:id
DELETE /v1/certification-types/:id

GET    /v1/appearance-checklist-items
POST   /v1/appearance-checklist-items
PATCH  /v1/appearance-checklist-items/:id

GET    /v1/pay-classifications
POST   /v1/pay-classifications
PATCH  /v1/pay-classifications/:id
DELETE /v1/pay-classifications/:id
```

### Expanded `PATCH /v1/officials/:id/config`
Accepts the new `official_config` columns:
```json
{
  "service_start_month": 3,
  "service_start_year": 2018,
  "max_games_per_day": 3,
  "max_games_per_week": 8,
  "pay_classification_id": 2,
  "preferred_payment_method": "direct_deposit"
}
```

Travel origins are managed separately via `/v1/officials/:id/travel-origins` (see §5).

### BFF (proxy + orchestration)
- BFF proxies all the above to officials-sys
- The official profile page calls a single BFF aggregate endpoint:
  ```
  GET /api/officials/:id/profile-summary
  ```
  Returns: config, certifications (with expiry status), last background check, years of service (computed), appearance compliance rate, travel origins (with resolved default), venue/team preferences, schedule limits, pay classification, payment method

## Frontend UX

### Official Profile Page (Enhanced)
Organized as tabbed sections within the existing official detail view:

| Tab | Content |
|-----|---------|
| **Overview** | Name, uniform #, years of service, association joined date, pay classification, payment method, status badges (certs, background check) |
| **Certifications** | Table of certs with type, number, issued/expiry, status, document link. Add/edit/remove actions. Expiring-soon certs highlighted. |
| **Background** | Read-only summary: last check date, next due, status badge. Link to ADR-0031 admin workflow. |
| **Appearance** | Compliance history: table of checks with date, game, pass/fail, details. Overall compliance rate. |
| **Preferences** | Travel origins (multi-address cards: label, address, max distance, applicable days/times; add/edit/remove), preferred/restricted venues (multi-select), preferred/restricted teams (multi-select), schedule limits (games/day, games/week). |
| **Pay & Admin** | Pay classification, payment method, 1099 status. Editable by tenant admin only. |

### Certification Expiration Dashboard (Admin)
- List of officials with certs expiring within 30/60/90 days
- Bulk notification actions
- Filter by cert type, sport

## Consequences
- **Pros**: Rich official profiles reduce manual tracking in spreadsheets; expiration workflows prevent compliance lapses; travel/schedule limits improve auto-assignment accuracy; pay classification simplifies rate management
- **Cons**: Many new tables; migration effort for existing data; officials may resist entering all profile data (mitigate with progressive onboarding — mark fields as required over time)

## Related ADRs
- **ADR-0031**: Background Checks & Renewal Policy
- **ADR-0030**: 1099-NEC Officials
- **ADR-0003**: Billing & Payroll
- **ADR-0035**: Official Availability & Blocking
- **ADR-0023**: Contest Assignment & Official Metrics
- **ADR-0037**: Official Ranking, Tiers & Performance (companion)
- **ADR-0038**: Conflict of Interest & Risk Management (companion)
