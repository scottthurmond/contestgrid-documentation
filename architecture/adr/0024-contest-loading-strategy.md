# ADR 0024: Contest Loading Strategy (Import & Native Creation)

## Status
Proposed

## Context
Contests are the core of the system; all assignment, billing, and reporting flow from contests. Two loading paths are needed:
1. **Native**: create contests in-app with full data (teams, rosters, coaches, leagues, divisions)
2. **Import**: load contests from external sources (spreadsheets, external APIs, web scraping) when customers aren't tenants

Both paths must support small-to-extra-large volumes, validation, conflict resolution, and audit trails. Users need clear error feedback and smart correction suggestions, not just rejection.

## Decision

### Import Strategy

#### File Format & Columns
Support CSV and Excel (.xlsx) with:

**Required Columns** (validation fails if missing/empty):
- `date` (YYYY-MM-DD or locale format, configurable)
- `time` (HH:MM in 24h or 12h AM/PM, configurable)
- `home_team` (text, will map to existing or create new)
- `away_team` (text, will map to existing or create new)
- `venue` (text, will match or create)
- `division` (text or ID; values e.g., T-Ball, Pee Wee, 8U, Varsity, JV)
- `league` (text or ID; values e.g., Recreation, GGBL, Independent Travel, High School, NCAA)

**Optional Columns** (ignored if missing):
- `sub_venue` (court/field)
- `status` (scheduled, tentative; default: scheduled)
- `home_coach` (name/email; linked if exists, created if allowed)
- `away_coach` (name/email; linked if exists, created if allowed)
- `notes` (free text)
- `external_id` (reference to source system, e.g., QuickScores game ID, for sync/audit)
- `game_type` (regular, playoff, tournament, exhibition, scrimmage)

#### Data Sources
1. **Spreadsheet upload**: CSV or .xlsx via file picker
2. **External API**: if available (e.g., QuickScores), authenticate and fetch schedule
3. **Web scraping**: if no API but data is on web page, provide scraper with user-defined selectors (advanced, opt-in)
4. **Template download**: pre-populate with existing teams, venues, divisions, leagues; user fills in new contests

#### Validation & Error Handling
**Validation phases**:
1. **File format**: check structure (columns present, format), encoding
2. **Data type**: parse dates/times, verify formats
3. **Required fields**: check non-empty
4. **Business rules**: check team existence, venue valid, division in league, date not in past (configurable), no duplicates
5. **Mapping & conflicts**: detect existing contests, team mismatches, venue missing

**Error reporting**:
- Before import: show all validation errors by row/column with reason (e.g., "Row 5: Date is invalid (Jan 32, 2025); expected YYYY-MM-DD")
- Smart suggestions:
  - "Row 5: 'January 32' detected; did you mean January 31?"
  - "Row 8: Team 'Red Wings' not found; did you mean 'Detroit Red Wings'? [YES] [CREATE NEW]"
  - "Row 3: Venue missing; [SKIP] [ASSIGN VENUE] [CREATE NEW]"
  - "Row 12: Contest date 2025-01-28 conflicts with existing game (same teams, time±30m); [SKIP] [UPDATE] [DUPLICATE]"
- User can:
  - Fix inline in preview (edit team name, select from dropdown, etc.)
  - Download corrected template, re-upload
  - Mark rows to skip (if using partial import mode)

**Import modes**:
1. **All-or-nothing**: validate all; if any fail, reject entire file; user must fix all and re-upload
2. **Partial**: validate all; show failed rows; user selects which to import, which to skip; import valid subset

**Async processing**:
- Small (≤100 rows): sync, immediate preview
- Medium (100–1000 rows): async, show progress bar, preview when ready
- Large (1000–10K rows): async, background job, email/notification when done; allow retry/resume
- Extra-large (>10K rows): batch processing, chunked validation, detailed report

#### Data Mapping
**Team matching**:
- Exact match by name → auto-assign
- Fuzzy match (similar name) → suggest with user confirmation
- No match → offer create new or skip

**Venue matching**: same logic as teams

**Coach/official**: link to existing or create stub (name/email only initially)

**League/division**: must exist (show dropdown in import UI); if not, user must create first or skip contest

#### Conflict Handling
**Existing contest detection**:
- Key: (league, division, date ±30m, home_team, away_team)
- Action: skip, update, or treat as duplicate (configurable per import)

**Validation rule configuration**:
- Allow past dates? (default: no)
- Allow duplicate games? (default: no)
- Auto-create teams/venues? (default: yes, with user confirmation)
- Timezone handling (auto-detect from tenant, or user selects)

#### Rollback & Audit
- **Rollback**: post-import, user can undo/revert all imported contests (removes contest records, linked data if no other refs)
- **Audit trail**:
  - Source: file name, upload timestamp, uploader
  - Counts: total rows, validated, imported, skipped, failed
  - Details per contest: created, updated, skipped reason
  - Linked to external system IDs (e.g., QuickScores ID) for sync tracking

### Native Creation Strategy

#### Single Contest Form
- Form with all required + optional fields
- Pre-loaded dropdowns (teams, venues, leagues, divisions, coaches)
- Option to add new team/venue/coach inline
- Preview splits (if billing configured)
- Submit → create contest, show confirmation, offer add another

#### Bulk Contest Entry
- Multi-row editor (spreadsheet-like table)
- Copy/paste from Excel
- Auto-populate from template
- Row-level validation with error icons
- Bulk create on submit

#### Pre-loaded Data
- Display existing teams, venues, coaches, divisions, leagues
- Option to create new in dedicated admin views
- Offer quick-add modal during contest creation ("Team not found? Create here")
- Allow bulk pre-load from file (teams, coaches) before contest entry

### UI Components
- **Import wizard**: file picker → format preview → validation → mapping → confirm → async progress
- **Validation error view**: filterable, sortable, inline edit suggestions, fix/skip/retry
- **Contest preview**: show parsed data, highlight conflicts/warnings
- **Single contest form**: fields, dropdowns, inline add, preview, submit
- **Bulk entry table**: row entry, error badges, bulk validation, submit
- **Rollback modal**: confirm undo, show impact (contests removed, linked data handled)
- **Audit report**: export validation summary, import details, contest counts

### Data Models (indicative)
```
Import {
  id, tenantId, source (spreadsheet | api | scrape),
  sourceFile (filename), externalSourceRef (e.g., QuickScores org ID),
  uploadedAt, uploadedBy,
  mode (allOrNothing | partial),
  status (validating | validated | importing | imported | failed | rolledBack),
  totalRows, validatedRows, importedRows, skippedRows, failedRows,
  validationErrors: { row, column, message, suggestion }[],
  rollbackAvailable: boolean, rolledBackAt, rolledBackBy
}

Contest {
  id, tenantId,
  // ... (from ADR 0023)
  importRef: { importId, sourceId, externalId },
  createdVia (native | import)
}

ValidationRule {
  id, tenantId, scope (global | league),
  allowPastDates: boolean,
  allowDuplicateGames: boolean,
  autoCreateTeams: boolean,
  autoCreateVenues: boolean,
  timezone: string,
  duplicateKeyWindow: int (minutes, default 30)
}
```

### Behavior
1. **Import upload**: user selects file → system detects format → streams/parses content
2. **Validation**: phase 1-5 as above; collect all errors and suggestions
3. **Preview**: show parsed data, errors, suggestions; user can inline-edit or download template
4. **Mapping**: user reviews team/venue/coach matches; accept, override, or skip rows
5. **Confirm & import**: user selects mode (all-or-nothing or partial); system imports valid rows async
6. **Rollback**: post-import audit view allows undo; removes contests, cleans up linked data
7. **Audit log**: every import/rollback logged with details for compliance

## Consequences
- **Pros**: flexible loading paths; smart error handling reduces user burden; audit-friendly; supports large volumes; safe rollback
- **Cons**: complex validation logic; UI workflow has many states (mitigated via clear wizard flow); web scraping fragile (mitigated via API preference)

## Related ADRs
- ADR-0023: Contest Assignment & Official Metrics (contests are core data)
- ADR-0006: Architecture (async job processing for large imports)
- ADR-0002: Telemetry and Audit (audit trail for imports)
