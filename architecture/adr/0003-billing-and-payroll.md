# ADR 0003: Billing (Tenants) and Payroll (Officials)

## Status
Accepted

## Context
The platform must invoice tenants for subscriptions and usage, and generate pay stubs and payouts for game officials. We want strong compliance, minimal PII handling, and robust reporting. Officials organizations also serve sports associations and individual customers; they must issue invoices to those downstream customers and receive payments on those invoices. Those customers may or may not be tenants in the platform—they could be sub-organizations, third-party organizations, individuals, or informal groups. The billing model must support flexible payers beyond just system tenants.

## Decision
- Implement a flexible **billing entity model** (see ADR-0029) that supports tenants, sub-organizations, cost centers, events, third-party organizations, individuals, and informal groups as payers.
- Support officials organizations invoicing any billing entity for assigned officials, with payment collection (card/ACH/wallets) and reconciliation status per invoice.
- Support split billing when multiple billing entities pay for a single contest.
- Implement officials payroll with calculated earnings from assignments, withholds, pay periods, and payouts via provider.
- Provide Platform Admin billing dashboards and Officials Admin payroll dashboards.

## Data Models

### Billing Entity (from ADR-0029)
```
BillingEntity {
  id, entity_type (tenant|sub_organization|cost_center|event|third_party|individual|group),
  name, abbreviation, description,
  tenant_id (NULL for third-party/individual/group),
  parent_billing_entity_id (for hierarchies),
  contact_name, email, phone, website,
  address_id, payment_method, payment_reference, tax_id,
  bill_to_email, billing_cycle, payment_terms_days,
  is_primary, is_verified, is_taxpayer,
  status (active|inactive|suspended|archived)
}
```

### Split Billing
```
ContestBillingSplit {
  id, contest_id, billing_entity_id,
  percentage_responsible (OR fixed_amount),
  status (pending|confirmed|invoiced|paid|disputed),
  notes
}
```

### Tenant Billing
- `Invoice(id, tenantId, periodStart, periodEnd, status)`
- `LineItem(description, quantity, unitPrice, taxRate)`
- `Subscription(planId, start, end, status)`
- `UsageRecord(metric, value, timestamp)`
- `Payment(status, method, amount, date)`
- `Refund`, `CreditNote`

### Officials Payroll
- `PayRate(role, base, modifiers)`
- `AssignmentEarning(assignmentId, gross, modifiers)`
- `PayPeriod(start, end, status)`
- `PayStub(id, officialId, periodId, gross, withholds, net)`
- `Withholding(type, amount)`
- `Payout(status, providerRef, date)`
- `Adjustment(reason, amount)`

## Invoicing Workflow

1. **Create Invoice** → Links to billing entity (single or split)
2. **Calculate Amount** → Based on contest_rates + billing_entity allocation
3. **Send Invoice** → To billing_entity.bill_to_email (may differ from contact email)
4. **Track Status** → pending, issued, sent, paid, overdue, void, cancelled
5. **1099 Reporting** (see ADR-0030) → Officials associations issue 1099-NEC to officials (independent contractors); use `official_tax_profile` (minimal metadata, last4 + vault ref, W-9 status) and record issued forms in `form_1099_nec` (tax_year, amounts, delivery, corrections); never store full SSN/EIN in platform DBs.

## Providers
- **Subscription Billing (Tenants)**: Stripe/Adyen (tokens, invoices, hosted pay links, cards, ACH, wallets like Apple Pay/Google Pay, optional PayPal; dunning)
- **Contest Invoicing (Officials Customers)**: Stripe/Adyen (same as above; track per billing_entity)
- **Payouts (Officials)**: Stripe Treasury/Connect, Adyen MarketPay (ACH), optional check printing integrations; instant debit payouts where supported.

## Templates
- **Invoice PDF/HTML**: line items, taxes, totals, payment instructions, customized per billing_entity type (org vs individual)
- **Pay Stub PDF/HTML**: earnings, withholds, net pay, period summary
- **1099-NEC (for individuals)**: IRS-compliant forms for independent contractors
- **Confirmation & Approval UI**: officials confirmation screens, dispute reconciliation, tenant admin approval and batch marking for payment

## Compliance & Security
- **PCI**: Offloaded to provider; store only tokens/refs.
- **PII**: Minimized and encrypted at rest; masking in UI. Tax IDs encrypted and isolated.
- **Regional Tax & Labor Rules**: Configurable; audit trails for all calculations.
 **1099 Reporting** (see ADR-0030): Automatic generation for eligible individuals using payouts; aggregated and filed per requirements; minimal TIN storage (last4 + external vault reference); electronic/paper delivery with corrections.
- **Third-Party Verification**: Billing entities marked as third-party require verification before invoicing (optional approval workflow).
- **Venmo/Zelle/Checks**: If supported via policy, treat as manual methods with reconciliation workflows; ensure AML/KYC considerations and secure record-keeping.

## Data Access & Audit
- All invoice creation, payment, and payout actions logged to audit trail
- Officials can see invoices issued to them (via billing_entity)
- Sports associations can see invoices issued to their billing entities (self + sub-organizations)
- Third-party payers see only their own invoices and payment status
- Officials associations see all invoices they've issued

## Consequences
- **Pros**: 
  - Clear financial flows for complex payer scenarios (splits, non-tenants, hierarchies)
  - Strong compliance posture (audit trail, 1099 reporting, tax handling)
  - Admin visibility across all payer types
  - Backward compatible with existing tenant-based billing
- **Cons**: 
  - Integration complexity with multiple payer types
  - Invoicing UI must handle different entity types
  - Testing matrix expands (multiple entity types × payment methods)
  - Mitigated via provider SDKs, clear type validation, and phased rollout

## Related ADRs
- **ADR-0029**: Payer and Billing Entity Model (detailed design)
- **ADR-0011**: Officials Payment Workflow (confirmation→approval→payment process)
- **ADR-0014**: Payments Provider and Convenience Fees
- **ADR-0012**: Officials Subscription & Fees
 - **ADR-0030**: 1099-NEC Reporting for Officials (tax profiles, secure TIN handling, annual forms)
