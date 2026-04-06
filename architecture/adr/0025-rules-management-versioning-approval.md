# ADR 0025: Rules Management with Versioning & Approval Workflows

## Status
Proposed

## Context
Contest levels, divisions, and age groups each have their own rule sets that can change season to season. Sports associations need version-controlled rules with multi-step approval workflows (league director → association president), officials associations need to acknowledge rule changes, and individual officials must acknowledge they've read and understood rules both initially and when changes are published. Rules must be displayable on-screen and downloadable as PDFs with full audit trails.

## Decision

### Rules Data Model
```
Rules {
  id, tenantId,
  scopeType (contestLevel | division | ageGroup),
  scopeId (id of the level/division/ageGroup),
  seasonId (which season these rules apply to),
  version (1.0, 1.1, 2.0, etc.),
  status (draft | pending_approval | approved | published | archived),
  content (rich text or structured sections),
  effectiveDate, expiryDate,
  createdBy, createdAt,
  publishedAt, publishedBy,
  pdfUrl (generated PDF for download)
}

RuleApprovalWorkflow {
  id, ruleId, version,
  approvalChain: [
    { role: "league_director", userId, status (pending | approved | rejected), timestamp, comments },
    { role: "association_president", userId, status, timestamp, comments }
  ],
  currentStep (which role needs to approve next),
  finalStatus (pending | approved | rejected),
  completedAt
}

RuleAcknowledgments {
  id, ruleId, version,
  officialsAssociationId (tenant),
  acknowledgedBy (association admin/president),
  acknowledgedAt,
  comments,
  auditTrail
}

OfficialRuleAcknowledgments {
  id, ruleId, version,
  officialId,
  acknowledgedAt,
  requiresReAcknowledgment (boolean, set when rule changes),
  acknowledgedVersions: [ { version, acknowledgedAt } ],
  status (pending | acknowledged),
  remindersSent (count, timestamps)
}

RuleChangeNotifications {
  id, ruleId, oldVersion, newVersion,
  changeType (minor | major),
  changeSummary (text describing what changed),
  notifiedAt,
  recipients (officialsAssociationIds, officialIds),
  deliveryStatus (sent, delivered, acknowledged)
}
```

### Workflow

**1. Rule Creation**:
- Admin creates draft rules (scoped to level/division/age group + season)
- Rich text editor with sections, numbering
- Preview and generate PDF
- Status: draft

**2. Approval Workflow**:
- Submit for approval → status: pending_approval
- League Director reviews/approves → forwards to Association President
- Association President reviews/approves → status: approved
- Any rejection sends back to draft with comments
- Audit trail logs all approvals/rejections with timestamps

**3. Publishing**:
- Once approved, admin publishes → status: published
- Generate final PDF, set effectiveDate
- Trigger notifications to Officials Associations

**4. Officials Association Acknowledgment**:
- Officials Association admin receives notification
- Reviews rules, acknowledges on behalf of association
- Logged in audit trail

**5. Individual Official Acknowledgment**:
- All officials linked to that level/division/season receive notification
- Must acknowledge before accepting assignments (configurable)
- Initial acknowledgment: first time they see rules
- Change acknowledgment: when rules updated, requiresReAcknowledgment flag set
- Reminders sent if not acknowledged within X days

**6. Version Control**:
- Each rule change creates new version
- Old versions archived, accessible for audit
- Change summary generated (what changed, why)
- All previous acknowledgments preserved

**7. PDF Generation**:
- Template with rule content, version, effectiveDate
- Header/footer with association branding
- Watermark if draft/pending
- Downloadable from UI

### UI Features
- **Rules Library**: list by level/division/season with filter/search
- **Rule Editor**: rich text, sections, numbering, version control
- **Approval Dashboard**: pending approvals, approval history, comment threads
- **Acknowledgment Dashboard**: who has/hasn't acknowledged, send reminders, bulk reminders
- **Version Comparison View**: diff between versions with highlighted changes
- **Audit Report**: all acknowledgments, timestamps, who approved, export capability
- **Official Portal**: view applicable rules, acknowledge, download PDF, version history

### Enforcement
- Block official assignment acceptance if required acknowledgment pending (configurable)
- Escalation reminders: 7d → 3d → 1d before deadline
- Admin override capability with audit log

## Consequences
- **Pros**: comprehensive audit trail; ensures officials are aware of rule changes; multi-level approval prevents unauthorized changes; PDF export for offline reference
- **Cons**: workflow complexity; notification fatigue (mitigated via digest/batching); versioning overhead (mitigated via automated version increments)

## Related ADRs
- ADR-0023: Contest Assignment & Official Metrics (rules apply to contests)
- ADR-0002: Telemetry and Audit (audit trail requirements)
- ADR-0015: Notification & Messaging (rule change notifications)
