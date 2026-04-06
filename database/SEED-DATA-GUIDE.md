# Seed Data Guide

Reference for the lab scenario data seeded by `V012__seed_lab_scenario_data.sql`.

---

## Quick Commands

```bash
cd flyway
export CONTEST_LAB_DB_PASSWORD='Wblot036'

# Check migration status
flyway -configFiles=conf/flyway-contest-lab.conf info

# Apply all pending migrations (including seed)
flyway -configFiles=conf/flyway-contest-lab.conf migrate

# Roll back the last migration (undo seed)
flyway -configFiles=conf/flyway-contest-lab.conf undo

# Verify counts after seeding
psql -h localhost -U contestgrid_lab_id -d contest_lab -c "
  SELECT 'tenants'  AS entity, count(*) FROM app.tenant
  UNION ALL SELECT 'persons',    count(*) FROM app.person
  UNION ALL SELECT 'officials',  count(*) FROM app.official
  UNION ALL SELECT 'teams',      count(*) FROM app.team
  UNION ALL SELECT 'venues',     count(*) FROM app.venue
  UNION ALL SELECT 'contests',   count(*) FROM app.contest_schedule
  UNION ALL SELECT 'rates',      count(*) FROM app.contest_rates
  ORDER BY entity;
"
```

---

## Scenario Overview

The seed creates a complete baseball scheduling scenario:

**"Metro Umpires Association" assigns officials to "Gwinnett Youth Baseball" games.**

| Entity | ID(s) | Details |
|--------|-------|---------|
| **Tenants** | 1, 2 | Metro Umpires Assoc (type=Officials Assoc), Gwinnett Youth Baseball (type=Sports League) |
| **Sports** | 1, 2, 3 | Baseball, Softball, Basketball |
| **Contest Types** | 1, 2, 3 | Regular Season, Playoff, Tournament |

---

## Entity Details

### Addresses (IDs 1–3)

| ID | Tenant | Address | Purpose |
|----|--------|---------|---------|
| 1 | 1 (MUA) | 100 Umpire Drive, Lawrenceville GA | Association HQ |
| 2 | 2 (GYB) | 200 Baseball Way, Dacula GA | League office |
| 3 | 2 (GYB) | 400 Bear Creek Road, Dacula GA | Park address |

### Persons (IDs 1–6)

| ID | Tenant | Type | Name | Email | Role |
|----|--------|------|------|-------|------|
| 1 | 1 (MUA) | Official | John Smith | john.smith@metro-umps.test | Official + Primary Assigner Admin |
| 2 | 1 (MUA) | Official | Mike Jones | mike.jones@metro-umps.test | Official |
| 3 | 1 (MUA) | Official | Sarah Davis | sarah.davis@metro-umps.test | Official |
| 4 | 1 (MUA) | Official | Chris Wilson | chris.wilson@metro-umps.test | Official |
| 5 | 2 (GYB) | Contact | Pat Johnson | admin@gwinnett-yb.test | League Director |
| 6 | 2 (GYB) | Payer | Robin Taylor | treasurer@gwinnett-yb.test | League Director |

### Officials (IDs 1–4)

| Official ID | Person | Uniform # | Joined |
|-------------|--------|-----------|--------|
| 1 | John Smith | 12 | 2020-03-15 |
| 2 | Mike Jones | 24 | 2021-01-10 |
| 3 | Sarah Davis | 36 | 2022-06-01 |
| 4 | Chris Wilson | 48 | 2023-02-20 |

### Officials Association

| ID | Name | Abbreviation | Address |
|----|------|--------------|---------|
| 1 | Metro Umpires Association | MUA | 100 Umpire Drive (address_id=1) |

### Contest Structure (all tenant 2 / GYB)

| Level ID | Name | Leagues |
|----------|------|---------|
| 1 | Rec | Rec 10U Baseball (id=1), Rec 12U Baseball (id=2) |
| 2 | Travel | Travel 10U Baseball (id=3), Travel 12U Baseball (id=4) |

**Seasons:**
- ID 1: Spring 2026 (Mar 1 – Jun 30)
- ID 2: Fall 2026 (Aug 1 – Nov 30)

### Teams (IDs 1–8, all tenant 2)

| ID | League | Level | Name |
|----|--------|-------|------|
| 1 | Rec 10U | Rec | Rec 10U Eagles |
| 2 | Rec 10U | Rec | Rec 10U Hawks |
| 3 | Rec 12U | Rec | Rec 12U Tigers |
| 4 | Rec 12U | Rec | Rec 12U Bears |
| 5 | Travel 10U | Travel | Travel 10U Storm |
| 6 | Travel 10U | Travel | Travel 10U Lightning |
| 7 | Travel 12U | Travel | Travel 12U Vipers |
| 8 | Travel 12U | Travel | Travel 12U Cobras |

### Venue

| Venue ID | Name | Sub-Venues |
|----------|------|------------|
| 1 | Bear Creek Park | Field 1 (main), Field 2 (60ft), Field 3 (50ft), Field 4 (practice) |

### Contest Rates (billing)

| Level | Bill Amount | Umpire Rate | Officials Required |
|-------|-------------|-------------|-------------------|
| Rec | $100.00 | $50.00 | 1 |
| Travel | $150.00 | $65.00 | 2 |

### Contest Schedule (April 5, 2026 — game day)

| ID | Time | Matchup | League | Field | Officials Needed |
|----|------|---------|--------|-------|-----------------|
| 1 | 9:00 AM | Eagles vs Hawks | Rec 10U | Field 1 | 1 |
| 2 | 11:00 AM | Tigers vs Bears | Rec 12U | Field 2 | 1 |
| 3 | 2:00 PM | Storm vs Lightning | Travel 10U | Field 1 | 2 |
| 4 | 4:00 PM | Vipers vs Cobras | Travel 12U | Field 3 | 2 |

**Total official slots needed: 6** (2 Rec × 1 + 2 Travel × 2)
**Available officials: 4** (John, Mike, Sarah, Chris)

---

## Tenant Mappings & Config

| Table | Data |
|-------|------|
| `officials_tenant_map` | MUA works with GYB for Baseball |
| `tenant_sport_map` | MUA → Baseball, Softball; GYB → Baseball |
| `tenant_person_map` | Officials → MUA; Contacts → GYB |
| `tenant_config` | Both default to Normal status / Regular Season |
| `tenant_license` | MUA: 50 licenses, free; GYB: 100 licenses, $29.99 |
| `tenant_pay_rate_map` | GYB uses rate plan 1 |

---

## API Verification Curls

```bash
# Core API — tenants, teams, venues, seasons, levels, leagues
curl -sk https://api.contestgrid.local:8443/v1/core/health | python3 -m json.tool
curl -sk https://api.contestgrid.local:8443/v1/tenants | python3 -m json.tool
curl -sk https://api.contestgrid.local:8443/v1/teams -H "X-Tenant-ID: 2" | python3 -m json.tool
curl -sk https://api.contestgrid.local:8443/v1/venues -H "X-Tenant-ID: 2" | python3 -m json.tool
curl -sk https://api.contestgrid.local:8443/v1/seasons -H "X-Tenant-ID: 2" | python3 -m json.tool
curl -sk https://api.contestgrid.local:8443/v1/levels -H "X-Tenant-ID: 2" | python3 -m json.tool
curl -sk https://api.contestgrid.local:8443/v1/leagues -H "X-Tenant-ID: 2" | python3 -m json.tool

# Officials API — officials, associations, bookings
curl -sk https://api.contestgrid.local:8443/v1/officials/health | python3 -m json.tool
curl -sk https://api.contestgrid.local:8443/v1/officials -H "X-Tenant-ID: 1" | python3 -m json.tool
curl -sk https://api.contestgrid.local:8443/v1/associations | python3 -m json.tool

# Billing API — rates, payments
curl -sk https://api.contestgrid.local:8443/v1/billing/health | python3 -m json.tool
curl -sk https://api.contestgrid.local:8443/v1/rates -H "X-Tenant-ID: 2" | python3 -m json.tool
curl -sk https://api.contestgrid.local:8443/v1/payments | python3 -m json.tool
```

---

## FK Dependency Order

When writing new seed migrations, insert in this order to satisfy foreign keys:

```
 1. sport, contest_type           (reference — no deps)
 2. tenant                        (depends on tenant_type)
 3. address                       (depends on tenant)
 4. person                        (depends on tenant, person_type)
 5. person_roles                  (depends on person, roles)
 6. officials_association         (depends on address)
 7. official_config               (no deps)
 8. official                      (depends on person, official_config)
 9. official_slots                (depends on officials_association, sport)
10. officials_tenant_map          (depends on officials_association, tenant, sport)
11. tenant_config/license/maps    (depends on tenant + referenced tables)
12. contest_season                (depends on tenant)
13. contest_level                 (depends on tenant, officials_association)
14. contest_league                (depends on tenant, officials_association, contest_level)
15. team                          (depends on tenant, contest_league, contest_level)
16. venue                         (depends on tenant, address, officials_association)
17. venue_sub                     (depends on venue)
18. contest_rates                 (depends on officials_association, tenant, sport, contest_level)
19. tenant_pay_rate_map           (depends on tenant)
20. contest_schedule              (depends on many — insert last)
```

For undo migrations, delete in **reverse** order (20 → 1).

---

## Writing New Seed Migrations

### Naming Convention
```
V013__seed_<description>.sql    # forward
U013__seed_<description>.sql    # undo (optional but recommended)
```

### Idempotency Pattern
Use `ON CONFLICT ... DO NOTHING` with explicit IDs, and reset sequences after:

```sql
INSERT INTO sport (sport_id, sport_name) VALUES
  (4, 'Soccer')
ON CONFLICT (sport_id) DO NOTHING;

SELECT setval(pg_get_serial_sequence('sport', 'sport_id'),
  GREATEST((SELECT COALESCE(MAX(sport_id), 1) FROM sport), 4), true);
```

### RLS Reminder
Tables with Row Level Security require `set_config('app.tenant_id', ...)` when queried by non-superuser roles. The Flyway user (`contestgrid_lab_id`) typically runs as the table owner and bypasses RLS, but keep this in mind if you create restricted roles.
