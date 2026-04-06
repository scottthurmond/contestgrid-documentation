# ADR 0026: Coach Score Entry & Dispute Resolution

## Status
Proposed

## Context
Sports associations need coaches from competing teams to enter final contest scores post-game. Scores feed standings, tournament advancement, and analytics. When scores disagree between coaches, league directors must resolve disputes. Coaches and admins should be able to correct scores after finalization with full audit trails.

## Decision

### Score Entry Workflow
1. **Contest completion**: When contest status changes to "completed", both team coaches receive email/SMS reminders to enter final score
2. **Score entry form** (per coach):
   - Final score (home/away goals, runs, points, etc.)
   - Optional sport-specific stats (goals-against, errors, etc.)
   - Optional notes/context
3. **Two-coach approval**:
   - First coach enters score
   - Second coach reviews and confirms OR disputes with explanation
   - If both confirm same score → auto-finalize, standings/brackets update immediately
   - If both confirm same score but one initially disputed → still finalizes
   - If scores disagree → flagged for league director resolution
4. **Dispute resolution** (league director):
   - Reviews both submissions, coach notes, and optional photo/video evidence
   - Selects correct score or requests re-entry
   - Documents decision in audit trail with reason
   - Once resolved → standings/brackets update
5. **Post-finalization edits**:
   - Coaches and admins can request score corrections (with reason)
   - League director approves or denies change
   - All changes logged in audit trail (old score, new score, who changed it, when, why)

### Notifications & Reminders
**Escalating reminders** (configurable per league):
- T+0 (immediate): initial reminder email/SMS
- T+1 day: "Score still needed" reminder
- T+2 days: escalation reminder
- T+3 days: final reminder before auto-mark as "no score entered" or league director override

**Notification recipients**:
- Coaches: score entry reminders and dispute resolution outcome
- League admin: when score entered, when disputed, when resolved
- Sent via email + SMS (configurable per league)

### Data Models
```
ContestScore {
  id, contestId,
  homeTeamScore, awayTeamScore,
  homeCoachId, awayCoachId,
  homeCoachSubmittedAt, awayCoachSubmittedAt,
  homeCoachConfirmed (boolean), awayCoachConfirmed (boolean),
  status (pending | entered_one_coach | disputed | approved_both_agree | approved_after_dispute | needs_correction),
  finalizedAt, finalizedBy,
  homeCoachNotes, awayCoachNotes,
  disputeNotes (if disputed),
  disputeResolvedBy (league director ID),
  disputeResolvedAt,
  scoreCorrectionHistory: [
    { oldScore, newScore, requestedBy, requestedAt, approvedBy, approvedAt, reason }
  ]
}

ScoreEntryReminders {
  id, contestId, contestScoreId,
  reminderNumber (1, 2, 3),
  sentAt, sentTo (coach ID),
  channel (email | sms)
}

ScoreReminderPolicy {
  id, leagueId, contestLevelId, divisionId,
  reminders: [
    { delayHours: 0, channel: "email|sms" },
    { delayHours: 24, channel: "email|sms" },
    { delayHours: 48, channel: "sms" },
    { delayHours: 72, channel: "email|sms" }
  ],
  autoMarkNoScoreAfterHours: int (default 5 days = 120h)
}
```

### Standings & Tournament Integration
- Standings recalculate and update **immediately** when score is finalized (after both coaches agree or league director resolves dispute)
- Tournament brackets advance teams based on finalized scores
- Historical score changes create audit log entry; standings do **not** retroactively recalculate (e.g., if score corrected 2 days later, brackets already advanced—document decision in audit)
- Optional: add "score pending" status in standings/brackets to indicate unfinalized games

### Behavior
- **Entry**: first coach enters, second coach reviews and confirms/disputes
- **Agreement**: both agree → auto-finalize, update standings/brackets immediately
- **Dispute**: scores differ → league director reviews and decides
- **Correction**: after finalization, either coach or admin can request change with reason; league director approves; audit logged

### UI Features
- **Coach score entry form**: modal with team logo, opposing team, final score input, notes, submit/cancel
- **Score review modal** (second coach): shows first coach's entry, requests confirmation or dispute reason
- **League admin dashboard**: pending scores, disputed scores, resolution queue; filter by contest level/division/date
- **Dispute resolution panel**: side-by-side comparison of both submissions, coach notes, decision form (pick score or request re-entry), audit comment
- **Standings view**: badge for pending/disputed scores next to game results
- **Score edit audit trail**: view all corrections on contest detail page
- **Notifications**: templated email/SMS with contest details, quick link to enter score

## Consequences
- **Pros**: coaches responsible for accuracy; two-step verification reduces errors; league director arbitration prevents stalemate; full audit for compliance
- **Cons**: adds friction (two coaches must act); dispute resolution adds league work; reminders can spam if not tuned

## Related ADRs
- ADR-0024: Contest Loading Strategy (contests are core data)
- ADR-0002: Telemetry and Audit (score entry/corrections logged)
- ADR-0015: Notification & Messaging (score entry reminders)
