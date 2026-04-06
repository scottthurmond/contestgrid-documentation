# ADR 0017: Contract Lifecycle Management & E-Signature

## Status
Accepted

## Context
Sports associations (leagues) and officials associations need to execute binding agreements (service agreements, liability waivers, partnership contracts). Platform facilitates contract creation, e-signature via DocuSign, renewal reminders, and expiration management. Officials associations pay a fee for this managed workflow.

## Decision
Implement a contract management system with templated/custom contracts, e-signature integration (DocuSign), automated renewal/expiration tracking, and tiered fee models. Support flexibility for future extensibility (other e-sign providers, contract management systems).

## Contract Parties & Scope
- Primary use case: League ↔ Officials Association service agreement (recurring).
- Secondary: League ↔ Vendor, Officials Association ↔ Platform, Custom bilateral agreements.
- Multi-party: support contracts involving 2+ leagues or official groups (e.g., consortium agreement).
- Contract versioning: track all versions; signatories can reference specific version.

## Contract Lifecycle

### 1. Template Management
- **Platform templates**: pre-built templates for common contracts (official assignment agreement, liability waiver, partnership terms).
- **Custom templates**: league admins can upload custom contract templates (Word, PDF).
- **Template variables**: support template variables (e.g., `{{leagueName}}`, `{{effectiveDate}}`, `{{term}}`, `{{renewal}}`).
- **Tenant branding**: contracts auto-populate with league/officials association branding (logo, colors, contact info).

### 2. Contract Creation
- **Initiator**: league admin or platform admin can initiate contract creation.
- **Template selection**: choose platform template or upload custom template.
- **Party configuration**: specify league, officials association, optional additional parties.
- **Metadata**: contract name, effective date, term length (months/years), renewal policy (auto-renew, manual renewal).
- **Signatories**: specify signing roles (e.g., league president, officials association director).
- **Payment setup** (if applicable): define fee for contract lifecycle management (one-time or annual).

### 3. E-Signature via DocuSign
- **Placeholder generation**: system marks signature/initial fields in contract (via DocuSign API or manual markup).
- **Envelope creation**: create DocuSign envelope with contract document, signatories, signature fields.
- **Send for signature**: email signatories with secure signing link; track opens and signature events.
- **Signature tracking**: record signer identity, IP, timestamp, signature image; audit trail.
- **Reminders**: auto-send reminders if signature pending (1d, 3d, 7d after initial send).
- **Rejection/renegotiation**: support signing workflow (sign → review → reject → redline → re-sign).

### 4. Post-Signature
- **Signed document storage**: store final signed PDF in S3 with encryption; backup copy in audit log.
- **Status tracking**: mark contract as `signed`, record all signatories, final signature date.
- **Notification**: notify all parties that contract is executed; provide download link.

### 5. Renewal & Expiration
- **Tracking**: calculate expiry date based on effective date + term.
- **Renewal reminders**: 
  - 90 days before expiry: notify parties of upcoming renewal.
  - 30 days before expiry: second notice.
  - 7 days before expiry: urgent notice.
  - On expiry: contract marked as `expired`; access/permissions may be restricted per policy.
- **Auto-renewal policy**:
  - Option A: auto-generate new contract with same terms; send for signature.
  - Option B: require manual renewal; provide renewal button in UI.
  - Option C: hybrid (auto-generate, but require approval before sending).
- **Renewal fees**: charge renewal fee (if applicable) when new contract is executed.

### 6. Expiration & Offboarding
- **Post-expiry actions**: 
  - Officials association can no longer use league services (if contract required for access).
  - League can suspend officials association until renewed.
  - Data retention: keep signed contract in archive per retention policy.
- **Negotiation**: parties can initiate early renewal or renegotiation before expiry.
- **Termination**: contract can be terminated early with mutual consent (audit trail required).

## Data Model
```
Contract {
  id, tenantId (league), partyId (officials association)
  name, description
  templateId (reference to platform template or custom template)
  effectiveDate, expiryDate, termMonths
  renewalPolicy: 'auto'|'manual'|'hybrid'
  status: 'draft'|'sent_for_signature'|'signed'|'expired'|'terminated'|'renewal_pending'
  currentVersion, versionHistory []
  createdAt, createdBy (adminId)
  updatedAt, updatedBy
}

ContractSignature {
  id, contractId, version
  signatoryEmail, signatoryRole (e.g., 'president', 'director')
  docusignEnvelopeId, docusignRecipientId
  status: 'pending'|'signed'|'declined'|'voided'
  signedAt, signedByName, signatureImage
  ipAddress, deviceInfo
  signedDocumentUrl
}

ContractTemplate {
  id, name, description, scope: 'platform'|'tenant'
  tenantId (if tenant-specific)
  variables [] (e.g., 'leagueName', 'effectiveDate', 'term')
  templateFileUrl, templatePreview
  createdAt, updatedAt
}

ContractFee {
  id, contractId, feeType: 'setup'|'annual_renewal'|'per_contract'
  amount, currency, status: 'pending'|'charged'|'failed'
  chargedAt, chargeReference (payment processor ID)
  audit trail with timestamps
}

ContractAudit {
  id, contractId, action: 'created'|'sent'|'signed'|'renewed'|'expired'|'terminated'|'renegotiated'
  actor (userId), details {}, timestamp
}
```

## Fee Models (Configurable)

### Option A: Per-Contract Setup Fee
- Fee charged when contract is executed (signature complete).
- Example: $50 per contract execution.
- Billing: charged to officials association or league (configurable).

### Option B: Annual Subscription Add-On
- Fixed annual fee for contract lifecycle management.
- Covers unlimited contracts, renewals, reminders.
- Example: $200/year for officials association.
- Billing: added to monthly/annual invoice.

### Option C: Per-Renewal Fee
- Fee charged each time contract is renewed.
- Encourages multi-year terms upfront.
- Example: $25 per renewal.

### Option D: Hybrid (Recommended)
- Small setup fee per contract (e.g., $25).
- Small renewal fee (e.g., $15).
- Combined with annual add-on option (e.g., $100/year for unlimited contracts).
- Platform can offer either pay-as-you-go or subscription for each tenant.

## Monetization & Billing
- **Fee configuration**: platform admin sets fees per tenant or globally.
- **Invoicing**: fees added to monthly/annual invoice for officials association.
- **Failed billing**: if fee unpaid, contract renewal is blocked until payment clears.
- **Revenue reporting**: dashboard showing contract-related revenue, renewal rates, churn.

## DocuSign Integration
- **OAuth2 flow**: obtain DocuSign credentials during contract setup; store securely.
- **API calls**: 
  - Create envelope (add document + signatories + fields).
  - Send envelope (initiate signing).
  - Get envelope status (polling or webhook for real-time updates).
  - Retrieve signed document.
- **Webhooks**: DocuSign sends events (envelope sent, signed, declined); update contract status in real-time.
- **Error handling**: retry on transient failures; alert on persistent issues (invalid email, rejected signature).

## Extensibility
- **Provider abstraction**: design interface for e-signature providers (could swap DocuSign for HelloSign, Adobe Sign, etc.).
- **Integration hooks**: webhooks for custom business logic (e.g., auto-generate follow-up contracts, notify external systems).
- **Template library**: extensible template system; future support for template versioning, approval workflows, A/B testing.

## Compliance & Security
- **Document storage**: encrypted at rest in S3; access controlled by RBAC (only parties + admins).
- **Audit trail**: immutable log of all actions (creation, sending, signing, renewal, termination).
- **Signature validity**: DocuSign certificates ensure non-repudiation (signer cannot deny signature).
- **PII handling**: signer names, emails, signatures stored securely; minimized in logs.
- **Retention**: keep signed contracts per policy; archive per legal holds.
- **Compliance**: support SOC2, GDPR, HIPAA requirements via configuration.

## UI/UX Flows
1. **League Admin → Create Contract**: select template → configure parties/dates → set fees → review → send.
2. **Signatory → Sign**: click email link → review contract → add signature/initials → submit.
3. **Admin → Track Contracts**: dashboard showing pending/signed/expired; renewal calendar; export reports.
4. **Admin → Manage Templates**: upload custom templates; preview; mark as active/deprecated; track usage.

## Consequences
- Pros: enables B2B contracts, new revenue stream, automated renewal management, reduces manual admin work.
- Cons: added complexity (DocuSign integration, fee tracking); mitigated by clear UX and good error handling.
