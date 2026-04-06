# ADR 0035: Official Availability & Blocking

## Status
Proposed

## Context
Officials need a way to communicate when they are and are not available to work contests. Currently the assignment process has no visibility into an official's schedule, forcing assigners to contact officials individually and handle conflicts reactively. This creates unnecessary back-and-forth, increases decline rates, and degrades the assignment experience for both assigners and officials.

The system must support two complementary models:
1. **Blocked time** — dates/times the official **cannot** work (vacations, personal commitments, other jobs)
2. **Available time** — dates/times the official **can** work (proactive declaration of open slots)

Officials should be able to enter availability via a **form** (quick data entry) or a **calendar view** (visual, drag-and-drop). Entries can be **one-time** or **recurring** (e.g., "every Tuesday evening" or "first Saturday of each month").

## Decision

### Data Model

#### `app.official_availability`
Stores both availability and blocked-time entries per official.

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `official_availability_id` | `bigint` (PK) | NO | Auto-generated identity |
| `official_id` | `bigint` (FK → official) | NO | The official this entry belongs to |
| `tenant_id` | `bigint` (FK → tenant) | NO | Tenant isolation (RLS) |
| `entry_type` | `text` | NO | `'available'` or `'blocked'` |
| `start_date` | `date` | NO | Start date of the window |
| `end_date` | `date` | NO | End date (same as start_date for single-day entries) |
| `start_time` | `time` | YES | Start time (NULL = all day) |
| `end_time` | `time` | YES | End time (NULL = all day) |
| `all_day` | `boolean` | NO | `true` if the entry covers the full day(s) |
| `recurrence_rule` | `text` | YES | iCal RRULE string (NULL = one-time). Examples: `FREQ=WEEKLY;BYDAY=TU`, `FREQ=MONTHLY;BYDAY=1SA` |
| `recurrence_end_date` | `date` | YES | When the recurrence stops (NULL = indefinite until manually removed) |
| `reason` | `text` | YES | Optional free-text reason (e.g., "Family vacation", "Available for weekend games") |
| `created_at` | `timestamptz` | NO | Row creation timestamp |
| `updated_at` | `timestamptz` | NO | Last modification timestamp |
| `created_by` | `bigint` | YES | Person who created the entry (official or admin) |

**RLS policy**: Same tenant-isolation pattern as other `app.*` tables — filter on `tenant_id` matching `current_setting('app.tenant_id')` with platform-admin bypass.

**Indexes**:
- `(official_id, start_date, end_date)` — efficient range lookups for assignment conflict checks
- `(tenant_id, entry_type, start_date)` — admin queries: "show all blocked time for my officials this week"

#### Recurrence Model
Recurrence uses the **iCal RRULE** standard (RFC 5545), which is widely supported by calendar libraries (rrule.js, Python dateutil, etc.) and enables future calendar export/sync (Google Calendar, Outlook, iCal).

Common recurrence patterns:
| Pattern | RRULE |
|---------|-------|
| Every Tuesday | `FREQ=WEEKLY;BYDAY=TU` |
| Every weekday evening | `FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR` (with start_time/end_time) |
| First Saturday of each month | `FREQ=MONTHLY;BYDAY=1SA` |
| Every other Friday | `FREQ=WEEKLY;INTERVAL=2;BYDAY=FR` |
| Specific date range (one-time) | `NULL` (no recurrence) |

Recurrence expansion happens at query time — the DB stores only the rule, and the API/service layer expands occurrences for a requested date range.

### Entry Types

#### Blocked Time (entry_type = 'blocked')
- **Full-day block**: "I'm unavailable March 20–22" → `all_day=true`, `start_date=2026-03-20`, `end_date=2026-03-22`
- **Partial-day block**: "I can't work Tuesday evenings" → `all_day=false`, `start_time=17:00`, `end_time=23:59`, `recurrence_rule=FREQ=WEEKLY;BYDAY=TU`
- **One-time partial block**: "I have a dentist appointment March 19 from 2–4 PM" → `all_day=false`, `start_date=2026-03-19`, `end_date=2026-03-19`, `start_time=14:00`, `end_time=16:00`, `recurrence_rule=NULL`

#### Available Time (entry_type = 'available')
- **Full-day available**: "I can work every Saturday" → `all_day=true`, `recurrence_rule=FREQ=WEEKLY;BYDAY=SA`
- **Partial-day available**: "I'm free weeknights 6–10 PM" → `all_day=false`, `start_time=18:00`, `end_time=22:00`, `recurrence_rule=FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR`
- **One-time available**: "I'm open all day April 5" → `all_day=true`, `start_date=2026-04-05`, `end_date=2026-04-05`, `recurrence_rule=NULL`

### Interpretation Mode
The association (tenant) configures whether availability is interpreted as:
1. **Block-only** (default): Officials are assumed available unless they block time. Only blocked entries are checked during assignment.
2. **Available-only**: Officials must declare when they can work. Only available entries are considered during assignment.
3. **Hybrid**: Both blocked and available entries are used. Blocked takes precedence over available.

This is stored as a tenant-level configuration (`official_availability_mode` in `app.tenant` or a tenant config table) with values `block_only`, `available_only`, or `hybrid`.

### API Endpoints

Owned by **officials-sys** (system API, port 3002):

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/v1/officials/:officialId/availability` | List all availability/block entries for an official. Query params: `start_date`, `end_date`, `entry_type`, `expand=true` (expand recurrences) |
| `POST` | `/v1/officials/:officialId/availability` | Create a new availability/block entry |
| `PATCH` | `/v1/officials/:officialId/availability/:entryId` | Update an existing entry |
| `DELETE` | `/v1/officials/:officialId/availability/:entryId` | Delete an entry |
| `GET` | `/v1/availability/summary` | Aggregated availability for all officials in the tenant for a date range (used by assignment planner) |

Orchestrated by **scheduling-proc** (proc API, port 3004):

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/workflows/officials/:officialId/availability` | Expanded availability with conflict detection against existing assignments |
| `GET` | `/workflows/availability/matrix` | Availability matrix for a date range — which officials are available for which time slots (feeds the assignment algorithm) |

Proxied through **BFF** (port 3000):

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/proxy/officials/:officialId/availability` | Pass-through to officials-sys |
| `POST` | `/api/proxy/officials/:officialId/availability` | Pass-through to officials-sys |
| `PATCH` | `/api/proxy/officials/:officialId/availability/:entryId` | Pass-through to officials-sys |
| `DELETE` | `/api/proxy/officials/:officialId/availability/:entryId` | Pass-through to officials-sys |

### Frontend Views

#### 1. Availability Form (Quick Entry)
- **Location**: Dialog accessible from the Officials detail page and from the Calendar view ("+ Add Entry" button)
- **Fields**:
  - Entry type: toggle between "Blocked" and "Available"
  - Date range picker: start date, end date (defaults to same day for single-day)
  - All-day toggle
  - Time range (shown when all-day is off): start time, end time
  - Recurrence toggle → reveals recurrence builder:
    - Frequency: Daily, Weekly, Monthly
    - Interval: every _N_ weeks/months
    - Days of week (for weekly): checkboxes Mon–Sun
    - Monthly pattern: "Day X of month" or "Nth weekday" (e.g., 1st Saturday)
    - End: Never, On date, After N occurrences
  - Reason (optional text field)
- **Validation**:
  - End date ≥ start date
  - End time > start time (when not all-day)
  - At least one day selected for weekly recurrence
  - Warn if new entry overlaps existing entries (non-blocking)
- **Entitlement**: `officials:update` (officials and admins can manage their own availability; admins can manage any official's availability)

#### 2. Calendar View
- **Location**: Dedicated tab or view within the Official detail page; also accessible as a standalone page at `/officials/:id/availability`
- **Display modes**: Month view (default), Week view, Day view
- **Visual encoding**:
  - Blocked time: red/orange blocks
  - Available time: green blocks
  - Existing assignments: blue blocks (read-only, pulled from assignments data)
  - Recurring entries: repeating pattern indicator (icon or hatching)
- **Interactions**:
  - Click a date → opens the form pre-filled with that date
  - Click-and-drag across dates → opens the form pre-filled with the date range
  - Click an existing entry → opens edit form
  - Right-click or long-press → context menu: Edit, Delete, Duplicate
- **Filters**: Show/hide blocked, available, assignments; filter by recurrence type
- **Technology**: Vuetify calendar component (`v-calendar`) or a dedicated library (FullCalendar with Vue adapter) for rich drag-and-drop support
- **Responsive**: On mobile, degrades to a list/agenda view grouped by date; swipe gestures for date navigation

#### 3. Admin Availability Overview
- **Location**: New tab on the Officials list page for association admins
- **Purpose**: See all officials' availability at a glance for planning
- **Display**: Gantt-style or heatmap grid — officials on Y-axis, dates on X-axis, color-coded cells
- **Use case**: "Which officials are available next Saturday afternoon?" → filter by date/time, see green cells
- **Entitlement**: `officials:read`

### Assignment Integration
The assignment algorithm (scheduling-proc) consults availability before suggesting or auto-assigning officials:

1. **Pre-filter**: When building candidate lists for a contest, exclude officials who have a blocking entry that overlaps the contest date/time.
2. **Preference boost**: Officials who have explicitly declared themselves available for the contest's time slot get a higher ranking score.
3. **Conflict detection**: When creating an assignment, check for blocking entries and warn the assigner (soft block) or prevent the assignment (hard block, configurable per tenant).
4. **Decline auto-detection**: If an official adds a blocking entry that overlaps an existing accepted assignment, the system can optionally auto-flag the assignment for reassignment and notify the assigner.

### Notifications
- **Official → Assigner**: When an official adds/modifies a blocking entry that overlaps a future assignment, notify the assigner.
- **Assigner → Official**: When an assigner overrides a block (if allowed by tenant config), notify the official.
- **Reminder**: Configurable reminder to officials who haven't updated their availability in N days (tenant setting).

## Consequences

### Positive
- Reduces assignment declines by filtering unavailable officials before assignment
- Gives officials self-service control over their schedule
- Recurrence support minimizes repetitive data entry for regular schedules
- Calendar view provides an intuitive visual interface familiar to all users
- iCal RRULE standard enables future calendar export/sync (Google, Outlook)
- Admin overview enables proactive staffing decisions

### Negative
- Recurrence expansion at query time adds computational cost (mitigated by caching expanded windows for a rolling 90-day window)
- Two entry modes (form + calendar) increase frontend surface area
- Officials who don't maintain their availability will still cause assignment friction — requires cultural adoption and optional reminders

### Risks
- **Data volume**: Active officials with many recurring entries could generate large expanded result sets. Mitigate with pagination and date-range scoping on all queries.
- **Timezone handling**: Officials may travel or work across timezones. Store times in local time with the official's home timezone; convert at display/query time.
- **Recurrence edge cases**: "Last Friday of the month" and other complex patterns need thorough testing. Lean on battle-tested rrule.js library.

## Related
- ADR-0023: Contest Assignment & Official Metrics (assignment algorithm consumes availability)
- ADR-0027: Officials Game Report Workflow (completed assignments interact with availability windows)
- Roadmap: Officials Admin MVP → Availability Calendar
- scheduling-proc README: Availability Management section
