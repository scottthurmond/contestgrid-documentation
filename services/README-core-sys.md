# ContestGrid - System API: Core

**Data ownership for**: Tenants, Contests, Leagues, Teams, Venues

Part of the multi-tier architecture: **Frontend → BFF → Proc APIs → System APIs**

## Architecture

This is a **System API** (data ownership layer) that:
- Owns database tables: `tenant`, `address`, `person`, `contest_season`, `contest_level`, `contest_league`, `team`, `venue`, `venue_sub`, `contest_schedule`
- Enforces Row-Level Security (RLS) via PostgreSQL session variable `app.tenant_id`
- Provides CRUD endpoints for core domain entities
- Follows ADR-0006 (BFF→Proc→System architecture)

## Tech Stack

- **Runtime**: Node.js 18+ with TypeScript
- **Framework**: Express 4
- **Database**: PostgreSQL 16 with RLS
- **Validation**: Zod
- **Logging**: Pino (structured JSON)
- **Testing**: Vitest

## Prerequisites

- Node.js 18.18+
- PostgreSQL 16+
- Database schema applied via Flyway migrations (stored in `../flyway/db/migrations/`)

Docs:
- Local lab DB setup (recommended): `docs/LOCAL-LAB-DATABASE.md`

## Getting Started

```bash
# Install dependencies
npm install

# Copy environment configuration
cp .env.example .env
# Edit .env with your database credentials

# Run in development mode (with hot reload)
npm run dev

# If you hit EMFILE (too many open files) on Linux
# Option A: run without file watching
npm run dev:run
# Option B: build + run (no watch)
npm run build
npm start
# Option C: watch using polling (slower, but avoids some watcher limits)
npm run dev:poll

# Run tests
npm test

# Build for production
npm run build
npm start
```

## API Endpoints

All endpoints are mounted under the versioned base path: `/v1`.

### Health Check
- `GET /v1/health` - Service health and database connectivity

### Tenants
- `GET /tenants` - List all tenants (admin only)
- `GET /tenants/:id` - Get tenant by ID
- `POST /tenants` - Create new tenant (admin only)
- `PATCH /tenants/:id` - Update tenant
- `DELETE /tenants/:id` - Soft delete tenant (admin only)

### Contests (Levels, Leagues, Seasons)
- `GET /levels` - List contest levels (filtered by tenant)
- `POST /levels` - Create contest level
- `GET /leagues` - List leagues (filtered by tenant)
- `POST /leagues` - Create league
- `GET /seasons` - List seasons (filtered by tenant)
- `POST /seasons` - Create season

### Teams
- `GET /teams` - List teams (filtered by tenant)
- `POST /teams` - Create team
- `GET /teams/:id` - Get team details
- `PATCH /teams/:id` - Update team
- `DELETE /teams/:id` - Soft delete team

### Venues
- `GET /venues` - List venues (filtered by tenant)
- `POST /venues` - Create venue
- `GET /venues/:id` - Get venue with sub-venues
- `POST /venues/:id/sub-venues` - Add sub-venue
- `PATCH /venues/:id` - Update venue

### Contest Schedule
- `GET /contests` - List scheduled contests (filtered by tenant)
- `POST /contests` - Create contest entry
- `GET /contests/:id` - Get contest details
- `PATCH /contests/:id` - Update contest
- `DELETE /contests/:id` - Cancel contest

## Multi-Tenancy & RLS

All data access is isolated by tenant using PostgreSQL Row-Level Security. The middleware extracts `tenant_id` from the JWT token (or request header for testing) and sets the PostgreSQL session variable:

```sql
SELECT set_config('app.tenant_id', '1001', true);
```

RLS policies enforce that queries only return/modify data belonging to the current tenant (using `current_setting('app.tenant_id', true)`).

## Project Structure

```
src/
├── index.ts                 # Application entry point
├── config/
│   ├── database.ts          # PostgreSQL connection pool
│   └── env.ts               # Environment variable validation
├── middleware/
│   ├── tenantContext.ts     # Extract tenant_id, set session variable
│   ├── errorHandler.ts      # Global error handler
│   └── requestLogger.ts     # Request logging
├── routes/
│   ├── index.ts             # Main router
│   ├── health.ts            # Health check
│   ├── tenants.ts           # Tenant CRUD
│   ├── levels.ts            # Contest levels
│   ├── leagues.ts           # Leagues
│   ├── seasons.ts           # Seasons
│   ├── teams.ts             # Teams
│   ├── venues.ts            # Venues
│   └── contests.ts          # Contest schedule
├── services/
│   ├── tenantService.ts     # Tenant business logic
│   ├── contestService.ts    # Contest business logic
│   └── ...
└── types/
    └── index.ts             # Shared type definitions

tests/
├── unit/                    # Unit tests
└── integration/             # Integration tests with database
```

## Testing

```bash
# Run all tests
npm test

# Run with coverage
npm test -- --coverage

# Run integration tests only
npm run test:integration

# Watch mode
npm run test:watch
```

## Development

```bash
# Start with hot reload
npm run dev

# Lint code
npm run lint

# Format code
npm run format
```

## Environment Variables

See `.env.example` for all configuration options.

## Related Projects

- `contestgrid-fe` - Frontend (Vue 3 + Vuetify 4)
- `contestgrid-bff` - Backend for Frontend
- `contestgrid-proc-scheduling` - Scheduling workflow orchestration
- `contestgrid-system-officials` - Officials data ownership
- `contestgrid-system-billing` - Billing data ownership
