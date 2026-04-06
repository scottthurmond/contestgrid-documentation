# ADR 0016: Tenant Onboarding & Provisioning Workflow

## Status
Accepted

## Context
Tenants (league/officials organizations) need a streamlined onboarding process that collects required information, processes payment upfront, sets up authentication/SSO, and provisions the tenant environment with sensible defaults.

## Decision
## Decision
Implement a multi-step onboarding workflow supporting four initiation methods (prioritized): Self-Service (organic), Email, SMS, and QR Code. Self-service via public website "Join Now" button is primary channel; email/SMS/QR drive traffic to public site. Each method has appropriate security verification, expiry windows, and use cases. Branding is optional (use defaults); SSO/login setup is mandatory but updatable post-onboarding. Design for future flexibility in authentication methods.

## Initiation Methods (Priority Order)

### Priority 1: Self-Service (Public Website Join Button)
**Use Case:** Organic discovery, word-of-mouth, search traffic, paid ads; tenants self-initiate without pre-existing invite

**Workflow:**
- Prospect visits Contest Schedule public website (contestsch.com)
- Public landing page prominently displays "Join Now", "Get Started", or "Request Demo" button
- Prospect clicks button → enters self-service onboarding flow (Step 1: Information Collection)
- No token verification needed (unlike admin-to-admin invites)
- First page collects: organization name, primary admin email, phone number, timezone
- Prospect proceeds through full onboarding (info collection → payment → provisioning → go-live)
- Attribution source: `utm_source=organic|paid_search|social_referral|etc` tracked via landing page parameters
- Audit trail: self-initiated, first page loaded, timestamp

**Landing Page Design:**
- Hero section: platform value proposition, key features
- "Join Now" CTA button (prominent, above fold)
- Pricing tiers visible (Starter, Pro, Enterprise)
- Use cases / industry testimonials
- FAQ section
- Option to "Request Demo" (alternative path, lead capture)

**Pros:** self-directed, lowest friction, captures highly motivated prospects, no permission needed, scalable without manual outreach
**Cons:** requires marketing/SEO investment to drive traffic, lower volume than outbound campaigns initially

**Why Priority 1:**
- Scalable: no manual outreach per prospect
- Lowest cost per acquisition (no SMS/email/print costs)
- Highest intent: prospects actively seeking solution
- No compliance issues (TCPA, CAN-SPAM, etc.)

### Priority 2: Email Campaign (Self-Service Redirect)
**Use Case:** Traditional email marketing, nurture sequences, follow-ups; email drives traffic to public website

**Workflow:**
- Sales/marketing team sends email to prospect
- Email contains personalized message, CTA button ("Join Now"), and link to public website
- Link includes campaign tracking: `?utm_source=email&campaign=spring2025&email_id=abc123`
- Prospect clicks link → lands on Contest Schedule public landing page
- Public page shows "Join Now" button
- Prospect clicks "Join Now" → initiates self-service onboarding
- Email delivery tracking (opens, clicks) via AWS SES
- Audit trail: email sent, open timestamp, click timestamp, campaign attribution

**Provider:** AWS SES (transactional/marketing email)
**Cost:** ~$0.10 per 1,000 emails
**Delivery SLA:** <5 seconds
**Link Validity:** email can be saved; link valid indefinitely (redirect URL maintained)
**Retry Policy:** auto-retry on bounce; suppress future emails to invalid addresses

**Pros:** low cost, familiar channel, longer shelf-life, no regulatory friction, scales easily
**Cons:** lower engagement rate (~20–30%), may land in spam, no identity pre-verification

**Why Priority 2:**
- Extremely low cost (~$0.0001/email vs. $0.0075/SMS)
- Familiar, professional channel
- Easy to scale (send 10K emails same effort as 100)
- Long shelf-life (prospect can revisit email days later)

### Priority 3: SMS Campaign (Self-Service Redirect)
**Use Case:** Marketing campaigns, outreach to target prospects; SMS drives traffic to public website where tenants self-initiate

**Workflow:**
- Sales/marketing team sends SMS to prospect's phone number
- SMS contains personalized message and short URL pointing to **public website** (e.g., contestsch.com)
- SMS includes campaign tracking parameter: `?utm_source=sms&campaign=spring2025`
- Prospect clicks link → lands on Contest Schedule public landing page (not onboarding form)
- Public page has prominent "Join Now" or "Get Started" button
- Prospect clicks "Join Now" → initiates self-service onboarding
- SMS click tracking via short URL service (Bitly, AWS)
- Audit trail: SMS sent, click timestamp, campaign source

**Provider:** AWS Pinpoint (primary) or SNS (fallback)
**Cost:** ~$0.0075 per SMS (US domestic)
**Delivery SLA:** <5 seconds
**Link Validity:** SMS has no expiry; campaign can be deactivated anytime
**Retry Policy:** 3 retries with backoff; if fails, offer email alternative

**Pros:** high engagement (~98% open rate), immediate delivery, drives awareness to platform, prospect controls onboarding timing
**Cons:** higher cost (75x more than email), requires valid phone number, TCPA compliance, carrier rate-limiting

**Why Priority 3:**
- Higher cost per contact vs. email
- TCPA compliance overhead
- Carrier rate-limiting can slow campaigns
- Use for high-value prospects or time-sensitive campaigns only

### Priority 4: QR Code Campaign (Self-Service Redirect)
**Use Case:** In-person events, printed materials, conference booths, posters, business cards; QR drives traffic to public website

**Workflow:**
- Sales/marketing team generates QR code for campaign (e.g., "SoccerCon2025")
- QR code encodes short URL pointing to **public website** with campaign tracking: `https://contestsch.com?utm_source=qr&campaign=soccercon2025`
- QR code printed on: event materials, posters, business cards, signage, follow-up letters
- Prospect scans QR → redirected to Contest Schedule public landing page
- Public page highlights "Join Now" call-to-action
- Prospect clicks "Join Now" → initiates self-service onboarding
- QR scans tracked: device, IP, timestamp, country, device type, source attribution
- QR code can be deactivated anytime; redirects still work (via short URL service)
- Audit trail: scan timestamp, device info, campaign attribution

**QR Code Hosting:** Use AWS Shortened URL + redirect, or Bitly, or custom short URL service
- QR encodes: `https://cs.co/soccercon25` → redirects to `https://contestsch.com?utm_source=qr&campaign=soccercon2025`
- QR Code Size: v7–10 (suitable for print, ~200–500 bytes)

**Campaign Tracking:** QrCampaign entity
```
QrCampaign {
  id, campaignName (e.g., "SoccerCon2025"), createdBy
  shortUrl (e.g., "cs.co/soccercon25"), targetUrl (public landing page + params)
  qrCodeImageUrl (image data for print/download)
  
  -- Campaign lifecycle
  launchedAt, expiresAt (optional)
  status: 'active'|'paused'|'archived'
  
  -- Analytics
  scans: [ { id, timestamp, ip, country, deviceType, userAgent, clicked } ]
  totalScans, uniqueScans (deduplicated by device), clickRate
  
  createdAt, updatedAt
}
```

**Token Expiry:** QR code can link to public website indefinitely (no token expiry); only the short URL can be deactivated
**Scan Limit:** optional (unlimited scans typical; can cap at X scans/day for rate-limit abuse)
**Print Validity:** no expiry; printed QRs remain scannable as long as redirect active

**Pros:** memorable, offline-scannable, highly trackable, modern, great for events/print marketing, zero friction on prospect side
**Cons:** requires phone camera, print production cost, QR code design considerations (contrast, size), limited reach (event-specific)

**Why Priority 4:**
- Highest upfront cost (design + print)
- Limited reach (event attendees only)
- Scan rates vary widely (5–20% of people who see QR)
- Best for supplementary touchpoints, not primary acquisition channel

---

**Summary of Initiation Methods (Priority Order):**
| Priority | Method | Prospect Action | Flow | Best For | Cost |
|----------|--------|-----------------|------|----------|------|
| **1** | **Self-Service** | Discover site → click "Join Now" button | Public Landing → Self-Serve Onboarding | Organic/word-of-mouth/paid ads | None |
| **2** | **Email Campaign** | Click email link → land on public site → click "Join Now" | Email → Public Landing → Self-Serve Onboarding | Traditional marketing, nurture | $0.0001/email |
| **3** | **SMS Campaign** | Click SMS link → land on public site → click "Join Now" | SMS → Public Landing → Self-Serve Onboarding | Targeted outreach, high engagement | $0.0075/SMS |
| **4** | **QR Code Campaign** | Scan QR → land on public site → click "Join Now" | QR Scan → Public Landing → Self-Serve Onboarding | Events, print, in-person | Print cost + QR tracking |
| **-** | **Admin Invite** (Email/SMS) | Receive invite link → click → onboarding pre-filled | Email/SMS Token → Direct to Onboarding | Used by tenants to invite other admins | $0.0075/SMS or $0.0001/email |

---

### Data Model (Updated)

**TenantInvitation** (used for admin-to-admin invites only):
```
TenantInvitation {
  id, tenantId, email?, phoneNumber?
  
  -- Invitation method & channel
  invitationMethod: 'sms'|'email'|'qr_code'
  
  -- SMS specifics
  smsVerificationCode?, smsVerificationCodeExpiresAt?
  verifiedPhoneAt?
  
  -- Email/QR specifics
  token (JWT or signed UUID), tokenExpiresAt
  tokenVerifiedAt?
  
  -- QR specifics
  qrCampaignId?
  
  -- Metadata
  role: 'admin'|'billing'|'support' (for admin-to-admin invites)
  status: 'sent'|'opened'|'verified'|'accepted'|'expired'|'declined'
  invitedBy (admin user ID), invitedAt
  expiresAt
  
  -- Tracking
  sentAt, openedAt, clickedAt, acceptedAt
  lastReminderSentAt, reminderCount
}

SmsCampaign {
  id, campaignName, purpose: 'awareness'|'conversion'|'retention'
  shortUrl, targetUrl (public landing page)
  phoneNumberCount, sentAt, deliveredCount, failedCount, openedCount (clicks)
  cost, conversionRate (phones → onboarding started)
  createdBy, createdAt, updatedAt
}

EmailCampaign {
  id, campaignName, purpose: 'awareness'|'conversion'|'retention'
  emailCount, sentAt, deliveredCount, bounceCount, openCount, clickCount
  cost, conversionRate (emails → onboarding started)
  createdBy, createdAt, updatedAt
}

QrCampaign {
  id, campaignName, purpose: 'event'|'print'|'digital'
  shortUrl, targetUrl (public landing page)
  qrCodeImageUrl, qrCodeText
  
  -- Analytics
  scans: [ { id, timestamp, ip, country, deviceType, userAgent, clicked } ]
  totalScans, uniqueScans, clickRate
  launchedAt, expiresAt (optional)
  status: 'active'|'paused'|'archived'
  
  cost (design/print if physical), conversionRate (scans → onboarding started)
  createdBy, createdAt, updatedAt
}

TenantSignup {
  id, source: 'sms_campaign'|'email_campaign'|'qr_campaign'|'organic'|'admin_invite'
  campaignId? (reference to SmsCampaign, EmailCampaign, or QrCampaign)
  organizationName, adminEmail, adminPhone, timezone
  
  -- Attribution
  utmSource, utmCampaign, utmMedium, referralCode?
  
  -- Progress tracking
  step: 1-8 (see onboarding steps below)
  status: 'in_progress'|'completed'|'abandoned'
  startedAt, completedAt
  
  createdAt, updatedAt
}
```

## Onboarding Steps

### Step 1: Information Collection (Post-Invite Verification)
**Organization Details:**
- Organization ID, name, abbreviation
- Physical address (billing, legal, operational purposes)
- Timezone, locale/language preference
- Industry/sport type, organization size estimate
- Non-profit status (for tax/feature eligibility)

**Contacts:**
- Primary admin: name, email, phone
- Billing contact: name, email, phone (can be same person)
- Support email, emergency contact

**Technical:**
- Requested subdomain (validate uniqueness, DNS)
- Data residency requirement (US, EU, specific region)

### Step 2: Billing & Legal
- Billing address (can match physical address or differ)
- Tax ID/VAT number (if applicable)
- Currency preference, billing cycle (monthly/annual)
- Invoice delivery preferences (email, portal, both)
- DPA acceptance (GDPR compliance)
- ToS acceptance (versioned, dated, timestamped)
- Initial payment method (card/ACH; tokenized via provider)

### Step 3: Payment Processing
- Process payment via provider (Stripe/Adyen) before granting access
- Payment confirmation → receipt issued
- Audit: record payment event with amount, plan tier, timestamp
- Failure handling: retry logic, support escalation, clear error messaging

### Step 4: Authentication & SSO Setup
**Flexible Design (support multiple auth methods):**
- Default: Cognito User Pool login (email/password or SSO federation)
- Future: support SAML, OIDC custom providers, or API-key-only tenants
- Tenant can configure later: SAML metadata, OIDC issuer/client, API keys

**Onboarding Setup:**
- Create Cognito user group for tenant
- Generate initial admin user invite (email with link + temp password option)
- Admin sets up preferred authentication method
- Configure MFA settings (default: TOTP + SMS backup)
- Optionally set up SSO federation (Google, Microsoft, custom SAML)

### Step 5: Environment Provisioning
**Database Setup (Shared Database with Row-Level Isolation):**
- Create tenant record in shared Aurora PostgreSQL database (see ADR-0021)
- All tenants share same database instance with `tenant_id` isolation
- No separate schema/namespace per tenant (reduces operational complexity)
- Row-Level Security (RLS) policies enforce tenant boundaries automatically
- Add `tenant_id` to all tenant-scoped tables (leagues, officials, games, etc.)
- Simpler operations: single backup, single migration, single monitoring dashboard

**Storage & CDN:**
- Provision S3 bucket prefix for tenant assets: `s3://contest-assets/{tenant_id}/`
- Subfolders: `/logos`, `/documents`, `/contracts`, `/exports`
- Set up CloudFront distribution with tenant-specific URL pattern (if custom domain)

**API & Integration Setup:**
- Generate API keys for tenant apps (if using API-based access)
- Configure webhooks endpoint (optional, for integrations with external systems)
- Apply feature flags per plan tier (e.g., advanced analytics, white-label, API access)
- Set usage quotas: max games/month, max officials, API rate limits (enforced by API Gateway)

**Tenant Isolation Verification:**
- Run smoke tests: ensure tenant cannot access other tenant's data
- Verify RLS policies active on all tables
- Test subdomain routing: `{subdomain}.contestsch.com` → correct tenant context

### Step 6: Branding & Customization (Optional)
- Offer upload of logo, favicon, colors
- Provide defaults if skipped (use platform design system)
- Store in S3 with versioned URLs
- Apply via CSS variables at runtime
- Can be updated anytime post-onboarding via settings

### Step 7: Initial Admin Setup
- Confirm admin email (verify ownership)
- Create initial admin user account in Cognito
- Add secondary admins if needed
- Grant roles: tenant-admin, tenant-billing (configurable)
- Send welcome email with setup guide, support contacts, next steps

### Step 8: Go-Live
- Mark tenant status as `active`
- Enable portal access and API access
- Provide onboarding checklist (add teams, officials, schedule first game)
- Assign support contact / onboarding specialist
- Schedule follow-up (post-go-live QA, feedback)

## Data Model
```
Tenant {
  id, name, abbreviation
  organizationId, status: 'invited'|'verified'|'provisioned'|'active'|'suspended'
  physicalAddress, billingAddress
  timezone, locale, currency
  industryType, organizationSize, nonProfitStatus
  primaryAdminId, billingContactId, supportEmail, emergencyContact
  subdomain, customDomain?, dataResidency
  planTier, subscriptionStartDate, renewalDate, contractTermMonths
  paymentMethodId (tokenized), billingCycle: 'monthly'|'annual'
  brandingLogoUrl?, brandingPrimaryColor?, brandingSecondaryColor?
  cognitoUserPoolId, cognitoUserGroupId
  apiKeyIds []
  webhookEndpoint?
  dpaAcceptedAt, tosAcceptedAt (versioned), tosVersion
  createdAt, updatedAt, activatedAt
  provisioningStatus: 'pending'|'complete'
  provisioningErrors []
}

TenantAudit {
  id, tenantId, userId, action: 'created'|'verified'|'payment_processed'|'provisioned'|'activated'
  details {}, timestamp
}

TenantInvitation {
  id, tenantId, email, role: 'admin'|'billing'|'support'
  token, expiresAt, status: 'sent'|'opened'|'accepted'|'expired'
  invitedAt, acceptedAt
}
```

## Workflow States & Transitions
1. **invited** → admin invited, waiting for email verification
2. **verified** → email confirmed, payment info entered
3. **provisioned** → payment processed, environment created, awaiting activation
4. **active** → admin confirmed, SSO set up, tenant can use platform
5. **suspended** → payment failed, contract expired, or manual admin action
6. **deleted** → offboarded, data exported and purged per policy

Resend invitations: available until expiry (7 days default); notify support if overdue.

## SSO & Authentication Flexibility
- Initial setup: Cognito-hosted UI with email/password or federated login options.
- Post-onboarding updates: tenant admin can reconfigure via settings without re-onboarding.
- Support for future auth methods: inject auth provider interface; config-driven selection.
- Session policies: defined per tenant or plan tier (duration, idle timeout, MFA enforcement, device trust).

## Branding & Defaults
- If tenant skips branding: use platform design system tokens.
- Logo fallback: platform logo or initials badge.
- Color fallback: platform primary/secondary/accent colors.
- Update anytime: branding settings in tenant admin portal.
- Validation: enforce contrast ratios (WCAG AA), reserved semantic colors.

## Error Handling & Escalation
- Validation errors: clear feedback, inline guidance, retry.
- Payment failures: retry with exponential backoff; escalate after 3 failures.
- Provisioning errors: log and notify support; block tenant activation; include detail in UI.
- Audit: all errors, retries, and escalations logged with context.

## Consequences
- Pros: streamlined onboarding, upfront commitment (payment), clear role separation, flexible auth for future needs.
- Cons: multi-step process can be long; mitigated by clear UX, progress indicator, support help.
