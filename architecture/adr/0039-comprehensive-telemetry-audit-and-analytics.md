# ADR 0039: Comprehensive Telemetry, Audit & Analytics

## Status
Proposed — supersedes ADR-0002 (Telemetry & Audit Strategy)

## Context
The platform currently has **no telemetry, audit trail, or analytics infrastructure**. Every service logs to `console.log` with no structure, no correlation, and no persistence. There is no record of who changed what data, no frontend performance tracking, no API timing analytics, and no database query profiling. The only auditable data is the `subscription_tier_date_audit` table (billing tier date changes) and `created_at`/`updated_at` timestamps on rows — which don't record *who* made the change.

ADR-0002 outlined a high-level plan for telemetry but was never implemented. This ADR replaces it with a comprehensive, implementation-ready specification covering four pillars:

1. **Audit Trail** — immutable record of every data mutation, who did it, what changed
2. **API Analytics** — request/response timing, status codes, throughput, error rates across all services
3. **Database Analytics** — query execution time, slow query detection, connection pool health
4. **Frontend Analytics** — page load times, component render times, API call durations, user navigation patterns, interaction tracking

## Decision

### Architecture Overview

```
┌─────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│  Frontend (Vue)  │────▶│   BFF (Express)  │────▶│  Proc / Sys APIs │
│                  │     │                  │     │                  │
│ • Page load time │     │ • Request timing │     │ • Request timing │
│ • API call time  │     │ • Proxy latency  │     │ • Query timing   │
│ • Navigation     │     │ • Audit events   │     │ • Audit triggers │
│ • User actions   │     │ • Error tracking │     │ • Error tracking │
│ • Perf Observer  │     │                  │     │                  │
└────────┬─────────┘     └────────┬─────────┘     └────────┬─────────┘
         │                        │                         │
         ▼                        ▼                         ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    Telemetry Ingestion Layer                        │
│  (Local: PostgreSQL tables   |   Prod: CloudWatch / OpenTelemetry) │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Pillar 1: Audit Trail

### 1.1 Database-Level Change Capture

Every INSERT, UPDATE, and DELETE on `app.*` tables is captured automatically via a PostgreSQL trigger that writes to an append-only audit table.

#### `audit.change_log`
Stored in a dedicated `audit` schema (not `app`) to separate concerns and allow different RLS/retention policies.

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `change_log_id` | `bigint` (PK) | NO | Auto-generated identity |
| `schema_name` | `varchar(63)` | NO | Always `'app'` for now |
| `table_name` | `varchar(63)` | NO | Table that was modified |
| `operation` | `varchar(10)` | NO | `INSERT`, `UPDATE`, `DELETE` |
| `row_id` | `text` | NO | Primary key value(s) of the affected row (composite keys joined with `::`) |
| `old_data` | `jsonb` | YES | Full row before change (NULL for INSERT) |
| `new_data` | `jsonb` | YES | Full row after change (NULL for DELETE) |
| `changed_fields` | `text[]` | YES | List of column names that changed (NULL for INSERT/DELETE) |
| `tenant_id` | `bigint` | YES | Extracted from `current_setting('app.tenant_id', true)` |
| `user_id` | `bigint` | YES | Extracted from `current_setting('app.user_id', true)` |
| `session_id` | `text` | YES | Extracted from `current_setting('app.session_id', true)` |
| `correlation_id` | `text` | YES | Extracted from `current_setting('app.correlation_id', true)` — ties to the API request |
| `ip_address` | `inet` | YES | Extracted from `current_setting('app.client_ip', true)` |
| `user_agent` | `text` | YES | Extracted from `current_setting('app.user_agent', true)` |
| `occurred_at` | `timestamptz` | NO | `clock_timestamp()` — wall-clock time of the change |
| `transaction_id` | `bigint` | NO | `txid_current()` — groups changes within a single transaction |

**Trigger function**:
```sql
CREATE OR REPLACE FUNCTION audit.log_change() RETURNS trigger AS $$
DECLARE
  _row_id text;
  _changed text[];
  _old jsonb;
  _new jsonb;
BEGIN
  -- Determine the PK value
  IF TG_OP = 'DELETE' THEN
    _row_id := OLD.{{ pk_column }}::text;
    _old    := to_jsonb(OLD);
    _new    := NULL;
  ELSIF TG_OP = 'INSERT' THEN
    _row_id := NEW.{{ pk_column }}::text;
    _old    := NULL;
    _new    := to_jsonb(NEW);
  ELSE -- UPDATE
    _row_id := NEW.{{ pk_column }}::text;
    _old    := to_jsonb(OLD);
    _new    := to_jsonb(NEW);
    -- Compute changed fields
    SELECT array_agg(key) INTO _changed
    FROM jsonb_each(_new) n
    FULL OUTER JOIN jsonb_each(_old) o USING (key)
    WHERE n.value IS DISTINCT FROM o.value;
    -- Skip audit if nothing actually changed
    IF _changed IS NULL THEN RETURN NEW; END IF;
  END IF;

  INSERT INTO audit.change_log (
    schema_name, table_name, operation, row_id,
    old_data, new_data, changed_fields,
    tenant_id, user_id, session_id, correlation_id,
    ip_address, user_agent, occurred_at, transaction_id
  ) VALUES (
    TG_TABLE_SCHEMA, TG_TABLE_NAME, TG_OP, _row_id,
    _old, _new, _changed,
    nullif(current_setting('app.tenant_id',    true), '')::bigint,
    nullif(current_setting('app.user_id',      true), '')::bigint,
    nullif(current_setting('app.session_id',   true), ''),
    nullif(current_setting('app.correlation_id', true), ''),
    nullif(current_setting('app.client_ip',    true), '')::inet,
    nullif(current_setting('app.user_agent',   true), ''),
    clock_timestamp(), txid_current()
  );

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

**Applied to every `app.*` table** via a migration loop:
```sql
DO $$
DECLARE tbl text;
BEGIN
  FOR tbl IN
    SELECT tablename FROM pg_tables
    WHERE schemaname = 'app' AND tablename != 'flyway_schema_history'
  LOOP
    EXECUTE format(
      'CREATE TRIGGER trg_audit_%I
       AFTER INSERT OR UPDATE OR DELETE ON app.%I
       FOR EACH ROW EXECUTE FUNCTION audit.log_change()',
      tbl, tbl
    );
  END LOOP;
END $$;
```

**Indexes**:
- `(table_name, row_id, occurred_at DESC)` — "show me the history of this record"
- `(user_id, occurred_at DESC)` — "show me everything this user changed"
- `(tenant_id, occurred_at DESC)` — "show me everything that changed in this tenant"
- `(correlation_id)` — "show me all changes from this API request"
- `(occurred_at)` — retention/archival queries

**Partitioning**: Partition `audit.change_log` by month on `occurred_at` for efficient archival and pruning. Retain 12 months online, archive to cold storage (S3/Glacier) beyond that.

### 1.2 Application-Level Audit Context

To populate `user_id`, `session_id`, `correlation_id`, `client_ip`, and `user_agent` in the audit log, each service must set these PostgreSQL session variables **within the same transaction** as the data mutation.

**Updated `query()` function** (all three sys services):
```typescript
export async function query<T>(
  text: string,
  params?: any[],
  context: {
    tenantId?: string | number;
    userId?: string | number;
    sessionId?: string;
    correlationId?: string;
    clientIp?: string;
    userAgent?: string;
  } = {}
): Promise<pg.QueryResult<T>> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    if (context.tenantId)      await client.query(`SELECT set_config('app.tenant_id', $1, true)`, [String(context.tenantId)]);
    if (context.userId)        await client.query(`SELECT set_config('app.user_id', $1, true)`, [String(context.userId)]);
    if (context.sessionId)     await client.query(`SELECT set_config('app.session_id', $1, true)`, [context.sessionId]);
    if (context.correlationId) await client.query(`SELECT set_config('app.correlation_id', $1, true)`, [context.correlationId]);
    if (context.clientIp)      await client.query(`SELECT set_config('app.client_ip', $1, true)`, [context.clientIp]);
    if (context.userAgent)     await client.query(`SELECT set_config('app.user_agent', $1, true)`, [context.userAgent]);
    await client.query(`SELECT set_config('app.encryption_key', $1, true)`, [env.piiEncryptionKey]);
    const result = await client.query<T>(text, params);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    try { await client.query('ROLLBACK'); } catch {}
    throw error;
  } finally {
    client.release();
  }
}
```

### 1.3 Audit API

#### officials-sys / core-sys / billing-sys (read-only)
```
GET /v1/audit/changes?table=&row_id=&user_id=&from=&to=&limit=&offset=
```
Returns paginated change log entries. Requires `audit:read` entitlement.

#### BFF
```
GET /api/audit/changes?table=&row_id=&user_id=&from=&to=
GET /api/audit/changes/:correlationId   — all changes from a single API request
GET /api/audit/user/:userId/activity    — all changes by a specific user
```

### 1.4 New Entitlements

| `entitlement_key` | `resource_name` | `operation` | `description` |
|--------------------|-----------------|-------------|---------------|
| `audit:read` | `audit` | `read` | View audit trail / change history |

**Default**: Tenant Admin and Platform Admin only.

---

## Pillar 2: API Analytics

### 2.1 Structured Logging (Replace console.log)

Replace all `console.log`/`console.error` with **pino** (already in `package.json` for core-sys and officials-sys; add to BFF, billing-sys, billing-proc, scheduling-proc).

#### Logger Setup (shared across all services)
```typescript
// src/config/logger.ts
import pino from 'pino';

export const logger = pino({
  level: process.env.LOG_LEVEL || 'info',
  formatters: {
    level: (label) => ({ level: label }),
  },
  timestamp: pino.stdTimeFunctions.isoTime,
  serializers: {
    err: pino.stdSerializers.err,
    req: pino.stdSerializers.req,
    res: pino.stdSerializers.res,
  },
  // Pretty-print in development
  transport: process.env.NODE_ENV !== 'production'
    ? { target: 'pino-pretty', options: { colorize: true, translateTime: 'HH:MM:ss' } }
    : undefined,
});
```

### 2.2 Request Timing Middleware

Replace all inline request loggers with a standardized middleware:

```typescript
// src/middleware/requestLogger.ts
import { Request, Response, NextFunction } from 'express';
import { randomUUID } from 'crypto';
import { logger } from '../config/logger.js';

export function requestLogger(serviceName: string) {
  return (req: Request, res: Response, next: NextFunction) => {
    // Skip health checks
    if (req.path === '/health' || req.path === '/ready') return next();

    // Generate or propagate correlation ID
    const correlationId = req.headers['x-correlation-id'] as string || randomUUID();
    req.headers['x-correlation-id'] = correlationId;
    res.setHeader('x-correlation-id', correlationId);

    const start = process.hrtime.bigint();

    res.on('finish', () => {
      const durationMs = Number(process.hrtime.bigint() - start) / 1_000_000;

      logger.info({
        event: 'http_request',
        service: serviceName,
        correlationId,
        method: req.method,
        path: req.path,
        route: req.route?.path,       // Express route pattern (e.g., /persons/:id)
        statusCode: res.statusCode,
        durationMs: Math.round(durationMs * 100) / 100,
        contentLength: res.getHeader('content-length'),
        userId: (req as any).user?.personId,
        tenantId: (req as any).tenantId,
        userAgent: req.headers['user-agent'],
        ip: req.ip || req.headers['x-forwarded-for'],
      });
    });

    next();
  };
}
```

### 2.3 Request Timing Persistence

#### `telemetry.api_request_log`
Stored in a `telemetry` schema. For local dev, written directly to PostgreSQL. In production, shipped via CloudWatch / OpenTelemetry collector.

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `request_log_id` | `bigint` (PK) | NO | Auto-generated identity |
| `service_name` | `varchar(50)` | NO | `bff`, `core-sys`, `officials-sys`, `billing-sys`, `billing-proc`, `scheduling-proc` |
| `correlation_id` | `text` | NO | UUID tying the full request chain together |
| `parent_correlation_id` | `text` | YES | The upstream correlation ID (BFF → proc → sys) |
| `method` | `varchar(10)` | NO | HTTP method |
| `path` | `text` | NO | Actual request path |
| `route_pattern` | `text` | YES | Express route pattern (e.g., `/v1/persons/:id`) |
| `status_code` | `smallint` | NO | HTTP response status |
| `duration_ms` | `numeric(10,2)` | NO | Total request processing time |
| `request_size_bytes` | `integer` | YES | `content-length` of request |
| `response_size_bytes` | `integer` | YES | `content-length` of response |
| `user_id` | `bigint` | YES | Authenticated user (from JWT) |
| `tenant_id` | `bigint` | YES | |
| `ip_address` | `inet` | YES | Client IP |
| `user_agent` | `text` | YES | |
| `error_message` | `text` | YES | Error message if status >= 400 |
| `occurred_at` | `timestamptz` | NO | Request start time |

**Partitioned** by month on `occurred_at`. Retain 6 months online, archive beyond.

**Indexes**:
- `(service_name, occurred_at DESC)` — per-service dashboards
- `(correlation_id)` — trace a request across services
- `(route_pattern, occurred_at DESC)` — per-endpoint analytics
- `(user_id, occurred_at DESC)` — per-user activity
- `(status_code, occurred_at DESC)` — error analysis

### 2.4 Correlation ID Propagation

Every service-to-service call propagates the correlation ID:

```
Browser → BFF: generates correlation_id (UUID)
BFF → proc: forwards x-correlation-id header
proc → sys: forwards x-correlation-id header
sys → DB: sets app.correlation_id in transaction context
```

**BFF proxy/axios interceptor** adds the header automatically:
```typescript
// In apiClients.ts request interceptor
config.headers['x-correlation-id'] = config.headers['x-correlation-id']
  || req.headers['x-correlation-id']
  || randomUUID();
```

### 2.5 Error Tracking Middleware

```typescript
// src/middleware/errorHandler.ts (enhanced)
export function errorHandler(err: Error, req: Request, res: Response, next: NextFunction) {
  const correlationId = req.headers['x-correlation-id'];

  logger.error({
    event: 'unhandled_error',
    correlationId,
    method: req.method,
    path: req.path,
    error: err.message,
    stack: err.stack,
    userId: (req as any).user?.personId,
    tenantId: (req as any).tenantId,
  });

  const status = (err as any).statusCode || 500;
  res.status(status).json({
    error: err.message || 'Internal Server Error',
    correlationId,
  });
}
```

---

## Pillar 3: Database Analytics

### 3.1 Query Timing Wrapper

Wrap all database queries to capture execution time:

```typescript
// src/config/database.ts (enhanced query function)
export async function query<T>(
  text: string,
  params?: any[],
  context: QueryContext = {}
): Promise<pg.QueryResult<T> & { durationMs: number }> {
  const client = await pool.connect();
  const start = process.hrtime.bigint();

  try {
    await client.query('BEGIN');
    // ... set_config calls for tenant, user, correlation, etc. ...

    const queryStart = process.hrtime.bigint();
    const result = await client.query<T>(text, params);
    const queryDurationMs = Number(process.hrtime.bigint() - queryStart) / 1_000_000;

    await client.query('COMMIT');

    const totalDurationMs = Number(process.hrtime.bigint() - start) / 1_000_000;

    // Log query timing
    logger.debug({
      event: 'db_query',
      correlationId: context.correlationId,
      durationMs: Math.round(queryDurationMs * 100) / 100,
      totalDurationMs: Math.round(totalDurationMs * 100) / 100,
      rowCount: result.rowCount,
      query: text.substring(0, 200),   // truncate for safety
    });

    // Flag slow queries
    if (queryDurationMs > SLOW_QUERY_THRESHOLD_MS) {
      logger.warn({
        event: 'slow_query',
        correlationId: context.correlationId,
        durationMs: queryDurationMs,
        query: text.substring(0, 500),
        params: params?.length,
      });
    }

    return Object.assign(result, { durationMs: queryDurationMs });
  } catch (error) {
    // ...
  } finally {
    client.release();
  }
}
```

### 3.2 Query Analytics Table

#### `telemetry.db_query_log`

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `query_log_id` | `bigint` (PK) | NO | |
| `service_name` | `varchar(50)` | NO | Which sys service ran the query |
| `correlation_id` | `text` | YES | Ties to the originating API request |
| `query_fingerprint` | `text` | NO | Normalized SQL (parameterized, whitespace-collapsed) |
| `query_text` | `text` | YES | First 500 chars of raw SQL (only for slow queries) |
| `duration_ms` | `numeric(10,2)` | NO | Query execution time |
| `row_count` | `integer` | YES | Rows returned/affected |
| `tenant_id` | `bigint` | YES | |
| `is_slow` | `boolean` | NO | `true` if above threshold |
| `occurred_at` | `timestamptz` | NO | |

**Partitioned** by month. Retain 3 months online.

**Slow query threshold**: Configurable per environment — default 200ms dev, 100ms prod.

**Indexes**:
- `(query_fingerprint, occurred_at DESC)` — aggregate stats per query pattern
- `(is_slow, occurred_at DESC)` — slow query dashboard
- `(service_name, occurred_at DESC)` — per-service DB health

### 3.3 Connection Pool Metrics

Periodically emit pool health stats (every 30 seconds):
```typescript
setInterval(() => {
  logger.info({
    event: 'db_pool_health',
    service: serviceName,
    totalConnections: pool.totalCount,
    idleConnections: pool.idleCount,
    waitingClients: pool.waitingCount,
  });
}, 30_000);
```

### 3.4 PostgreSQL Statement Stats

Enable `pg_stat_statements` extension for aggregate query analytics:
```sql
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
```

Expose via admin API:
```
GET /v1/admin/db-stats/slow-queries?min_duration_ms=100&limit=20
GET /v1/admin/db-stats/frequent-queries?limit=20
GET /v1/admin/db-stats/pool-health
```

---

## Pillar 4: Frontend Analytics

### 4.1 Telemetry Client SDK

A lightweight composable (`useTelemetry`) integrated into the Vue app:

```typescript
// src/composables/useTelemetry.ts
import api from '@/services/api';

interface TelemetryEvent {
  event: string;
  category: 'navigation' | 'interaction' | 'performance' | 'error' | 'api';
  data: Record<string, any>;
  timestamp: string;
  sessionId: string;
  route: string;
}

const SESSION_ID = crypto.randomUUID();
const EVENT_BUFFER: TelemetryEvent[] = [];
const FLUSH_INTERVAL_MS = 10_000;
const MAX_BUFFER_SIZE = 50;

function enqueue(event: Omit<TelemetryEvent, 'timestamp' | 'sessionId' | 'route'>) {
  EVENT_BUFFER.push({
    ...event,
    timestamp: new Date().toISOString(),
    sessionId: SESSION_ID,
    route: window.location.pathname,
  });
  if (EVENT_BUFFER.length >= MAX_BUFFER_SIZE) flush();
}

async function flush() {
  if (EVENT_BUFFER.length === 0) return;
  const batch = EVENT_BUFFER.splice(0);
  try {
    await api.post('/telemetry/events', { events: batch });
  } catch {
    // Re-queue on failure (up to a cap)
    EVENT_BUFFER.unshift(...batch.slice(0, MAX_BUFFER_SIZE));
  }
}

setInterval(flush, FLUSH_INTERVAL_MS);
// Also flush on page visibility change (user leaving)
document.addEventListener('visibilitychange', () => {
  if (document.visibilityState === 'hidden') flush();
});

export function useTelemetry() {
  return { trackEvent: enqueue, flush, SESSION_ID };
}
```

### 4.2 Page Load & Navigation Timing

Integrated with Vue Router:

```typescript
// src/router/telemetry.ts
import { Router } from 'vue-router';
import { useTelemetry } from '@/composables/useTelemetry';

export function installRouterTelemetry(router: Router) {
  let navigationStart: number;

  router.beforeEach((to, from) => {
    navigationStart = performance.now();
  });

  router.afterEach((to, from) => {
    const { trackEvent } = useTelemetry();
    const durationMs = Math.round(performance.now() - navigationStart);

    trackEvent({
      event: 'page_navigation',
      category: 'navigation',
      data: {
        fromPath: from.fullPath,
        toPath: to.fullPath,
        toName: to.name as string,
        durationMs,
        isInitialLoad: from.name === undefined,
      },
    });
  });
}
```

### 4.3 API Call Timing (Axios Interceptor)

```typescript
// src/services/api.ts (enhanced)
api.interceptors.request.use((config) => {
  (config as any)._startTime = performance.now();
  (config as any)._correlationId = crypto.randomUUID();
  config.headers['x-correlation-id'] = (config as any)._correlationId;
  // ... existing JWT attachment ...
  return config;
});

api.interceptors.response.use(
  (response) => {
    const durationMs = Math.round(performance.now() - (response.config as any)._startTime);
    const { trackEvent } = useTelemetry();
    trackEvent({
      event: 'api_call',
      category: 'api',
      data: {
        method: response.config.method?.toUpperCase(),
        url: response.config.url,
        statusCode: response.status,
        durationMs,
        correlationId: (response.config as any)._correlationId,
        responseSize: JSON.stringify(response.data)?.length,
      },
    });
    return response;
  },
  (error) => {
    const config = error.config || {};
    const durationMs = Math.round(performance.now() - (config._startTime || 0));
    const { trackEvent } = useTelemetry();
    trackEvent({
      event: 'api_error',
      category: 'error',
      data: {
        method: config.method?.toUpperCase(),
        url: config.url,
        statusCode: error.response?.status,
        durationMs,
        correlationId: config._correlationId,
        errorMessage: error.message,
      },
    });
    // ... existing 401 handling ...
    return Promise.reject(error);
  },
);
```

### 4.4 Web Vitals & Performance Observer

Track Core Web Vitals automatically:

```typescript
// src/telemetry/webVitals.ts
import { useTelemetry } from '@/composables/useTelemetry';

export function observeWebVitals() {
  const { trackEvent } = useTelemetry();

  // Largest Contentful Paint
  new PerformanceObserver((list) => {
    const entries = list.getEntries();
    const last = entries[entries.length - 1];
    trackEvent({
      event: 'web_vital_lcp',
      category: 'performance',
      data: { value: Math.round(last.startTime), element: (last as any).element?.tagName },
    });
  }).observe({ type: 'largest-contentful-paint', buffered: true });

  // First Input Delay
  new PerformanceObserver((list) => {
    for (const entry of list.getEntries()) {
      trackEvent({
        event: 'web_vital_fid',
        category: 'performance',
        data: { value: Math.round((entry as any).processingStart - entry.startTime) },
      });
    }
  }).observe({ type: 'first-input', buffered: true });

  // Cumulative Layout Shift
  let clsValue = 0;
  new PerformanceObserver((list) => {
    for (const entry of list.getEntries()) {
      if (!(entry as any).hadRecentInput) {
        clsValue += (entry as any).value;
      }
    }
    trackEvent({
      event: 'web_vital_cls',
      category: 'performance',
      data: { value: Math.round(clsValue * 1000) / 1000 },
    });
  }).observe({ type: 'layout-shift', buffered: true });

  // Long Tasks (>50ms)
  new PerformanceObserver((list) => {
    for (const entry of list.getEntries()) {
      trackEvent({
        event: 'long_task',
        category: 'performance',
        data: { durationMs: Math.round(entry.duration), startTime: Math.round(entry.startTime) },
      });
    }
  }).observe({ type: 'longtask', buffered: true });

  // Resource Loading (images, scripts, stylesheets, fonts)
  new PerformanceObserver((list) => {
    for (const entry of list.getEntries()) {
      const e = entry as PerformanceResourceTiming;
      if (e.duration > 500) { // Only log slow resources
        trackEvent({
          event: 'slow_resource',
          category: 'performance',
          data: {
            name: e.name,
            type: e.initiatorType,
            durationMs: Math.round(e.duration),
            transferSize: e.transferSize,
          },
        });
      }
    }
  }).observe({ type: 'resource', buffered: true });

  // Initial Page Load timing (from Navigation Timing API)
  window.addEventListener('load', () => {
    setTimeout(() => {
      const nav = performance.getEntriesByType('navigation')[0] as PerformanceNavigationTiming;
      if (nav) {
        trackEvent({
          event: 'page_load',
          category: 'performance',
          data: {
            dnsMs: Math.round(nav.domainLookupEnd - nav.domainLookupStart),
            tcpMs: Math.round(nav.connectEnd - nav.connectStart),
            ttfbMs: Math.round(nav.responseStart - nav.requestStart),
            downloadMs: Math.round(nav.responseEnd - nav.responseStart),
            domParseMs: Math.round(nav.domInteractive - nav.responseEnd),
            domContentLoadedMs: Math.round(nav.domContentLoadedEventEnd - nav.fetchStart),
            fullLoadMs: Math.round(nav.loadEventEnd - nav.fetchStart),
            transferSize: nav.transferSize,
          },
        });
      }
    }, 0);
  });
}
```

### 4.5 User Interaction Tracking

```typescript
// src/telemetry/interactions.ts
import { useTelemetry } from '@/composables/useTelemetry';

export function installInteractionTracking() {
  const { trackEvent } = useTelemetry();

  // Track button clicks with data-track attribute
  document.addEventListener('click', (e) => {
    const target = (e.target as HTMLElement).closest('[data-track]');
    if (!target) return;

    trackEvent({
      event: 'user_interaction',
      category: 'interaction',
      data: {
        action: 'click',
        trackId: target.getAttribute('data-track'),
        component: target.tagName,
        text: target.textContent?.trim().substring(0, 50),
      },
    });
  });

  // Track form submissions
  document.addEventListener('submit', (e) => {
    const form = e.target as HTMLFormElement;
    trackEvent({
      event: 'form_submit',
      category: 'interaction',
      data: {
        formId: form.id || form.getAttribute('data-track') || 'unknown',
      },
    });
  });

  // Track search/filter interactions (debounced input on search fields)
  let searchTimeout: ReturnType<typeof setTimeout>;
  document.addEventListener('input', (e) => {
    const target = e.target as HTMLInputElement;
    if (!target.matches('[data-track-search], [type="search"], .v-text-field input')) return;

    clearTimeout(searchTimeout);
    searchTimeout = setTimeout(() => {
      trackEvent({
        event: 'search_input',
        category: 'interaction',
        data: {
          field: target.getAttribute('data-track-search') || target.name || 'search',
          queryLength: target.value.length,
          // Never log the actual search text for privacy
        },
      });
    }, 1000);
  });

  // Track errors
  window.addEventListener('error', (e) => {
    trackEvent({
      event: 'js_error',
      category: 'error',
      data: {
        message: e.message,
        filename: e.filename,
        lineno: e.lineno,
        colno: e.colno,
      },
    });
  });

  window.addEventListener('unhandledrejection', (e) => {
    trackEvent({
      event: 'unhandled_rejection',
      category: 'error',
      data: {
        reason: String(e.reason).substring(0, 200),
      },
    });
  });
}
```

### 4.6 Frontend Event Storage

#### `telemetry.frontend_event`

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `frontend_event_id` | `bigint` (PK) | NO | |
| `session_id` | `text` | NO | Browser session UUID |
| `user_id` | `bigint` | YES | Authenticated user |
| `tenant_id` | `bigint` | YES | |
| `event_name` | `varchar(100)` | NO | e.g., `page_navigation`, `api_call`, `web_vital_lcp`, `user_interaction` |
| `category` | `varchar(30)` | NO | `navigation`, `interaction`, `performance`, `error`, `api` |
| `route` | `text` | YES | Current route path |
| `data` | `jsonb` | NO | Event-specific payload |
| `occurred_at` | `timestamptz` | NO | |

**Partitioned** by month. Retain 6 months online.

**Indexes**:
- `(session_id, occurred_at)` — replay a user session
- `(event_name, occurred_at DESC)` — per-event-type analytics
- `(category, occurred_at DESC)` — category dashboards
- `(user_id, occurred_at DESC)` — per-user analytics

### 4.7 BFF Ingestion Endpoint

```
POST /api/telemetry/events
Body: { events: TelemetryEvent[] }
```

Rate-limited (100 events/10 seconds per session). Validates event schema. Enriches with `user_id` and `tenant_id` from JWT. Writes to `telemetry.frontend_event` in batch.

---

## Pillar 5: Dashboards & Reporting

### 5.1 Admin Analytics Dashboard (Frontend)

New route: `/admin/analytics` — requires `audit:read` entitlement.

| Dashboard Panel | Data Source | Metrics |
|----------------|-------------|---------|
| **API Health** | `telemetry.api_request_log` | Requests/min, avg response time, p50/p95/p99 latency, error rate, top 10 slowest endpoints |
| **Database Health** | `telemetry.db_query_log` | Queries/min, avg duration, slow query count, top 10 slowest queries, connection pool utilization |
| **Frontend Performance** | `telemetry.frontend_event` | Avg page load time, LCP/FID/CLS scores, API call timing from browser, long task count, JS error rate |
| **User Activity** | `telemetry.frontend_event` + `audit.change_log` | Active users, page views, most-visited pages, top actions, session duration |
| **Audit Trail** | `audit.change_log` | Recent changes (filterable by table, user, date), most-modified tables, changes per user |
| **Error Log** | `telemetry.api_request_log` + `telemetry.frontend_event` | Recent errors, error frequency by endpoint, error trends |

### 5.2 Record-Level Audit Trail (per entity)

Every detail page (person, official, contest, venue, team, etc.) gets a **History** tab showing:
- Chronological list of changes from `audit.change_log`
- Diff view: what fields changed, old → new values
- Who made the change (user name lookup), when, from what IP
- Correlation ID links to full request trace

### 5.3 Pre-Built Reports

| Report | Schedule | Description |
|--------|----------|-------------|
| **Daily API Health** | Daily 6am | Avg/p95/p99 latency per service, error count, slowest endpoints |
| **Weekly Slow Queries** | Weekly Monday | Top 20 slowest queries, frequency, avg duration, optimization suggestions |
| **Monthly User Activity** | Monthly 1st | Active users/tenant, pages viewed, features used, session stats |
| **Monthly Performance** | Monthly 1st | Web Vitals trends, page load trends, API latency trends |
| **On-Demand Audit** | On request | Full change history for a specific record, user, or time window |

---

## Privacy & Security

| Concern | Mitigation |
|---------|------------|
| **PII in audit data** | `old_data`/`new_data` JSONB automatically captures row contents — encrypted PII fields (like `birth_date`) appear as encrypted values, not plaintext. Field-level redaction can be added for specific columns. |
| **Telemetry PII** | Never log search text content, only query length. Never log form values. Interaction tracking uses `data-track` attributes, not DOM content. |
| **Audit table access** | `audit` schema has separate RLS: tenant-scoped by default. Only `audit:read` entitlement holders can query. |
| **Data retention** | Configurable per tenant. Default: 12 months audit, 6 months API/frontend telemetry, 3 months DB query logs. Automated archival via pg_cron or external scheduler. |
| **Volume management** | Frontend events batched (10s / 50 events). DB query logging only persists slow queries by default (configurable). API request log captures all requests but partitioned monthly for efficient pruning. |
| **Frontend sampling** | Configurable sampling rate per event type (e.g., 100% for errors, 10% for resource timing, 100% for API calls). Controlled via tenant config. |

---

## Implementation Plan

### Phase 1: Foundation (Week 1-2)
1. Create `audit` and `telemetry` schemas
2. Create `audit.change_log` table with partitioning
3. Create `audit.log_change()` trigger function
4. Apply audit triggers to all `app.*` tables via Flyway migration
5. Update `query()` in all 3 sys services to accept and set `user_id`, `correlation_id`, `client_ip`, `user_agent`
6. Add correlation ID middleware to all services
7. Replace `console.log` with pino across all 6 services
8. Add `requestLogger` middleware to all 6 services

### Phase 2: API & DB Analytics (Week 3)
9. Create `telemetry.api_request_log` table
10. Add async log writer (batched inserts, non-blocking) to request logger
11. Create `telemetry.db_query_log` table
12. Add query timing wrapper to sys services
13. Enable `pg_stat_statements`
14. Add pool health periodic emitter
15. Add `audit:read` entitlement to database seed

### Phase 3: Frontend Analytics (Week 4)
16. Create `useTelemetry` composable
17. Add router telemetry (navigation timing)
18. Enhance axios interceptors (API timing + correlation IDs)
19. Add Web Vitals observer
20. Add interaction tracking (`data-track` attributes on key buttons)
21. Add error tracking (window.onerror, unhandledrejection)
22. Create `POST /api/telemetry/events` BFF endpoint
23. Create `telemetry.frontend_event` table

### Phase 4: Dashboards (Week 5-6)
24. Admin analytics dashboard (API health, DB health, frontend perf)
25. Record-level History tab on entity detail pages
26. User activity audit view
27. Configurable retention / archival job

---

## Database Schema Summary (New Objects)

| Object | Schema | Type | Purpose |
|--------|--------|------|---------|
| `audit.change_log` | `audit` | Table (partitioned) | Immutable record of every data mutation |
| `audit.log_change()` | `audit` | Trigger function | Captures INSERT/UPDATE/DELETE on all `app.*` tables |
| `telemetry.api_request_log` | `telemetry` | Table (partitioned) | HTTP request timing across all services |
| `telemetry.db_query_log` | `telemetry` | Table (partitioned) | Database query execution timing |
| `telemetry.frontend_event` | `telemetry` | Table (partitioned) | Browser events: navigation, performance, interactions, errors |

---

## Consequences
- **Pros**: Complete visibility into every data change (who, what, when); end-to-end request tracing via correlation IDs; quantifiable performance metrics for every layer (browser → API → DB); proactive slow query detection; frontend error tracking catches issues before users report them; Web Vitals tracking ensures UX quality; structured logging enables log search/aggregation in production
- **Cons**: Audit triggers add ~1-3ms overhead per write operation (acceptable); telemetry tables will grow significantly (mitigated by monthly partitioning and retention policies); frontend event batching means events may be lost on hard crashes (mitigated by flush-on-visibility-change); initial implementation is ~6 weeks across all pillars (can be phased)

## Related ADRs
- **ADR-0002**: Telemetry & Audit Strategy (superseded — this ADR provides the full implementation spec)
- **ADR-0032**: Infrastructure & API Security (mentions OpenTelemetry)
- **ADR-0034**: RBAC Entitlement System (new `audit:read` entitlement)
- **ADR-0015**: Data Protection & Encryption (PII handling in audit data)
