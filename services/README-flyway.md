# Flyway (database migrations)

This folder centralizes Flyway configs, migration SQL, and Flyway-related docs for the ContestGrid workspace.

## Layout

- `conf/` Flyway config templates
- `db/migrations/` Versioned SQL migrations (`V###__*.sql`)
- `docs/` Flyway usage docs

## Quick start (local contest_lab)

From this folder:

```bash
# 1) Configure Flyway
cp conf/flyway-local.conf.example conf/flyway-local.conf
export FLYWAY_PASSWORD='...'

# 2) See status + run migrations
flyway -configFiles=conf/flyway-local.conf info
flyway -configFiles=conf/flyway-local.conf migrate
```

## Notes

- Do not commit real credentials. Prefer env-var placeholders like `${FLYWAY_PASSWORD}`.
