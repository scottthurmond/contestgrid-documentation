# Flyway Database Migrations - Quick Reference

Flyway is our database-as-code tool for version-controlled schema changes. All database migrations are tracked in Git and applied automatically across environments.

## 📚 Core Concepts

- **Versioned Migrations** (`V###__description.sql`): One-time schema changes (DDL, reference data)
- **Repeatable Migrations** (`R__description.sql`): Re-runnable objects (views, functions, procedures)
- **Undo Migrations** (`U###__description.sql`): Rollback scripts (optional, use sparingly)
- **Callbacks** (`beforeMigrate.sql`, `afterMigrate.sql`): Pre/post migration hooks

---

## 🚀 Quick Start

### Installation

```bash
# macOS
brew install flyway

# Windows
choco install flyway.commandline

# Linux
wget -qO- https://repo1.maven.org/maven2/org/flywaydb/flyway-commandline/10.8.1/flyway-commandline-10.8.1-linux-x64.tar.gz | tar xvz
sudo ln -s `pwd`/flyway-10.8.1/flyway /usr/local/bin

# Verify
flyway -v
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
    ├── R__*.sql
    └── ...
```

### Configuration Files

#### Local Development (`conf/flyway-local.conf`)
```properties
flyway.url=jdbc:postgresql://localhost:5432/contest_lab
flyway.user=contestgrid
flyway.password=${FLYWAY_PASSWORD}
flyway.schemas=public
flyway.locations=filesystem:./db/migrations
flyway.baselineOnMigrate=true
flyway.baselineVersion=0
flyway.encoding=UTF-8
flyway.validateOnMigrate=true
flyway.cleanDisabled=true
flyway.outOfOrder=false
```

#### Staging (`conf/flyway-staging.conf`)
```properties
flyway.url=jdbc:postgresql://staging-db.cluster-xyz.us-east-1.rds.amazonaws.com:5432/contestdb
flyway.user=flyway_migrator
flyway.password=${FLYWAY_STAGING_PASSWORD}
flyway.schemas=public
flyway.locations=filesystem:./db/migrations
flyway.validateOnMigrate=true
flyway.cleanDisabled=true
```

#### Production (`conf/flyway-production.conf`)
```properties
flyway.url=jdbc:postgresql://prod-db.cluster-abc.us-east-1.rds.amazonaws.com:5432/contestdb
flyway.user=flyway_migrator
flyway.password=${FLYWAY_PROD_PASSWORD}
flyway.schemas=public
flyway.locations=filesystem:./db/migrations
flyway.validateOnMigrate=true
flyway.cleanDisabled=true
flyway.outOfOrder=false
```

---

## 📝 Migration File Naming

### Versioned Migrations
**Pattern**: `V{version}__{description}.sql`

```
V001__create_tenants_table.sql
V002__create_users_table.sql
V010__add_billing_entities.sql
V011__enable_rls_on_leagues.sql
V020__add_contest_status_index.sql
```

**Version Numbers**:
- Sequential: `V1`, `V2`, `V3`, ... (simple projects)
- Timestamp: `V20260305120000` (YYYYMMDDHHmmss) (team collaboration)
- Semantic: `V01.02.003` (structured releases)

### Repeatable Migrations
**Pattern**: `R__{description}.sql`

```
R__standings_view.sql
R__official_metrics_view.sql
R__calculate_payouts_function.sql
R__audit_triggers.sql
```

---

## 🛠️ Common Commands

### Check Migration Status
```bash
# Show pending and applied migrations
flyway -configFiles=conf/flyway-local.conf info

# Output example:
# +-----------+---------+---------------------+------+---------------------+
# | Category  | Version | Description         | Type | Installed On        |
# +-----------+---------+---------------------+------+---------------------+
# | Versioned | 1       | create tenants      | SQL  | 2026-03-05 10:00:00 |
# | Versioned | 2       | create users        | SQL  | 2026-03-05 10:00:01 |
# | Pending   | 3       | add leagues         | SQL  |                     |
# +-----------+---------+---------------------+------+---------------------+
```

### Run Migrations
```bash
# Migrate to latest version
flyway -configFiles=conf/flyway-local.conf migrate

# Migrate to specific version
flyway -configFiles=conf/flyway-local.conf migrate -target=5

# Dry run (show SQL without executing)
flyway -configFiles=conf/flyway-local.conf migrate -dryRunOutput=migration-plan.sql
```

### Validate Migrations
```bash
# Validate applied migrations match source files
flyway -configFiles=conf/flyway-local.conf validate

# If checksums differ, you'll see:
# ERROR: Validate failed: Migration checksum mismatch
```

### Repair Metadata
```bash
# Fix checksum mismatches (use carefully!)
flyway -configFiles=conf/flyway-local.conf repair

# Use cases:
# - Migration file was edited after being applied (dev only!)
# - Failed migration needs to be marked as successful
# - Deleted migration file needs to be removed from history
```

### Baseline Existing Database
```bash
# Mark existing database as version 0 (skip earlier migrations)
flyway -configFiles=conf/flyway-local.conf baseline

# Baseline at specific version
flyway -configFiles=conf/flyway-local.conf baseline -baselineVersion=5
```

### Clean Database (Dev Only!)
```bash
# Drop all objects in schema (DANGEROUS!)
# Only works if cleanDisabled=false
flyway -configFiles=conf/flyway-local.conf clean

# ⚠️ NEVER use in staging or production!
```

---

## ✍️ Writing Migrations

### Example: Create Table
```sql
-- V001__create_tenants_table.sql
-- Description: Create tenants table for multi-tenancy
-- Author: DevTeam
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

COMMENT ON TABLE tenants IS 'Multi-tenant organizations (leagues, officials associations)';
```

### Example: Add Column
```sql
-- V010__add_timezone_to_tenants.sql
-- Description: Add timezone column for tenant-specific time display

ALTER TABLE tenants ADD COLUMN timezone VARCHAR(50) DEFAULT 'UTC';

UPDATE tenants SET timezone = 'America/New_York' WHERE id IN (
    -- List of specific tenants
);

ALTER TABLE tenants ALTER COLUMN timezone SET NOT NULL;
```

### Example: Create Index
```sql
-- V011__add_index_to_games_date.sql
-- Description: Improve query performance for games by date

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_games_date 
    ON games(game_date, tenant_id);

-- CONCURRENTLY avoids locking table during index creation
-- IF NOT EXISTS prevents errors if index already exists
```

### Example: Enable RLS
```sql
-- V012__enable_rls_on_leagues.sql
-- Description: Enable row-level security for tenant isolation

-- Enable RLS
ALTER TABLE leagues ENABLE ROW LEVEL SECURITY;

-- Create policy for tenant isolation
CREATE POLICY tenant_isolation_policy ON leagues
    USING (tenant_id = current_setting('app.tenant_id', true)::uuid);

-- Allow admin role to bypass RLS
CREATE POLICY admin_all_access ON leagues
    TO admin_role
    USING (true);

COMMENT ON POLICY tenant_isolation_policy ON leagues 
    IS 'Enforce tenant data isolation via RLS';
```

### Example: Repeatable View
```sql
-- R__standings_view.sql
-- Description: Team standings view (re-runnable)

CREATE OR REPLACE VIEW v_team_standings AS
SELECT 
    t.id AS team_id,
    t.name AS team_name,
    t.tenant_id,
    l.id AS league_id,
    l.name AS league_name,
    COUNT(g.id) AS games_played,
    SUM(CASE WHEN g.winner_id = t.id THEN 1 ELSE 0 END) AS wins,
    SUM(CASE WHEN g.winner_id != t.id AND g.winner_id IS NOT NULL THEN 1 ELSE 0 END) AS losses,
    SUM(CASE WHEN g.winner_id IS NULL AND g.status = 'completed' THEN 1 ELSE 0 END) AS ties,
    SUM(CASE WHEN g.winner_id = t.id THEN 3 WHEN g.winner_id IS NULL THEN 1 ELSE 0 END) AS points
FROM teams t
JOIN leagues l ON t.league_id = l.id
LEFT JOIN games g ON (g.home_team_id = t.id OR g.away_team_id = t.id)
    AND g.status = 'completed'
    AND g.tenant_id = t.tenant_id
GROUP BY t.id, t.name, t.tenant_id, l.id, l.name
ORDER BY points DESC, wins DESC, losses ASC;
```

---

## 🔄 Development Workflow

### Creating a New Migration

```bash
# 1. Create migration file with timestamp version
touch db/migrations/V$(date +%s)__add_contest_status_field.sql

# 2. Write your SQL
cat > db/migrations/V1709650800__add_contest_status_field.sql <<EOF
-- V1709650800__add_contest_status_field.sql
-- Description: Add status field to contests table

ALTER TABLE contests ADD COLUMN status VARCHAR(50) DEFAULT 'draft';
CREATE INDEX idx_contests_status ON contests(status);
EOF

# 3. Validate migration syntax
flyway -configFiles=conf/flyway-local.conf validate

# 4. Run migration locally
flyway -configFiles=conf/flyway-local.conf migrate

# 5. Verify in database
kubectl exec -n contestgrid contest-db-postgresql-0 -c postgresql -- \
  psql -U postgres -d contestdb -c "\d contests"

# 6. Commit to Git
git add db/migrations/
git commit -m "Add status field to contests table"
git push
```

### Testing Migrations

```bash
# Create test database
kubectl exec -n contestgrid contest-db-postgresql-0 -c postgresql -- \
  psql -U postgres -c "CREATE DATABASE contestdb_test;"

# Update flyway config to point to test DB
cat > flyway-test.conf <<EOF
flyway.url=jdbc:postgresql://localhost:5432/contestdb_test
flyway.user=postgres
flyway.password=localdevpassword
flyway.schemas=public
flyway.locations=filesystem:./db/migrations
EOF

# Run all migrations from scratch
flyway -configFiles=flyway-test.conf clean
flyway -configFiles=flyway-test.conf migrate

# Verify all tables created
kubectl exec -n contestgrid contest-db-postgresql-0 -c postgresql -- \
  psql -U postgres -d contestdb_test -c "\dt"
```

### Handling Migration Failures

```bash
# If migration fails mid-execution:
# 1. Check error message
flyway -configFiles=conf/flyway-local.conf info

# 2. If migration marked as failed, fix SQL and repair
# Edit: db/migrations/V010__problem_migration.sql

# 3. Repair metadata to allow re-run
flyway -configFiles=conf/flyway-local.conf repair

# 4. Re-run migration
flyway -configFiles=conf/flyway-local.conf migrate

# Alternative: Manually mark as successful (if SQL was partially applied)
kubectl exec -n contestgrid contest-db-postgresql-0 -c postgresql -- \
  psql -U postgres -d contestdb -c \
  "UPDATE flyway_schema_history SET success = true WHERE version = '10';"
```

---

## 🚀 CI/CD Integration

### GitHub Actions Workflow

```yaml
# .github/workflows/database-migration.yml
name: Database Migration

on:
  push:
    branches: [main]
    paths:
      - 'db/migrations/**'

jobs:
  migrate-staging:
    runs-on: ubuntu-latest
    environment: staging
    steps:
    - uses: actions/checkout@v4
    
    - name: Install Flyway
      run: |
        wget -qO- https://repo1.maven.org/maven2/org/flywaydb/flyway-commandline/10.8.1/flyway-commandline-10.8.1-linux-x64.tar.gz | tar xvz
        sudo ln -s `pwd`/flyway-10.8.1/flyway /usr/local/bin
    
    - name: Flyway Info (Pre-migration)
      run: flyway -configFiles=flyway-staging.conf info
      env:
        FLYWAY_PASSWORD: ${{ secrets.FLYWAY_STAGING_PASSWORD }}
    
    - name: Flyway Migrate (Staging)
      run: flyway -configFiles=flyway-staging.conf migrate
      env:
        FLYWAY_PASSWORD: ${{ secrets.FLYWAY_STAGING_PASSWORD }}
    
    - name: Verify Migration
      run: flyway -configFiles=flyway-staging.conf validate
      env:
        FLYWAY_PASSWORD: ${{ secrets.FLYWAY_STAGING_PASSWORD }}
    
    - name: Post Migration Info
      run: flyway -configFiles=flyway-staging.conf info
      env:
        FLYWAY_PASSWORD: ${{ secrets.FLYWAY_STAGING_PASSWORD }}

  migrate-production:
    runs-on: ubuntu-latest
    needs: migrate-staging
    environment: production
    steps:
    - uses: actions/checkout@v4
    
    - name: Install Flyway
      run: |
        wget -qO- https://repo1.maven.org/maven2/org/flywaydb/flyway-commandline/10.8.1/flyway-commandline-10.8.1-linux-x64.tar.gz | tar xvz
        sudo ln -s `pwd`/flyway-10.8.1/flyway /usr/local/bin
    
    - name: Backup Database (Aurora Snapshot)
      run: |
        aws rds create-db-cluster-snapshot \
          --db-cluster-identifier prod-contest-db \
          --db-cluster-snapshot-identifier prod-pre-migration-$(date +%Y%m%d-%H%M%S)
      env:
        AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
        AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        AWS_DEFAULT_REGION: us-east-1
    
    - name: Flyway Migrate (Production)
      run: flyway -configFiles=flyway-production.conf migrate
      env:
        FLYWAY_PASSWORD: ${{ secrets.FLYWAY_PROD_PASSWORD }}
    
    - name: Verify Migration
      run: flyway -configFiles=flyway-production.conf validate
      env:
        FLYWAY_PASSWORD: ${{ secrets.FLYWAY_PROD_PASSWORD }}
```

---

## 🏭 Production Deployment

### Pre-deployment Checklist
- [ ] All migrations tested in dev environment
- [ ] Migrations run successfully in staging
- [ ] Rollback plan documented (if applicable)
- [ ] Database backup taken (Aurora snapshot)
- [ ] Downtime window scheduled (if needed)
- [ ] Team notified of deployment
- [ ] Monitoring alerts configured

### Deployment Steps

```bash
# 1. Create pre-migration backup
aws rds create-db-cluster-snapshot \
  --db-cluster-identifier prod-contest-db \
  --db-cluster-snapshot-identifier prod-pre-migration-$(date +%Y%m%d-%H%M%S)

# 2. Check migration status (dry-run)
flyway -configFiles=flyway-production.conf info
# Review pending migrations

# 3. Execute migration
flyway -configFiles=flyway-production.conf migrate

# 4. Verify
flyway -configFiles=flyway-production.conf validate

# 5. Check migration history in database
psql -h prod-db.cluster-abc.us-east-1.rds.amazonaws.com \
     -U postgres -d contestdb \
     -c "SELECT installed_rank, version, description, success, installed_on 
         FROM flyway_schema_history 
         ORDER BY installed_rank DESC 
         LIMIT 5;"

# 6. Monitor application for errors
# Check CloudWatch logs, error rates, response times
```

---

## 🔍 Troubleshooting

### Checksum Mismatch
**Error**: `Migration checksum mismatch`

**Cause**: Migration file was edited after being applied

**Solution**:
```bash
# Option 1: Repair metadata (dev only!)
flyway -configFiles=conf/flyway-local.conf repair

# Option 2: Create new migration with fix (production)
# Never edit applied migrations in production!
```

### Failed Migration
**Error**: `Migration V010__add_column.sql failed`

**Solution**:
```bash
# 1. Check error details
flyway -configFiles=conf/flyway-local.conf info

# 2. Fix SQL in migration file
vim db/migrations/V010__add_column.sql

# 3. Repair and re-run (dev only)
flyway -configFiles=conf/flyway-local.conf repair
flyway -configFiles=conf/flyway-local.conf migrate

# Production: Create new migration to fix issue
```

### Out-of-Order Migration
**Error**: `Detected resolved migration not applied to database`

**Cause**: New migration has older version than last applied

**Solution**:
```bash
# Allow out-of-order (not recommended for production)
flyway -configFiles=conf/flyway-local.conf -outOfOrder=true migrate

# Better: Rename migration with newer version
mv V005__new_feature.sql V015__new_feature.sql
```

### Connection Failure
**Error**: `Unable to obtain connection from database`

**Solution**:
```bash
# Check database is running
kubectl get pods -n contestgrid -l app.kubernetes.io/name=postgresql

# Verify port forward is active
lsof -i :5432

# Restart port forward
kubectl port-forward -n contestgrid svc/contest-db-postgresql 5432:5432 &

# Test connection
psql -h localhost -U postgres -d contestdb -c "SELECT 1;"
```

---

## 📊 Best Practices

### ✅ Do's

- **Version Control**: Commit all migrations to Git
- **Sequential Versions**: Use timestamps or incremental numbers
- **One Change**: One logical change per migration
- **Idempotent**: Use `IF EXISTS`, `IF NOT EXISTS` where possible
- **Test First**: Always test in dev before staging/prod
- **Comments**: Document why and what changed
- **Peer Review**: Treat migrations like code
- **Backup**: Always backup before production migrations
- **Small Batches**: Deploy migrations frequently
- **Monitor**: Watch for errors post-migration

### ❌ Don'ts

- **Don't** edit applied migrations (breaks checksums)
- **Don't** delete applied migrations
- **Don't** run migrations manually in production
- **Don't** skip staging environment
- **Don't** use `flyway clean` in production
- **Don't** commit sensitive data in migrations
- **Don't** create large migrations without batching
- **Don't** ignore failed migrations
- **Don't** use non-idempotent SQL without planning
- **Don't** forget to test rollback procedures

---

## 🔗 References

- **Primary ADR**: [ADR-0021: Data Storage Architecture](adr/0021-data-storage-architecture.md) (Comprehensive Flyway section)
- **Flyway Documentation**: https://flywaydb.org/documentation/
- **Flyway CLI Commands**: https://flywaydb.org/documentation/usage/commandline/
- **PostgreSQL Documentation**: https://www.postgresql.org/docs/

## 🆘 Getting Help

```bash
# Flyway help
flyway -h

# Command-specific help
flyway migrate -h
flyway info -h

# Version
flyway -v
```
