# ADR 0018: Platform Monetization Strategy

## Status
Accepted

## Context
Contest Schedule operates as a multi-tenant SaaS platform with diverse revenue streams from league tenants, officials associations, and payment processing. Need a comprehensive, clear, and flexible pricing model supporting both predictable subscription revenue and variable usage-based charges.

## Revenue Streams

### 1. League Tenant Subscriptions & Usage-Based Billing
**Subscription Plans (Tiered):**
- **Starter**: $99/month
  - Up to 50 games/season, 20 officials, 1 league, email support
  - Basic scheduling, officials assignment, public portal read-only
- **Pro**: $299/month
  - Up to 500 games/season, 200 officials, 5 leagues, standard support
  - Advanced scheduling, tournament management, custom fields, API access, basic analytics
- **Enterprise**: Custom pricing
  - Unlimited games/officials, multiple leagues, premium support, dedicated account manager
  - White-label branding, custom integrations, SLA guarantees, advanced reporting/webhooks

**Usage-Based Charges (Overage Fees):**
- Games over quota: $0.50/game
- Officials over quota: $1.00/official/month
- Custom fields/metadata: $10/field/month (beyond 5 included)
- API calls over rate limit: burst overage $0.001 per 1000 calls
- Storage overage (docs, videos): $0.05/GB/month over 10GB included

**Billing Cycle:**
- Monthly or annual (annual gets 15% discount)
- Pro-ration for mid-cycle changes
- Automatic renewal; dunning workflows for failed payments
- Suspension after 7 days of failed payment attempts

**Payment Methods:**
- Credit/debit cards (Visa, Mastercard, Amex) with convenience fee
- ACH bank transfer (no convenience fee)
- Digital wallets (Apple Pay, Google Pay) with convenience fee
- PayPal (optional; partner agreement)
- Manual methods (Venmo, Zelle, checks) with reconciliation workflow

**Convenience Fees:**
- Card/Wallet payments: +2.9% + $0.30 per transaction
- ACH: included (no separate fee)
- Tenant absorbs or passes to end customers (configurable)

### 2. Officials Association Fees
**Subscription Fee for Officials (Per-Official, Per-Tenant):**
- Default configurable per tenant: e.g., $8–15/official/month
- Platform retains 100% of fee (or configurable split)
- Monthly billing with proration on join/exit
- Monthly invoices sent to officials association

**Per-Official Adjustments:**
- Discounts: % or fixed amount (e.g., -$2, -10%); time-bound; stacking rules
- Surcharges: late fees, service fees ($1–5); apply on demand
- Coupons: percentage or fixed-amount; redemption tracking; expiry management
- Governance: all adjustments audit-logged with admin who applied and reason

**Officials Payment Paths:**
- Deduct from payouts: net out fee from assignment earnings (reduces what official receives)
- Direct payment: charge official's card/ACH directly (requires tokenized payment method on file)
- Invoice to association: platform invoices officials association; they collect from officials

**Default Calculation Example:**
- Official earns $100 from assignments
- Default fee: $10/month
- If deducting: official receives $90
- If direct: officials association charged $10 separately; official receives full $100

### 3. Contract Lifecycle Management & E-Signature
**Setup Fee:**
- $25–50 per contract execution (adjustable per tenant)
- Charged to officials association when contract is fully signed

**Annual Subscription Add-On (for unlimited contracts):**
- $100–300/year (configurable per tenant)
- Covers unlimited contract creation, renewals, reminders
- Alternative to per-contract pricing

**Per-Renewal Fee:**
- $15–25 per contract renewal (auto-charge on renewal date)
- Discounts available for multi-year terms (e.g., -20% for 3-year contract)

**Hybrid Model (Recommended):**
- Setup fee: $20/contract
- Annual add-on: $150/year (includes up to 10 renewals free)
- Per-renewal (if over 10): $10
- Tenant chooses subscription or pay-as-you-go per contract type

**Renewal Failure Handling:**
- If renewal fee payment fails: contract marked for manual renewal
- Reminders sent with payment retry option
- Tenant access not restricted (contracts are business agreements, not system access)

### 4. Support & SLA Tiers
**Community (Included with all plans):**
- Email support, 48h response time
- Help center access, community forum
- No SLA guarantee

**Standard (+$50/month or included in Pro/Enterprise):**
- Email + chat support, 24h response time
- Priority ticketing, dedicated support email
- 99.5% uptime SLA commitment

**Premium (+$150/month or included in Enterprise):**
- Phone + email + chat support, 2h response time
- Dedicated support specialist, proactive monitoring
- 99.9% uptime SLA, incident response playbook
- Quarterly business reviews

**Enterprise:**
- Included with Enterprise plan
- 24/7 phone + on-site support available
- 99.95% uptime SLA + uptime credits
- Dedicated success manager, custom training

### 5. Premium Add-Ons & Features
**White-Label Branding:**
- Custom domain (e.g., mycustomdomain.com instead of tenant.contestschedule.com)
- Branded emails, PDFs, invoices with tenant logo/colors
- Removal of Contest Schedule branding (footer, watermarks)
- **Cost**: $100–200/month

**Advanced Analytics & Reporting:**
- Custom dashboards beyond standard dashboards
- Advanced filters, cohort analysis, predictive insights
- Export to BI tools (Tableau, Looker, etc.)
- Scheduled report delivery (daily/weekly/monthly)
- **Cost**: $75/month or per-report API access

**Custom Integrations & Webhooks:**
- Webhook delivery to external systems (CRM, ticketing, slack, etc.)
- Custom API endpoints tailored to tenant workflows
- Bulk import/export tools (CSV, XML, custom format)
- **Cost**: $50/month + $500 setup fee (non-refundable)

**Enhanced Security & Compliance:**
- SSO/SAML integration setup and management
- Dedicated encryption keys per tenant (BYOK)
- Compliance audit preparation (SOC2, HIPAA, GDPR attestations)
- **Cost**: $200/month

**Advanced Scheduling & AI-Driven Assignment:**
- AI official recommendation engine (machine learning-based matching)
- Constraint solving for complex scheduling (venue conflicts, travel optimization)
- Predictive no-show flagging
- **Cost**: $150/month

### 6. Data & Reporting Premium
**Data Export & Portability:**
- Unlimited data exports (CSV, JSON) included in all plans
- SQL database export (for custom analysis): +$50/month
- Real-time data API with webhooks: included in Pro+ (Standard support)

**Premium Report Templates:**
- Custom report designer (drag-and-drop)
- Financial reports (revenue, cost per game, ROI by official)
- Compliance reports (audit trails, data retention, GDPR export)
- **Cost**: $30 per custom report template/month

**Advanced Forecasting:**
- Demand forecasting (game volume by date/division)
- Churn prediction and retention recommendations
- Revenue forecasting and scenario modeling
- **Cost**: $200/month

### 7. Mobile App Premium Features
**Base Offering (Included):**
- Officials app with assignment viewing, confirmation, earnings
- Officials admin app with basic roster and payout tracking
- Public portal app (read-only schedules, standings)

**Premium Mobile Features:**
- Offline mode: view/manage assignments, sync when reconnected
- Push notifications: real-time game updates, confirmation reminders
- Location services: GPS navigation to venues, travel distance estimation
- Biometric auth: fingerprint or face ID for quick login
- **Cost**: $25/official/month (charged to officials association)

### 8. Marketplace & Partner Ecosystem
**Third-Party App Store (Future):**
- Plugin marketplace for integrations (video streaming, stat tracking, social media integration, etc.)
- Revenue split: 70% developer, 30% platform
- Platform takes transaction fee on in-app purchases (15%)
- Featured app listings: $500/month or revenue share

**Partner Program:**
- Referral commissions: 20% of first-year MRR for referred customers
- Co-marketing opportunities: joint webinars, case studies
- Channel partner support: dedicated technical liaison, margin discounts

### 9. Professional Services (Optional Revenue)
**Implementation & Setup Services:**
- Tenant onboarding consultation: $1,000–5,000 (one-time)
- Data migration from legacy systems: $500–2,000 per tenant
- Custom workflow configuration: $200/hour
- Staff training: $1,500 per day on-site or virtual

**Consulting:**
- Scheduling optimization analysis: $2,000–10,000 per engagement
- Business process consulting: $2,500/day
- Compliance & audit preparation: $3,000–10,000

## Pricing Model Philosophy

### Core Principles:
1. **Transparency**: all fees clearly disclosed upfront; no hidden charges
2. **Flexibility**: plans customizable; mix-and-match add-ons
3. **Fairness**: free tier for small leagues (< 20 games/season); no surprise overage bills
4. **Scalability**: per-usage pricing scales with growth; plans encourage expansion
5. **Predictability**: subscription base predictable; usage swings smoothed via caps/generous allotments

### Pricing Tiers Decision Rules:
- **Starter**: target small recreational leagues, youth leagues, startup officials groups
- **Pro**: mid-size leagues, regional associations, small professional leagues
- **Enterprise**: large multi-state/multi-sport operators, professional leagues, federations
- **Overage**: encourage plan upgrades but allow burst usage without hard failures

### Revenue Mix Target (Year 1→3):
- Subscription revenue: 70% (recurring, predictable)
- Usage overages: 10%
- Contract/officials fees: 8%
- Premium add-ons & support: 8%
- Payment processing margins: 3%
- Other (professional services, marketplace): 1%

## Billing & Collections

### Invoicing:
- Monthly invoices generated on billing date; auto-charged to default payment method
- Failed payment: retry 3 times over 7 days with exponential backoff
- Dunning workflow: day 1 soft notice, day 3 urgency email, day 7 suspension warning
- After day 7: suspend tenant access; collections escalation to support/finance

### Refunds & Credits:
- Pro-rata refunds for mid-cycle cancellations (30-day notice required)
- Credits for service issues: support team authorized to issue credits up to 1 month service value
- No refund for usage overages (best-effort notice and plan upgrade option)

### Tax Handling:
- Tenant tax ID collection during onboarding
- Auto-calculate tax based on billing address (sales tax, VAT, GST)
- Separate tax line item on invoices
- Tax-exempt status supported (non-profit with valid EIN/documentation)

## Upsell & Retention Strategies

### Usage-Based Upsells:
- Monitor approaching quotas; email notification at 80% of limit
- "Upgrade" CTA in dashboard when quota exceeded
- Offer plan upgrade discount (e.g., "upgrade to Pro, save 20% on first month")

### Expansion Revenue:
- Cross-sell: league using basic scheduling → offer tournament management add-on
- Bundle discounts: multi-year contracts or buying 2+ add-ons together
- Seasonal offers: off-season discounts for next-season early signup

### Churn Prevention:
- NPS surveys at 30d, 90d, 180d; follow up on low scores
- Win-back campaigns for cancelled tenants (offer 50% off for 3 months to return)
- Loyalty discounts: long-term customers (3+ years) get 10% annual discount

## Metrics & Reporting

### Financial KPIs:
- MRR (Monthly Recurring Revenue): subscription base
- ARR (Annual Recurring Revenue): MRR × 12
- ARPU (Average Revenue Per User/Tenant): total revenue / # tenants
- LTV (Lifetime Value): average revenue per tenant over lifetime
- CAC (Customer Acquisition Cost): marketing + sales spend / # new customers
- Churn rate: % of tenants lost per month
- Expansion revenue: revenue from existing customers (upsells + add-ons)

### Dashboards:
- **Finance dashboard**: MRR/ARR trends, churn, expansion, CAC payback period
- **Tenant dashboard** (for tenants): invoice history, usage tracking, billing forecast
- **Platform dashboard**: per-tenant revenue, usage patterns, quota compliance

## Consequences
- **Pros**: multiple revenue streams reduce customer concentration risk; tiered pricing allows market segmentation; usage pricing rewards growth; premium features drive upsells.
- **Cons**: complexity in billing logic and tax handling; mitigated by strong billing platform (Stripe, Zuora) and clear communication.
