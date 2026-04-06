# ADR 0012: Officials Subscription & Fees (Per-Tenant Defaults, Discounts, Surcharges)

## Status
Accepted

## Context
We need to charge officials for use of the system. Fees should be configurable per tenant with defaults, and the platform owner must be able to apply discounts or additional fees at discretion with auditability.

## Decision
Introduce per-tenant fee schedules and per-official subscriptions with adjustments (discounts/surcharges). Support monthly billing, proration, and payment options (deduct from payouts or direct payment via card/ACH). Record all changes with audit metadata.

## Data Models
- `FeeSchedule(tenantId, defaultFee, currency, effectiveFrom, effectiveTo?)`
- `OfficialSubscription(officialId, tenantId, plan, feeAmount, currency, status)`
- `Adjustment(id, type: 'discount'|'surcharge', amount, percent?, reason, appliedBy, appliedAt, expiresAt?)`
- `Coupon(code, percentOff|amountOff, maxRedemptions, expiresAt)`
- `OfficialInvoice(id, officialId, periodStart, periodEnd, lineItems, total, status)`

## Workflows
1. Tenant sets default fee in Platform Admin (FeeSchedule).
2. Officials inherit default fee; owner can apply per-official adjustments or coupons.
3. Monthly billing run computes charges (proration for mid-cycle changes), applies adjustments, and generates invoices.
4. Payment: either deduct fee from payout (net earnings) or charge via card/ACH; receipts issued.
5. Audit: all fee changes and invoice actions logged with `userId`, `tenantId`, `reason`, timestamps.

## UI Flows
- See [flows/platform-admin-fees.md](../flows/platform-admin-fees.md) for screen maps and step-by-step flows to configure default fees, apply adjustments, manage coupons, select payment paths, and review invoices with audit.

## Governance
- Stacking rules: define precedence (e.g., coupon → discount → surcharge) and prevent negative totals.
- Expiry and renewal: time-bound adjustments auto-expire; renewal policies documented.
- Disputes & refunds: workflow for disputed charges; refund handling via provider.

## Compliance
- Disclosure and consent in ToS; clear line items on invoices.
- PCI offloaded to payment provider; PII minimized and encrypted.

## Consequences
- Pros: flexible monetization, per-tenant control, auditable financial changes.
- Cons: complexity in adjustments and proration; mitigated via clear rules and UI.
