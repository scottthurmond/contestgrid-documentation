# ADR 0038: Conflict of Interest & Risk Management

## Status
Proposed

## Context
Assigning officials to games where they have a personal connection — child on a team, close friend coaching, school affiliation — creates conflicts of interest that undermine fairness and expose the association to complaints and liability. Currently there is no system-level tracking; assigners rely on memory and word-of-mouth.

This ADR addresses three domains:
1. **Conflict of interest tracking** — self-declared and admin-managed relationships that block or warn against specific assignments
2. **Disciplinary history** — warnings, suspensions, probation, reinstatement for officials
3. **Ejection & incident report involvement** — linking officials to game incidents recorded in the game report workflow (ADR-0027)

## Decision

### 1. Conflict of Interest

#### `app.conflict_relationship_type` (reference table)
| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `relationship_type_id` | `integer` (PK) | NO | |
| `relationship_type_name` | `varchar(100)` | NO | e.g., "Parent of player", "Spouse of coach", "School affiliation", "Close friend of coach", "Family member on team", "Former player", "Business relationship" |
| `severity` | `varchar(20)` | NO | `hard_block` (always prevent), `soft_block` (warn but allow override), `advisory` (informational only) |
| `tenant_id` | `bigint` (FK → tenant) | NO | |
| `created_at` | `timestamptz` | NO | |
| `updated_at` | `timestamptz` | NO | |

#### `app.official_conflict`
| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `official_conflict_id` | `bigint` (PK) | NO | Auto-generated identity |
| `official_id` | `bigint` (FK → official) | NO | |
| `relationship_type_id` | `integer` (FK → conflict_relationship_type) | NO | |
| `related_team_id` | `bigint` (FK → team) | YES | Team the conflict relates to |
| `related_person_id` | `bigint` (FK → person) | YES | Specific person (coach, player parent, etc.) |
| `related_venue_id` | `bigint` (FK → venue) | YES | Venue-based conflict (e.g., works at the school) |
| `related_league_id` | `bigint` (FK → contest_league) | YES | League-level conflict |
| `description` | `text` | NO | Free-text explanation (e.g., "Son plays on Titans 12U", "Best friends with Coach Jim Miller") |
| `declared_by` | `bigint` (FK → person) | NO | Who reported the conflict (official self-report or admin) |
| `is_self_declared` | `boolean` | NO | True if the official reported it themselves |
| `effective_from` | `date` | NO | When the conflict begins (e.g., start of season) |
| `effective_to` | `date` | YES | When the conflict ends (NULL = indefinite/ongoing) |
| `status` | `varchar(20)` | NO | `active`, `expired`, `waived`, `removed` |
| `waived_by` | `bigint` (FK → person) | YES | If status = waived, who authorized the waiver |
| `waiver_reason` | `text` | YES | Why the conflict was waived |
| `tenant_id` | `bigint` (FK → tenant) | NO | |
| `created_at` | `timestamptz` | NO | |
| `updated_at` | `timestamptz` | NO | |

**Indexes**:
- `(official_id, status)` — quickly find active conflicts for an official
- `(related_team_id, status)` — quickly check if any official has a conflict with a team
- `(tenant_id, status, effective_from, effective_to)` — admin queries

**Assignment integration**:
When assigning an official to a contest, the scheduling-proc checks:
1. Load `official_conflict` where `status = 'active'` and today is within `effective_from`/`effective_to`
2. Match against the contest's `home_team_id`, `visiting_team_id`, `venue_id`, `contest_league_id`
3. If `severity = 'hard_block'` → exclude from auto-assignment; block manual assignment with error message
4. If `severity = 'soft_block'` → exclude from auto-assignment; allow manual assignment with a **confirmation dialog** showing the conflict details
5. If `severity = 'advisory'` → allow assignment; show an info badge on the assignment card

**Self-declaration workflow**:
Officials can declare their own conflicts via the official portal. An admin reviews and approves or adjusts severity. Self-declared conflicts default to `soft_block` until reviewed.

### 2. Disciplinary History

#### `app.disciplinary_action_type` (reference table)
| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `action_type_id` | `integer` (PK) | NO | |
| `action_type_name` | `varchar(100)` | NO | e.g., "Verbal Warning", "Written Warning", "Probation", "Suspension", "Termination", "Reinstatement" |
| `severity_rank` | `smallint` | NO | Ordering: 1 = mildest (verbal warning), 6 = most severe (termination) |
| `blocks_assignments` | `boolean` | NO | Whether this action prevents game assignments while active |
| `tenant_id` | `bigint` (FK → tenant) | NO | |
| `created_at` | `timestamptz` | NO | |
| `updated_at` | `timestamptz` | NO | |

#### `app.official_disciplinary_action`
| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `disciplinary_action_id` | `bigint` (PK) | NO | |
| `official_id` | `bigint` (FK → official) | NO | |
| `action_type_id` | `integer` (FK → disciplinary_action_type) | NO | |
| `issued_by` | `bigint` (FK → person) | NO | Admin who issued the action |
| `issued_at` | `timestamptz` | NO | When the action was issued |
| `effective_from` | `date` | NO | When the action takes effect |
| `effective_to` | `date` | YES | When the action expires (NULL = indefinite until manually lifted) |
| `reason` | `text` | NO | Detailed reason/description |
| `related_contest_id` | `bigint` (FK → contest_schedule) | YES | Game that triggered the action (if applicable) |
| `related_incident_id` | `bigint` | YES | FK to incident report (if applicable, see §3) |
| `status` | `varchar(20)` | NO | `active`, `completed`, `appealed`, `overturned`, `expired` |
| `appeal_notes` | `text` | YES | Notes from appeal process |
| `resolved_by` | `bigint` (FK → person) | YES | Admin who resolved/closed the action |
| `resolved_at` | `timestamptz` | YES | When the action was resolved |
| `tenant_id` | `bigint` (FK → tenant) | NO | |
| `created_at` | `timestamptz` | NO | |
| `updated_at` | `timestamptz` | NO | |

**Assignment gating**: When `blocks_assignments = true` and `status = 'active'` and today is within `effective_from`/`effective_to`, the official is excluded from all assignments. The official's profile shows a red "Suspended" or "On Probation" badge.

**Workflow**:
1. Admin issues action (e.g., "Suspension for 2 weeks due to unprofessional conduct at Game #1234")
2. Official is notified (via notification system, ADR-0010)
3. While active: blocked from assignments, profile badge shown
4. Official can submit an appeal (sets `status = 'appealed'`, adds `appeal_notes`)
5. Admin reviews appeal: `overturned` (reinstated immediately) or `completed` (appeal denied, action stands)
6. On `effective_to` date: auto-transitions to `expired` status

### 3. Ejection & Incident Report Involvement

ADR-0027 defines the Officials Game Report Workflow, which captures incidents, ejections, and rule violations during games. This section links officials to those incidents for tracking purposes.

#### `app.official_incident_involvement`
| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `involvement_id` | `bigint` (PK) | NO | |
| `official_id` | `bigint` (FK → official) | NO | The official involved |
| `contest_schedule_id` | `bigint` (FK → contest_schedule) | NO | The game |
| `involvement_type` | `varchar(30)` | NO | `ejection_issued`, `ejection_received`, `incident_witness`, `incident_subject`, `complaint_subject` |
| `description` | `text` | NO | What happened |
| `reported_by` | `bigint` (FK → person) | NO | Who filed the report |
| `reported_at` | `timestamptz` | NO | |
| `outcome` | `varchar(30)` | YES | `no_action`, `warning_issued`, `suspension_issued`, `under_review` |
| `related_disciplinary_id` | `bigint` (FK → official_disciplinary_action) | YES | If a disciplinary action resulted |
| `tenant_id` | `bigint` (FK → tenant) | NO | |
| `created_at` | `timestamptz` | NO | |
| `updated_at` | `timestamptz` | NO | |

**Involvement types**:
- `ejection_issued` — official ejected a player/coach (positive — official enforced the rules)
- `ejection_received` — official was ejected or removed from game (rare but possible in some systems)
- `incident_witness` — official witnessed an incident (fight, injury, parent altercation)
- `incident_subject` — official was the subject of an incident (complaint about their behavior)
- `complaint_subject` — coach or league submitted a formal complaint about the official

**Reporting**: Per-official incident summary shows totals by type, trend over seasons, and links to related disciplinary actions.

## Entitlements

The conflict and disciplinary features use existing entitlements plus one new resource:

| `entitlement_key` | `resource_name` | `operation` | `description` |
|--------------------|-----------------|-------------|---------------|
| `conflicts:read` | `conflicts` | `read` | View official conflict declarations |
| `conflicts:write` | `conflicts` | `write` | Create/update/waive conflict records |
| `discipline:read` | `discipline` | `read` | View disciplinary history |
| `discipline:write` | `discipline` | `write` | Issue/resolve disciplinary actions |

**Default role assignments**:
| Role | `conflicts:read` | `conflicts:write` | `discipline:read` | `discipline:write` |
|------|-------------------|--------------------|--------------------|---------------------|
| Primary Assigner Admin | ✅ | ✅ | ✅ | ✅ |
| Secondary Assigner Admin | ✅ | — | ✅ | — |
| Tenant Admin | ✅ | ✅ | ✅ | ✅ |
| Official | own only | self-declare only | own only | — |
| League Director | teams they manage | — | — | — |
| Coach | — | — | — | — |

## API Surface

### officials-sys
```
# Conflicts
GET    /v1/officials/:id/conflicts                — all conflicts for an official
POST   /v1/officials/:id/conflicts                — declare a conflict
PATCH  /v1/officials/:id/conflicts/:conflictId    — update/waive/remove
GET    /v1/conflicts?team_id=&status=active        — find conflicts by team

GET    /v1/conflict-relationship-types              — reference data
POST   /v1/conflict-relationship-types
PATCH  /v1/conflict-relationship-types/:id
DELETE /v1/conflict-relationship-types/:id

# Disciplinary
GET    /v1/officials/:id/disciplinary-actions       — history for an official
POST   /v1/officials/:id/disciplinary-actions       — issue an action
PATCH  /v1/officials/:id/disciplinary-actions/:id   — update/resolve/appeal
GET    /v1/disciplinary-actions?status=active        — all active actions (admin)

GET    /v1/disciplinary-action-types                 — reference data
POST   /v1/disciplinary-action-types
PATCH  /v1/disciplinary-action-types/:id

# Incidents
GET    /v1/officials/:id/incidents                   — involvement history
POST   /v1/officials/:id/incidents                   — record involvement
PATCH  /v1/officials/:id/incidents/:id               — update outcome
GET    /v1/incidents?contest_id=                      — all incidents for a game
```

### scheduling-proc (assignment integration)
```
GET    /v1/assignments/:contestId/conflict-check     — returns list of officials with conflicts for a given contest
POST   /v1/assignments/:contestId/override-conflict   — acknowledge and override a soft-block conflict
```

### BFF
```
GET    /api/officials/:id/risk-profile               — aggregated view: active conflicts, disciplinary status, incident summary
```

## Frontend UX

### Conflict Management

#### Official Self-Declaration Form
- Route: Official portal → "My Conflicts"
- Simple form: select relationship type, select team/coach/venue, describe, set effective dates
- Officials can add/edit/remove their own declarations
- Status shows: "Pending Review" until admin confirms

#### Admin Conflict Dashboard
- Route: `/officials/conflicts`
- Table: all active conflicts across officials, with filters by team, venue, official, severity
- Quick actions: waive (with reason), change severity, deactivate
- **Assignment impact preview**: shows how many upcoming assignments are affected

#### Assignment Conflict Warning
On the assignment screen, when an assigner selects an official with a conflict:
- **Hard block**: Red banner — "Cannot assign: [Official] has son on [Team Name]" with the conflict description
- **Soft block**: Yellow warning — "Conflict detected: [description]. Override?" with Confirm/Cancel
- **Advisory**: Blue info badge on the assignment card

### Disciplinary Management

#### Issue Disciplinary Action
- Route: `/officials/:id/disciplinary` → "New Action"
- Form: select action type, fill reason, link to game (optional), set effective dates
- Preview: shows impact (e.g., "This will block all assignments for 14 days")

#### Disciplinary History View
- Timeline of all actions for an official, color-coded by severity
- Current status badge prominently displayed (Active Suspension, On Probation, Clear)
- Appeal workflow: official submits appeal text → admin reviews → overturn or deny

### Incident Log
- Per-official: table of all incidents (ejections issued, complaints received, etc.)
- Per-game: all incidents involving any official at that game
- Trends: incidents per season, by type, comparison to association average

## Consequences
- **Pros**: Eliminates conflict-of-interest blind spots; structured disciplinary process replaces informal warnings; incident tracking builds institutional memory; assignment algorithm enforces compliance automatically; self-declaration empowers officials while maintaining admin oversight
- **Cons**: Requires cultural shift — officials must self-declare conflicts honestly (mitigate with consequences for undisclosed conflicts); disciplinary records are sensitive data requiring strict RBAC; conflict matching increases assignment algorithm complexity (mitigate with indexed lookups and caching)

## Related ADRs
- **ADR-0023**: Contest Assignment & Official Metrics (assignment algorithm, conflict rules field)
- **ADR-0027**: Officials Game Report Workflow (incident/ejection source data)
- **ADR-0031**: Background Checks & Renewal Policy (compliance gating pattern)
- **ADR-0036**: Official Profile & Qualifications (companion — profile data)
- **ADR-0037**: Official Ranking, Tiers & Performance (companion — grading feeds into risk assessment)
- **ADR-0010**: Notifications & Messaging (disciplinary notifications to officials)
- **ADR-0034**: RBAC Entitlement System (entitlement model for new permissions)
