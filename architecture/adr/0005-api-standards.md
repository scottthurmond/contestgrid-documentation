# ADR 0005: API Standards (Pagination, Errors, Rate Limits, Versioning)

## Status
Accepted

## Context
We require paginated APIs with consistent error handling and rate limits. Multi-tenant constraints and telemetry need stable, traceable responses.

## Decision
- Resource Naming: use plural nouns (e.g., `/v1/leagues`, `/v1/teams`, `/v1/games`).
- Verbs & Methods: GET (read), POST (create), PUT (replace), PATCH (partial update), DELETE (remove); avoid RPC-style endpoints.
- Pagination: adopt cursor-based pagination (`cursor`, `limit`) as the default; allow `page`, `limit` for simple lists.
- Filtering/Sorting: query params with namespaced filters (`filter[field]`) and sort (`sort=field` or `-field`).
- Errors: use RFC7807 problem+json shape with `requestId`.
- Rate Limits: enforce per-tenant/app quotas and per-IP safeguards; surface standard rate-limit headers.
- Versioning: prefix with `/v1`; breaking changes via new version.
- Caching & Concurrency: ETag/If-None-Match for GET, If-Match for conditional updates; server-side cache at BFF.
- Idempotency: idempotency keys for POST operations that can be retried.

## Pagination Contract
Request: `GET /v1/resource?cursor=abc123&limit=25`
Response:
```json
{
  "data": [/* items */],
  "nextCursor": "def456",
  "prevCursor": "abc123",
  "total": 1234,
  "links": {
    "next": "/v1/resource?cursor=def456&limit=25",
    "prev": "/v1/resource?cursor=abc123&limit=25"
  }
}
```
Limits: default 25, max 200; deterministic ordering.

## Error Shape (problem+json)
```json
{
  "type": "https://example.com/problems/resource-not-found",
  "title": "Resource Not Found",
  "status": 404,
  "detail": "Team id=123 was not found",
  "instance": "/v1/teams/123",
  "code": "TEAM_NOT_FOUND",
  "requestId": "rq_9f8a..."
}
```

## Rate Limits
## Response Envelope (success)
```json
{
  "data": {/* resource or list */},
  "meta": {
    "requestId": "rq_9f8a...",
    "tenantId": "t_123",
    "pagination": { "nextCursor": "def456" }
  },
  "links": {
    "self": "/v1/resource",
    "next": "/v1/resource?cursor=def456&limit=25"
  }
}
```

## Filtering & Sorting Examples
`GET /v1/games?filter[division]=U14&filter[date.gte]=2025-01-01&sort=-startDate`

## Status Codes
200/201/202; 204 for no content; 400/401/403/404/409/422; 429; 500/503 with `requestId`.
Headers: `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset`.
429 behavior: include backoff hints; telemetry event for throttling.
Implementation: API Gateway usage plans & API keys (where applicable), Cognito authorizers for user-based limits, WAF for IP rate-based rules.

## Telemetry
Log pagination usage, errors, and throttling events with `tenantId`, `userId`, `requestId`.

## Consequences
- Pros: stable consumer experience, clearer ops signals, version safety.
- Cons: added complexity for cursor generation; mitigated via shared helpers.
