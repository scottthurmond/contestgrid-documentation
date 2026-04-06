# ADR 0023: Contest Assignment & Official Metrics

## Status
Proposed

## Context
Officials associations need to assign sports officials to contests (games/matches). The assignment process requires rich context about the contest, flexible billing models (split payments, direct official payment), and comprehensive metrics tracking on official performance and responsiveness. Hierarchical control over requirement enforcement (e.g., why an official declined) is needed across global, official, association, and sports-association scopes.

## Decision

### Contest Data Model
Each contest record contains:
- **Identity**: id, league id, division (e.g., T-Ball, Pee Wee, Minor, Major, Pony, Senior, 8U, 9U, 10U, Varsity, JV), sport (tied to league type: Recreation, GGBL, Independent Travel, High School, NCAA)
- **Scheduling**: date, time (local), timezone, status (scheduled, tentative, postponed, canceled, normal, rainout, forfeit, suspended, completed)
- **Location**: venue (name, address, geo-coordinates), sub-venue (court/field identifier)
- **Teams**: home team (id, name), away team (id, name)
- **Officials**: required count, required roles (crew chief, umpire, line judge, etc.)
- **Billing Model**: payer (home team, away, league, venue, sponsor, other), payment method per payer:
  - Amount splits: exact dollar amounts or percentages per payer
  - **Direct official payment flag**: mark if coaches/teams pay officials directly (informs whether platform bills for the game and manages official payout)
  - Official pay rate and details
- **Special requirements**: certification level, gender, conflict rules, travel limits

### Official Metrics
Track per official:
- **Assignment stats**:
  - Games assigned (current/active assignments only)
  - Games worked (completed)
  - Declines (rejected assignment)
  - Accepted then turned back (revoked after acceptance)
  - Response latency (time from assignment sent to accept/decline)
- **Assignment categorization**:
  - Short-notice (same-day assignment)
  - Mid-range (assigned within 3 days)
  - Normal (assigned >3 days prior)
- **Turn-back tracking**:
  - Reason (text field, hierarchically required or optional)
  - Timestamp
  - SLA feedback (response time vs. expected thresholds)
- **Performance indicators** (optional future):
  - No-shows, late arrivals, reassignments, conflict hits

### Hierarchical Requirement Control
Support cascading requirement policies for:
- Turn-back reason requirement (mandatory, optional)
- Response-time SLA thresholds (time to accept/decline)
- **Tracking start window** (minutes before game start to begin location tracking, default 60)
- **Late alert threshold** (minutes before game start to alert if not at venue, default 15)
- Policy levels (in priority order):
  1. **Global**: platform-wide default
  2. **Officials Association**: per association override
  3. **Sports Association**: per sports league override
  4. **Venue**: per venue override (e.g., remote venue needs 90 min tracking)
  5. **Individual Official**: per official override
- Resolution: lowest-level (individual) takes precedence; inherit upward if not set
- Audit trail: log policy changes and enforcement

### Data Models (indicative)
```
Contest {
  id, tenantId (officials assoc), leagueId, divisionId, sportId,
  date, time, timezone, status,
  venueId, subVenueId,
  homeTeamId, awayTeamId,
  requiredOfficialCount, requiredRoles: Role[],
  billingModel: {
    payers: { payerId, amount | percentage, paymentMethod }[],
    directOfficialPayment: boolean
  },
  requirements: { certificationLevel, gender, conflictRules, travelLimit }
}

OfficialMetrics {
  officialId, tenantId,
  gamesWorked, gamesAssigned, declines, turnedBack,
  shortNoticeCount, midRangeCount, normalCount,
  avgResponseTime, medianResponseTime,
  lastUpdated
}

Assignment {
  id, contestId, officialId, role, status (pending, accepted, declined, turnedBack, enroute, arrived),
  sentAt, respondedAt, respondedStatus (accept | decline),
  turnBackReason (if declined/turnedBack), turnBackAt,
  shortNoticeFlag (boolean, computed at creation),
  locationTracking: {
    enabled: boolean,
    trackingStartTime (1h before game start),
    currentLocation: { lat, lng, accuracy, timestamp },
    eta: { minutes, updatedAt },
    status (not_started | enroute | arrived | departed),
    arrivedAt, departedAt (if multi-venue day),
    expectedArrivalTime, punctualityStatus (early | on_time | late | unknown)
  }
}

OfficialLocationUpdate {
  id, assignmentId, officialId, contestId,
  location: { lat, lng, accuracy },
  timestamp,
  distanceToVenue (meters),
  eta (minutes),
  status (enroute | arrived | departed)
}

OfficialPunctualityAudit {
  id, officialId, assignmentId, contestId, venueId,
  gameStartTime, trackingStartTime (1h before start),
  arrivedAt, departedAt (if multi-venue),
  arrivalStatus (early | on_time | late | no_show),
  minutesEarlyOrLate (positive = early, negative = late),
  lateAlertSent (boolean), lateAlertSentAt,
  trackingStatus (active | opted_out | interrupted),
  createdAt
}

OfficialPunctualityMetrics {
  officialId, tenantId,
  totalGames, arrivedEarly, arrivedOnTime, arrivedLate, noShows,
  avgMinutesEarly (across all games),
  lateIncidents (count), lateRate (percentage),
  punctualityTrend (improving | stable | degrading),
  lastUpdated
}

RequirementPolicy {
  id, tenantId, scope (global | officialAssoc | sportsAssoc | official | venue),
  scopeId (if scoped),
  turnBackReasonRequired: boolean,
  responseSLAMs: int (threshold in milliseconds),
  trackingStartMinutes: int (minutes before game start, default 60),
  lateAlertThresholdMinutes: int (minutes before game start, default 15),
  createdAt, updatedAt, createdBy
}
```

### Behavior
- **Assignment creation**: mark short-notice flag at creation (same-day vs. within 3d vs. normal)
- **Assignment response**: record respondedAt, respondedStatus; if declined/turnedBack, fetch applicable RequirementPolicy and enforce reason requirement
- **Metrics update**: on each assignment state change, recalculate OfficialMetrics (counters, latencies)
- **Hierarchical lookup**: when checking policies, query in order (individual → venue → sportsAssoc → officialAssoc → global); use first found
- **SLA tracking**: calculate response time vs. threshold; flag if breached; store in Assignment for audit
- **Tracking window resolution**: for each assignment, resolve tracking start time by looking up RequirementPolicy hierarchy (individual → venue → sportsAssoc → officialAssoc → global); default 60 minutes before game start
- **Late alert threshold resolution**: similarly resolve late alert threshold (default 15 minutes before game start) via hierarchy
- **Location tracking**: when official accepts assignment, enable location tracking (opt-in with consent); periodically update location; calculate ETA based on current location + traffic; notify sports/officials associations when official is enroute and when arrived; geofence venue to detect arrival

### Location Tracking & Arrival ETA
**Purpose**: Allow sports associations and officials associations to know when assigned officials will arrive at venue; track punctuality patterns for audit and performance evaluation.

**Features**:
- **Consent & Privacy**: Officials opt-in to location tracking per assignment or globally; location data only shared during active assignment window (configurable minutes before first game start time through game completion, default 60 minutes)
- **Tracking Window** (configurable, hierarchical):
  - Global default: 60 minutes before game start
  - Overridable per: Officials Association, Sports Association, Venue, Individual Official
  - Resolution: lowest-level (individual → venue → sportsAssoc → officialAssoc → global) takes precedence
  - Examples: remote venue needs 90 min tracking; reliable official only needs 30 min tracking
  - Start tracking at resolved time; continue until game completed; if official has multiple games at different venues on same day, track continuously with per-venue arrival tracking
- **Real-time Updates**: Mobile app sends location updates periodically (every 1–5 minutes when enroute, configurable)
- **ETA Calculation**: Calculate estimated arrival time based on current location, traffic conditions (via Google Maps/Mapbox API), and venue coordinates; update ETA dynamically as conditions change
- **Status States**: not_started (official hasn't left), enroute (location updates active), arrived (within geofence), departed (for multi-venue days)
- **Geofencing**: Define geofence radius around venue (default 100m); auto-detect arrival when official enters geofence; detect departure when leaving geofence
- **Multi-Venue Days**: If official assigned to games at multiple venues on same day:
  - Track route from venue A → venue B with separate arrival/departure times
  - Display ETAs for each venue with traffic-based routing
  - Alert if transit time between venues insufficient (configurable buffer, e.g., 30 min)
  - Show both associations: current venue, next venue, ETA to next venue
- **Punctuality Alerts** (configurable per association):
  - Default threshold: 15 minutes before first game start (alert if official not at venue)
  - Configurable thresholds via hierarchy: Global → Officials Association → Sports Association → Venue → Individual Official
  - Escalation: first alert at threshold, reminder at T-10 min, critical at T-5 min (escalation times also configurable)
  - Alert recipients: sports association admin, officials association admin, official (reminder)
  - No alert if official already checked in or arrived via geofence
- **Notifications**:
  - Sports association: notified when official is enroute, when ETA < 15 minutes, when arrived, when running late (threshold breach)
  - Officials association: dashboard view of all officials' locations and ETAs for active games; late alerts aggregated
  - Late alerts: if ETA indicates late arrival or official not tracking at threshold, alert both associations
  - Multi-venue routing: notify when official departs first venue, ETA to second venue, potential delays
- **Historical Tracking & Audit**:
  - Store all location updates, arrival times, departure times (multi-venue), late incidents
  - Per-official audit report: arrival time vs game start time, early/on-time/late rate, avg early arrival time, late incidents count, venues worked
  - Retention: keep arrival/departure audit data indefinitely (or per policy, e.g., 3 years); anonymize location coordinates after 90 days but preserve arrival times and punctuality metrics
  - Punctuality metrics: "arrived 20 min early" (good), "arrived on-time" (0-5 min before), "arrived late" (-5 min or after start)
  - Pattern detection: consistently late (>20% late rate), consistently early, punctuality degradation over time
- **Battery Optimization**: Use geofencing and significant location changes (iOS/Android APIs) to minimize battery drain; reduce update frequency if official stationary
- **Offline Handling**: If official loses connectivity, resume tracking when back online; estimate ETA based on last known location; flag as "tracking interrupted" in audit

**Data Privacy**:
- Location coordinates deleted after 90 days; arrival/departure times and punctuality metrics retained for audit (3 years default)
- Officials can disable tracking any time (flags assignment as "tracking disabled"; still logs as "opted out" for audit)
- No location tracking outside assignment window
- GDPR/regional compliance: explicit consent, right to deletion (deletes coordinates immediately, retains anonymized punctuality stats)

### UI Features
- Assignment form: show contest details (date, venue, teams, required roles), preview of payment splits, direct-pay flag
- Official assignment modal: display short-notice label, SLA threshold, fetch and display applicable RequirementPolicy
- Official profile/stats dashboard: display metrics (games worked, declines, avg response time, short-notice count); add punctuality metrics (on-time rate, avg early arrival, late incidents, punctuality trend)
- Requirement policy admin panel: view/edit policies at each scope with inheritance preview
- Analytics: response time distribution, decline patterns, short-notice assignment trends; add punctuality analytics (early/on-time/late distribution, punctuality by venue/time-of-day, officials with late patterns)
- **Location tracking dashboard** (officials association): map view showing all active officials' locations, ETAs, status (enroute/arrived); list view with filters; multi-venue routing visualization; late alerts summary
- **Game day view** (sports association): per-game official status with ETA, arrival notifications, late alerts; multi-venue official schedule with ETAs
- **Official mobile app**: enable/disable location tracking, view own ETA, geofence arrival confirmation, multi-venue route with next venue ETA, punctuality feedback ("You arrived 12 min early—great!")
- **Punctuality audit reports**: per-official punctuality summary (rate, avg early time, late incidents); filterable by date range, venue, contest level; export to CSV/PDF
- **Alert configuration**: admins set per-association/per-official late alert thresholds (default 15 min before start); escalation rules (T-10, T-5)
- **Tracking window configuration**: admins set tracking start time (minutes before game) at global/association/venue/official levels with inheritance preview; default 60 minutes

## Consequences
- **Pros**: clear billing model with flexibility; rich metrics for performance management; granular policy control; audit-friendly; real-time visibility into official arrival status reduces game delays and no-shows
- **Cons**: schema complexity; policy lookup overhead (mitigated via caching); multi-level configuration can confuse admins (mitigate with UI defaults); location tracking privacy concerns (mitigated via explicit consent, limited window, auto-deletion); battery drain on mobile (mitigated via geofencing and significant location changes)

## Related ADRs
- ADR-0003: Billing and Payroll (split billing, officials payment)
- ADR-0011: Officials Payment Workflow
- ADR-0006: Architecture (BFF/Proc system for assignment orchestration)
