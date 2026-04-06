# ADR 0021: Data Storage Architecture (Aurora PostgreSQL)

## Status
Accepted

## Context
Contest Schedule requires a relational database for multi-tenant SaaS with complex scheduling logic, leaderboards, and financial transactions. Must support current single-region MVP and eventual multi-region deployments. Team is AWS-focused and willing to learn PostgreSQL for domain-specific advantages.

## Decision
Use **Amazon Aurora PostgreSQL** (Serverless v2 for MVP, provisioned instances for scale). PostgreSQL chosen over MySQL for superior support of window functions (leaderboards/rankings), JSON/JSONB support, row-level security (RLS), and advanced query patterns (CTEs for tournament bracket generation).

## Database Stack

### Primary Database: Amazon Aurora PostgreSQL
**Version:** PostgreSQL 15+ (latest stable)
**Deployment:** 
- **MVP**: Aurora Serverless v2 (auto-scale, pay-per-second)
- **Scale**: Provisioned Aurora cluster with read replicas

**Why PostgreSQL over MySQL:**
1. **Window Functions**: native support for ROW_NUMBER(), RANK(), DENSE_RANK(), LAG(), LEAD()
   - Leaderboards/standings queries simpler and more performant
   - Officials ranking by reliability, game count, availability
2. **JSON/JSONB**: JSONB supports indexing and GIN/GIST operators for fast queries
   - Fee schedules with adjustments (nested structures)
   - Contract terms and configuration (flexible schema)
   - Query example: `WHERE fee_schedule @> '{"type": "discount"}'` (native JSON query)
3. **Row-Level Security (RLS)**: enforce multi-tenancy at DB level
   - CREATE POLICY statements prevent accidental cross-tenant data access
   - Defense-in-depth: app + DB layers
4. **Advanced Queries**: recursive CTEs, lateral joins
   - Tournament bracket generation (recursive parent-child relationships)
   - Hierarchical scheduling constraints (divisions → teams → games)
5. **Extensibility**: PostGIS (geospatial for location-based features), UUID types, range types

### Caching Layer: Amazon ElastiCache (Redis)
**Purpose:** session storage, query result caching, leaderboard caching
**Use Cases:**
- User sessions (faster than DB)
- Leaderboard snapshots (materialized, refreshed hourly)
- API response caching (standings, rankings, search results)
- Rate limit counters (per-tenant API quotas)

**Deployment:** Single Redis cluster (primary + replicas for failover)

### Search & Analytics: Amazon OpenSearch (Optional, Phase 2)
**Purpose:** full-text search, read models for dashboards
**Use Cases:**
- Search officials, leagues, teams, venues, schedules
- Aggregated metrics (official workload, game volume, no-show rates)
- Real-time analytics for dashboards

**Deployment:** Managed OpenSearch domain with multiple nodes

## Multi-Tenancy Strategy

### Approach: Row-Level Security (RLS) + Row-Level Filtering
**Rationale:** Simpler operational model than schema-per-tenant; shared infrastructure reduces costs; RLS enforces isolation.

**Implementation:**
```sql
-- Add tenant_id to all tables
ALTER TABLE leagues ADD COLUMN tenant_id UUID;
ALTER TABLE officials ADD COLUMN tenant_id UUID;
ALTER TABLE games ADD COLUMN tenant_id UUID;

-- Create RLS policy
CREATE POLICY tenant_isolation ON leagues
  USING (tenant_id = current_setting('app.tenant_id')::uuid);

-- Enable RLS
ALTER TABLE leagues ENABLE ROW LEVEL SECURITY;

-- On app connection, set tenant context
SET app.tenant_id = '<current-tenant-uuid>';
```

**Advantages:**
- Single database/schema (simpler operations)
- Shared infrastructure (cost-efficient)
- Easy tenant onboarding (add rows, no schema changes)
- Easier analytics across tenants (if needed for platform dashboards)

**Disadvantages:**
- Must ensure every query includes tenant_id filter (app responsibility)
- Backup/restore per-tenant harder (full DB or custom tools)

**Mitigation:**
- Use shared library for query builders (enforce tenant_id filter)
- ORM with tenant-aware context (Sequelize, TypeORM, Prisma)
- Code review for any raw SQL

### Alternative Rejected: Schema-Per-Tenant
- Pros: perfect isolation, simpler security audit
- Cons: operational nightmare (100+ tenants = 100+ schemas), schema migrations per tenant, backup complexity, higher infrastructure cost
- Not recommended for MVP/scale phase

## Data Model Overview

**Core Entities:**
- `Tenants`: league/officials org metadata, billing config, branding, settings
- `Users`: admin, coordinators, officials, viewers
- `Leagues`: league/organization details
- `Teams`: teams within leagues
- `Divisions`: divisions (age groups, skill levels)
- `Venues`: game venues
- `Games`: scheduled games with state (scheduled, played, cancelled)
- `Officials`: official registry per tenant
- `Assignments`: official → game mapping with confirmation status
- `Availability`: official availability calendar
- `PayRates`: pay rates per official/game type
- `PayPeriods`: billing periods (monthly, yearly)
- `PayStubs`: official earnings statements
- `Invoices`: tenant billing invoices
- `Contracts`: lease/service agreements
- `OfficialSubscriptions`: yearly subscription per official per tenant
- `AuditLog`: immutable event log

**Relationships:**
- Tenants -< Leagues -< Teams, Divisions, Venues, Games
- Tenants -< Officials -< Availability, Assignments, Subscriptions, PayStubs
- Tenants -< Invoices, Contracts, PayRates

**Indexing Strategy:**
- Primary: tenant_id, user_id, league_id, official_id (for RLS + filtering)
- Foreign keys: all relationships
- Business logic: game start_date, official availability_date, invoice due_date
- Search: league.name, team.name, official.name (for full-text or prefix search)
- Analytics: assignment status, game outcome, subscription status

## Scaling & Performance

### Phase 1 (MVP): Serverless v2
- **Capacity**: 0.5–2 ACUs (Aurora Compute Units), auto-scale based on load
- **Cost**: ~$100–400/month (variable based on usage)
- **Suitable for**: <10K games/month, <1K active leagues, MVP validation

### Phase 2 (Early Scale): Provisioned Cluster
- **Primary**: db.r6g.large (2 vCPU, 16GB RAM) or similar
- **Read Replicas**: 1–2 additional instances for read scaling
- **Cost**: ~$500–1.5K/month depending on instance types
- **Suitable for**: 50K–500K games/month, 10K+ officials, growing tenant base

### Phase 3 (High Scale): Horizontal Scaling
- Upgrade to larger instances (db.r6g.xlarge or db.r6g.2xlarge)
- Add more read replicas per region
- Consider sharding if single DB becomes bottleneck (years away)
- Estimated timeline: 3–5 years

### Connection Pooling
**Tool**: PgBouncer or Amazon RDS Proxy
**Purpose**: limit concurrent connections to DB (PostgreSQL max ~200 by default, but resource-constrained)
**Deployment**: Lambda function or EC2 instance proxy

**Configuration:**
- Pool size: (# connections) = (app instances × avg connections per app)
- Mode: transaction pooling (safest for serverless)
- Idle timeout: 5–10 minutes

## Backup & Disaster Recovery

### Automated Backups
- **Frequency**: continuous binary logging (Aurora), snapshots retained 35 days (configurable)
- **RPO**: <1 minute (recovery point objective)
- **RTO**: <5 minutes (recovery time objective)

### Multi-Region Replication (Future, Phase 3+)
- Aurora Global Database (asynchronous replication)
- Read replica in secondary region (us-west-2, eu-west-1, etc.)
- Failover: ~1 minute RTO, <5s RPO

### Backup Testing
- Monthly restore test to separate account
- Document restore procedure and timeline
- Rotate testing across tenants

## Encryption

### At Rest
- Aurora encryption (AWS KMS): default enabled
- Encrypted snapshots: automated

### In Transit
- TLS 1.2+ for all connections
- SSL certificate validation (RDS endpoint)
- Enforce require_secure_transport in PostgreSQL config

### Field-Level Encryption (Sensitive Data)
- Encrypt PII before storing (SSN, bank account numbers)
- Use app-level encryption with AWS KMS for decryption keys
- Store encrypted blobs in bytea columns

## Monitoring & Maintenance

### CloudWatch Metrics
- CPU utilization, memory, storage, connections
- Query performance insights (RDS Performance Insights)
- Replication lag (if applicable)

### Alerts
- High CPU/memory (>80%)
- Connection pool exhaustion
- Replication lag >1s
- Failed backups

### Maintenance Windows
- Monthly patching (minor versions): 30-min downtime (Aurora minimized)
- Major version upgrades (annual): test in dev environment first

### Cost Optimization
- Serverless v2: scales down during idle periods
- Reserved instances (Phase 2+): 30–40% discount for 1–3 year commitment
- Automated snapshots cleanup (delete old snapshots)

## Database Migrations with Flyway

### Tool: Flyway (Database as Code)
**Version**: Flyway 10+
**Purpose**: Version-controlled database schema migrations
**Why Flyway**: 
- SQL-first approach (familiar for DBAs and developers)
- Version control integration (migrations tracked in Git)
- Repeatable migrations for views, procedures, functions
- Rollback support (undo migrations)
- Baseline support for existing databases
- Team collaboration (prevents migration conflicts)
- Production-ready with enterprise features

### Migration Strategy

#### Versioned Migrations (V-prefix)
**Purpose**: Schema changes (DDL), reference data
**Naming Convention**: `V{version}__{description}.sql`
**Examples**:
- `V001__create_tenants_table.sql`
- `V002__create_users_table.sql`
- `V003__add_tenant_id_to_leagues.sql`
- `V004__enable_rls_on_leagues.sql`
- `V010__create_billing_entities.sql`

**Structure**:
```sql
-- V001__create_tenants_table.sql
-- Description: Create tenants table with multi-tenancy support
-- Author: Team
-- Date: 2026-03-05

CREATE TABLE tenants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    subdomain VARCHAR(100) NOT NULL UNIQUE,
    status VARCHAR(50) DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_tenants_subdomain ON tenants(subdomain);
CREATE INDEX idx_tenants_status ON tenants(status);

-- Audit trigger
CREATE TRIGGER update_tenants_updated_at
    BEFORE UPDATE ON tenants
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE tenants IS 'Multi-tenant organizations (leagues, officials associations)';
```

#### Repeatable Migrations (R-prefix)
**Purpose**: Views, stored procedures, functions (can be re-run)
**Naming Convention**: `R__{description}.sql`
**Examples**:
- `R__standings_view.sql`
- `R__calculate_official_metrics.sql`
- `R__audit_functions.sql`

**Structure**:
```sql
-- R__standings_view.sql
-- Description: Materialized view for team standings
-- Can be safely re-run to update logic

CREATE OR REPLACE VIEW v_team_standings AS
SELECT 
    t.id AS team_id,
    t.name AS team_name,
    l.id AS league_id,
    COUNT(g.id) AS games_played,
    SUM(CASE WHEN g.winner_id = t.id THEN 1 ELSE 0 END) AS wins,
    SUM(CASE WHEN g.winner_id != t.id AND g.winner_id IS NOT NULL THEN 1 ELSE 0 END) AS losses,
    SUM(CASE WHEN g.winner_id IS NULL AND g.status = 'completed' THEN 1 ELSE 0 END) AS ties
FROM teams t
JOIN leagues l ON t.league_id = l.id
LEFT JOIN games g ON (g.home_team_id = t.id OR g.away_team_id = t.id)
    AND g.status = 'completed'
GROUP BY t.id, t.name, l.id
ORDER BY wins DESC, losses ASC;
```

#### Undo Migrations (U-prefix, Optional)
**Purpose**: Rollback versioned migrations
**Naming Convention**: `U{version}__{description}.sql`
**Example**: `U003__drop_tenant_id_from_leagues.sql`

**Note**: Use sparingly; forward-only migrations preferred in production.

### Flyway Configuration

#### flyway.conf (or flyway.toml)
```properties
# Flyway configuration for Contest Schedule
flyway.url=jdbc:postgresql://localhost:5432/contestdb
flyway.user=postgres
flyway.password=${FLYWAY_PASSWORD}
flyway.schemas=public
flyway.locations=filesystem:./db/migrations
flyway.baselineOnMigrate=true
flyway.baselineVersion=0
flyway.encoding=UTF-8
flyway.placeholderReplacement=true
flyway.validateOnMigrate=true
flyway.cleanDisabled=true  # Prevent accidental data loss
flyway.outOfOrder=false  # Enforce sequential migrations
```

#### Environment-Specific Configs
```bash
# flyway-local.conf (local Rancher Desktop)
flyway.url=jdbc:postgresql://localhost:5432/contestdb
flyway.user=postgres
flyway.password=localdevpassword

# flyway-staging.conf
flyway.url=jdbc:postgresql://staging-db.cluster-xyz.us-east-1.rds.amazonaws.com:5432/contestdb
flyway.user=flyway_migrator
flyway.password=${FLYWAY_STAGING_PASSWORD}

# flyway-production.conf
flyway.url=jdbc:postgresql://prod-db.cluster-abc.us-east-1.rds.amazonaws.com:5432/contestdb
flyway.user=flyway_migrator
flyway.password=${FLYWAY_PROD_PASSWORD}
```

### Directory Structure
```
flyway/
├── conf/
│   ├── flyway-local.conf
│   ├── flyway-remote.conf
│   └── ...
└── db/
   └── migrations/
      ├── V001__create_*.sql
      ├── V002__create_*.sql
      └── ...
```

### Flyway Commands

#### Development Workflow
```bash
# Run Flyway from the consolidated workspace folder
cd ../flyway

# Check migration status
flyway -configFiles=conf/flyway-local.conf info

# Validate migrations
flyway -configFiles=conf/flyway-local.conf validate

# Run pending migrations
flyway -configFiles=conf/flyway-local.conf migrate

# Repair metadata table (if checksums differ)
flyway -configFiles=conf/flyway-local.conf repair

# Baseline existing database
flyway -configFiles=conf/flyway-local.conf baseline

# Generate migration report
flyway -configFiles=conf/flyway-local.conf info > migration-status.txt
```

#### CI/CD Integration
```yaml
# GitHub Actions example
name: Database Migration
on:
  push:
    branches: [main]
    paths:
      - 'db/migrations/**'

jobs:
  migrate:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    
    - name: Install Flyway
      run: |
        wget -qO- https://repo1.maven.org/maven2/org/flywaydb/flyway-commandline/10.8.1/flyway-commandline-10.8.1-linux-x64.tar.gz | tar xvz
        sudo ln -s `pwd`/flyway-10.8.1/flyway /usr/local/bin
    
    - name: Run Flyway Info (Pre-migration)
      run: flyway -configFiles=flyway-staging.conf info
      env:
        FLYWAY_PASSWORD: ${{ secrets.FLYWAY_STAGING_PASSWORD }}
    
    - name: Run Flyway Migrate (Staging)
      run: flyway -configFiles=flyway-staging.conf migrate
      env:
        FLYWAY_PASSWORD: ${{ secrets.FLYWAY_STAGING_PASSWORD }}
    
    - name: Verify Migration
      run: flyway -configFiles=flyway-staging.conf validate
      env:
        FLYWAY_PASSWORD: ${{ secrets.FLYWAY_STAGING_PASSWORD }}
```

### Multi-Tenancy Considerations

**Approach**: Single schema with RLS (tenant_id column)
**Flyway Strategy**: 
- All migrations apply to shared schema
- Tenant-specific data seeded via application (not migrations)
- RLS policies defined in versioned migrations

**Example RLS Migration**:
```sql
-- V006__enable_rls_on_leagues.sql

-- Enable RLS on leagues table
ALTER TABLE leagues ENABLE ROW LEVEL SECURITY;

-- Create policy for tenant isolation
CREATE POLICY tenant_isolation_policy ON leagues
    USING (tenant_id = current_setting('app.tenant_id', true)::uuid);

-- Allow bypass for service accounts (with bypassrls role)
CREATE POLICY admin_all_access ON leagues
    TO admin_role
    USING (true);

COMMENT ON POLICY tenant_isolation_policy ON leagues IS 'Enforce tenant data isolation via RLS';
```

### Team Workflow

#### Creating a New Migration
1. Generate migration file:
   ```bash
   # Use naming convention
   touch db/migrations/V$(date +%s)__add_contest_status_field.sql
   ```

2. Write migration SQL:
   ```sql
   ALTER TABLE contests ADD COLUMN status VARCHAR(50) DEFAULT 'draft';
   CREATE INDEX idx_contests_status ON contests(status);
   ```

3. Test locally:
   ```bash
   cd ../flyway
   flyway -configFiles=conf/flyway-local.conf migrate
   ```

4. Commit and push:
   ```bash
   git add db/migrations/
   git commit -m "Add status field to contests table"
   git push
   ```

#### Handling Conflicts
- **Prevention**: Communicate schema changes in team channel
- **Resolution**: If two developers create migrations simultaneously, rename with sequential versions
- **Flyway**: Will detect and apply in version order

### Production Deployment

#### Pre-deployment Checklist
- [ ] All migrations tested in dev environment
- [ ] Migrations run successfully in staging
- [ ] Rollback plan documented (if applicable)
- [ ] Database backup taken (Aurora snapshot)
- [ ] Downtime window scheduled (if needed)
- [ ] Team notified of deployment

#### Deployment Steps
1. **Pre-migration backup**:
   ```bash
   aws rds create-db-cluster-snapshot \
     --db-cluster-identifier prod-contest-db \
     --db-cluster-snapshot-identifier prod-pre-migration-$(date +%Y%m%d-%H%M%S)
   ```

2. **Run Flyway info** (dry-run check):
   ```bash
   flyway -configFiles=flyway-production.conf info
   ```

3. **Execute migration**:
   ```bash
   flyway -configFiles=flyway-production.conf migrate
   ```

4. **Verify**:
   ```bash
   flyway -configFiles=flyway-production.conf validate
   psql -h prod-db.cluster-abc.us-east-1.rds.amazonaws.com -U postgres -d contestdb -c "SELECT * FROM flyway_schema_history ORDER BY installed_rank DESC LIMIT 5;"
   ```

5. **Monitor application** for errors post-migration

#### Rollback Strategy
- **Option 1**: Restore from snapshot (data loss risk)
- **Option 2**: Run undo migration (if available)
- **Option 3**: Forward fix (new migration to revert changes)

**Recommended**: Forward fixes for production

### Best Practices

✅ **Version Control**: All migrations committed to Git
✅ **Sequential Versions**: Use timestamps or sequential numbers
✅ **Idempotent**: Use `CREATE TABLE IF NOT EXISTS`, `DROP INDEX IF EXISTS`
✅ **Small Changes**: One logical change per migration
✅ **Test First**: Always test in dev before staging/prod
✅ **No Rollbacks in Prod**: Use forward-only migrations
✅ **Comments**: Document why and what changed
✅ **Peer Review**: Migrations reviewed like code
✅ **Backup**: Always backup before production migrations
✅ **Monitoring**: Watch for errors post-migration

❌ **Avoid**: 
- Data loss operations without backup
- Modifying applied migrations (breaks checksums)
- Running migrations manually in production
- Skipping staging environment
- Large migrations without batching

## Migrations & Compliance

### Data Export (Tenant Portability)
- pg_dump for full tenant export (schema + data filtered by tenant_id)
- CSV export for reports (admin-initiated)
- GDPR right-to-data: automated export within 30 days

### Schema Evolution with Flyway
- **Migrations tool**: Flyway 10+ (SQL-first, version controlled)
- **Version control**: Git-tracked migrations in `db/migrations/`
- **Testing**: Automated migration tests on each PR (CI/CD)
- **Deployment**: Flyway CLI in GitHub Actions for staging/production
- **Rollback**: Forward-only migrations preferred; undo migrations for emergencies
- **Documentation**: See Flyway section above for full details

### Compliance
- Encryption at rest + in transit: ✓
- Audit logging: application level (immutable audit table)
- GDPR: data export, deletion workflows, retention policies
- Backups: retained per data classification (7y financial, 3y general)

## Consequences
- **Pros**: PostgreSQL's advanced features simplify complex queries; RLS provides defense-in-depth; Aurora is fully managed (less ops burden); cost-effective at MVP scale; clear upgrade path
- **Cons**: PostgreSQL learning curve (mitigated by good docs); RLS requires discipline in app code; future schema migrations require planning
