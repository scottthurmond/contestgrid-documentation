# ADR 0011: Officials Payment Workflow (Confirmation → Approval → Payment)

## Status
Accepted

## Context
Multiple officials may work a single game. We require a robust workflow where each official confirms participation, the officials tenant performs final approval, and assignments are marked for payment and included in payout batches.

## Decision
Adopt a post-game confirmation workflow per assignment, with optional crew chief reconciliation, tenant admin final approval, and batch marking for payment followed by payout execution and pay stub delivery.

## Workflow
1. Trigger: `game.played` event starts confirmation window (e.g., 48h).
2. Officials confirm: each assigned official submits attendance/role/notes.
3. Conflict detection: system flags mismatches or no-shows; opens disputes.
4. Reconciliation: optional crew chief resolves minor disputes; unresolved escalate to tenant admin.
5. Final approval: officials tenant admin reviews/approves assignments.
6. Mark for payment: approved assignments move to `marked-for-payment` and join the next pay period batch.
7. Payout & pay stubs: ACH payout run executes; pay stubs generated and delivered; assignment status `paid` with receipt.

## Status Model
- Game: `scheduled` → `played`.
- Assignment: `assigned` → `confirmed-by-official` → `approved-by-tenant` → `marked-for-payment` → `paid`.
- Disputes: `disputed` → `resolved` | `void`.

## Policies
- Confirmation window with reminders; overdue escalations; auto-void rules configurable.
- Pro-rating for partial cancellations; replacement officials require explicit confirmation and admin approval.

## Data & Audit
- Records: `AssignmentConfirmation`, `Dispute`, `Approval`, `PaymentMark`, `PayoutBatch`, `PayStub`.
- Audit: log all actions with `userId`, `tenantId`, timestamps; telemetry summarizes rates and SLA adherence.

## Consequences
- Pros: accurate payouts, stronger accountability, auditable flow.
- Cons: added steps and dispute handling; mitigated via clear UI and reminders.
