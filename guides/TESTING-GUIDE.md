# Quick Start: Testing System API: Core

## Prerequisites

1. PostgreSQL running at `192.168.68.20:5432`
2. Database `contest_dev` with migrations applied (V001-V011)
3. Node.js 18+ installed

## Setup

```bash
cd /home/scott/projects/contestgrid/contestgrid-core-sys
npm install
cp .env.example .env
```

## Configure .env

Edit `.env` with your database credentials:

```
DB_HOST=192.168.68.20
DB_PORT=5432
DB_NAME=contest_dev
DB_USER=postgres
DB_PASSWORD=<your-password>
DB_SSL_MODE=require
NODE_ENV=development
```

## Start the Server

```bash
npm run dev
```

You should see:
```
✅ Database connected: contest_dev
✅ System API: Core listening on http://localhost:3001
```

## Test Basic Health

```bash
curl http://localhost:3001/v1/health
```

Expected response:
```json
{
  "service": "contestgrid-system-core",
  "status": "healthy",
  "timestamp": "2026-03-05T...",
  "uptime": 2.345,
  "database": {
    "connected": true
  }
}
```

## Test Tenant Endpoints

### Get All Tenants
```bash
curl http://localhost:3001/v1/tenants
```

### Get Specific Tenant
```bash
curl http://localhost:3001/v1/tenants/1001
```

### Create Tenant
```bash
curl -X POST http://localhost:3001/v1/tenants \
  -H "Content-Type: application/json" \
  -d '{
    "tenantName": "New League",
    "tenantAbbreviation": "NL",
    "tenantTypeId": 1
  }'
```

## Test Tenant-Scoped Endpoints

All these endpoints require the `X-Tenant-ID` header:

### Get All Levels (for tenant 1001)
```bash
curl -H "X-Tenant-ID: 1001" http://localhost:3001/v1/levels
```

### Create a Level
```bash
curl -X POST http://localhost:3001/v1/levels \
  -H "X-Tenant-ID: 1001" \
  -H "Content-Type: application/json" \
  -d '{
    "levelName": "U12 Division",
    "officialsAssociationId": 1
  }'
```

### Create a Season
```bash
curl -X POST http://localhost:3001/v1/seasons \
  -H "X-Tenant-ID: 1001" \
  -H "Content-Type: application/json" \
  -d '{
    "seasonName": "Spring 2026",
    "startDate": "2026-03-01T00:00:00Z",
    "endDate": "2026-05-31T00:00:00Z"
  }'
```

### Create a League
```bash
curl -X POST http://localhost:3001/v1/leagues \
  -H "X-Tenant-ID: 1001" \
  -H "Content-Type: application/json" \
  -d '{
    "levelId": 1,
    "leagueName": "Recreational League - U10",
    "officialsAssociationId": 1
  }'
```

### Create a Team
```bash
curl -X POST http://localhost:3001/v1/teams \
  -H "X-Tenant-ID: 1001" \
  -H "Content-Type: application/json" \
  -d '{
    "leagueId": 1,
    "levelId": 1,
    "teamName": "Tigers"
  }'
```

### Create a Venue
```bash
curl -X POST http://localhost:3001/v1/venues \
  -H "X-Tenant-ID: 1001" \
  -H "Content-Type: application/json" \
  -d '{
    "venueName": "Central Park",
    "addressId": 1,
    "officialsAssociationId": 1
  }'
```

### Create a Sub-Venue
```bash
curl -X POST http://localhost:3001/v1/venues/1/sub-venues \
  -H "X-Tenant-ID: 1001" \
  -H "Content-Type: application/json" \
  -d '{
    "subVenueName": "Field A",
    "subVenueDesc": "North field"
  }'
```

### Get Venues with Sub-Venues
```bash
curl -H "X-Tenant-ID: 1001" http://localhost:3001/v1/venues/1/sub-venues
```

## Run Integration Tests

```bash
# Run all integration tests
npm run test:integration

# Run all tests (unit + integration)
npm test

# Watch mode
npm run test:watch
```

## Expected Test Output

```
System API: Core - Integration Tests
  Health Endpoint
    ✓ GET /v1/health should return 200 with service status
  Tenants Endpoint
    ✓ GET /v1/tenants should return list of tenants
    ✓ GET /v1/tenants/:id should return specific tenant
    ✓ GET /v1/tenants/:id should return 404 for non-existent tenant
  Levels Endpoint
    ✓ GET /v1/levels should require tenant context
    ✓ GET /v1/levels should return levels with tenant context
  Seasons Endpoint
    ✓ GET /v1/seasons should return seasons with tenant context
    ✓ POST /v1/seasons should create new season
```

## Database Verification

To verify data was created in the database:

```sql
-- Connect to contest_dev database
psql -h 192.168.68.20 -U postgres -d contest_dev

-- Set tenant context
SET app.tenant_id = '1001';

-- Check tenants
SELECT * FROM tenant;

-- Check levels
SELECT * FROM contest_level;

-- Check seasons
SELECT * FROM contest_season;

-- Check teams
SELECT * FROM team;

-- Check venues
SELECT * FROM venue;
```

## Common Issues & Solutions

### Issue: "Failed to connect to database"

**Check**:
1. PostgreSQL is running: `psql -h 192.168.68.20 -U postgres -c "SELECT version();"`
2. Database exists: `psql -h 192.168.68.20 -U postgres -l | grep contest_dev`
3. Migrations applied: `psql -h 192.168.68.20 -U postgres -d contest_dev -c "\dt"` (should show 19+ tables)
4. User has access: `psql -h 192.168.68.20 -U postgres -d contest_dev -c "SELECT * FROM tenant LIMIT 1;"`

### Issue: "SSL error"

**Solution**: Edit `.env`:
```
DB_SSL_MODE=prefer
```

### Issue: "Tenant ID is required"

**Solution**: Add header to tenant-scoped endpoints:
```bash
-H "X-Tenant-ID: 1001"
```

## API Reference Summary

| Endpoint | Method | Tenant-Scoped | Description |
|----------|--------|---------------|-------------|
| /v1/health | GET | No | Health check |
| /v1/tenants | GET | No | List all tenants |
| /v1/tenants | POST | No | Create tenant |
| /v1/tenants/:id | GET/PATCH | No | Get/update tenant |
| /v1/levels | GET/POST | Yes | Levels CRUD |
| /v1/levels/:id | PATCH/DELETE | Yes | Update/delete level |
| /v1/seasons | GET/POST | Yes | Seasons CRUD |
| /v1/seasons/:id | PATCH/DELETE | Yes | Update/delete season |
| /v1/leagues | GET/POST | Yes | Leagues CRUD |
| /v1/leagues/:id | PATCH/DELETE | Yes | Update/delete league |
| /v1/teams | GET/POST | Yes | Teams CRUD |
| /v1/teams/:id | PATCH/DELETE | Yes | Update/delete team |
| /v1/venues | GET/POST | Yes | Venues CRUD |
| /v1/venues/:id | PATCH/DELETE | Yes | Update/delete venue |
| /v1/venues/:id/sub-venues | GET/POST | Yes | Sub-venue management |

## What's Next?

- See [DAY1-SUMMARY.md](./DAY1-SUMMARY.md) for complete implementation details
- Check [ARCHITECTURE.md](../ARCHITECTURE.md) for the full project roadmap
- Day 2: Implement System API: Officials and System API: Billing
