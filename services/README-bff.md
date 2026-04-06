# ContestGrid - BFF (Backend for Frontend)

**Responsibilities**: API aggregation, authentication, caching, frontend-specific endpoints

Part of the multi-tier architecture: **Frontend → BFF → Proc APIs → System APIs**

## Architecture

This is the **BFF layer** that:
- Provides frontend-optimized API endpoints
- Handles Cognito JWT authentication
- Extracts tenant context from JWT tokens
- Aggregates data from multiple downstream services
- Implements caching for performance
- Normalizes responses for frontend consumption
- Follows ADR-0006 (BFF→Proc→System architecture)

## Key Features

### Authentication
- Validates Cognito JWT tokens
- Extracts user identity and tenant_id from JWT claims
- Propagates tenant context to downstream services
- Implements RBAC (Admin, League Director, Coach, Official)

### Aggregation
- Combines data from multiple System/Proc APIs
- Example: `GET /contests/:id` fetches contest + venue + teams + officials in one call
- Reduces frontend roundtrips

### Caching
- In-memory cache for reference data (levels, sports, roles)
- Short-lived cache for frequently accessed data
- Cache invalidation strategies

### Frontend Optimization
- Pagination, sorting, filtering tailored to UI needs
- Response shaping (only return fields frontend needs)
- Error normalization

## API Endpoints

### Auth
- `POST /auth/login` - Mock login (returns JWT)
- `GET /me` - Current user info
- `POST /auth/refresh` - Refresh JWT token

### Contests (Aggregated)
- `GET /contests` - List contests with venue + teams
- `GET /contests/:id` - Contest details + officials + venue
- `POST /contests` - Create contest (calls Proc API)

### Dashboard
- `GET /dashboard/overview` - Aggregated dashboard data
- `GET /dashboard/contests/upcoming` - Upcoming contests
- `GET /dashboard/officials/available` - Available officials

### Officials
- `GET /officials` - List officials (proxies to System API)
- `GET /officials/:id` - Official details + certifications + bookings

Port: **3000**

## Dependencies

Calls:
- `contestgrid-system-core` (port 3001)
- `contestgrid-system-officials` (port 3002)
- `contestgrid-system-billing` (port 3003)
- `contestgrid-proc-scheduling` (port 3004)
- `contestgrid-proc-billing` (port 3005)

## Running

```bash
npm install
cp .env.example .env
# Edit .env with service URLs and Cognito config
npm run dev
```

Frontend connects to: **http://localhost:3000**
