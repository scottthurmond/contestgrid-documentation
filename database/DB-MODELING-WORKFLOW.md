# Database Modeling Workflow (Open Source / Free)

This guide defines the standard process and toolchain for database design and documentation.

## Recommended Toolchain

- **pgModeler** (primary visual modeler for PostgreSQL)
  - Best for full ER modeling and PostgreSQL-specific features
  - Use for initial schema design and larger refactors
- **Flyway** (source of truth for schema changes)
  - All schema changes are committed as SQL migrations
  - Production/staging/dev stay aligned through versioned migrations
- **SchemaSpy** (auto-generated documentation from real database)
  - Publishes browsable schema docs with relationships and constraints
  - Run in CI/CD or on demand for up-to-date docs
- **Mermaid ER diagrams** (lightweight docs in ADRs/README)
  - Use for architecture communication and quick diagrams

## Why This Standard

- Visual modeling is fast during design discussions
- Flyway keeps real, executable schema history in Git
- SchemaSpy verifies and documents the actual deployed state
- Mermaid keeps docs readable in pull requests and ADRs

## Team Workflow

### 1) Model the Change

Use **pgModeler** to design new tables/relations and validate cardinality.

Output:
- Updated ERD screenshot/export (for PR context)
- Change notes (new tables, altered constraints, indexes)

### 2) Implement as Flyway Migration

Create a migration in `db/migrations/`:

- `V###__description.sql` for one-time schema changes
- `R__description.sql` for views/functions/procedures

Rules:
- One logical change per migration
- Never edit previously applied migration files
- Prefer idempotent SQL where practical (`IF EXISTS`, `IF NOT EXISTS`)

### 3) Validate Locally

Run:

```bash
cd ../flyway
flyway -configFiles=conf/flyway-local.conf validate
flyway -configFiles=conf/flyway-local.conf migrate
flyway -configFiles=conf/flyway-local.conf info
```

Then verify schema in PostgreSQL (or DBeaver if desired).

### 4) Publish Documentation

- Add/update Mermaid ER diagram in relevant ADR/feature doc
- Regenerate SchemaSpy docs against the latest schema
- Attach ERD or schema delta screenshot in PR

### 5) Promote Through Environments

- Migrate staging first
- Run smoke checks
- Backup production (Aurora snapshot)
- Migrate production via CI/CD

## Tool Selection Guidance

- Choose **pgModeler** when you need deep PostgreSQL modeling and constraint/index precision.
- Choose **DrawDB** for quick collaborative sketches and early ideation.
- Keep **DBeaver** for exploration and ad-hoc inspection, not as the primary design source.

## Minimum PR Checklist (Database Changes)

- [ ] Migration file added under `db/migrations/`
- [ ] `flyway validate` passes
- [ ] `flyway migrate` passes locally
- [ ] Index/constraint impact reviewed
- [ ] Tenant isolation / RLS impact reviewed (if applicable)
- [ ] Documentation updated (Mermaid + notes)

## Optional: SchemaSpy Automation

If you want auto-published schema docs, add a CI job that:

1. Spins up PostgreSQL
2. Applies Flyway migrations
3. Runs SchemaSpy
4. Publishes generated HTML as build artifact (or docs site)

## Related Documents

- [Flyway Database Migrations Quick Reference](FLYWAY-QUICKREF.md)
- [ADR-0021: Data Storage Architecture](adr/0021-data-storage-architecture.md)
- [API Security & Infrastructure Quick Reference](API-SECURITY-QUICKREF.md)
