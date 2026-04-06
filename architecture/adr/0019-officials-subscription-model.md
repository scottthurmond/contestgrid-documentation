# ADR 0019: Officials Subscription Model & Multi-Association Membership

## Status
Accepted

## Context
Officials need to subscribe to the platform yearly. Officials associations invite officials to join their organization. Officials may belong to multiple associations simultaneously. Platform must support flexible billing models for multi-association membership.

## Decision
Implement yearly subscription billing for officials with configurable multi-association billing strategies. Support per-association fees, flat-rate unbounded, or hybrid models. Allow platform and tenant admins to choose billing approach.

## Officials Subscription

### Yearly Billing (Not Monthly)
- Officials pay annual subscription fee (e.g., $15–50/year)
- Renewal date: anniversary of signup or aligned to tenant's fiscal year (configurable per tenant)
- Pro-ration: if official joins mid-year, charge pro-rated amount; full year at renewal
- Annual invoicing: consolidated invoice sent to official or officials association

### Multi-Association Membership & Billing Strategies

**Billing Strategy #1: Per-Association Fee (Default)**
- Official charged separately for each association membership
- Example: Official joins 3 associations, each charges $20/year → Official owes $60/year total
- Use case: associations want to track their own official costs; distinct association fee structures
- Implementation: separate subscription record per association; individual invoices or consolidated

**Billing Strategy #2: Flat-Rate Unbounded (All Associations Included)**
- Official pays single annual fee for unlimited association memberships
- Example: Official pays $40/year, can join 5+ associations
- Use case: officials who work across multiple associations; simplify billing
- Implementation: one subscription record; covers all associations; associations configured as "included"
- Tenant config: mark association as "included in flat-rate" during setup

**Billing Strategy #3: Hybrid (Tiered by Count)**
- First association included free or at base rate; additional associations charged per-add-on
- Example: 1st association $0 (included), 2nd–5th associations $5 each, 6+ capped at max ($25/year total)
- Use case: encourage officials to work with primary association; minimize friction for multi-association
- Implementation: tiered logic in billing engine; track cumulative fees per official

**Billing Strategy #4: Association-Specific Pricing**
- Each association sets own fee rate (e.g., Assoc A: $15/year, Assoc B: $25/year, Assoc C: $30/year)
- Official joins A, B, C → charged $15 + $25 + $30 = $70/year
- Allows associations to differentiate by size, features, or market
- Implementation: fee field per (association, official) relationship; aggregate at billing time

**Tenant-Level Configuration:**
- Platform admin or tenant admin chooses billing strategy during onboarding or later
- Options: "per-association", "flat-rate", "hybrid", "association-specific"
- Can change strategy with notice (e.g., 30d warning before renewal)
- Audit trail of billing strategy changes

## Officials Association Invitations

### Invitation Workflow
1. **Initiate**: Officials association admin (league/officials organization) invites official by email
2. **Send**: Platform sends invitation email with secure invite link + QR code
3. **Accept**: Official clicks link or scans QR → presented with:
   - Association details (name, logo, description)
   - Subscription fee (per chosen billing strategy)
   - Terms of engagement (optional association-specific waiver or contract)
   - Payment method setup or confirmation (if not already subscribed)
4. **Activate**: Official accepts → joins association; subscription charges

### Multi-Association Management (Official Dashboard)
- Officials can view all associations they're a member of
- Leave association: deactivate membership; uncharge future fees
- View subscription status: active/expired, renewal date, fee per association
- Update payment method (global or per-association)
- View invoices across all associations (consolidated or per-association)

### Multi-Association Management (Association Admin)
- View all officials in association
- Invite new officials (batch invite or individual)
- Revoke membership (official removed; future charges stopped)
- Configure billing strategy per official (override default if allowed)
- View subscription status and overdue accounts

## Data Model

```
OfficialSubscription {
  id, officialId, associationId (tenantId), billingStrategy: 'per-association'|'flat-rate'|'hybrid'|'association-specific'
  annualFee (amount for this subscription/association combination)
  renewalDate, status: 'active'|'pending_payment'|'expired'|'suspended'
  invitationSentAt, acceptedAt, activatedAt
  lastChargedAt, nextChargeDate
  auditTrail [] (who invited, when accepted, fee changes, etc.)
}

OfficialInvitation {
  id, officialId, associationId, invitedBy (adminId)
  invitationToken, expiresAt (7 days default)
  status: 'sent'|'opened'|'accepted'|'declined'|'expired'
  sentAt, openedAt, acceptedAt
  invitationEmail, customMessage
}

AssociationBillingConfig {
  associationId (tenantId)
  strategy: 'per-association'|'flat-rate'|'hybrid'|'association-specific'
  baseFee (for per-association or flat-rate)
  tierConfig {} (for hybrid: {tier1: {count: 1, fee: 0}, tier2: {count: 2-5, fee: 5}, ...})
  associationSpecificFeeOverride {} (for association-specific strategy)
  createdAt, updatedAt, changedBy (adminId)
  effectiveDate (when change takes effect; for active officials, if in middle of term, pro-rate)
}

OfficialInvoice {
  id, officialId, billingPeriod (Jan 1 - Dec 31)
  lineItems [] ({associationId, associationName, amount, billingStrategy})
  total, currency
  status: 'draft'|'sent'|'paid'|'overdue'|'failed'
  dueDate, paidAt, paymentMethod, transactionId
  createdAt, sentAt
}
```

## Billing Scenarios & Examples

### Scenario 1: Per-Association Billing
```
Official: John
Associations: League A ($20/year), League B ($15/year), League C ($10/year)
Total fee: $45/year
Invoicing: Single consolidated invoice OR three separate invoices (configurable)
Payment: Single charge of $45 OR three charges of $20, $15, $10 (configurable)
```

### Scenario 2: Flat-Rate Unbounded
```
Official: Jane
Associations: 5 different associations
Fee: $40/year (flat)
Invoicing: One invoice for $40, covers all associations
Payment: Single charge of $40
Renewal: automatic yearly unless official cancels
```

### Scenario 3: Hybrid (Tiered)
```
Official: Mike
Billing config: 1st association free, additional $8 each (capped at $50/year)
Associations: League A (free), League B (+$8), League C (+$8), League D (+$8), League E (+$8), League F (+$8)
Calculation: $0 + $8 + $8 + $8 + $8 + $8 = $48 (under cap)
Total: $48/year
```

### Scenario 4: Association-Specific Pricing
```
Official: Sarah
League A: $25/year (premium league)
League B: $15/year (regional league)
League C: $35/year (professional league)
Total: $75/year
```

## Billing & Collection

### Annual Renewal Cycle
- 60 days before renewal: reminder email with renewal details
- 30 days before: second notice with payment method confirmation
- 7 days before: final notice
- On renewal date: auto-charge to payment method on file
- If charge fails: retry 3 times over 14 days (vs. 7 for tenants)
- If payment succeeds: renew for another year; send renewal confirmation
- If payment fails: mark as overdue; send escalation; suspension after 14 days

### Grace Period & Reinstatement
- Overdue but not suspended: official can still view assignments (read-only)
- Suspended: official cannot accept new assignments until payment clears
- Payment received: automatically reinstate; back-date to renewal date (no gap)

### Consolidation & Batch Billing (If Multiple Associations)
- **Option A**: Individual invoices per association (sent separately or on same date)
- **Option B**: Consolidated invoice (single invoice with line items per association)
- **Option C**: Hybrid (some associations consolidated, some separate)
- Configuration: per-official choice or default per tenant

### Proration (Mid-Year Joins)
- Official joins March 1 for yearly fee with Dec 31 renewal
- Pro-rated amount for March 1 → Dec 31 (~10 months)
- First renewal: next Dec 31 (full year)
- Formula: (annual fee) × (days remaining in period / 365)

## Feature Flags & Flexibility

### Admin Controls
- **Platform Admin** can:
  - Set default billing strategy (global default)
  - Override strategy per tenant
  - Offer tenants choice (self-serve billing strategy config)
- **Tenant Admin** can:
  - Configure billing strategy for their association
  - Set custom fee per official (manual override for special cases)
  - Enable/disable new official invitations (toggle)
  - Configure grace period duration
  - Choose consolidation method (individual vs. consolidated invoicing)

### Future Extensibility
- Support monthly billing (if needed for certain regions/segments)
- Discounts for multi-year commitments (e.g., 2-year → 10% off)
- Seasonal pricing (off-season discount for next season)
- Family/group plans (multiple officials from same household)

## Compliance & Audit

### Audit Trail
- Track all invitations (sent, opened, accepted, declined)
- Track all billing strategy changes (who, when, effective date, old vs. new)
- Track fee changes (per official, per association)
- Track all payments (success, failure, refunds, reversals)

### Consent & Terms
- Invitation includes association terms (if any)
- Official must accept subscription terms to join
- Versioned terms; track which version official accepted
- Records signed/timestamped for compliance

## Consequences
- **Pros**: flexible billing accommodates different business models; yearly subscription is simpler; multi-association support enables broader official networks; configurable admin controls allow future experimentation.
- **Cons**: billing logic complexity; must handle proration and multi-association aggregation carefully; mitigated by strong billing platform and clear rules.
