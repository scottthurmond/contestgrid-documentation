# ADR 0027: Officials Game Report Workflow

## Status
Proposed

## Context
Officials (umpires, referees, crew chiefs) working contests sometimes encounter game issues, ejections, rule violations, controversial calls, or other significant events that should be documented. Sports associations need a structured way to collect these reports for audit, compliance, rule enforcement, team appeals, and league governance.

Reports must be highly configurable—some leagues require reports for every playoff game; others only for disputes. Some want only crew chief sign-off; others want all officials to acknowledge. Some use reports to block contest close-out; others treat them informational. Some want public visibility for coaches/teams; others keep them internal. All requirements vary by sport, division, league, and venue.

## Decision

### Configurable Report Framework
All report behavior is configurable at multiple levels (hierarchically): global defaults → officials org → sports org → division → individual game. Per-game overrides allow exceptions.

#### Configuration Scope

**Requirement & Scope**
- Games requiring reports: all, none, or specific types (playoff, tournament, certain divisions/levels)
- Configured per: officials org, sports org, division, level, or per-game override
- Default behavior: report required for all contested games; configurable off per entity

**Signatory Model** (per-game configuration)
- Single-official: only crew chief or designated official signs off
- Crew-wide: all officials working game must acknowledge/sign report
- Hybrid: crew chief signs; other officials optional or required per role (umpire, crew chief, scorer, etc.)
- Selection UI: league director chooses model when scheduling/assigning officials

**Blocking Behavior** (configurable)
- Blocking: report must be filed and approved before contest can be marked "closed" or standings finalized
- Informational: report optional; filed after close-out; does not block workflow
- Delayed blocking: report required within 24–48 hours post-game; blocks payouts if not submitted
- Configuration: set per league/division; per-game override available

**Report Content: Templates & Free-Form**
- Template-based: pre-defined incident types (ejection, injury, rule dispute, equipment failure, unusual weather, etc.) with optional notes
- Free-form: open text field for custom issues
- Hybrid (default): pick from templates + add notes; if none match, free-form entry required
- Templates: stored per sport/division; customizable by league admin

**Public Visibility** (configurable)
- Internal only: only officials org, sports org admins, league director, and involved officials can view
- Coach/team visible: coaches of both teams can see reports (redacted or full details configurable)
- Public: visible to all coaches, teams, and public (if league chooses)
- Audit visibility: compliance/support teams always have access regardless of setting
- Default: internal only (officials/sports org/league management only)

**Dispute Mechanism** (optional, configurable)
- If enabled: officials can flag disagreements with report content (e.g., "I didn't say that" or "context is missing")
- Flagged reports: sent to league director for review; may require official meeting/call
- Resolution: league director approves report as-is, edits with official consent, or requests rewrite
- Disabled by default; enabled per league if needed
- Not a "veto"—league director makes final decision

### Report Workflow

1. **Contest completion**: Officials assigned to game receive notification to file report (if configured)
2. **Report entry** (per official or crew chief, depending on signatory model):
   - Select incident type from template list OR select "Custom" for free-form
   - If template: auto-populate known fields (time of incident, player/team involved if logged); add optional notes
   - If free-form: open text editor with minimum 10 characters, maximum 5000 characters
   - Attach optional evidence (photo, video, document URL)
   - Review & confirm before submit
3. **Signatory acknowledgment**:
   - If single-official: crew chief submits; other officials optionally notified/invited to review
   - If crew-wide: all required officials receive notification; must acknowledge (read + confirm understanding)
   - Signature/acknowledgment timestamped with IP, device info for audit
4. **League director review** (if blocking enabled or dispute flagged):
   - Review report and evidence
   - Approve as-is, edit with official consent, or request rewrite
   - Document decision and reasoning (separate audit trail)
   - If disputed: contact official(s) for clarification; resolve disagreement
5. **Publish/Finalize**:
   - Once approved, report becomes immutable (read-only for officials; audit trail visible)
   - If blocking enabled: unblock contest close-out; allow standings/payouts to proceed
   - Visibility: apply configured access level (internal/team/public)
6. **Post-finalization corrections**:
   - Officials/admins can request amendments (factual corrections, missing context)
   - Creates new amendment request (not direct edit); league director approves
   - Original report + amendments visible together in audit trail (original never deleted)

### Report Content Structure

```
GameReport {
  id, gameId, contestId,
  reportType: 'template' | 'freeform' | 'hybrid',
  
  // Template-based fields
  templateId,           // reference to incident template
  incidentType: enum,   // 'ejection' | 'injury' | 'rule_dispute' | 'equipment_failure' | 'weather' | 'custom'
  incidentTime: timestamp,
  involvedTeam,         // team(s) or neutral
  involvedPlayer,       // jersey number, name
  
  // Free-form field
  description: string,  // 10-5000 chars
  
  // Evidence
  attachments: [{ url, type ('photo'|'video'|'document'), uploadedAt }],
  
  // Signatory info
  signatories: [{
    officialId, role ('crew_chief'|'umpire'|'scorer'), 
    signedAt, ipAddress, deviceInfo,
    status: 'required' | 'acknowledged' | 'declined'
  }],
  
  // Dispute tracking
  disputeStatus: 'none' | 'flagged' | 'resolved',
  disputeReasons: [{
    officialId, reason, flaggedAt
  }],
  
  // League director action
  approvalStatus: 'pending' | 'approved' | 'rejected' | 'pending_revision',
  reviewedBy, reviewedAt, reviewNotes,
  
  // Amendments
  amendments: [{
    requestedBy, requestedAt, reason,
    approvedBy, approvedAt,
    oldValue, newValue
  }],
  
  // Configuration snapshot at time of report
  configSnapshot: {
    requiredModel, blockingBehavior, visibilityLevel, disputeEnabled
  },
  
  // Audit
  createdAt, finalizedAt, deletedAt (soft delete),
  auditTrail: [timestamp, action, actor, changes]
}

IncidentTemplate {
  id, sportId, divisionId (optional),
  incidentType, label, description,
  fields: [{ name, type, required, default }],
  createdAt, updatedAt, deletedAt (soft delete)
}

GameReportConfig {
  id, officialsOrgId, sportsOrgId (optional), divisionId (optional), levelId (optional),
  requiredFor: 'all' | 'none' | 'playoff_only' | 'tournament_only' | 'custom',
  signatoryModel: 'single_official' | 'crew_wide' | 'hybrid',
  blockingBehavior: 'blocking' | 'informational' | 'delayed_blocking',
  blockingDelay (if delayed): 24 | 48 hours,
  visibilityLevel: 'internal' | 'team_visible' | 'public',
  disputeEnabled: boolean,
  freeformRequired: boolean,
  createdAt, updatedAt
}
```

### Hierarchical Configuration

**Override hierarchy** (most specific wins):
```
Global default
  ↓
Officials org default
  ↓
Sports org default
  ↓
Division default
  ↓
Per-game override
```

**Configuration API**: Admin can set defaults at each level; system evaluates hierarchy when report required.

### Notifications & Reminders

**Initial notification** (on contest completion):
- If report required: send to all assigned officials (or crew chief if single-official model)
- Include: game summary, incident types for reference, form link

**Follow-up reminders** (configurable per league):
- T+2 hours: "Report awaiting your review" (if crew-wide model)
- T+24 hours: "Game report still pending"
- T+48 hours: if blocking enabled, "Report required to finalize contest"
- T+72 hours: if blocking enabled, escalate to league director (mark as blocked)

**Dispute notification**:
- When official flags dispute: notify league director and involved officials
- League director review & decision sent to all signatories

**Approval notification**:
- When approved: notify officials (final status), notify league admin
- Include summary of any amendments or disputes resolved

### Data Access & Visibility

**Officials**
- Can view/edit their own reports (until finalized)
- Can see other crew members' reports if crew-wide model
- Can view approved reports if dispute flagged and they're involved
- Cannot view other teams' reports (unless public visibility enabled)

**League Director / Sports Org Admin**
- Can view all reports for their division/sport
- Can approve, reject, request revisions
- Can view dispute flags and contact officials
- Can view amendment requests and approve/deny

**Coaches / Team Members** (if team_visible or public):
- Can view reports for their own games (details depend on visibility level)
- Cannot edit or flag disputes
- Can see incident type and summary; details may be redacted (configurable)

**Compliance / Support**
- Always have full access regardless of visibility setting
- Can audit all actions, amendments, disputes
- Can override configurations in emergency

**Public** (if visibility = public):
- Anonymized or full reports visible depending on league choice
- Read-only access; no download restrictions
- Visible via public portal or API

### User Interface Features

**Officials View**
- Dashboard: games with pending reports; due dates; color-coded urgency
- Report entry form: template selector, free-form text editor, attachment uploader, draft save, preview
- Report review modal: display report before final submit; crew acknowledgment section for multi-official sign-off
- My reports: list of submitted reports with status (pending approval, approved, amendments requested)
- Report history: see past reports, track patterns

**League Director View**
- Report queue: pending approval, flagged disputes, amendment requests
- Report detail: full report, signatory acknowledgments, evidence, dispute flags
- Approval controls: approve, reject, request revision, edit (with audit note), contact officials
- Bulk actions: approve multiple, export reports for compliance, print for archive
- Amendment panel: review requested changes, approve/deny with notes

**Sports Association Admin View**
- Report analytics: incident frequency by official/team/game type, dispute rate, approval SLA tracking
- Configuration manager: set defaults for template library, signatory model, blocking behavior, visibility per division
- Template library: manage incident types, add custom templates, enable/disable per division

**Configuration & Audit Trail**
- All changes logged: who changed visibility level, when, reason (with audit note)
- Immutable finalized reports: timestamp of finalization, seal/signature for compliance
- Amendment history: side-by-side view of original vs. amended content
- Dispute log: all flags, reasons, resolutions documented

### Consequences

**Positive**
- Incident documentation improves league governance, rule enforcement, and player safety tracking
- Officials feel heard; dispute mechanism provides outlet for context/disagreement
- Flexibility (full configurability) accommodates diverse league needs without custom builds
- Audit trails support compliance, investigations, and risk management
- Post-finalization amendments allow corrections without destroying evidence
- Blocking behavior option prevents premature standings updates or payouts pending critical issues

**Negative**
- Configuration complexity: admins must understand signatory models, blocking behavior, visibility levels; poor choices can frustrate workflows
- Report fatigue: if required for all games, officials may submit boilerplate reports; quality control needed
- Dispute mechanism adds burden on league director if overused; needs clear policy (only for factual disagreements, not subjective calls)
- Privacy/public visibility: if enabled, officials may be reluctant to report issues (chilling effect); balance needed
- Storage burden: attachments (photos/video) may consume significant storage; retention policy required

### Implementation Notes

1. **Templates**: Pre-populate with common incident types per sport (ejection, injury, rule violation, weather, equipment, unusual incident); allow league admins to customize
2. **Evidence storage**: Use S3/CloudFront for attachments; scan for malware; enforce file size/type limits
3. **Notifications**: Send via email + SMS (configurable); include deep links to report form
4. **Amendments**: Track as separate records, never overwrite original; show delta in UI
5. **Bulk export**: Support CSV export for league records retention (name, date, incident type, resolution)
6. **Mobile**: Officials need mobile-friendly form (single-column, large inputs) for on-site reporting
7. **Accessibility**: Support voice input for free-form field if evidence (photo/video) already captured
8. **Performance**: Index reports by gameId, officialId, contestId; cache templates per sport
9. **Finalization seal**: Use timestamp + SHA-256 hash of report content to prevent tampering; display in read-only view
10. **Dispute escalation**: If unresolved after 48 hours, auto-escalate to sports association executive director (configurable)

### Future Enhancements

- Machine learning: identify anomalous report patterns (e.g., one official filing disputes in >80% of games)
- Recommendation engine: suggest similar past incidents for context when filing new report
- Bulk reporting: allow officials to file a single report for multi-game assignments with same issue
- Video timestamp integration: auto-link incident timestamp to game video replay (if video recorded)
- Team/coach appeals: allow coaches to respond to reports (with league director arbitration)
- Third-party review: escalate controversial reports to external arbiter (for playoff/tournament games)
