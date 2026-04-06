# Implementation Quick Start

## 📍 Current State (March 5, 2026)

- ✅ Architecture fully planned (32 ADRs)
- ✅ MVP scope defined (3–5 weeks engineering)
- ✅ Frontend scaffold complete (Vue 3, TypeScript, Vite, Router, Pinia, Vuetify 4)
- ✅ Vuetify 4 integrated (Material Design components, theming system)
- ✅ Tests configured (vitest 2.1.9, Playwright, MSW)
- ✅ Database schema designed (Aurora PostgreSQL with RLS, Row-Level Security)
- ✅ Infrastructure fully documented (Kubernetes, Istio, Flux, Helm, cert-manager)
- ✅ Flyway migrations tooling configured

**Next**: Begin Phase 0 (database schema), then Phase 1 (backend APIs), then Phase 2 (frontend UIs).

---

## 🗄️ Phase 0: Database Schema & Flyway Migrations (Week 0, Days 1–5)

**Goal**: Create baseline PostgreSQL schema using Flyway, ensuring migrations are version-controlled and reproducible across environments.

### Setup (Pre-work)
- [ ] Create `db/` directory structure:
  ```
  db/
  ├── migrations/          # Versioned Flyway SQL files
  ├── seeds/
  │   ├── dev/            # Development seed data
  │   └── test/           # Test seed data
  └── scripts/
      └── local-bootstrap.sh  # Bootstrap script
  ```
- [ ] Create `flyway-local.conf`, `flyway-staging.conf`, `flyway-production.conf`
  - See [flyway/docs/FLYWAY-QUICKREF.md](../../flyway/docs/FLYWAY-QUICKREF.md) for templates
- [ ] Verify `flyway -version` outputs 10.8.1+
- [ ] Set up PostgreSQL locally (via Rancher Desktop or Docker)
- [ ] Test port-forward: `kubectl port-forward -n contestgrid svc/contest-db-postgresql 5432:5432`

### Day 1–2: Foundation Tables
**Goal**: Create base tables for tenants, users, roles, and foundational data types.

- [ ] Create `V001__create_tenants_table.sql`
  - `tenants` table (id, name, subdomain, status, created_at, updated_at)
  - Unique constraint on subdomain
  - Indexes on status and subdomain
  - Comment: "Multi-tenant root entities (leagues, officials associations)"
  
- [ ] Create `V002__create_users_table.sql`
  - `users` table (id, tenant_id, cognito_sub, email, role, created_at, updated_at)
  - Foreign key to tenants
  - Enable RLS: users can only see their own tenant's users
  - Index on tenant_id and cognito_sub
  
- [ ] Create `V003__create_contests_levels_table.sql`
  - `contest_levels` table (id, tenant_id, name, description, display_order)
  - Index on tenant_id
  - Comment: "Age/skill divisions (e.g., U10, U12, High School)"
  
- [ ] Create `V004__create_divisions_table.sql`
  - `divisions` table (id, tenant_id, level_id, name, sport, rules_version, status)
  - Foreign key to levels
  - Index on tenant_id and level_id
  - Comment: "Sport divisions (e.g., Boys U10 Baseball, Girls U12 Softball)"
  
- [ ] Create `V005__create_seasons_table.sql`
  - `seasons` table (id, tenant_id, name, year, start_date, end_date)
  - Index on tenant_id and year
  - Comment: "Contest seasons (Spring 2026, Fall 2026)"
  
- [ ] Run migrations locally: `(cd ../flyway && flyway -configFiles=conf/flyway-local.conf migrate)`
- [ ] Verify tables created: `psql -h localhost -d contestdb -c "\dt"`
- [ ] Commit: `git add db/migrations/ && git commit -m "Phase 0 Day 1-2: Foundation tables"`

**Deliverable**: Base tables created with RLS, indexes, and constraints in place.

### Day 3–4: Data Tables
**Goal**: Create tables for leagues, teams, venues, coaches, officials, certifications.

- [ ] Create `V006__create_leagues_table.sql`
  - `leagues` table (id, tenant_id, season_id, division_id, name, status)
  - Foreign keys to seasons and divisions
  - Enable RLS
  - Index on tenant_id, season_id
  
- [ ] Create `V007__create_teams_table.sql`
  - `teams` table (id, tenant_id, league_id, name, coach_id, status)
  - Foreign key to leagues
  - Index on tenant_id, league_id
  
- [ ] Create `V008__create_venues_table.sql`
  - `venues` table (id, tenant_id, name, address, city, state, zip, capacity, latitude, longitude)
  - Index on tenant_id
  - Comment: "Physical locations for contests"
  
- [ ] Create `V009__create_sub_venues_table.sql`
  - `sub_venues` table (id, venue_id, name, court_number, capacity)
  - Foreign key to venues
  - Index on venue_id
  - Comment: "Individual courts/fields within a venue"
  
- [ ] Create `V010__create_coaches_table.sql`
  - `coaches` table (id, tenant_id, team_id, user_id, name, email, phone, role)
  - Foreign keys to teams and users
  - Index on tenant_id, team_id
  
- [ ] Create `V011__create_officials_table.sql`
  - `officials` table (id, tenant_id, user_id, name, email, phone, status)
  - Foreign key to users
  - Index on tenant_id, status
  
- [ ] Create `V012__create_certifications_table.sql`
  - `certifications` table (id, tenant_id, name, description, expires_at)
  - `official_certifications` table (id, official_id, certification_id, issued_at, expires_at)
  - Index on tenant_id, official_id
  - Comment: "Official credentials (umpire, scorer, crew chief, etc.)"
  
- [ ] Create `V013__create_roles_table.sql`
  - `roles` table (id, tenant_id, division_id, name, description)
  - Foreign key to divisions
  - Index on tenant_id, division_id
  - Comment: "Sport-specific roles (umpire, scorer, crew chief)"
  
- [ ] Run migrations: `(cd ../flyway && flyway -configFiles=conf/flyway-local.conf migrate)`
- [ ] Verify via SQL queries (sample joins across tables)
- [ ] Commit

**Deliverable**: Complete data tables with foreign keys and RLS policies in place.

### Day 5: Contests & Scoring Tables
**Goal**: Create contests, games, score entry, and audit trail tables.

- [ ] Create `V014__create_contests_table.sql`
  - `contests` table (id, tenant_id, league_id, level_id, division_id, venue_id, sub_venue_id, scheduled_at, status, notes)
  - Foreign keys to relevant tables
  - Index on tenant_id, league_id, scheduled_at, status
  - Comment: "Individual contest events"
  
- [ ] Create `V015__create_games_table.sql`
  - `games` table (id, contest_id, home_team_id, away_team_id, scheduled_time, status)
  - Foreign keys to contests and teams
  - Index on contest_id, status
  
- [ ] Create `V016__create_score_entries_table.sql`
  - `score_entries` table (id, game_id, entered_by_coach_id, home_score, away_score, notes, created_at, updated_at)
  - Tracks coach score submissions
  - Index on game_id, entered_by_coach_id
  - Comment: "Individual score entry from each coach"
  
- [ ] Create `V017__create_final_scores_table.sql`
  - `final_scores` table (id, game_id, home_score, away_score, winner_id, finalized_at)
  - Index on game_id
  - Comment: "Finalized score after both coaches agree or admin resolution"
  
- [ ] Create `V018__create_score_disputes_table.sql`
  - `score_disputes` table (id, game_id, coach1_score_entry_id, coach2_score_entry_id, resolved_by_user_id, resolution, resolved_at)
  - Tracks disagreements between coaches
  - Index on game_id, resolved_at
  
- [ ] Create `V019__create_audit_log_table.sql`
  - `audit_log` table (id, tenant_id, user_id, entity_type, entity_id, action, old_value, new_value, created_at)
  - Immutable append-only log
  - Index on tenant_id, entity_type, created_at
  - Comment: "Immutable audit trail for compliance"
  
- [ ] Run all migrations: `(cd ../flyway && flyway -configFiles=conf/flyway-local.conf migrate)`
- [ ] Run validation: `(cd ../flyway && flyway -configFiles=conf/flyway-local.conf validate)`
- [ ] Verify schema with `\dt+` and relationship diagram
- [ ] Commit all migrations

**Deliverable**: Complete schema ready for API layer; all 17+ migrations in version control.

### Phase 0 Summary
- ✅ Flyway migrations version-controlled in Git
- ✅ Database schema verified locally
- ✅ RLS policies in place for multi-tenancy
- ✅ Foreign keys and indexes optimized
- ✅ Ready for API layer to consume

---

## 🔌 Phase 1: Backend APIs (Weeks 1–2)

**Goal**: Build REST/GraphQL APIs for all data entities, tested and integrated with PostgreSQL via Flyway migrations.

### Architecture
- **Stack**: Node.js/Express (or Python FastAPI) + PostgreSQL + Cognito
- **Pattern**: Resource-based REST endpoints following ADR-0005 (API Standards)
- **Authentication**: Cognito JWT tokens (ADR-0004)
- **Authorization**: RLS in PostgreSQL + Cognito groups/roles (ADR-0015)
- **Testing**: Integration tests with real database, mock auth layer

### Week 1

#### Day 1–2: Core API Scaffold & Auth
- [ ] Create Express server with:
  - Middleware: CORS, helmet, request logging, auth
  - Cognito JWT validation (middleware)
  - Tenant context extraction from JWT
  - Error handling and structured logging
  
- [ ] Create Cognito integration:
  - Verify JWT tokens (public key validation)
  - Extract tenant_id from JWT custom claims
  - Extract user roles (Admin, League Director, Coach, Official)
  
- [ ] Bootstrap endpoints:
  - `GET /health` (health check)
  - `POST /auth/login` (mock for now; real flow via frontend)
  - `GET /me` (current user info from Cognito + database)
  
- [ ] Database connection pool: Configure to local PostgreSQL
- [ ] Logging: Structured JSON logs with request ID and tenant
- [ ] Tests: Unit tests for middleware, auth validation

**Deliverable**: API server running, auth flow functional, local PostgreSQL connected.

#### Day 3–4: Foundational Data Endpoints
- [ ] Implement REST endpoints for Phase 0 tables:
  - `GET /tenants` (admin only)
  - `GET /levels` (list division levels)
  - `POST /levels` (create level)
  - `GET /divisions` (list; filtered by tenant)
  - `POST /divisions` (create)
  - `GET /seasons` (list)
  - `POST /seasons` (create)
  - `GET /leagues` (list by season/division)
  - `POST /leagues` (create)
  
- [ ] For each endpoint:
  - Request validation (body schema, query params)
  - RLS-based filtering (tenant isolation via PostgreSQL RLS)
  - Response pagination (offset/limit per ADR-0005)
  - Error responses (400, 403, 404, 500 with structured format)
  - Unit + integration tests
  
- [ ] Test with Postman/cURL:
  - Create level
  - Create division under level
  - List divisions (verify RLS filters by tenant)

**Deliverable**: Foundation data CRUD APIs working end-to-end.

#### Day 5: Integration & Testing
- [ ] E2E API test: Create tenant → Add level → Add division → Add season → Add league (verify relationships)
- [ ] Load test: 100 concurrent requests to list endpoints (verify response time <500ms)
- [ ] Security test: Verify RLS prevents cross-tenant data access
- [ ] API documentation (OpenAPI/Swagger): Auto-generate from code
- [ ] Commit all API code and tests

**Deliverable**: Foundation data APIs fully tested and documented.

### Week 2

#### Day 1–2: Teams, Venues, Coaches, Officials
- [ ] Implement CRUD endpoints:
  - `GET/POST /teams` (linked to leagues)
  - `GET/POST /venues` (with sub_venues)
  - `GET/POST /coaches` (linked to teams)
  - `GET/POST /officials` (with certifications)
  - `GET/POST /certifications`
  - `GET/POST /roles` (sport-specific)
  
- [ ] Test relationships:
  - Create team in league → verify team can be assigned to contests
  - Create venue with sub-venues → verify sub-venues queryable
  - Create official with certifications → verify certifications appear in list
  
- [ ] Tests, Swagger docs, commit

**Deliverable**: All foundational data endpoints working.

#### Day 3–4: Contests & Games
- [ ] Implement endpoints:
  - `GET/POST /contests` (draft, scheduled, in-progress, completed states)
  - `GET/POST /games` (linked to contests)
  - `GET /contests/{id}/games` (games within a contest)
  - `PATCH /contests/{id}` (update status)
  
- [ ] State machine validation:
  - contest: draft → scheduled → in-progress → completed → archived
  - game: pending → in-progress → completed → disputed
  
- [ ] Tests, commit

**Deliverable**: Contest and game management APIs.

#### Day 5: Score Entry & Bulk Import
- [ ] Score entry endpoints:
  - `POST /games/{id}/score-entries` (coach submits score)
  - `GET /games/{id}/score-entries` (view both coach scores)
  - `POST /games/{id}/finalize-score` (admin resolves disputed scores)
  - `POST /games/{id}/disputes` (create dispute record)
  - `GET /disputes` (queue for admin)
  - `PATCH /disputes/{id}` (admin resolution)
  
- [ ] Bulk import endpoint:
  - `POST /contests/import` (CSV → database)
  - Validation logic (check teams exist, dates valid, no duplicates)
  - Return import summary (rows created, rows failed, errors)
  
- [ ] Tests, commit

**Deliverable**: Score entry and bulk import fully functional.

### Phase 1 Summary
- ✅ All REST APIs implemented and tested
- ✅ RLS enforces tenant isolation
- ✅ JWT auth integrated with Cognito
- ✅ Database migrations (Phase 0) consumed by APIs
- ✅ Ready for frontend to integrate

---

## 🎨 Phase 2: Foundation Data UIs (Weeks 3–4)

**Goal**: Build CRUD forms for all foundational data types so sports association admins can set up their contests.

### Week 1

#### Day 1–2: Contest Levels & Divisions
- [ ] Create `src/views/admin/LevelsView.vue` (list, create, edit, delete using v-data-table)
- [ ] Add `src/components/admin/LevelForm.vue` (form with v-text-field, v-select, validation)
- [ ] Create Pinia store `src/stores/levels.ts` with mock data
- [ ] Create `src/views/admin/DivisionsView.vue` (hierarchically linked to Levels using v-treeview or v-data-table)
- [ ] Add `src/components/admin/DivisionForm.vue` (v-select dropdown to select parent Level)
- [ ] Create Pinia store `src/stores/divisions.ts`
- [ ] Add routes to router config; add nav links using v-navigation-drawer
- [ ] Unit tests for forms and stores

**Deliverable**: Users can view, create, edit, delete contest levels and divisions.

#### Day 3–4: Seasons & Leagues
- [ ] Create `src/views/admin/SeasonsView.vue` (year + timeframe using v-select)
- [ ] Add `src/components/admin/SeasonForm.vue` (v-date-picker for date range selection)
- [ ] Create Pinia store `src/stores/seasons.ts`
- [ ] Create `src/views/admin/LeaguesView.vue` (linked to Season + Division with v-data-table)
- [ ] Add `src/components/admin/LeagueForm.vue` (v-select with multiple prop for Division selection)
- [ ] Create Pinia store `src/stores/leagues.ts`
- [ ] Routes, nav using v-list, tests

**Deliverable**: Users can manage seasons and leagues per division.

#### Day 5: Integration & Testing
- [ ] Cross-feature testing (create season → create league in that season → verify hierarchy)
- [ ] Form validation edge cases (duplicate names, past dates, invalid timeframes)
- [ ] UI polish (spacing, alignment, error messages)
- [ ] Accessibility audit (color contrast, keyboard nav, labels)

**Deliverable**: Levels → Divisions → Seasons → Leagues fully functional, hierarchically linked.

### Week 2

#### Day 1–2: Teams & Venues
- [ ] Create `src/views/admin/TeamsView.vue` (linked to League with v-data-table)
- [ ] Add `src/components/admin/TeamForm.vue` (v-select for league, v-autocomplete for coach multi-select)
- [ ] Create Pinia store `src/stores/teams.ts`
- [ ] Create `src/views/admin/VenuesView.vue` (address, capacity, geocoding fields using v-text-field, v-textarea)
- [ ] Add `src/components/admin/VenueForm.vue` (v-autocomplete for address with Google Maps API integration)
- [ ] Add `src/components/admin/SubVenueForm.vue` (for multi-court venues using v-expansion-panels)
- [ ] Create Pinia store `src/stores/venues.ts`
- [ ] Routes, nav with v-tabs, tests

**Deliverable**: Users can create teams (with coach rosters) and venues (with sub-venues).

#### Day 3–4: Coaches, Officials, Roles
- [ ] Create `src/views/admin/CoachesView.vue` (v-data-table with linked Team, contact info)
- [ ] Add `src/components/admin/CoachForm.vue` (v-text-field for name/email/phone, v-select for team)
- [ ] Create Pinia store `src/stores/coaches.ts`
- [ ] Create `src/views/admin/OfficialsView.vue` (v-data-table with certifications, availability chips)
- [ ] Add `src/components/admin/OfficialForm.vue` (v-select multiple for certifications, v-calendar for availability)
- [ ] Create Pinia store `src/stores/officials.ts`
- [ ] Create `src/views/admin/RolesView.vue` (v-list for sport-specific roles: umpire, scorer, crew chief)
- [ ] Add `src/components/admin/RoleForm.vue` (v-text-field, v-textarea)
- [ ] Create Pinia store `src/stores/roles.ts`
- [ ] Create certification management UI (`src/views/admin/CertificationsView.vue` with v-data-table)
- [ ] Routes, nav with v-navigation-drawer, tests

**Deliverable**: Users can manage officials with certifications and availability; define roles per sport.

#### Day 5: End-to-End Testing
- [ ] E2E flow: Create sport → Define roles → Create division → Create league → Create teams → Add coaches → Add officials with certifications → Verify relationships
- [ ] Bulk import test (CSV with pre-defined teams/venues/coaches/officials → system populates data)
- [ ] UI polish and accessibility

**Deliverable**: Complete foundation data setup workflow functional and tested.

**Goal**: Build CRUD forms for all foundational data types so sports association admins can set up their contests.

### Week 3

#### Day 1–2: Contest Levels & Divisions
- [ ] Create `src/views/admin/LevelsView.vue` (list, create, edit, delete using v-data-table)
- [ ] Add `src/components/admin/LevelForm.vue` (form with v-text-field, v-select, validation)
- [ ] Create Pinia store `src/stores/levels.ts` (fetch from `/levels` API)
- [ ] Create `src/views/admin/DivisionsView.vue` (hierarchically linked to Levels using v-treeview or v-data-table)
- [ ] Add `src/components/admin/DivisionForm.vue` (v-select dropdown to select parent Level)
- [ ] Create Pinia store `src/stores/divisions.ts` (fetch from `/divisions` API)
- [ ] Add routes to router config; add nav links using v-navigation-drawer
- [ ] Unit tests for forms and stores
- [ ] Integration tests: fetch from real API (mock server or staging)

**Deliverable**: Users can view, create, edit, delete contest levels and divisions via API.

#### Day 3–4: Seasons & Leagues
- [ ] Create `src/views/admin/SeasonsView.vue` (year + timeframe using v-select)
- [ ] Add `src/components/admin/SeasonForm.vue` (v-date-picker for date range selection)
- [ ] Create Pinia store `src/stores/seasons.ts` (call `/seasons` API)
- [ ] Create `src/views/admin/LeaguesView.vue` (linked to Season + Division with v-data-table)
- [ ] Add `src/components/admin/LeagueForm.vue` (v-select with multiple prop for Division selection)
- [ ] Create Pinia store `src/stores/leagues.ts` (call `/leagues` API)
- [ ] Routes, nav using v-list, integration tests

**Deliverable**: Users can manage seasons and leagues per division.

#### Day 5: Integration & Testing
- [ ] Cross-feature E2E (Playwright): Create season → Create league in that season → Verify hierarchy
- [ ] Form validation edge cases (duplicate names, past dates, invalid timeframes)
- [ ] UI polish (spacing, alignment, error messages)
- [ ] Accessibility audit (color contrast, keyboard nav, labels)

**Deliverable**: Levels → Divisions → Seasons → Leagues fully functional, pulling from real API.

### Week 4

#### Day 1–2: Teams & Venues
- [ ] Create `src/views/admin/TeamsView.vue` (linked to League with v-data-table)
- [ ] Add `src/components/admin/TeamForm.vue` (v-select for league, v-autocomplete for coach multi-select)
- [ ] Create Pinia store `src/stores/teams.ts`
- [ ] Create `src/views/admin/VenuesView.vue` (address, capacity, geocoding fields using v-text-field, v-textarea)
- [ ] Add `src/components/admin/VenueForm.vue` (v-autocomplete for address with Google Maps API integration)
- [ ] Add `src/components/admin/SubVenueForm.vue` (for multi-court venues using v-expansion-panels)
- [ ] Create Pinia store `src/stores/venues.ts`
- [ ] Routes, nav with v-tabs, integration tests

**Deliverable**: Users can create teams (with coach rosters) and venues (with sub-venues).

#### Day 3–4: Coaches, Officials, Roles
- [ ] Create `src/views/admin/CoachesView.vue` (v-data-table with linked Team, contact info)
- [ ] Add `src/components/admin/CoachForm.vue` (v-text-field for name/email/phone, v-select for team)
- [ ] Create Pinia store `src/stores/coaches.ts`
- [ ] Create `src/views/admin/OfficialsView.vue` (v-data-table with certifications, availability chips)
- [ ] Add `src/components/admin/OfficialForm.vue` (v-select multiple for certifications, v-calendar for availability)
- [ ] Create Pinia store `src/stores/officials.ts`
- [ ] Create `src/views/admin/RolesView.vue` (v-list for sport-specific roles: umpire, scorer, crew chief)
- [ ] Add `src/components/admin/RoleForm.vue` (v-text-field, v-textarea)
- [ ] Create Pinia store `src/stores/roles.ts`
- [ ] Create certification management UI (`src/views/admin/CertificationsView.vue` with v-data-table)
- [ ] Routes, nav with v-navigation-drawer, integration tests

**Deliverable**: Users can manage officials with certifications and availability; define roles per sport.

#### Day 5: End-to-End Testing
- [ ] E2E flow (Playwright): Create sport → Define roles → Create division → Create league → Create teams → Add coaches → Add officials with certifications → Verify relationships
- [ ] Bulk import test (CSV import feature from Phase 1 API)
- [ ] UI polish and accessibility

**Deliverable**: Complete foundation data setup workflow functional and tested against real APIs.

---

## 🎮 Phase 3: Contest Lifecycle (Weeks 5–6)

**Goal**: Build contest creation and import; coach score entry and standings.

### Week 3

#### Day 1–2: Contest Creation
- [ ] Create `src/views/admin/ContestsView.vue` (v-data-table with status chips and filters)
- [ ] Add `src/components/admin/ContestForm.vue` (v-select for teams/division/venue/season/type, v-date-picker and v-time-picker)
- [ ] Create Pinia store `src/stores/contests.ts` (mock API with status state machine)
- [ ] Contest status workflow: draft → scheduled → in-progress → completed → archived (use v-stepper for visualization)
- [ ] Form validation (future dates, required fields, team conflict check) using Vuetify validation rules
- [ ] Routes, nav with v-breadcrumbs, tests

**Deliverable**: Users can create contests natively with full context.

#### Day 3–4: CSV Import
- [ ] Create `src/views/admin/ContestImportView.vue` (v-file-input, column mapping with v-select, v-data-table preview)
- [ ] Add `src/components/admin/ContestImportForm.vue` (v-file-input with drag-drop, auto-detect columns)
- [ ] Validation logic: check for missing teams, invalid dates, duplicate contests
- [ ] Error reporting UI (v-alert for errors, v-expansion-panels showing which rows failed with v-chip indicators)
- [ ] Preview table (v-data-table with row highlighting showing parsed data before confirmation)
- [ ] Confirmation modal (v-dialog with confirm import; v-checkbox options to skip failed rows or abort)
- [ ] Async processing simulation (v-progress-linear for now; later EventBridge)
- [ ] Tests (various CSV formats, edge cases)

**Deliverable**: Users can import contests from CSV with smart validation and error handling.

#### Day 5: Integration
- [ ] E2E: Create division → Create season → Create league → Import 100 contests from CSV → Verify all created
- [ ] Contest list view (show imported contests with status)
- [ ] UI refinement (progress indicators for import, animations)

**Deliverable**: Contest creation and import workflows fully functional.

### Week 4

#### Day 1–2: Score Entry & Approval
- [ ] Create `src/views/contests/ScoreEntryView.vue` (coach form with v-form to enter final score)
- [ ] Add `src/components/contests/ScoreEntryForm.vue` (v-text-field for home/away scores, v-textarea for notes, v-btn for submit)
- [ ] Score entry state machine: pending → entered_by_coach1 → entered_by_coach2 → finalized_or_disputed (visualize with v-timeline)
- [ ] Two-coach logic: if both enter same score → auto-finalize; if different → flag for dispute (show v-alert)
- [ ] Pinia store `src/stores/scores.ts` (track entries, approval status, amendments)
- [ ] Notification simulation (v-snackbar when score submitted, when second coach confirms, when finalized)
- [ ] Tests (score validation, approval logic, edge cases)

**Deliverable**: Coaches can enter scores; system auto-finalizes when both agree.

#### Day 3–4: Dispute Resolution & Amendments
- [ ] Create `src/views/admin/ScoreDisputesView.vue` (v-data-table queue of disputes for league director with v-badge for count)
- [ ] Add `src/components/admin/ScoreDisputeModal.vue` (v-dialog showing both entries in v-card, coach notes in v-expansion-panel, v-radio-group to select correct score)
- [ ] Post-finalization amendment form (v-form for corrections with v-textarea for reason)
- [ ] Amendment approval queue (v-data-table for league director with v-btn-group for approve/deny)
- [ ] Amendment history view (v-timeline audit trail with v-chip showing old/new values, who approved, when, why)
- [ ] Standings recalculation logic (update after approval, not immediately)
- [ ] Tests (dispute workflows, amendment logic, standings updates)

**Deliverable**: Disputes resolved; standings updated after approval; amendments tracked in audit.

#### Day 5: Bracket Integration
- [ ] Bracket generation logic (feed standings into tournament advancement)
- [ ] Standings view (live table updating as scores finalize)
- [ ] Bracket view (visual tree showing winner advancement, byes, tiebreaker logic)
- [ ] E2E test: Create tournament → Enter scores for round 1 → Verify standings update → Check bracket advancement

**Deliverable**: Score entry to standings to bracket advancement fully functional.

**Goal**: Build contest creation and import; coach score entry and standings.

### Week 5

#### Day 1–2: Contest Creation
- [ ] Create `src/views/admin/ContestsView.vue` (v-data-table with status chips and filters)
- [ ] Add `src/components/admin/ContestForm.vue` (v-select for teams/division/venue/season/type, v-date-picker and v-time-picker)
- [ ] Create Pinia store `src/stores/contests.ts` (fetch from `/contests` API)
- [ ] Contest status workflow: draft → scheduled → in-progress → completed → archived (use v-stepper for visualization)
- [ ] Form validation (future dates, required fields, team conflict check) using Vuetify validation rules
- [ ] Routes, nav with v-breadcrumbs, integration tests

**Deliverable**: Users can create contests natively with full context.

#### Day 3–4: CSV Import
- [ ] Create `src/views/admin/ContestImportView.vue` (v-file-input, column mapping with v-select, v-data-table preview)
- [ ] Add `src/components/admin/ContestImportForm.vue` (v-file-input with drag-drop, auto-detect columns)
- [ ] Call `/contests/import` API endpoint
- [ ] Validation logic: check for missing teams, invalid dates, duplicate contests (return errors from API)
- [ ] Error reporting UI (v-alert for errors, v-expansion-panels showing which rows failed with v-chip indicators)
- [ ] Preview table (v-data-table with row highlighting showing parsed data before confirmation)
- [ ] Confirmation modal (v-dialog with confirm import; v-checkbox options to skip failed rows or abort)
- [ ] Progress tracking (v-progress-linear for upload and processing)
- [ ] Tests (various CSV formats, edge cases)

**Deliverable**: Users can import contests from CSV with smart validation and error handling.

#### Day 5: Integration
- [ ] E2E: Create division → Create season → Create league → Import 100 contests from CSV → Verify all created
- [ ] Contest list view (show imported contests with status)
- [ ] UI refinement (progress indicators for import, animations)

**Deliverable**: Contest creation and import workflows fully functional.

### Week 6

#### Day 1–2: Score Entry & Approval
- [ ] Create `src/views/contests/ScoreEntryView.vue` (coach form with v-form to enter final score)
- [ ] Add `src/components/contests/ScoreEntryForm.vue` (v-text-field for home/away scores, v-textarea for notes, v-btn for submit)
- [ ] Call `/games/{id}/score-entries` API
- [ ] Score entry state machine: pending → entered_by_coach1 → entered_by_coach2 → finalized_or_disputed (visualize with v-timeline)
- [ ] Two-coach logic: if both enter same score → auto-finalize; if different → flag for dispute (show v-alert)
- [ ] Pinia store `src/stores/scores.ts` (track entries, approval status, amendments)
- [ ] Notification simulation (v-snackbar when score submitted, when second coach confirms, when finalized)
- [ ] Tests (score validation, approval logic, edge cases)

**Deliverable**: Coaches can enter scores; system auto-finalizes when both agree.

#### Day 3–4: Dispute Resolution & Amendments
- [ ] Create `src/views/admin/ScoreDisputesView.vue` (v-data-table queue of disputes for league director with v-badge for count)
- [ ] Add `src/components/admin/ScoreDisputeModal.vue` (v-dialog showing both entries in v-card, coach notes in v-expansion-panel, v-radio-group to select correct score)
- [ ] Call `/disputes/{id}` API to resolve
- [ ] Post-finalization amendment form (v-form for corrections with v-textarea for reason)
- [ ] Amendment approval queue (v-data-table for league director with v-btn-group for approve/deny)
- [ ] Amendment history view (v-timeline audit trail with v-chip showing old/new values, who approved, when, why)
- [ ] Standings recalculation logic (fetch from `/standings` API after approval)
- [ ] Tests (dispute workflows, amendment logic, standings updates)

**Deliverable**: Disputes resolved; standings updated after approval; amendments tracked in audit.

#### Day 5: Bracket Integration
- [ ] Bracket generation logic (feed standings into tournament advancement)
- [ ] Standings view (live table updating as scores finalize; fetch from `/standings` API)
- [ ] Bracket view (visual tree showing winner advancement, byes, tiebreaker logic)
- [ ] E2E test: Create tournament → Enter scores for round 1 → Verify standings update → Check bracket advancement

**Deliverable**: Score entry to standings to bracket advancement fully functional.

---

## ⚖️ Phase 4: Compliance & Workflows (Week 7+)

### Week 5a: Rules & Assignment (Days 1–5)

#### Rules Management
- [ ] Create `src/views/admin/RulesView.vue` (versioned rules per division)
- [ ] Add `src/components/admin/RuleEditor.vue` (rich text editor with sections)
- [ ] Approval workflow UI (submit for approval → league director review → president approval)
- [ ] Acknowledgment tracking (org-level + individual official)
- [ ] PDF generation (use jsPDF or html2pdf library; branded template with version/date)
- [ ] Tests (version control, approval workflow, PDF generation)

**Deliverable**: Rules versioning with multi-step approval and acknowledgments.

#### Assignment Confirmation
- [ ] Create `src/views/officials/AssignmentsView.vue` (list of assigned games)
- [ ] Add `src/components/officials/ConfirmAssignmentModal.vue` (accept/decline with reason)
- [ ] Notification reminder system (initial + escalating reminders at 24h, 12h, 6h before game)
- [ ] Dashboard for league director (view confirmation status, follow up with officials)
- [ ] Tests (confirmation workflow, reminder logic)

**Deliverable**: Officials can accept/decline assignments with confirmation tracking.

### Week 5b–5c: Game Reports & Tracking (Days 1–5)

#### Game Reports
- [ ] Create `src/views/officials/GameReportsView.vue` (list of games needing reports)
- [ ] Add `src/components/officials/GameReportForm.vue` (template selector, free-form text, evidence upload)
- [ ] Signatory model configuration (single vs. crew-wide; toggle in assignment)
- [ ] Approval queue for league director (review reports, approve/request revision)
- [ ] Amendment requests (track corrections with audit trail)
- [ ] Immutability logic (once finalized, read-only; create new amendment records)
- [ ] Tests (various signatory models, approval workflows, immutability)

**Deliverable**: Officials file reports; league director approves; amendments tracked.

#### Location Tracking (Optional; defer if time-constrained)
- [ ] Location service integration (Google Maps or Mapbox)
- [ ] Real-time update UI (map view of officials en-route)
- [ ] ETA calculation and display
- [ ] Geofence arrival detection (automaic or manual confirmation)
- [ ] Punctuality alerts (configurable, escalating)
- [ ] Audit metrics dashboard (punctuality rates, trends)
- [ ] Mobile-responsive form
- [ ] Tests (geofencing logic, ETA calculation, alert escalation)

**Deliverable**: Location tracking with punctuality alerts (if time permits).

### Week 5d: Billing & Payouts (Days 1–5)

- [ ] Invoice generation (per-game, per-official, per-period; Pinia store for mock data)
- [ ] Payment processing UI (simulate Stripe integration; show payment status)
- [ ] Payout scheduling (auto-generate payouts per pay period)
- [ ] Pay stub generation (PDF with earnings breakdown, fees, deductions)
- [ ] Reconciliation view (invoice → payment matching)
- [ ] Tests (invoice calculation, payout logic, reconciliation accuracy)

**Deliverable**: Invoices generated; payouts scheduled; reconciliation tracked.

### Week 7a: Rules & Assignment (Days 1–5)

#### Rules Management
- [ ] Create `src/views/admin/RulesView.vue` (versioned rules per division)
- [ ] Add `src/components/admin/RuleEditor.vue` (rich text editor with sections)
- [ ] Call `/divisions/{id}/rules` API
- [ ] Approval workflow UI (submit for approval → league director review → president approval)
- [ ] Acknowledgment tracking (org-level + individual official)
- [ ] PDF generation (use jsPDF or html2pdf library; branded template with version/date)
- [ ] Tests (version control, approval workflow, PDF generation)

**Deliverable**: Rules versioning with multi-step approval and acknowledgments.

#### Assignment Confirmation
- [ ] Create `src/views/officials/AssignmentsView.vue` (list of assigned games)
- [ ] Add `src/components/officials/ConfirmAssignmentModal.vue` (accept/decline with reason)
- [ ] Call `/assignments` API
- [ ] Notification reminder system (initial + escalating reminders at 24h, 12h, 6h before game)
- [ ] Dashboard for league director (view confirmation status, follow up with officials)
- [ ] Tests (confirmation workflow, reminder logic)

**Deliverable**: Officials can accept/decline assignments with confirmation tracking.

### Week 7b–7c: Game Reports & Tracking (Days 1–5)

#### Game Reports
- [ ] Create `src/views/officials/GameReportsView.vue` (list of games needing reports)
- [ ] Add `src/components/officials/GameReportForm.vue` (template selector, free-form text, evidence upload)
- [ ] Call `/games/{id}/reports` API
- [ ] Signatory model configuration (single vs. crew-wide; toggle in assignment)
- [ ] Approval queue for league director (review reports, approve/request revision)
- [ ] Amendment requests (track corrections with audit trail)
- [ ] Immutability logic (once finalized, read-only; create new amendment records)
- [ ] Tests (various signatory models, approval workflows, immutability)

**Deliverable**: Officials file reports; league director approves; amendments tracked.

#### Location Tracking (Optional; defer if time-constrained)
- [ ] Location service integration (Google Maps or Mapbox)
- [ ] Real-time update UI (map view of officials en-route)
- [ ] ETA calculation and display
- [ ] Geofence arrival detection (automaic or manual confirmation)
- [ ] Punctuality alerts (configurable, escalating)
- [ ] Audit metrics dashboard (punctuality rates, trends)
- [ ] Mobile-responsive form
- [ ] Tests (geofencing logic, ETA calculation, alert escalation)

**Deliverable**: Location tracking with punctuality alerts (if time permits).

### Week 7d: Billing & Payouts (Days 1–5)

- [ ] Create invoice generation endpoints (`POST /invoices/generate`)
- [ ] Create `src/views/admin/InvoicesView.vue` (per-game, per-official, per-period)
- [ ] Add payment processing UI (simulate Stripe integration; show payment status)
- [ ] Call `/payouts` API to schedule payouts
- [ ] Pay stub generation (PDF with earnings breakdown, fees, deductions)
- [ ] Reconciliation view (invoice → payment matching)
- [ ] Tests (invoice calculation, payout logic, reconciliation accuracy)

**Deliverable**: Invoices generated; payouts scheduled; reconciliation tracked.

---

## ✅ Phase 5: Testing & Hardening (Week 8+)

- [ ] E2E tests (Playwright): critical user journeys (create contest → assign officials → enter scores → resolve disputes → approve reports → generate invoices → schedule payouts)
- [ ] Load testing (Artillery): 1000 concurrent users, 100+ simultaneous contests, verify API response time <500ms (p95)
- [ ] Security audit: RLS enforcement test, SQL injection, XSS, CSRF, auth token validation
- [ ] Performance profiling: page load time <2s, Lighthouse score >90
- [ ] Accessibility audit (WCAG 2.1 AA): color contrast, keyboard navigation, screen reader support, focus indicators
- [ ] Data integrity tests: verify audit trails, soft deletes preserve data, no orphaned records
- [ ] Integration tests: cross-tenant isolation, multi-tenant workflows, data doesn't leak between tenants

**Deliverable**: Production-ready MVP with comprehensive test coverage.

---

## 🚀 Getting Started (This Week)

### 1. Confirm scope and timeline with team
- Share [MVP-SCOPE.md](MVP-SCOPE.md) with all engineers
- Review [IMPLEMENTATION-QUICKSTART.md](IMPLEMENTATION-QUICKSTART.md) (this doc) for phased breakdown
- Discuss defer items (location tracking? assignment algorithm? public portal? billing integration?)
- Assign Phase 0 DRI (database schema lead) and Phase 1 DRI (backend API lead)
- Align on timeline: Weeks 0–2 (DB + API), Weeks 3–6+ (Frontend + Features)

### 2. Set up local infrastructure

**Baseline requirement**: Rancher Desktop with PostgreSQL, Flyway, and local dev API server.

**Option A: Recommended—Rancher Desktop (Kubernetes parity with production)**

See [ADR-0032](adr/0032-infrastructure-and-api-security.md) for full details:

```bash
# Install Rancher Desktop
brew install rancher-desktop  # macOS
# or download from https://rancherdesktop.io/

# Verify Kubernetes is running
kubectl cluster-info
kubectl get nodes

# Create namespace
kubectl create namespace contestgrid

# Install PostgreSQL via Helm
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install contest-db bitnami/postgresql \
  --namespace contestgrid \
  --set auth.username=postgres \
  --set auth.password=localdevpassword \
  --set auth.database=contestdb

# Install Flyway (for Phase 0: database migrations)
brew install flyway  # macOS
# or: choco install flyway.commandline  # Windows
# or: wget https://repo1.maven.org/maven2/org/flywaydb/flyway-commandline/10.8.1/flyway-commandline-10.8.1-linux-x64.tar.gz  # Linux

# Set up Flyway configuration
cd ../flyway
cp conf/flyway-local.conf.example conf/flyway-local.conf

# Port forward PostgreSQL (for Phase 0)
kubectl port-forward -n contestgrid svc/contest-db-postgresql 5432:5432 &

# Verify connection
psql -h localhost -U postgres -d contestdb -c "SELECT 1;"

# Set up local DNS (add to /etc/hosts)
echo "127.0.0.1 contestgrid.local api.contestgrid.local" | sudo tee -a /etc/hosts

# Optional: Install Istio + Flux for full infrastructure parity
# (defer until Phase 2; start with minimal setup)
```

**Option B: Docker Compose (Simpler, non-Kubernetes)**

If you prefer a simpler local setup without Kubernetes:

```bash
# Create docker-compose.yml with PostgreSQL and optional backend service
cat > docker-compose.yml <<EOF
version: '3.8'
services:
  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: localdevpassword
      POSTGRES_DB: contestdb
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

  # Backend API container (add after Phase 1)
  # api:
  #   build: ./backend
  #   environment:
  #     DATABASE_URL: postgresql://postgres:localdevpassword@postgres:5432/contestdb
  #   ports:
  #     - "3000:3000"
  #   depends_on:
  #     - postgres

volumes:
  postgres_data:
EOF

# Start services
docker-compose up -d

# Verify PostgreSQL
docker exec contestgrid-postgres-1 psql -U postgres -d contestdb -c "SELECT 1;"
```

**Option C: Production (AWS EKS)**

Defer until Phase 2–3. See [ADR-0032](adr/0032-infrastructure-and-api-security.md) for EKS setup with Flux CD and Istio.

---

### 3. Set up Phase 0 (Database) workspace

```bash
# Clone repository (or switch to initial-design branch)
git clone https://github.com/scottthurmond/contestgrid-fe
cd contestgrid-fe
git switch initial-design

# Create db/migrations directory
mkdir -p db/migrations

# Flyway configs + migrations live in the consolidated workspace folder:
#   ../flyway/conf/
#   ../flyway/db/migrations/
# Copy the example config and edit DB/url/user as needed:
#   (cd ../flyway && cp conf/flyway-local.conf.example conf/flyway-local.conf)

# Assign Phase 0 DRI (database schema lead)
# This person owns: db/migrations/, schema design, Flyway coordination
```

### 4. Set up Phase 1 (Backend API) workspace

```bash
# Clone backend repository (or create new Express/FastAPI project)
# Option A: Existing backend repo
git clone https://github.com/scottthurmond/contestgrid-api
cd contestgrid-api

# Option B: Create new backend from scratch
# See backend setup guide (separate repo)

# Assign Phase 1 DRI (backend API lead)
# This person owns: REST/GraphQL API routes, database query logic, auth integration
```

### 5. Set up Phase 2 (Frontend) workspace

```bash
# Frontend workspace already set up in this repo
cd contestgrid-fe

# Install frontend dependencies
npm install

# Start dev server
npm run dev

# Assign Phase 2 DRI (frontend lead)
# This person owns: Vue components, Vuetify theming, Pinia stores, integration with APIs
```

---

### 6. Create Phase 0–2 backlog in GitHub
```
# Phase 0: Database Schema (Week 0)
Epic 0.1: Foundation Tables
  ├─ Create Flyway V001__create_tenants_table.sql
  ├─ Create Flyway V002__create_users_table.sql
  ├─ Create Flyway V003__create_contests_levels_table.sql
  ├─ ... (17+ migrations total)
  └─ Validate all migrations locally

Epic 0.2: Integration & Testing
  ├─ Test RLS policies (tentant isolation)
  ├─ Test foreign key constraints
  ├─ Verify schema against ADR-0021
  └─ Document schema in Mermaid ERD

# Phase 1: Backend APIs (Weeks 1–2)
Epic 1.1: Auth & Core Infrastructure
  ├─ Set up Express/FastAPI server
  ├─ Cognito JWT validation
  ├─ Tenant context extraction
  └─ Structured logging + error handling

Epic 1.2: Foundation Data Endpoints
  ├─ GET/POST /levels
  ├─ GET/POST /divisions
  ├─ GET/POST /seasons
  ├─ GET/POST /leagues
  └─ Integration tests for each endpoint

Epic 1.3: Teams, Venues, Officials
  ├─ GET/POST /teams
  ├─ GET/POST /venues
  ├─ GET/POST /coaches
  ├─ GET/POST /officials
  ├─ GET/POST /certifications
  └─ GET/POST /roles

Epic 1.4: Contests & Score Entry
  ├─ GET/POST /contests
  ├─ GET/POST /games
  ├─ POST /games/{id}/score-entries
  ├─ POST /contests/import
  └─ POST /disputes/{id} (resolve)

# Phase 2: Frontend UIs (Weeks 3–6)
Epic 2.1: Foundation Data UIs
  ├─ LevelsView + LevelForm
  ├─ DivisionsView + DivisionForm
  ├─ SeasonsView + SeasonForm
  ├─ LeaguesView + LeagueForm
  ├─ E2E tests (Playwright)
  └─ Accessibility audit

... (continue for Teams, Venues, Coaches, Officials, etc.)
```

### 7. Assign team roles

```

**Suggested team structure**:

| Role | Responsibility | Weeks 0–2 | Weeks 3–6 |
|------|---|---|---|
| **Database Lead** | Schema design, Flyway migrations, RLS policies | 100% | Support (5%) |
| **Backend Lead** | API architecture, auth integration, database queries | 10% | 100% |
| **Frontend Lead** | Component design, Pinia stores, testing infra | 5% | 100% |
| **Full-Stack Dev #1** | Support DB lead (Week 0), then API endpoints (Week 1–2) | 50% | Framework development |
| **Full-Stack Dev #2** | Support DB lead (Week 0), then API endpoints (Week 1–2) | 50% | Framework development |
| **Frontend Dev #1** | Assist frontend lead (Weeks 0–1), then UI build (Weeks 3–6) | 20% | 90% |
| **Frontend Dev #2** | Assist frontend lead (Weeks 0–1), then UI build (Weeks 3–6) | 20% | 90% |
| **DevOps/QA** | Infrastructure setup (all weeks), test automation (Weeks 1–6) | 80% | 80% |

### 8. Kick off Week 0 (Database)
- **Day 1**: 
  - Team onboarding, project architecture overview
  - Local dev setup (Rancher Desktop or Docker Compose)
  - Assign Phase 0 DRI
  - Review [ADR-0021](adr/0021-data-storage-architecture.md)
  
- **Days 2–5**: 
  - Phase 0 begins: Database Lead creates Flyway migrations V001–V019
  - Full-Stack devs assist, create integration tests
  - Run migrations locally, test RLS policies
  - Commit to GitHub

### 9. Kick off Week 1 (Backend APIs)
- **Day 1**:
  - Phase 0 complete ✅
  - Phase 1 DRI creates API project (Express, FastAPI, etc.)
  - Set up auth middleware (Cognito JWT validation)
  - Review [ADR-0005](adr/0005-api-standards.md) (API standards)
  
- **Days 2–5**:
  - Phase 1 begins: API endpoints for foundation data
  - Full-Stack devs implement CRUD routes
  - Integration tests against real PostgreSQL database
  - API documentation (Swagger/OpenAPI)

### 10. Kick off Week 2 (More APIs)
- Phase 1 continues: Contests, Games, Scores endpoints
- All APIs documented and tested

### 11. Kick off Week 3 (Frontend)
- **When ready**:
  - Phase 2 DRI reviews [IMPLEMENTATION-QUICKSTART.md](IMPLEMENTATION-QUICKSTART.md) (this doc, Weeks 3–6)
  - Frontend devs start building LevelsView, LevelForm, etc.
  - Begin integration with real APIs (no more mock data)
  - E2E tests with Playwright

---

## 📚 Key Reference Docs

- **MVP Scope**: [docs/MVP-SCOPE.md](docs/MVP-SCOPE.md)
- **Roadmap**: [docs/roadmap.md](docs/roadmap.md)
- **ADRs**: [docs/adr/](docs/adr/) (32 files)
- **Session Summary**: [docs/SESSION-SUMMARY.md](docs/SESSION-SUMMARY.md)
- **Database Migrations**: [flyway/docs/FLYWAY-QUICKREF.md](../../flyway/docs/FLYWAY-QUICKREF.md)
- **Database Modeling Workflow**: [docs/DB-MODELING-WORKFLOW.md](docs/DB-MODELING-WORKFLOW.md)
- **Local Development Setup**: [docs/LOCAL-DEVELOPMENT-SETUP.md](docs/LOCAL-DEVELOPMENT-SETUP.md)
- **API Security**: [docs/API-SECURITY-QUICKREF.md](docs/API-SECURITY-QUICKREF.md)
- **Infrastructure & Kubernetes**: [docs/adr/0032-infrastructure-and-api-security.md](docs/adr/0032-infrastructure-and-api-security.md)
- **Design System**: Check `src/style/tokens.css` and `src/components/ui/`
- **Tenant CRUD Sample**: `src/views/admin/TenantsView.vue` and `src/stores/tenants.ts`

---

## ❓ Questions?

Refer to the respective ADR for architecture decisions:
- **Multi-tenancy?** → ADR 0022 (Data Storage, RLS)
- **Auth?** → ADR 0004 (AWS Cognito RBAC)
- **Scoring workflow?** → ADR 0026 (Coach Score Entry)
- **Game reports?** → ADR 0027 (Officials Game Report)
- **Location tracking?** → ADR 0023 (Assignment + Metrics)
- **Rules?** → ADR 0025 (Rules Management)
- **Billing?** → ADRs 0012 (Billing), 0013 (Monetization)

---

**Ready to build!** 🎯
