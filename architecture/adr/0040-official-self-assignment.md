# ADR 0040: Official Self-Assignment

## Status
Proposed

## Context
Assigners currently bear the full burden of scheduling every official to every contest. Many associations would benefit from allowing officials to **self-assign** to open games — particularly at the Rec level, where demand is high and the pool is large. However, unrestricted self-assignment introduces risk: an official may claim a game above their skill level or at a venue they are not qualified to work.

The system needs:
1. A **global toggle** so the primary assigner can enable or disable self-assignment across the entire tenant.
2. A **per-official toggle** so the assigner can grant or revoke self-assign privileges on an individual basis.
3. **Restriction rules** that constrain *what* an official may self-assign to — by sport, venue, contest level, and contest league (division) — informed by the official's tier ranking (ADR-0037).

### Relationship to Other ADRs
- **ADR-0037** — Official tiers (`official_tier`) determine which level+division combinations an official is qualified for.
- **ADR-0036** — Official profile/preferences (venue/team preferences may further inform UI display but do not gate self-assignment).
- **ADR-0035** — Availability/blocking: an official may only self-assign to a contest that falls within an available window.

### Entitlement Model
A new resource `self-assign` with two operations:
- `self-assign:write` — ability to change global/per-official self-assign settings (assigned to **Primary Assigner Admin** by default)
- `self-assign:read` — ability to view self-assign configuration (assigned to **Primary Assigner Admin** and **Secondary Assigner Admin** by default)

Officials exercising self-assignment do **not** need a special entitlement — the per-official `is_self_assign_enabled` flag and the restriction rules serve as the gate. The existing `assignments:write` entitlement is required.

## Decision

### 1. Global Self-Assignment Toggle

Add a column to `app.officials_association`:

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| `self_assign_enabled` | `boolean` | NO | `false` | When `false`, no official in this association may self-assign regardless of individual settings. When `true`, self-assignment is governed by per-official settings. |

**Why on `officials_association`?** A tenant may operate multiple associations (e.g., baseball and softball). Self-assignment policy may differ by association. Placing the toggle here gives per-association granularity.

**UI**: Toggle switch on the Association Settings page, visible only to users with `self-assign:write`.

### 2. Per-Official Self-Assignment Flag

Add a column to `app.official_config`:

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| `is_self_assign_enabled` | `boolean` | NO | `false` | Whether this official is allowed to self-assign when the global toggle is also on. |

**Logic**: An official can self-assign **only if**:
1. `officials_association.self_assign_enabled = true` (global on), **AND**
2. `official_config.is_self_assign_enabled = true` (individual on).

**UI**: Checkbox on the Official Profile page (Preferences tab), editable only by users with `self-assign:write`.

### 3. Self-Assignment Restriction Rules

#### `app.self_assign_restriction`

Each row whitelists a specific combination that the official is allowed to self-assign. If **no rows** exist for an official, the official has **no restrictions** and may self-assign to any open contest (subject to availability and travel distance). If **one or more rows** exist, the official may only self-assign to contests matching at least one row.

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `self_assign_restriction_id` | `bigint` (PK) | NO | Auto-generated identity |
| `official_id` | `bigint` (FK → official) | NO | The official this rule applies to |
| `sport_id` | `integer` (FK → sport) | YES | NULL = any sport |
| `venue_id` | `bigint` (FK → venue) | YES | NULL = any venue |
| `contest_level_id` | `bigint` (FK → contest_level) | YES | NULL = any level |
| `contest_league_id` | `bigint` (FK → contest_league) | YES | NULL = any league/division |
| `max_tier` | `smallint` | YES | Maximum tier value (1–3) the official must hold in the matching level+division to self-assign. NULL = no tier check. e.g., `2` means the official must be Tier 1 or 2 in that level+division. |
| `tenant_id` | `bigint` (FK → tenant) | NO | Tenant isolation |
| `created_at` | `timestamptz` | NO | |
| `updated_at` | `timestamptz` | NO | |

**Unique constraint**: `(official_id, sport_id, venue_id, contest_level_id, contest_league_id)` — prevent duplicate rules (using `COALESCE` or partial indexes for NULL handling).

**Examples**:

| Official | Sport | Venue | Level | Division | Max Tier | Meaning |
|----------|-------|-------|-------|----------|----------|---------|
| Fred | Baseball | NULL | Rec | Pee Wee | 2 | Fred can self-assign to Rec Pee Wee Baseball at any venue, but only if his tier for Rec+Pee Wee is 1 or 2 |
| Fred | Baseball | NULL | Rec | Minor | NULL | Fred can self-assign to Rec Minor Baseball, no tier check |
| Tim | NULL | NULL | NULL | NULL | NULL | Tim has no restrictions (can self-assign to anything) — same as having zero rows |
| Jane | Baseball | Venue A | NULL | NULL | NULL | Jane can only self-assign to Baseball games at Venue A |

### 4. Self-Assignment Eligibility Check

When an official attempts to self-assign to a contest, the system verifies:

```
1. officials_association.self_assign_enabled = true
2. official_config.is_self_assign_enabled = true
3. Contest has open (unfilled) official slots
4. Official is not already assigned to this contest
5. Contest falls within an available window (ADR-0035) and not in a blocked period
6. Travel distance is within limit (ADR-0036 travel origins)
7. Schedule limits not exceeded (max_games_per_day / max_games_per_week from ADR-0036)
8. IF self_assign_restriction rows exist for this official:
   a. At least one restriction row matches the contest's sport_id, venue_id, contest_level_id, contest_league_id
      (NULL in the restriction row = wildcard match)
   b. IF that matching row has a max_tier value:
      - Look up official_tier for (official_id, contest_level_id, contest_league_id)
      - Official's tier must be <= max_tier (i.e., Tier 1 ≤ 2 passes; Tier 3 ≤ 2 fails)
      - If no official_tier row exists, the official is treated as unranked and FAILS the tier check
9. No active conflict of interest (ADR-0038) for teams/venue in the contest
```

**On failure**: Return a structured error indicating which check(s) failed so the UI can display a meaningful message.

### 5. Self-Assignment Workflow

1. Official opens the **Available Games** view (filtered to their association, availability, travel range)
2. Games eligible for self-assignment are shown with a **"Claim"** button
3. Official clicks **Claim** → API performs eligibility check (§4)
4. On success: assignment created with `assignment_status = 'Confirmed'` (self-assignments skip the Pending→Confirmed step)
5. On failure: toast/dialog explains the reason (e.g., "Your tier for Rec Major is 3 — this game requires Tier 2 or better")
6. Assigner receives a notification that the official self-assigned (configurable — can be turned off)
7. Assigner can **revoke** a self-assignment at any time (existing assignment delete/cancel flow)

### 6. Admin Bulk Configuration

Assigners need fast tools to manage self-assign settings for many officials:

- **Bulk toggle**: Select multiple officials → Enable/Disable self-assign
- **Copy restrictions**: Select an official → Copy their restriction rules to other officials
- **Template rules**: Create named restriction templates (e.g., "Rec-only beginners", "Travel-qualified seniors") and apply to officials

Template functionality is a future enhancement — not in the initial schema. The bulk toggle and copy operations are API features, not additional tables.

## API Surface

### officials-sys

```
-- Global toggle
PATCH  /v1/associations/:id                        { "self_assign_enabled": true }

-- Per-official toggle (existing config endpoint, new field)
PATCH  /v1/officials/:id                           { "is_self_assign_enabled": true }

-- Restriction rules CRUD
GET    /v1/officials/:id/self-assign-restrictions
POST   /v1/officials/:id/self-assign-restrictions
PATCH  /v1/officials/:id/self-assign-restrictions/:ruleId
DELETE /v1/officials/:id/self-assign-restrictions/:ruleId
PUT    /v1/officials/:id/self-assign-restrictions   (bulk replace)

-- Self-assignment action
POST   /v1/officials/:id/self-assign               { "contest_schedule_id": 42 }
```

### BFF
```
-- Proxies all the above
-- Additional aggregate endpoint:
GET    /api/officials/:id/available-games           Returns contests eligible for self-assign
POST   /api/officials/:id/self-assign               Proxies to officials-sys
```

## Frontend UX

### Official View — Available Games
- Filterable list/calendar of upcoming contests with open slots
- Each game card shows: date, time, venue, level, division, sport, slots remaining
- Games that pass all eligibility checks show a green **"Claim"** button
- Games that fail show a grayed **"Not Eligible"** badge with tooltip explaining why
- After claiming, the game moves to "My Assignments" with a ✅ badge

### Assigner View — Self-Assign Settings
- **Association Settings**: Global toggle switch
- **Officials List**: Column showing self-assign status (On/Off), filterable
- **Official Profile → Preferences Tab**: Toggle + restriction rules table
  - Add/edit/remove restriction rows
  - Each row: sport dropdown, venue dropdown, level dropdown, league/division dropdown, max tier dropdown
  - Dropdowns default to "Any" (NULL) for ease of use

## Consequences
- **Pros**: Reduces assigner workload dramatically for high-volume associations; officials get agency over their schedules; restriction rules prevent unqualified self-assignment; tier integration ensures skill-appropriate games
- **Cons**: Adds complexity to the assignment eligibility logic; officials associations with strict assigner-only culture may find this feature unwelcome (mitigated by the global toggle defaulting to OFF); potential for rapid "land grab" on popular games (mitigated by tier restrictions and future fairness/rotation features)

## Related ADRs
- **ADR-0035**: Official Availability & Blocking
- **ADR-0036**: Official Profile & Qualifications
- **ADR-0037**: Official Ranking, Tiers & Performance
- **ADR-0038**: Conflict of Interest & Risk Management
