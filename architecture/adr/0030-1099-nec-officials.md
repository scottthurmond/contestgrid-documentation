# ADR 0030: 1099-NEC Reporting for Officials (Independent Contractors)

Status: Accepted
Date: 2025-12-27
Owners: Platform & Compliance

## Context
Officials are independent contractors engaged by officials associations. Associations must issue IRS Form 1099-NEC annually for nonemployee compensation and retain supporting records (W-9, consent for electronic delivery). Sensitive tax identifiers must be handled securely and never stored in plaintext in our databases.

This ADR formalizes the data model, workflows, and privacy controls required to generate, deliver, and audit 1099-NEC forms for officials.

## Decision
We will:
- Store a minimal tax profile for each official per association using `official_tax_profile` (PostgreSQL & MySQL).
  - Include `legal_name`, `tax_identifier_type` (SSN/EIN/ITIN), `tax_identifier_last4`, `external_vault_ref` (token pointing to full TIN in a secure vault), `w9_status`, `w9_received_at`, `backup_withholding_required`, delivery preferences and mailing address.
  - Enforce constraints for valid types and statuses; ensure one profile per (official, association).
- Record issued forms in `form_1099_nec` with unique `(association, official, tax_year)`.
  - Track `nonemployee_compensation`, withheld amounts, delivery method (paper/electronic), `issued_at`, `delivered_at`, `document_url`, `status`, and corrections.
- Derive annual `nonemployee_compensation` from payouts to officials (see `payout`), with reconciliation to invoice/payments.
- Require full TIN storage in a secure vault (e.g., Stripe Tax IDs, Adyen, dedicated KMS-backed service). The platform stores only `last4` + a vault reference.
- Support electronic delivery with explicit consent and fallback to paper delivery.

## Schema Additions
- PostgreSQL: `official_tax_profile`, `form_1099_nec` (see db/contestgrid-postgresql.sql).
- MySQL: `official_tax_profile`, `form_1099_nec` (see db/contestgrid.sql).

## Workflows
1. W-9 Collection & Verification
   - Association requests W-9 via secure onboarding.
   - TIN captured to vault; platform stores `last4` and `external_vault_ref`.
   - `w9_status` transitions to `approved` when verified; flag backup withholding if required.
2. Annual 1099 Preparation
   - Aggregate payouts per official per tax year; compute nonemployee compensation.
   - Generate PDF from templating service; upload to object storage; record `document_url`.
3. Delivery & Corrections
   - If `consent_electronic_delivery = true`, send secure link; else generate paper mailing.
   - Support corrected forms by linking `corrected_from_id` and updating `status`.
4. Audit & Compliance
   - Log actions in `audit_log`; retain proofs of delivery where applicable.

## Privacy & Security
- Never store full SSN/EIN in our DBs.
- Use KMS, tokenization, or third-party vaults for sensitive identifiers.
- Access to tax data limited to compliance roles via RBAC; all access audited.

## Alternatives Considered
- Storing full TINs in our DB encrypted-at-rest: rejected due to higher custody risk and compliance burden.
- Deriving compensation from invoices alone: insufficient; payouts provide authoritative amounts paid to contractors.

## Migration & Backfill
- For existing officials, implement a W-9 capture flow to populate `official_tax_profile`.
- Backfill `form_1099_nec` for prior years if needed using historical payouts.

## Impact
- Enables compliant 1099-NEC generation and delivery by officials associations.
- Minimal changes to existing payout logic; adds tax metadata and formal records for issued forms.

## References
- IRS Form 1099-NEC Instructions
- ADR 0003: Billing & Payroll (updated to reference 1099 workflows)
- ADR 0029: Payer & Billing Entity Model