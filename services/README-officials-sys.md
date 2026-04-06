# ContestGrid - System API: Officials

**Data ownership for**: Officials, Associations, Certifications, Official Slots, Bookings

Part of the multi-tier architecture: **Frontend → BFF → Proc APIs → System APIs**

## Architecture

This is a **System API** (data ownership layer) that:
- Owns database tables: `officials_association`, `official_config`, `official`, `official_slots`, `bookings`
- Enforces Row-Level Security (RLS) via PostgreSQL session variable `app.tenant_id`
- Provides CRUD endpoints for officials domain
- Follows ADR-0006 (BFF→Proc→System architecture)

## API Endpoints

### Officials
- `GET /officials` - List officials (filtered by tenant)
- `POST /officials` - Create official
- `GET /officials/:id` - Get official details
- `PATCH /officials/:id` - Update official
- `DELETE /officials/:id` - Soft delete official

### Associations
- `GET /associations` - List officials associations
- `POST /associations` - Create association
- `GET /associations/:id` - Get association details

### Certifications
- `GET /certifications` - List certifications
- `POST /certifications` - Create certification
- `GET /officials/:id/certifications` - Get official's certs

### Bookings
- `GET /bookings` - List bookings (filtered by tenant)
- `POST /bookings` - Create booking
- `GET /bookings/:id` - Get booking details
- `PATCH /bookings/:id` - Update booking status

## Running

```bash
npm install
cp .env.example .env
# Edit .env with database credentials
npm run dev
```

Port: **3002**
