# ADR 0010: Notifications and Messaging (Email/SMS, Preferences, Overrides)

## Status
Accepted

## Context
We must notify officials, leagues, and the public about changes (e.g., game updates) via email and SMS. Users should control how and when they receive messages, while the owner can override preferences for urgent cases.

## Decision
Create a Notification Service that consumes domain events and delivers messages via AWS SES (email) and AWS Pinpoint/SNS or Twilio (SMS). Implement per-user preferences (channels, timing, topics) and an owner override workflow with justification and audit.

## Architecture
- Event-driven: domain services publish events (e.g., `game.updated`), Notification Service filters, batches, and sends.
- Providers: Email via SES; SMS via Pinpoint/SNS or Twilio; templating with localization and tenant branding.
- Preferences: stored per user; include channels (email/SMS), frequency (real-time, digest), quiet hours, topics/subscriptions.
- Overrides: owner override requires reason, scope (tenants/users/topics), time-bound window; audit entries created.

## Data Models
- `UserPreference(userId, channels, frequency, quietHours, topics)`
- `NotificationTemplate(id, channel, locale, brandVariant)`
- `NotificationEvent(type, payload, tenantId, userId?, context)`
- `OverridePolicy(id, reason, scope, startsAt, endsAt, createdBy)`
- `DeliveryReceipt(id, channel, status, providerRef, latency)`

## Compliance & Deliverability
- CAN-SPAM/TCPA compliance; opt-in/out management; suppression lists.
- Rate limits per tenant/app; retries/backoff; sender identities and DKIM/SPF.
- Telemetry: record requests, deliveries, failures; dashboards for deliverability.

## Consequences
- Pros: user-centric messaging with administrative control; scalable and auditable.
- Cons: complexity of preferences and overrides; mitigated via clear UI and policy controls.
