# ContestGrid - System API: Billing

**Data ownership for**: Contest Rates, Payments, Payroll, 1099-NEC

Part of the multi-tier architecture: **Frontend → BFF → Proc APIs → System APIs**

## Architecture

This is a **System API** (data ownership layer) that:
- Owns database tables: `contest_rates`, `tenant_pay_rate_map`, payment records, 1099 data
- Enforces Row-Level Security (RLS) via PostgreSQL session variable `app.tenant_id`
- Provides CRUD endpoints for billing domain
- Follows ADR-0006 (BFF→Proc→System architecture)

## API Endpoints

### Contest Rates
- `GET /rates` - List contest rates (filtered by tenant)
- `POST /rates` - Create rate schedule
- `GET /rates/:id` - Get rate details
- `PATCH /rates/:id` - Update rate

### Payments
- `GET /payments` - List payments
- `POST /payments` - Record payment
- `GET /payments/:id` - Get payment details

### 1099-NEC
- `GET /1099s` - List 1099 records
- `POST /1099s` - Generate 1099 record
- `GET /officials/:id/1099/:year` - Get official's 1099 for year

Port: **3003**
