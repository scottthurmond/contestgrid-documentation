# Platform Admin: Officials Fees UI Flows

## Goals
- Configure tenant default fees, apply per-official discounts/surcharges, and audit changes.
- Support billing cadence, proration, and payment path selection (deduct vs direct).

## Screen Map
- Fees Overview (tenant)
- Default Fee Settings
- Adjustments (per-official)
- Coupons Management
- Invoices & Receipts (officials)
- Audit Log

## Flow 1: Set Tenant Default Fee
1. Navigate: Platform Admin → Billing → Officials Fees.
2. Screen: Default Fee Settings.
3. Actions:
   - Set `defaultFee`, `currency`, `effectiveFrom` (optional `effectiveTo`).
   - Preview impacted officials count.
   - Save → confirmation dialog with effective date.
4. Outcome: `FeeSchedule` created/updated; audit record stored.

## Flow 2: Apply Per-Official Adjustment
1. Navigate: Fees Overview → search/select official.
2. Screen: Official Fee Detail.
3. Actions:
   - Add `Adjustment` (discount/surcharge): amount or percent, reason, expiresAt.
   - Define stacking precedence (uses policy defaults; optional override).
   - Save → confirmation.
4. Outcome: `Adjustment` linked; recalculation for next billing; audit record.

## Flow 3: Create & Apply Coupon
1. Navigate: Coupons Management.
2. Actions:
   - Create `Coupon`: code, percentOff/amountOff, maxRedemptions, expiresAt.
   - Assign to officials or publish for self-apply.
3. Outcome: Coupon available; redemption tracked.

## Flow 4: Choose Payment Path (Deduct vs Direct)
1. Screen: Official Fee Detail.
2. Actions:
   - Select payment path: deduct from payouts or direct payment (card/ACH).
   - If direct: ensure payment method on file via provider UI (tokenized).
3. Outcome: preference stored; billing run uses chosen path.

## Flow 5: Review Invoices & Receipts
1. Navigate: Invoices & Receipts.
2. Actions:
   - Filter by period, status.
   - View invoice: line items (default fee, adjustments, coupons), total.
   - Download PDF/CSV; resend receipt.
3. Outcome: transparency and support.

## Flow 6: Audit & Governance
1. Navigate: Audit Log.
2. Actions:
   - Filter by actor (admin), action (create/update/delete), resource (FeeSchedule/Adjustment/Coupon).
   - Export for compliance.
3. Outcome: immutable audit trace.

## Edge Cases
- Negative totals prevented by guardrails; show validation errors.
- Expired adjustments auto-remove from future runs; UI badges indicate expiry.
- Disputes: link to dispute workflow (refunds/credits) when applicable.

## UX Notes
- Use accessible forms with clear labels and help text.
- Show effective date tooltips and proration warnings.
- Provide preview calculations before saving adjustments.
