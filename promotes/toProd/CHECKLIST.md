# Promote to Production — Checklist

> **Status**: Placeholder — to be completed when Test environment is stable.

## Differences from toTest
- No test data — only reference/lookup data
- Production secrets and DNS configuration
- TLS certificates (real, not self-signed)
- Monitoring and alerting setup

## TODO
- [ ] Define production environment variables / secrets
- [ ] Document DNS and TLS certificate setup
- [ ] Define production seed data (lookup tables only, no test data)
- [ ] Document blue/green or rolling deployment strategy
- [ ] Define rollback procedure
- [ ] Define monitoring/alerting requirements
