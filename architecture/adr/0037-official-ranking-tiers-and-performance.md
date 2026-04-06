# ADR 0037: Official Ranking, Tiers & Performance

## Status
Proposed

## Context
Assigners need a fast, structured way to evaluate and rank officials so the best-qualified people are assigned to the right games. Currently there is no ranking data in the system — assigners carry this knowledge in their heads or in spreadsheets.

The ranking model must be **multi-dimensional**: an official's skill varies by **level** (e.g., Rec, Travel, High School) and **division** (e.g., Pee Wee, Minor, Major, Pony, Senior). Within each level+division combination, they carry a **tier** (1 = best, 2 = mid-level, 3 = "last resort").

Beyond manual tier assignment, the system must track game history, attendance, punctuality, coach and league feedback, soft-skill notes, per-game grading, crew compatibility, and automatic ranking trends over time. It should also support promotion tracking (e.g., JV → Varsity).

### Entitlement Model
A new resource `rankings` with two operations:
- `rankings:write` — ability to set/change an official's tier (assigned to **Primary Assigner Admin** by default)
- `rankings:read` — ability to view ranking data (assigned to **Secondary Assigner Admin** and Primary Assigner Admin by default)

## Decision

### 1. Tier Ranking (Level × Division × Tier)

#### `app.official_tier`
| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `official_tier_id` | `bigint` (PK) | NO | Auto-generated identity |
| `official_id` | `bigint` (FK → official) | NO | |
| `contest_level_id` | `bigint` (FK → contest_level) | NO | e.g., Rec, Travel, High School |
| `contest_league_id` | `bigint` (FK → contest_league) | NO | e.g., Rec 10U, Travel 12U (serves as the division) |
| `tier` | `smallint` | NO | 1 = top, 2 = mid, 3 = last resort |
| `ranked_by` | `bigint` (FK → person) | NO | Person who set the tier |
| `ranked_at` | `timestamptz` | NO | When the tier was last set/changed |
| `notes` | `text` | YES | Assigner notes justifying the ranking |
| `tenant_id` | `bigint` (FK → tenant) | NO | |
| `created_at` | `timestamptz` | NO | |
| `updated_at` | `timestamptz` | NO | |

**Unique constraint**: `(official_id, contest_level_id, contest_league_id)` — one tier per official per level+league(division).

**Example data**:
| Official | Level | League (Division) | Tier |
|----------|-------|--------------------|------|
| Fred Smith | Rec | Pony | 2 |
| Fred Smith | Rec | Major | 1 |
| Fred Smith | Rec | Minor | 1 |
| Tim Bryan | Travel | Travel 12U | 1 |
| Tim Bryan | Rec | Senior | 3 |

#### `app.official_tier_history`
Every tier change is logged for audit and trend analysis:

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `tier_history_id` | `bigint` (PK) | NO | |
| `official_tier_id` | `bigint` (FK → official_tier) | NO | |
| `previous_tier` | `smallint` | YES | NULL on first assignment |
| `new_tier` | `smallint` | NO | |
| `changed_by` | `bigint` (FK → person) | NO | |
| `changed_at` | `timestamptz` | NO | |
| `reason` | `text` | YES | Free-text reason for the change |
| `tenant_id` | `bigint` (FK → tenant) | NO | |

### 2. Fast Ranking UI

The ranking form must be **fast** — no long drawn-out process. The UI is a matrix/grid view:

```
                    Tee Ball   Pee Wee   Minor   Major   Pony   Senior
Fred Smith           —          3         2       1       2       —
Tim Bryan            —          —         1       1       1       2
Jane Doe             2          2         3       —       —       —
```

**Interaction**:
- Each cell is a clickable tier selector (1 / 2 / 3 / — for unranked)
- Click a cell → inline dropdown or toggle (1 → 2 → 3 → — → 1)
- Or drag-and-drop officials between tier swim lanes
- Bulk mode: select multiple officials, set tier for a level+division in one action
- Auto-save on change (no "Submit" button)
- Filter by level, division, current tier, official name
- Color coding: Tier 1 = green, Tier 2 = yellow, Tier 3 = red, Unranked = gray

**Keyboard shortcuts**: Arrow keys to navigate cells; 1/2/3/0 to set tier instantly.

### 3. Game History

All assignment history already exists in `app.official_contest_assignment`. The system needs to surface it holistically per official:

#### Game History View (per official)
Each row shows:
| Field | Source |
|-------|--------|
| Date | `contest_schedule.contest_start_date` |
| Time | `contest_schedule.contest_start_time` |
| Teams | `home_team.name` vs `visiting_team.name` |
| Level / Division | `contest_level.contest_level_name` / `contest_league.contest_league_name` |
| Venue | `venue.venue_name` |
| Status | `assignment_status.assignment_status_name` (Pending, Confirmed, Declined, Cancelled, Completed) |
| Position | `position_number` |
| Assigned at | `assigned_at` |
| Confirmed at | `confirmed_at` |
| Grade | from `official_game_grade` (see §5) |

**Filters**: Date range, status (assigned/given back/worked/declined), level, division, venue, team.

**Aggregates**:
- Total games worked (Completed)
- Total assignments (all statuses)
- Games given back (status changed from Confirmed → Cancelled by official)
- Decline rate
- Season breakdown

### 4. Attendance & Punctuality

ADR-0023 defines `OfficialPunctualityAudit` and `OfficialPunctualityMetrics` (location-based). In addition, for simpler systems not using GPS tracking, add manual attendance tracking:

#### `app.official_attendance`
| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `attendance_id` | `bigint` (PK) | NO | |
| `assignment_id` | `bigint` (FK → official_contest_assignment) | NO | |
| `official_id` | `bigint` (FK → official) | NO | |
| `contest_schedule_id` | `bigint` (FK → contest_schedule) | NO | |
| `arrived_on_time` | `boolean` | YES | NULL = not recorded |
| `minutes_early_or_late` | `smallint` | YES | Positive = early, negative = late |
| `no_show` | `boolean` | NO | Default false |
| `recorded_by` | `bigint` (FK → person) | NO | Who recorded attendance |
| `notes` | `text` | YES | |
| `tenant_id` | `bigint` (FK → tenant) | NO | |
| `created_at` | `timestamptz` | NO | |
| `updated_at` | `timestamptz` | NO | |

**Unique**: `(assignment_id)` — one attendance record per assignment.

### 5. Per-Game Grading & Feedback

#### `app.official_game_grade`
| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `game_grade_id` | `bigint` (PK) | NO | |
| `assignment_id` | `bigint` (FK → official_contest_assignment) | NO | |
| `official_id` | `bigint` (FK → official) | NO | |
| `contest_schedule_id` | `bigint` (FK → contest_schedule) | NO | |
| `graded_by` | `bigint` (FK → person) | NO | Evaluator / assigner / coach |
| `grader_role` | `varchar(30)` | NO | `assigner`, `evaluator`, `coach`, `league_director` |
| `overall_score` | `numeric(3,1)` | NO | 1.0–10.0 scale |
| `rule_knowledge_score` | `numeric(3,1)` | YES | 1.0–10.0 |
| `positioning_score` | `numeric(3,1)` | YES | 1.0–10.0 |
| `game_control_score` | `numeric(3,1)` | YES | 1.0–10.0 |
| `communication_score` | `numeric(3,1)` | YES | 1.0–10.0 |
| `professionalism_score` | `numeric(3,1)` | YES | 1.0–10.0 |
| `notes` | `text` | YES | Free-form narrative feedback |
| `tenant_id` | `bigint` (FK → tenant) | NO | |
| `created_at` | `timestamptz` | NO | |
| `updated_at` | `timestamptz` | NO | |

**Unique**: `(assignment_id, graded_by)` — one grade per grader per assignment.

#### Soft-Skill Tags

#### `app.feedback_tag` (reference table)
| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `feedback_tag_id` | `integer` (PK) | NO | |
| `tag_name` | `varchar(100)` | NO | e.g., "Good Game Control", "Struggles with positioning", "Avoid high-conflict games", "Strong communicator" |
| `tag_category` | `varchar(30)` | NO | `strength`, `concern`, `note` |
| `tenant_id` | `bigint` (FK → tenant) | NO | |
| `created_at` | `timestamptz` | NO | |
| `updated_at` | `timestamptz` | NO | |

#### `app.official_game_grade_tag`
| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `game_grade_tag_id` | `bigint` (PK) | NO | |
| `game_grade_id` | `bigint` (FK → official_game_grade) | NO | |
| `feedback_tag_id` | `integer` (FK → feedback_tag) | NO | |

This allows fast tagging: after grading, the evaluator clicks applicable tags from a chip list (e.g., ✅ "Good Game Control", ⚠️ "Struggles getting into position from A to B", 🚫 "Avoid high-conflict games").

#### `app.official_standing_tag`
Persistent tags that live on the official's profile (not tied to a single game):

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `standing_tag_id` | `bigint` (PK) | NO | |
| `official_id` | `bigint` (FK → official) | NO | |
| `feedback_tag_id` | `integer` (FK → feedback_tag) | NO | |
| `applied_by` | `bigint` (FK → person) | NO | |
| `applied_at` | `timestamptz` | NO | |
| `removed_at` | `timestamptz` | YES | NULL = still active |
| `notes` | `text` | YES | |
| `tenant_id` | `bigint` (FK → tenant) | NO | |

### 6. Coach & League Feedback

Uses the same `official_game_grade` table with `grader_role = 'coach'` or `'league_director'`. Coaches rate on a simpler scale:

| Field | Description |
|-------|-------------|
| `overall_score` | 1–10 |
| `notes` | Free-text feedback |
| Soft-skill tags | Select from same `feedback_tag` list |

Coach/league grades are **visible to assigners** but **not to officials** (configurable per tenant). This prevents retaliation concerns.

### 7. Game Difficulty Rating

#### `app.contest_difficulty`
| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `contest_difficulty_id` | `bigint` (PK) | NO | |
| `contest_schedule_id` | `bigint` (FK → contest_schedule) | NO | |
| `difficulty_score` | `smallint` | NO | 1–5 (1 = routine, 5 = high-stakes/high-conflict) |
| `rated_by` | `bigint` (FK → person) | NO | |
| `factors` | `text` | YES | e.g., "Rivalry game", "Playoff elimination", "Problem coach on home team" |
| `tenant_id` | `bigint` (FK → tenant) | NO | |
| `created_at` | `timestamptz` | NO | |
| `updated_at` | `timestamptz` | NO | |

**Assignment algorithm**: High-difficulty games (4–5) are only auto-assigned to Tier 1 officials. Medium (2–3) can go to Tier 1 or 2. Low (1) can go to any tier.

### 8. Crew Compatibility

#### `app.crew_compatibility`
| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `crew_compatibility_id` | `bigint` (PK) | NO | |
| `official_a_id` | `bigint` (FK → official) | NO | First official (always lower ID) |
| `official_b_id` | `bigint` (FK → official) | NO | Second official (always higher ID) |
| `compatibility_type` | `varchar(20)` | NO | `preferred`, `avoid`, `mentor` |
| `set_by` | `bigint` (FK → person) | NO | |
| `reason` | `text` | YES | |
| `tenant_id` | `bigint` (FK → tenant) | NO | |
| `created_at` | `timestamptz` | NO | |
| `updated_at` | `timestamptz` | NO | |

**Unique**: `(official_a_id, official_b_id)` — one compatibility record per pair.

**Types**:
- `preferred`: These officials work well together; favor pairing them
- `avoid`: Do not schedule together (personality clash, etc.)
- `mentor`: Pair experienced official with a developing one; prefer assigning together to lower-tier games

### 9. Automated Ranking Over Time

A scheduled process (scheduling-proc cron or event-driven) computes a **composite ranking score** per official per level+division. The score is derived from:

| Factor | Weight (configurable) | Source |
|--------|----------------------|--------|
| Current tier | 40% | `official_tier.tier` |
| Average game grade | 25% | `official_game_grade.overall_score` avg (last N games) |
| Attendance rate | 15% | `official_attendance` — % of assignments with `no_show = false` and `arrived_on_time = true` |
| Decline / turn-back rate | 10% | from `official_contest_assignment` status history |
| Years of service | 5% | from `official_config.service_start_year/month` |
| Soft-skill penalty | 5% | Deductions for active `concern` tags on `official_standing_tag` |

#### `app.official_ranking_score`
| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `ranking_score_id` | `bigint` (PK) | NO | |
| `official_id` | `bigint` (FK → official) | NO | |
| `contest_level_id` | `bigint` (FK → contest_level) | NO | |
| `contest_league_id` | `bigint` (FK → contest_league) | NO | |
| `composite_score` | `numeric(5,2)` | NO | 0.00–100.00 |
| `tier_component` | `numeric(5,2)` | NO | |
| `grade_component` | `numeric(5,2)` | NO | |
| `attendance_component` | `numeric(5,2)` | NO | |
| `reliability_component` | `numeric(5,2)` | NO | |
| `experience_component` | `numeric(5,2)` | NO | |
| `penalty_component` | `numeric(5,2)` | NO | |
| `computed_at` | `timestamptz` | NO | |
| `tenant_id` | `bigint` (FK → tenant) | NO | |

**Recomputed**: Nightly or on-demand. The score is **advisory** — it doesn't replace the assigner's manual tier, but it highlights when a Tier 2 official is performing like a Tier 1 (promotion candidate) or a Tier 1 is slipping (demotion warning).

### 10. Promotion Tracking

#### `app.official_promotion`
| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `promotion_id` | `bigint` (PK) | NO | |
| `official_id` | `bigint` (FK → official) | NO | |
| `from_level_id` | `bigint` (FK → contest_level) | YES | NULL if first entry into a level |
| `from_league_id` | `bigint` (FK → contest_league) | YES | |
| `to_level_id` | `bigint` (FK → contest_level) | NO | |
| `to_league_id` | `bigint` (FK → contest_league) | NO | |
| `from_tier` | `smallint` | YES | |
| `to_tier` | `smallint` | NO | |
| `promoted_by` | `bigint` (FK → person) | NO | |
| `promoted_at` | `timestamptz` | NO | |
| `reason` | `text` | YES | |
| `season_id` | `bigint` (FK → contest_season) | YES | Season during which the promotion occurred |
| `tenant_id` | `bigint` (FK → tenant) | NO | |

**Trigger**: When an `official_tier` row is updated and the tier improves (e.g., 2 → 1) or the official is ranked in a higher level, a promotion record is auto-created. Also supports manual "promoted from JV to Varsity" entries.

## New Entitlements

| `entitlement_key` | `resource_name` | `operation` | `description` |
|--------------------|-----------------|-------------|---------------|
| `rankings:read` | `rankings` | `read` | View official tier rankings and composite scores |
| `rankings:write` | `rankings` | `write` | Set/change official tiers and approve promotions |

**Default role assignments**:
| Role | `rankings:read` | `rankings:write` |
|------|-----------------|-------------------|
| Primary Assigner Admin | ✅ | ✅ |
| Secondary Assigner Admin | ✅ | — |
| Tenant Admin | ✅ | ✅ |
| Official | — | — |
| Coach | — | — |
| League Director | — | — |

## API Surface

### officials-sys
```
GET    /v1/officials/:id/tiers                     — all tiers for an official
PUT    /v1/officials/:id/tiers                     — bulk set tiers (fast ranking)
PATCH  /v1/officials/:id/tiers/:tierId             — update single tier
GET    /v1/officials/:id/tier-history               — audit trail

GET    /v1/officials/:id/attendance                 — attendance records
POST   /v1/officials/:id/attendance                 — record attendance for a game

GET    /v1/officials/:id/grades                     — all game grades
POST   /v1/officials/:id/grades                     — submit a grade
GET    /v1/officials/:id/grades/summary              — averages, trends

GET    /v1/officials/:id/standing-tags               — active standing tags
POST   /v1/officials/:id/standing-tags               — apply tag
DELETE /v1/officials/:id/standing-tags/:tagId         — remove tag

GET    /v1/officials/:id/ranking-scores              — composite scores per level+division
POST   /v1/officials/ranking-scores/recompute        — trigger recomputation

GET    /v1/officials/:id/promotions                  — promotion history
POST   /v1/officials/:id/promotions                  — manual promotion entry

GET    /v1/crew-compatibility                        — all pairings
POST   /v1/crew-compatibility                        — create pairing
PATCH  /v1/crew-compatibility/:id                    — update
DELETE /v1/crew-compatibility/:id                    — remove

GET    /v1/contests/:id/difficulty                   — game difficulty rating
POST   /v1/contests/:id/difficulty                   — set difficulty
PATCH  /v1/contests/:id/difficulty/:id               — update

GET    /v1/feedback-tags                             — all tags
POST   /v1/feedback-tags                             — create tag
PATCH  /v1/feedback-tags/:id                         — update tag
DELETE /v1/feedback-tags/:id                         — deactivate tag
```

### scheduling-proc (orchestration)
```
POST   /v1/rankings/recompute                       — trigger nightly ranking recalculation
GET    /v1/rankings/leaderboard?level=&league=       — sorted officials by composite score
GET    /v1/rankings/promotion-candidates              — officials whose score suggests tier upgrade
GET    /v1/rankings/demotion-warnings                 — officials whose score suggests tier downgrade
```

## Frontend UX

### Fast Ranking Grid (Primary UI)
- **Route**: `/officials/rankings`
- **Entitlement gate**: `rankings:read` to view, `rankings:write` to edit
- Full-width matrix: rows = officials, columns = divisions (grouped by level)
- Each cell shows tier (1/2/3/—) with color coding
- Click-to-cycle (1→2→3→—→1) or dropdown
- Inline save (auto-save, debounced 500ms)
- Keyboard navigation (arrow keys + number keys)
- Bulk actions: select multiple officials, set tier for selected level+division
- Filters: by official name, current tier, level, division, has-no-ranking

### Official Performance Dashboard
- **Route**: `/officials/:id/performance`
- **Sections**:
  - **Ranking overview**: Current tiers across all level+division combos as colored chips
  - **Composite score**: Gauge/bar showing 0–100 with component breakdown
  - **Game history**: Sortable/filterable table (date, teams, venue, status, grade, attendance)
  - **Grade trends**: Line chart of `overall_score` over time
  - **Attendance**: On-time %, late %, no-show count
  - **Feedback tags**: Active standing tags as chips (green = strength, red = concern)
  - **Promotion history**: Timeline view

### Post-Game Quick Grade
After a game is marked Completed, the assigner gets a notification/prompt to grade officials who worked. The form shows:
- Overall score (1–10, required, large slider or number input)
- Optional sub-scores (rule knowledge, positioning, game control, communication, professionalism)
- Tag selector (click applicable chips from the `feedback_tag` list)
- Notes (optional free text)
- **Goal**: Complete in under 30 seconds for a routine game

### Composite Score Leaderboard (Admin)
- Sorted table of officials by `composite_score` per level+division
- Highlights promotion candidates (Tier 2 with score above Tier 1 threshold) and demotion warnings (Tier 1 with score below Tier 2 threshold)
- Configurable thresholds per tenant

## Consequences
- **Pros**: Structured ranking replaces tribal knowledge; fast UI reduces assigner burden; composite scoring surfaces promotion/demotion candidates automatically; game-level grading builds objective performance history; soft-skill tags capture qualitative insights without free-text chaos
- **Cons**: Requires buy-in from assigners to grade games consistently; composite score weights need tuning per association; tier history generates significant data over time (mitigate with archival); officials may object to being graded (mitigate with privacy — grades not visible to officials by default, configurable per tenant)

## Related ADRs
- **ADR-0023**: Contest Assignment & Official Metrics (metrics, punctuality, location)
- **ADR-0036**: Official Profile & Qualifications (companion — certifications, years of service)
- **ADR-0038**: Conflict of Interest & Risk Management (companion)
- **ADR-0011**: Officials Payment Workflow (game completion triggers)
- **ADR-0027**: Officials Game Report Workflow (game reports feed into grading)
