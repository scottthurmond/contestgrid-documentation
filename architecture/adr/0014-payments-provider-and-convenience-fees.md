# ADR 0014: Payments Provider & Convenience Fees

## Status
Accepted

## Context
We need to accept credit/debit card payments while minimizing PCI scope. We also want to add a percentage-based convenience fee to cover processing costs.

## Decision
Use a third-party payments provider (e.g., Stripe or Adyen) with tokenized payment methods and hosted components to avoid handling raw card data. Implement a configurable convenience fee applied to eligible transactions with clear disclosure.

## Payment Method Handling
- Tokenization: store only provider tokens/IDs; no raw PAN/CVV in our systems.
- Hosted UI: use provider-hosted fields/checkout to keep PCI DSS scope minimal.
- Vaulting: rely on provider vault for card storage; we store references.
- Compliance: TLS 1.2+/1.3 in transit; provider maintains PCI certification.

## Convenience Fee Policy
- Fee Type: percentage (e.g., 2.9%) or fixed amount; per-tenant configurable with caps.
- Disclosure: show fee line item before payment authorization; require explicit consent.
- Applicability: apply to card/wallet payments; exclude ACH where policy dictates.
- Tax: clarify fee taxability by region; configure tax rules via provider where needed.
- Refunds: refund fees per policy (full/partial) and provider capabilities.

## Implementation Notes
- Calculation: convenience fee computed client-side for preview and server-side for finalization; avoid discrepancies.
- Line Items: invoice/payment intent includes fee line item with code (e.g., `convenience_fee`).
- Reconciliation: ledger records include base amount + fee; dashboards show fee revenue.
- Feature Flags: enable/disable by tenant; guardrails prevent excessive fees.

## Consequences
- Pros: reduced PCI exposure, transparent fee coverage, flexible per-tenant policy.
- Cons: regional compliance complexity; mitigated with provider tools and clear UX.
