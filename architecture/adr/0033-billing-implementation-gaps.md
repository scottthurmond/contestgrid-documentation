# ADR 0033: Billing & Subscription Implementation Gaps

## Status
Proposed

## Date
2026-03-09

## Context
A review of the billing design (ADRs 0003, 0012, 0014, 0017, 0018, 0019, 0029, 0030) against what is actually implemented in the database migrations (V001–V014) and service code (billing-sys, billing-proc) reveals significant gaps. The platform can record per-contest payments and per-official payouts today, but cannot track subscriptions, invoices, fee schedules, or discount codes.

This ADR catalogs every gap so the team can prioritize implementation.

## What IS Implemented

| Artifact | Location | What It Does |
|---|---|---|
| `contest_rates` table | V009 migration | Stores per-game bill amount and official pay rate keyed by (association, tenant, sport, level) |
| `tenant_pay_rate_map` table | `postgres-converted.sql` | Maps which rate schedules apply to which tenants |
| `payment` table | V014 migration | Records contest bill and official payout transactions with amount, status, processor ref, paid_at |
| `payment_status` reference | V014 migration | 6 statuses: Pending, Processing, Completed, Failed, Refunded, Cancelled |
| `payment_type` reference | V014 migration | 2 types: Contest Bill, Official Payout |
| billing-sys API | Port 3003 | CRUD for rates, payments, billing-payments |
| billing-proc API | Port 3005 | Payment processing workflow (mock Stripe), payroll calculation, payroll disbursement |
| BFF proxy routes | `proxy.ts` | Authenticated proxy to billing-sys and billing-proc endpoints |

## Gap 1: Tenant Subscription Tracking

**Designed in:** ADR-0018 (Platform Monetization), ADR-0003 (Billing & Payroll)

**What's missing:** No database table or API to track which plan a tenant is on, when they subscribed, their billing cycle, or when their next payment is due.

**Required artifacts:**
- `subscription_plan` reference table — Starter ($99/mo), Pro ($299/mo), Enterprise (custom)
- `tenant_subscription` table — tenant_id, plan_id, status (active/trial/past_due/cancelled/suspended), billing_cycle (monthly/annual), current_period_start, current_period_end, next_payment_date, payment_method_ref, provider_subscription_id
- `subscription_event` audit table — records plan changes, renewals, cancellations, suspensions with timestamps and actor
- Dunning state tracking — failed_payment_count, last_retry_at, suspension_date (suspend after 7 days per ADR-0018)
- Overage tracking — usage_metric, current_value, quota, overage_rate (games over 50, officials over 20, etc.)

**ADR references:** ADR-0018 §Tiered Plans, §Billing Cycle, §Dunning

---

## Gap 2: Officials Subscription Tracking

**Designed in:** ADR-0019 (Officials Subscription Model), ADR-0012 (Officials Subscription & Fees)

**What's missing:** No table to record an official's subscription status, renewal date, billing strategy, or multi-association membership billing.

**Required artifacts:**
- `official_subscription` table — official_id, status (active/expired/suspended/grace), fee_amount, currency, billing_strategy (per_association/flat_rate/hybrid/association_specific), renewal_date, signup_date, last_payment_date, next_payment_date, payment_method_ref, provider_subscription_id
- `official_association_subscription` table — for per-association billing: official_id, association_id, fee_amount, status, joined_at, left_at
- Renewal workflow state — reminder_60d_sent, reminder_30d_sent, reminder_7d_sent, retry_count, suspended_at
- Tenant-level billing strategy config — which of the 4 strategies a tenant uses, changeable with 30-day notice

**ADR references:** ADR-0019 §Yearly Billing, §Multi-Association Billing Strategies, §Renewal Cycle

---

## Gap 3: Fee Schedules, Adjustments & Coupons

**Designed in:** ADR-0012 (Officials Subscription & Fees)

**What's missing:** No tables for tenant-level fee defaults, per-official adjustments (discounts/surcharges), or coupon/promo codes.

**Required artifacts:**
- `fee_schedule` table — tenant_id, default_fee, currency, effective_from, effective_to
- `adjustment` table — id, type (discount/surcharge), target_type (official/tenant/association), target_id, amount, percent, reason, applied_by, applied_at, expires_at
- `coupon` table — code, percent_off, amount_off, max_redemptions, current_redemptions, expires_at, created_by
- `coupon_redemption` table — coupon_id, official_id, redeemed_at, invoice_id
- Stacking rules engine — precedence (coupon → discount → surcharge), negative-total prevention

**ADR references:** ADR-0012 §Data Models, §Governance

---

## Gap 4: Invoice & Line Item Tables

**Designed in:** ADR-0003 (Billing & Payroll), ADR-0012 (Officials Subscription & Fees)

**What's missing:** The `payment` table records individual transactions but there is no invoice abstraction that groups line items, applies taxes, tracks invoice lifecycle, or supports tenant subscription billing and officials fee invoicing.

**Required artifacts:**
- `invoice` table — id, billing_entity_id, tenant_id, invoice_number, status (draft/issued/sent/paid/overdue/void/cancelled), period_start, period_end, subtotal, tax_amount, total, due_date, paid_at, issued_at, sent_at, provider_invoice_id
- `invoice_line_item` table — invoice_id, description, quantity, unit_price, tax_rate, line_total, reference_type (subscription/overage/contest_bill/fee/adjustment), reference_id
- `official_invoice` table (or reuse invoice with type) — per ADR-0012: official_id, period_start, period_end, line_items, total, status
- Invoice PDF/HTML generation — per ADR-0003 §Templates
- Invoice status tracking and reminders — overdue notifications, auto-void policies

**ADR references:** ADR-0003 §Data Models (Tenant Billing), §Invoicing Workflow; ADR-0012 §Data Models (OfficialInvoice)

---

## Gap 5: Billing Entity Model

**Designed in:** ADR-0029 (Payer & Billing Entity Model), ADR-0003 (Billing & Payroll)

**What's missing:** No `billing_entity` table to support the 7 payer types (tenant, sub_organization, cost_center, event, third_party, individual, group). No split billing for multi-payer contests.

**Required artifacts:**
- `billing_entity` table — per ADR-0029 schema: id, entity_type, name, abbreviation, tenant_id (nullable), parent_billing_entity_id, contact fields, payment_method, billing_cycle, payment_terms_days, is_verified, status
- `contest_billing_split` table — contest_id, billing_entity_id, percentage_responsible or fixed_amount, status (pending/confirmed/invoiced/paid/disputed)
- `billing_entity_id` column on `contest_rates` — for entity-specific rate overrides (NULL = tenant default)
- Verification workflow for third-party billing entities

**ADR references:** ADR-0029 §Decision (full schema), ADR-0003 §Split Billing

---

## Gap 6: Convenience Fee Engine

**Designed in:** ADR-0014 (Payments Provider & Convenience Fees)

**What's missing:** No logic or configuration to apply convenience fees based on payment method.

**Required artifacts:**
- `convenience_fee_config` table or config — payment_method_type, fee_percent, fee_fixed, absorb_or_pass (tenant configurable)
- Fee calculation in billing-proc payment workflow — card/wallet: +2.9% + $0.30; ACH: $0
- Display on invoices as separate line item

**ADR references:** ADR-0014 §Fee Schedule

---

## Gap 7: Contract Lifecycle Fees

**Designed in:** ADR-0017 (Contract Lifecycle Management)

**What's missing:** No table or billing logic for contract setup fees, renewal fees, or annual subscription add-ons.

**Required artifacts:**
- `contract_fee_config` — fee_type (setup/renewal/annual_addon), amount, per_contract or flat
- Integration with invoice generation — contract fees as invoice line items

**ADR references:** ADR-0017 §Monetization (Hybrid model: $25 setup + $15 renewal + $100/yr option)

---

## Gap 8: 1099-NEC Tax Profiles & Forms

**Designed in:** ADR-0030 (1099-NEC Reporting)

**What's missing:** No `official_tax_profile` or `form_1099_nec` tables. No vault integration for secure TIN storage.

**Required artifacts:**
- `official_tax_profile` table — official_id, association_id, legal_name, tax_identifier_type, tax_identifier_last4, external_vault_ref, w9_status, w9_received_at, backup_withholding_required, delivery_preference, mailing_address
- `form_1099_nec` table — association_id, official_id, tax_year, nonemployee_compensation, federal_tax_withheld, state_tax_withheld, status (draft/issued/corrected/void), issued_at, delivered_at, document_url
- KMS/vault integration for full TIN storage
- Annual aggregation job — sum payouts per (association, official, tax_year)

**ADR references:** ADR-0030 §Decision (full schema)

---

## Implementation Priority Recommendation

| Priority | Gap | Rationale |
|---|---|---|
| **P0** | Gap 1: Tenant Subscription | Cannot bill tenants or track plan status without this |
| **P0** | Gap 4: Invoice & Line Items | Foundation for all billing — subscriptions, fees, contests |
| **P1** | Gap 2: Officials Subscription | Required before officials can be charged |
| **P1** | Gap 3: Fee Schedules & Coupons | Required for officials fee billing |
| **P1** | Gap 5: Billing Entity Model | Required for non-tenant payers (sub-orgs, third parties) |
| **P2** | Gap 6: Convenience Fees | Revenue optimization; can launch with flat pricing initially |
| **P2** | Gap 7: Contract Lifecycle Fees | Additional revenue; can defer until contracts feature ships |
| **P3** | Gap 8: 1099-NEC | Compliance; not needed until first tax year with payouts |

## Migration Sequence

When implementing, migrations should follow this order to respect foreign key dependencies:

1. `V015` — `subscription_plan`, `tenant_subscription`, `subscription_event`
2. `V016` — `billing_entity`, `contest_billing_split`
3. `V017` — `invoice`, `invoice_line_item`
4. `V018` — `fee_schedule`, `adjustment`, `coupon`, `coupon_redemption`
5. `V019` — `official_subscription`, `official_association_subscription`
6. `V020` — `convenience_fee_config`
7. `V021` — `contract_fee_config`
8. `V022` — `official_tax_profile`, `form_1099_nec`

## Consequences

- **Without these tables**, the platform can only record after-the-fact contest payments. It cannot manage subscription lifecycles, generate invoices, apply discounts, track overdue balances, or answer "when is tenant X's next payment due?"
- **Implementing P0 gaps first** unblocks the core billing workflow: tenant subscribes → invoice generated → payment tracked → renewal managed.
- Each gap has a corresponding ADR with full design — no new architectural decisions are needed, only implementation.

## Related ADRs
- ADR-0003: Billing & Payroll
- ADR-0012: Officials Subscription & Fees
- ADR-0014: Payments Provider & Convenience Fees
- ADR-0017: Contract Lifecycle Management
- ADR-0018: Platform Monetization Strategy
- ADR-0019: Officials Subscription Model
- ADR-0029: Payer & Billing Entity Model
- ADR-0030: 1099-NEC Reporting
