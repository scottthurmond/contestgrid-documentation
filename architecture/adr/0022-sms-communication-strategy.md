# ADR 0022: SMS Communication Strategy

## Status
Accepted

## Context
Contest Schedule needs to support SMS for high-engagement user interactions: tenant onboarding invites, official availability confirmations, payment/invoice reminders, game assignments, and emergency notifications. SMS has higher open rates (~98%) than email (~20–30%) and is critical for time-sensitive communications (game schedules, payment deadlines).

## Decision
Use **AWS Pinpoint** as primary SMS provider with **SNS** as fallback for cost optimization. Implement opt-in SMS preferences per user, respect STOP/HELP commands (compliance), throttle message frequency, and track delivery/read events for analytics.

## SMS Use Cases & Routing

### Tier 1: Critical (Transactional, Required)
**Purpose**: security-sensitive operations that legally must notify via SMS

- **Tenant Onboarding**: SMS invite with verification code (Step 1 of flow)
- **Payment Confirmation**: invoice issued, payment received, subscription renewed
- **Emergency Alerts**: contract expiration, account suspension, compliance issues
- **Account Security**: login verification (MFA), password reset, unusual activity

**Provider**: AWS Pinpoint (higher deliverability SLA)
**Delivery SLA**: <5 seconds
**Retry Policy**: 3 retries with exponential backoff (1min, 5min, 15min)

### Tier 2: High-Value (Operational, Opt-In)
**Purpose**: time-sensitive operational notifications users want immediate updates for

- **Game Assignments**: official assigned to game (accepts/declines via SMS reply or link)
- **Availability Confirmations**: request for official availability (respond yes/no)
- **Payment Reminders**: invoice due in 7 days, subscription renews in 30 days
- **Schedule Changes**: game rescheduled, venue changed, assignment cancelled

**Provider**: AWS Pinpoint (preferred) or SNS (cost optimization)
**Opt-In**: user must enable SMS notifications; enable by default for admins, officials can opt-in
**Delivery SLA**: <10 seconds
**Throttle**: max 3 messages per day per user (prevent fatigue)

### Tier 2: Low-Value (Convenience, Opt-In)
**Purpose**: helpful but non-critical notifications users can disable

- **Weekly Summaries**: games assigned, upcoming schedule, earnings
- **Event Reminders**: tournament registration opening, application deadline
- **Marketing**: platform feature announcements, promotional offers
- **Feedback Requests**: post-game surveys, feature suggestions

**Provider**: AWS Pinpoint (managed SMS)
**Opt-In**: explicitly enabled by user, easy to unsubscribe
**Frequency**: max 1 per week per user
**Throttle**: cluster promotional SMSes (e.g., 1 message/week on Mondays)

## Architecture

### SMS Workflow
```
Event (OrderCreated, GameAssigned, etc.)
  ↓
EventBridge Rule (filters by event type)
  ↓
Lambda (SMS Dispatcher)
  ├─ Check user SMS preferences (enabled? blocked? opted-in?)
  ├─ Compile message template (context + personalization)
  ├─ Rate-limit check (throttle rules)
  ├─ Call Pinpoint SendSMSMessage
  ├─ Log SmsEvent (user, timestamp, status, message_id)
  └─ Handle errors (retry/escalate)
  ↓
Pinpoint (SMS Gateway)
  ├─ Carrier validation, number format check
  ├─ Send to carrier
  ├─ Receive delivery/bounce callbacks
  └─ Update SmsEvent status (sent/delivered/failed/bounced)
  ↓
Analytics Pipeline (CloudWatch/OpenSearch)
  ├─ Delivery rates, bounce rates, cost tracking
  └─ Dashboard for ops team
```

### AWS Pinpoint Configuration
**Project**: Contest Schedule SMS
**SMS Channel**: enabled for all phone numbers
**Origination Identity**: Sender ID (if carrier supports) or Short Code (10DLC in US)
  - Sender ID: "ContestSch" (11 chars, max for alphanumeric)
  - Cost: $0.0075/SMS (US domestic, SMS tier)
  - Compliance: 10DLC registration (required for US, ~$10/month per number)

**Message Template Library** (Pinpoint Console):
- `tenant-invite-sms`: "Hi {{firstName}}, join {{organizationName}}! Verify: {{verificationCode}} (valid 10 min) {{shortUrl}}"
- `game-assignment-sms`: "You're assigned to {{gameName}} at {{venue}} on {{date}} at {{time}}. Reply CONFIRM or visit {{shortUrl}}"
- `availability-request-sms`: "{{organizationName}} needs your availability for {{dates}}. Reply YES/NO or {{shortUrl}}"
- `payment-reminder-sms`: "Invoice #{{invoiceId}} due {{dueDate}}. Amount: ${{amount}}. Pay now: {{shortUrl}}"
- `subscription-renewal-sms`: "Your {{organizationName}} subscription renews on {{renewalDate}}. Manage: {{shortUrl}}"

### SMS Preferences Data Model
```
UserSmsPreference {
  id, userId, tenantId
  phoneNumber, phoneNumberVerifiedAt
  smsEnabled: boolean (default false, opt-in)
  smsOptInAt, smsOptOutAt
  
  -- Preference categories per use case
  criticalAlertsEnabled: boolean (default true if smsEnabled)
  gameAssignmentsEnabled: boolean (default true if smsEnabled)
  paymentRemindersEnabled: boolean (default true if smsEnabled)
  scheduleChangesEnabled: boolean (default true if smsEnabled)
  weeklyDigestEnabled: boolean (default false, explicit opt-in)
  promotionalEnabled: boolean (default false, explicit opt-in)
  
  -- Throttling
  lastSmsSentAt, dailySmsCount, lastPromotionalSmsAt
  
  createdAt, updatedAt
}

SmsEvent {
  id, tenantId, userId, eventType, phoneNumber
  messageId, templateName, templateData (JSON: firstName, organizationName, etc.)
  deliveryStatus: 'pending'|'sent'|'delivered'|'failed'|'bounced'|'opted_out'
  bounceType: 'permanent'|'temporary'|null
  bounceCode: string (carrier reason, e.g., "UNDELIVERABLE")
  retryCount, nextRetryAt
  sentAt, deliveredAt, expiresAt
  cost: float ($0.0075 per SMS, billable to tenant account)
  createdAt, updatedAt
}
```

## Compliance & User Control

### TCPA & GDPR Compliance
- **Explicit Opt-In**: users must affirmatively enable SMS
  - Exception: Tier 1 Critical (transactional) cannot be opted out
  - Docs: "By enabling SMS, you consent to receive messages per our privacy policy"
- **STOP Command**: if user replies "STOP", mark user as `smsOptedOut`
  - Auto-reply: "You've been unsubscribed. Reply HELP for support"
  - Persist opt-out across all tenants they're associated with
- **HELP Command**: if user replies "HELP", send support contact number
- **Opt-Out Dashboard**: user can toggle SMS preferences anytime in account settings
- **Data Retention**: delete SmsEvent records after 13 months (GDPR + compliance window)
- **International**: respect local SMS laws; disable SMS for high-spam regions if needed

### Message Audit Trail
- All SMS sent/delivered/failed logged with user consent audit trail
- Supports regulatory inquiries (TCPA, GDPR data access requests)
- Immutable record: timestamp, user ID, message content, status, cost

## Cost Optimization

### Pricing Model (AWS Pinpoint)
- **Inbound SMS**: $0.0075 per message (carrier-dependent, typically higher for inbound)
- **Outbound SMS**: $0.0075 per message (US domestic)
- **Short Codes**: $1 per day + per SMS rate (high volume only)
- **10DLC**: $10/month per number for US compliance + per SMS rate

### Cost Projection (First Year)
- **MVP (1K users, 500 tenants)**:
  - Avg 2 SMSes per user/month (onboarding, payment reminders): 24K SMSes/year
  - Cost: ~$180/year + $120 10DLC compliance = ~$300/year
- **Growth (10K users)**:
  - Avg 3 SMSes per user/month: 360K SMSes/year
  - Cost: ~$2.7K/year + $120 compliance = ~$2.8K/year
- **Scale (100K+ users)**:
  - Avg 5 SMSes per user/month: 6M SMSes/year
  - Cost: ~$45K/year + $120 compliance = ~$45K/year

### Optimization Tactics
- Batch low-urgency SMSes (e.g., weekly digest on Monday 9am)
- Use dynamic short URLs (Bitly integration) to save characters
- Compress templates to fit in one SMS (160 chars) where possible
- Monitor bounce rates; remove bounced numbers from future sends
- A/B test message length/tone; longer messages = multi-part SMS = 2x cost

## Integration Points

### Event-Driven Triggers
- **TenantCreated**: initiate SMS invite workflow
- **GameAssigned**: notify official via SMS (if enabled)
- **InvoiceIssued**: send payment details and due date
- **PaymentFailed**: escalation SMS to billing contact
- **SubscriptionRenewalDue**: reminder (30d, 7d, 1d before)
- **ContractExpiring**: urgent notification (14d, 7d, 1d before)
- **AvailabilityRequested**: send request SMS, link to reply form

### Notification Preferences Hub
- Unified SMS/Email/Push notification preferences (see ADR-0010)
- User can set communication frequency per category
- Admin can set tenant-level SMS defaults (enable/disable by user role)
- Audit: track all preference changes

## Monitoring & Analytics

### CloudWatch Metrics
- SMSes sent, delivered, failed, bounced (daily, hourly)
- Bounce rate (%), delivery rate (%)
- Cost per SMS, total monthly cost
- Top failure reasons (carrier rejections, invalid number, etc.)
- SMS opt-out rate (% users unsubscribing)

### Alerts
- Bounce rate >5% (possible data quality issue)
- Delivery rate <90% (carrier issue or configuration problem)
- Monthly cost spike >20% (traffic anomaly or abuse)
- High opt-out rate >2% in week (message fatigue)

### Dashboard (Ops Team)
- Daily SMS volume, delivery metrics, cost tracker
- Top SMS event types (game assignments, payments, etc.)
- User engagement (delivery → click rate on SMS links)
- Tenant SMS quota usage (if enforced)

## Future Enhancements

### 2-Way SMS Conversations
- Official replies to game assignment: "CONFIRM", "DECLINE", "MAYBE"
- Parse responses → auto-update assignment status
- Availability replies: "YES", "NO", "MAYBE" → update availability calendar
- Requires Pinpoint 2-way SMS channel setup + Lambda parser

### SMS-to-WhatsApp/Messenger Migration
- Pinpoint supports WhatsApp messages (lower cost, higher features)
- Offer users choice: SMS, WhatsApp, or email
- WhatsApp cost: ~$0.01–0.04 per message (lower than SMS, more reliable in some regions)

### Short Codes & Keyword Campaigns
- High-volume use case (100K+ SMSes/month): apply for dedicated short code
- Keyword routing: "Text AVAILABLE to 55555", "Text PAYMENT to 55555"
- Cost: ~$500–1K/month but allows higher throughput, branded experience
- Deferred to Phase 2+ (MVP uses 10DLC)

## Consequences
- **Pros**: SMS reaches high-engagement users; fits time-sensitive notifications; opt-in model respects privacy; event-driven architecture keeps SMS coupled to business logic; Pinpoint handles compliance (TCPA logging, carrier validation)
- **Cons**: SMS costs scale with volume; carrier delivery not 100% guaranteed; 160-char limit requires careful templating; TCPA/international compliance complexity
