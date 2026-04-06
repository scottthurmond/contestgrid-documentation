# ADR 0013: Testing Strategy & Tooling

## Status
Accepted

## Context
We want fully automated testing from the beginning: unit, integration, E2E, API, contract and performance testing. Tests must be fast, reliable, and integrated into CI.

## Decision
Adopt a testing pyramid with strong unit tests, targeted integration tests, end-to-end UI tests, API tests, and load/performance tests. Use widely supported tooling integrated with pnpm/Turborepo.

## Tooling
- Unit & Component: Vitest + Vue Test Utils
  - Fast, TypeScript-friendly, snapshot and coverage via `c8`.
- Integration: Vitest with MSW (Mock Service Worker) for HTTP mocking
  - Test stores/composables/services against mocked APIs.
- E2E UI: Playwright
  - Cross-browser/device matrix; trace viewer; parallel runs.
- API Testing (Functional): Postman Collections + Newman in CI
  - Organize per-service collections; environment vars; pre-request/post-response scripts.
- Contract Testing: Pact (consumer/provider)
  - Validate FE→BFF contracts; ensure backward compatibility.
- Load/Performance: Artillery or k6
  - Scenario-based tests for critical APIs; CI-friendly summaries.
- Static Analysis: ESLint + TypeScript, and security linting (e.g., eslint-plugin-security)

## Practices
- Testing Pyramid: aim for ~70–80% unit coverage on core logic; fewer but meaningful integration/E2E tests.
- Deterministic Tests: isolate time, random, network by dependency injection and mocks.
- Fixtures & Factories: shared test factories for DTOs/models; avoid brittle snapshots.
- CI Gates: lint, type-check, unit, integration, API, E2E, and performance smoke suite on main branches.
- Test Data: seed minimal datasets per app; clear between tests; avoid cross-test coupling.
- Flake Management: retries only where safe; detect and fix flakey tests; record traces.

## Integration into Workspace
- Setup `packages/testing` with shared config, factories, MSW handlers, and helpers.
- Add `pnpm` scripts for each stage: `test:unit`, `test:int`, `test:e2e`, `test:api`, `test:perf`.
- Configure Playwright projects for device matrix and Lighthouse budgets.
- Add Newman to CI; store Postman collections in `tests/postman`.

## Consequences
- Pros: strong quality gates, early detection of regressions, confidence to refactor.
- Cons: more upfront investment; mitigated by reusable helpers and fast tooling.
