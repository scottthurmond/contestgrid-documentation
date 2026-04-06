# ADR 0028: Cross-Tenant Data Access (Officials Association ↔ Sports Association)

## Status
Accepted

## Context

Officials associations and sports associations are separate tenants in our multi-tenant architecture, but they have a service relationship where officials need access to contest data from sports associations to perform their duties. However, the level of data sharing should be configurable to respect privacy, business needs, and regulatory requirements (FERPA, COPPA).

The challenge is defining:
1. What data officials **must** have access to (required for job function)
2. What data is **helpful but optional** (informational context)
3. What data must be **restricted** (privacy, competitive, or financial sensitivity)
4. How to make data access **configurable per relationship**

## Decision

Implement a **tiered, configurable data access model** where sports associations control what data they share with their officials associations through per-relationship configuration stored in `officials_tenant_map`.

### Three-Tier Access Model

**Tier 1: Required Access (Always Available)**
- Contest date, time, and duration
- Venue address and sub-venue identifier
- Contest level and division (for certification matching)
- Number of officials required
- Team names (home/away)
- Contest status (scheduled, cancelled, postponed, completed)
- Pay rate for the assignment
- Emergency contact information

**Tier 2: Informational Access (Configurable)**
- Team colors and mascots
- Coach names and game-day contact info
- League standings and team records
- League rules and officiating guidelines
- Historical scores between teams
- Tournament bracket position
- Venue-specific notes (parking, facility details)
- Weather alerts and field conditions

**Tier 3: Restricted Access (Never Shared)**
- Sports association billing rates to families/teams
- Sports association profit margins or budget details
- Player personal information (names, ages, contact info)
- Team registration/payment status
- Internal team communications
- Dispute resolutions between teams
- Coach/player personal contact info beyond game-day needs
- Strategic/marketing plans

### Configuration Schema

```typescript
// Stored in officials_tenant_map.data_access_config (JSONB)
interface OfficialDataAccessConfig {
  // Team & roster visibility
  share_team_rosters: boolean;              // default: false (FERPA/COPPA)
  share_team_colors: boolean;               // default: true
  share_coach_contact_info: boolean;        // default: false
  share_coach_names: boolean;               // default: true
  
  // Historical context
  share_historical_scores: boolean;         // default: true
  share_standings: boolean;                 // default: true
  share_head_to_head_records: boolean;      // default: true
  
  // League information
  share_league_rules: boolean;              // default: true
  share_tournament_brackets: boolean;       // default: true
  
  // Venue details
  share_venue_notes: boolean;               // default: true
  share_parking_info: boolean;              // default: true
  share_facility_maps: boolean;             // default: true
  
  // Timing and logistics
  advance_schedule_visibility_days: number; // default: 90
  allow_schedule_browse: boolean;           // default: false (only assigned games)
  real_time_updates: boolean;               // default: true
  
  // Game execution requirements
  require_score_reporting: boolean;         // default: false
  require_incident_photos: boolean;         // default: false
  require_time_tracking: boolean;           // default: true
  
  // Privacy controls
  mask_player_names: boolean;               // default: true
  mask_player_ages: boolean;                // default: true
  mask_family_contact_info: boolean;        // default: true
  
  // Metadata
  config_version: number;
  last_updated_at: timestamp;
  last_updated_by: UUID;
}
```

### Default Access Presets

**Minimal (Privacy-First)**
- Only Tier 1 required data
- No rosters, no historical data, no coach contact info
- Ideal for: youth leagues (COPPA), high-privacy organizations

**Standard (Recommended)**
- All Tier 1 + team colors, standings, league rules, venue notes
- No personal contact info, no rosters
- Ideal for: most recreational and competitive leagues

**Full Transparency**
- All Tier 1 + all configurable Tier 2 options enabled
- Still excludes Tier 3 restricted data
- Ideal for: professional/semi-pro leagues, high-trust relationships

## Data Flow Architecture

### Read Access Pattern

```
Official User → Officials Association Tenant
  ↓ (via officials_tenant_map)
  → Sports Association Contest Data
    ↓ (filtered by data_access_config)
    → Allowed Fields Only
```

### Row-Level Security Implementation

```sql
-- Officials can read contest data if they have an active mapping
CREATE POLICY officials_read_contests ON contest_schedule
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM officials_tenant_map otm
      WHERE otm.tenant_id = contest_schedule.payer_id
        AND otm.officials_association_id = current_setting('app.officials_association_id')::UUID
        AND otm.status = 'active'
    )
  );

-- Field-level filtering handled in application layer
-- based on otm.data_access_config JSONB
```

### API Layer Filtering

```typescript
// BFF applies field-level filtering based on config
function filterContestForOfficial(
  contest: Contest,
  config: OfficialDataAccessConfig
): PartialContest {
  const filtered: any = {
    // Tier 1: always included
    contest_id: contest.contest_id,
    start_date: contest.start_date,
    start_time: contest.start_time,
    venue: contest.venue,
    sub_venue: contest.sub_venue,
    home_team_name: contest.home_team.name,
    away_team_name: contest.away_team.name,
    pay_rate: contest.pay_rate,
    status: contest.status
  };
  
  // Tier 2: conditional based on config
  if (config.share_team_colors) {
    filtered.home_team_colors = contest.home_team.colors;
    filtered.away_team_colors = contest.away_team.colors;
  }
  
  if (config.share_coach_names) {
    filtered.home_coach_name = contest.home_team.coach?.name;
    filtered.away_coach_name = contest.away_team.coach?.name;
  }
  
  if (config.share_standings) {
    filtered.home_team_record = contest.home_team.record;
    filtered.away_team_record = contest.away_team.record;
  }
  
  if (config.share_venue_notes) {
    filtered.venue_notes = contest.venue.notes;
  }
  
  // Tier 3: never included
  // (player rosters, billing data, internal notes)
  
  return filtered;
}
```

## Bidirectional Data Flow

### Officials → Sports Association
- Assignment confirmations (accept/decline/request-change)
- Arrival/departure timestamps (punctuality tracking)
- Location tracking (ETA, real-time positioning) [opt-in]
- Game reports (incidents, weather delays, equipment issues)
- Score reporting (if required by config)
- Photo evidence (incidents, field conditions)

### Sports Association → Officials
- Contest creation/updates (schedule changes)
- Venue modifications (address, sub-venue reassignment)
- Cancellations (weather, forfeit, emergency)
- Start time delays (real-time updates)
- Emergency notifications (facility issues, safety alerts)
- Rule clarifications (game-specific guidance)

## UI/UX Implications

### Sports Association Admin UI
- **Settings → Officials Data Sharing** screen
- Preset templates (Minimal, Standard, Full)
- Per-field toggles with explanatory help text
- Preview of "what officials see" for testing
- Audit log of configuration changes
- Warning indicators for privacy-sensitive fields

### Officials Association View
- Clear labeling of data availability ("limited info available")
- Request access feature ("Request full standings access")
- Graceful degradation when data unavailable
- No exposure of underlying configuration (just show/hide fields)

### Official Individual View
- Context-appropriate data only (assigned games)
- Optional: browse upcoming schedule (if allowed)
- Game detail page shows all available context
- Clear indicators when optional data unavailable

## Security & Privacy Considerations

**FERPA/COPPA Compliance:**
- Default to masking all player personal information
- Never share player contact info, birthdates, or family data
- Team rosters excluded by default

**Data Minimization:**
- Officials only access data for assigned games (unless browse enabled)
- Time-limited access: no access to games >90 days in past (configurable)
- Automatic redaction after game completion + retention period

**Audit Trail:**
- Log all cross-tenant data access
- Track configuration changes (who, when, what changed)
- Alert on suspicious access patterns (bulk exports, unusual queries)

**PII Protection:**
- Coach contact info requires explicit opt-in from coach
- Phone numbers partially masked: (555) ***-1234
- Email addresses available only during game-day window (±4 hours)

## Migration & Rollout Strategy

### Phase 1: Schema Updates
- Add `data_access_config` JSONB column to `officials_tenant_map`
- Add database triggers for audit logging
- Create configuration presets table

### Phase 2: API Layer
- Implement field-level filtering in BFF
- Add configuration management endpoints
- Update contest query responses to respect config

### Phase 3: UI Implementation
- Build configuration UI for sports association admins
- Update official-facing views to handle missing data gracefully
- Add "request access" workflow for officials

### Phase 4: Migration
- Set all existing relationships to "Standard" preset
- Notify sports associations of new capability
- Provide guided configuration wizard

### Phase 5: Monitoring
- Track configuration adoption
- Monitor performance impact of field-level filtering
- Collect feedback on data access needs

## Performance Considerations

**Caching Strategy:**
- Cache `data_access_config` per relationship (TTL: 5 minutes)
- Cache filtered contest responses (TTL: 1 minute)
- Invalidate cache on configuration change

**Query Optimization:**
- Include `data_access_config` in officials_tenant_map queries
- Use indexed lookups for active relationships
- Batch filtering for list views

**Scale Expectations:**
- 1000+ sports associations × 10-50 officials associations each
- 100,000+ contests per season
- Field filtering adds <5ms per response

## Consequences

**Positive:**
- Flexible data sharing respects diverse privacy requirements
- Clear boundaries between tenant data
- Audit trail for compliance (GDPR, SOC 2)
- Sports associations maintain control over their data
- Officials get context they need without overwhelming detail

**Negative:**
- Added complexity in API layer (field filtering)
- Configuration UI/UX requires careful design
- Testing matrix expands (each config permutation)
- Documentation burden for explaining access tiers

**Mitigations:**
- Well-defined presets reduce configuration burden
- Automated testing of access policies
- Clear inline documentation in configuration UI
- Performance monitoring to catch filtering overhead

## Future Enhancements

**Dynamic Access Requests:**
- Officials request temporary access to specific data
- Sports association approves/denies via notification
- Time-limited access grants (e.g., 24 hours)

**Role-Based Access Within Officials:**
- Crew chief sees more context than line officials
- Supervisors/evaluators get expanded access
- New officials get limited access (training mode)

**Analytics & Insights:**
- Sports associations see which data officials use most
- Officials associations see configuration coverage across customers
- Platform recommends optimal configurations

**Compliance Automation:**
- Auto-detect youth leagues → enforce minimal preset
- GDPR data subject requests include cross-tenant access logs
- SOC 2 compliance reports include access policy audits

---

## References
- ADR 0004: Authentication & Authorization (RBAC model)
- ADR 0015: Data Protection and Encryption
- ADR 0021: Data Storage Architecture (RLS policies)
- ADR 0023: Contest Assignment and Official Metrics
- ADR 0027: Officials Game Report Workflow
