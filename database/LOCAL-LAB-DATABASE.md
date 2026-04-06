# Local lab database (contest_lab) + Flyway

This page documents how to run **System API: Core** against a **local PostgreSQL database** named `contest_lab` using the repo’s Flyway migrations.

## Why this exists

We previously hit remote DB connectivity blockers (e.g. `pg_hba.conf` host restrictions). A local lab DB removes that dependency and makes Day 1 flows repeatable.

## What you’ll use

- PostgreSQL 16+ running locally
- Flyway CLI (recommended) OR a Flyway Docker image
- Migrations live in `flyway/db/migrations/`

> Note: Flyway configs and migrations live under `flyway/` in this workspace.

---

## 1) Start PostgreSQL locally (Docker option)

```bash
docker volume create contestgrid_pgdata

docker run --name contestgrid-postgres \
  -e POSTGRES_USER=contestgrid \
  -e POSTGRES_PASSWORD=contestgrid \
  -e POSTGRES_DB=contest_lab \
  -p 5432:5432 \
  -v contestgrid_pgdata:/var/lib/postgresql/data \
  -d postgres:16

psql "postgresql://contestgrid:contestgrid@localhost:5432/contest_lab" \
  -c "select current_database(), current_user, version();"
```

If you’re running Postgres natively, the important bits are:
- database name: `contest_lab`
- user/password: whatever you choose
- TCP port: `5432`

---

## 2) Run Flyway migrations into contest_lab

### Recommended: Flyway CLI

1) Install Flyway (Linux example):

```bash
wget -qO- https://repo1.maven.org/maven2/org/flywaydb/flyway-commandline/10.8.1/flyway-commandline-10.8.1-linux-x64.tar.gz | tar xvz
sudo ln -s "$(pwd)"/flyway-10.8.1/flyway /usr/local/bin/flyway
flyway -v
```

2) Use the repo-provided local lab config:

- File: `flyway/conf/flyway-contest-lab.conf`
- It targets: `jdbc:postgresql://localhost:5432/contest_lab`
- It expects: `CONTEST_LAB_DB_PASSWORD` in your shell

3) Run Flyway from the `flyway/` folder (because `flyway.locations` is `filesystem:./db/migrations`):

```bash
cd ../../flyway

export CONTEST_LAB_DB_PASSWORD='contestgrid'

flyway -configFiles=conf/flyway-contest-lab.conf info
flyway -configFiles=conf/flyway-contest-lab.conf migrate

psql "postgresql://contestgrid:contestgrid@localhost:5432/contest_lab" \
  -c "select version, description, success from flyway_schema_history order by installed_rank;"
```

### If Flyway says checksum/validation failed

Usually this means a migration file changed after it was applied. In a local lab DB you can typically do:

```bash
cd ../../flyway
flyway -configFiles=conf/flyway-contest-lab.conf repair
flyway -configFiles=conf/flyway-contest-lab.conf migrate
```

---

## 3) Configure System API: Core to use contest_lab

In `contestgrid-core-sys/.env` set:

```dotenv
DB_HOST=localhost
DB_PORT=5432
DB_NAME=contest_lab
DB_USER=contestgrid
DB_PASSWORD=contestgrid

# Local Postgres typically does not use SSL
# Any value other than "require" disables SSL in the current implementation.
DB_SSL_MODE=disable
```

Then start the service:

```bash
npm run dev
```

Health endpoint:

- `GET http://localhost:3001/v1/health`

---

## 4) Tenant context (RLS)

The database uses PostgreSQL Row Level Security policies that reference the session variable:

- `current_setting('app.tenant_id', true)`

This service sets that value per-request using `set_config('app.tenant_id', ..., true)` inside a transaction.

### Quick sanity tenant IDs

The seed migration inserts two deterministic tenants:

- Tenant `1001` ("RLS Tenant One")
- Tenant `1002` ("RLS Tenant Two")

When calling tenant-scoped endpoints, pass:

- Header `X-Tenant-ID: 1001` (or `1002`)

---

## 5) RestFox collections (quick start)

This repo includes two files you can import into RestFox:

- `ContestGrid-Core-API.restfox-export.json` (native RestFox export; most reliable)
- `ContestGrid-Core-API.restfox.json` (Postman v2.1 format; may be less reliable in RestFox)

Typical variables:

- `baseUrl`: `http://localhost:3001/v1`
- `tenantId`: `1001`

---

## Troubleshooting

### `pg_hba.conf` errors

This typically happens when using a remote DB with restrictive host rules. Using local Docker Postgres avoids it.

### `EMFILE: too many open files` during dev watch

Increase file descriptor limit in your shell before `npm run dev`:

```bash
ulimit -n 16384
npm run dev
```
