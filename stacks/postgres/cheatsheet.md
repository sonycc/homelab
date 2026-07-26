# Postgres cheatsheet

Placeholders: `<admin>` = the postgres superuser `POSTGRES_USER` from `.env`, `<user>` = a service role,
`<db>` = a database, `<table>` = a table.

---

## Connect

Every command below is a one-shot `psql -U <admin> -d <db> -c "..."`. From the host,
prefix it with:

```bash
docker exec postgres
```

From inside the container (Docker Desktop exec window) drop the prefix and run `psql`
directly. Use `docker exec -it postgres psql -U <admin> -d postgres` for an interactive
session instead.

`-d` is always required — without it `psql` uses the username as the database name and
fails. Use `-d postgres` for cluster-wide work (roles, creating databases) and `-d <db>`
for anything inside a database. `-c` can be repeated to run several statements.

```bash
psql -U <admin> -d postgres -c "SELECT version();"
```

---

## Meta-commands

Meta-commands work with `-c` like any other statement:

```bash
psql -U <admin> -d <db> -c "\dt"
```

| Command | What it does |
|---|---|
| `\l` | List databases |
| `\du` | List roles |
| `\dt` | List tables |
| `\d <table>` | Describe a table |
| `\dp` | Show table privileges |
| `\i file.sql` | Run a SQL file |

`\?` lists all of them, `\h CREATE TABLE` gives SQL syntax help. In an interactive
session, `\x` toggles row-per-line output and `\q` quits.

---

## Users

```bash
psql -U <admin> -d postgres -c "CREATE USER <user> WITH PASSWORD 'secret';"
psql -U <admin> -d postgres -c "ALTER USER <user> WITH PASSWORD 'new_secret';"
psql -U <admin> -d postgres -c "DROP USER <user>;"
```

Dropping fails while the role owns objects — hand them over first, once per database the
role owns anything in:

```bash
psql -U <admin> -d <db> -c "REASSIGN OWNED BY <user> TO <admin>;" -c "DROP OWNED BY <user>;"
```

---

## Databases

```bash
psql -U <admin> -d postgres -c "CREATE DATABASE <db> OWNER <user>;"
psql -U <admin> -d postgres -c "DROP DATABASE <db> WITH (FORCE);"
psql -U <admin> -d postgres -c "SELECT pg_size_pretty(pg_database_size('<db>'));"
```

Ownership is what lets the role create tables. For a role that must write to a database
it does not own:

```bash
psql -U <admin> -d <db> -c "GRANT USAGE, CREATE ON SCHEMA public TO <user>;"
```

---

## Tables

```bash
psql -U <admin> -d <db> -c "CREATE TABLE <table> (id bigserial PRIMARY KEY, name text NOT NULL UNIQUE, created_at timestamptz NOT NULL DEFAULT now());"
psql -U <admin> -d <db> -c "ALTER TABLE <table> ADD COLUMN note text;"
psql -U <admin> -d <db> -c "ALTER TABLE <table> DROP COLUMN note;"
psql -U <admin> -d <db> -c "ALTER TABLE <table> RENAME TO <new_name>;"
psql -U <admin> -d <db> -c "CREATE INDEX ON <table> (created_at);"
```

```bash
psql -U <admin> -d <db> -c "TRUNCATE <table>;"   # empty it, keep the table
psql -U <admin> -d <db> -c "DROP TABLE <table>;" # add CASCADE to drop dependents too
```

---

## Grants

```bash
psql -U <admin> -d <db> -c "GRANT SELECT ON ALL TABLES IN SCHEMA public TO <user>;"
psql -U <admin> -d <db> -c "REVOKE SELECT ON ALL TABLES IN SCHEMA public FROM <user>;"
```

Applies to tables created later, too:

```bash
psql -U <admin> -d <db> -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO <user>;"
```

---

## Activity

```bash
psql -U <admin> -d postgres -c "SELECT pid, usename, datname, state, query FROM pg_stat_activity;"
psql -U <admin> -d postgres -c "SELECT pg_terminate_backend(<pid>);"
```

```bash
docker logs --tail 100 -f postgres
```

---

## Backup & restore

These are `pg_dump` / `pg_dumpall`, not `psql`, so the prefix is
`docker exec postgres` with no `-t`:

```bash
docker exec postgres pg_dump -U <admin> -d <db> | gzip > <db>.sql.gz
docker exec postgres pg_dumpall -U <admin> | gzip > all.sql.gz
```

Restore into an existing, empty database — needs `-i` to pipe stdin in:

```bash
gunzip -c <db>.sql.gz | docker exec -i postgres psql -U <admin> -d <db>
```

---

## Maintenance

```bash
psql -U <admin> -d <db> -c "ANALYZE;"                    # refresh planner statistics
psql -U <admin> -d <db> -c "VACUUM (VERBOSE, ANALYZE);"  # reclaim space
psql -U <admin> -d postgres -c "SHOW shared_buffers;"    # read any setting
```

---

## Gotchas

- `POSTGRES_USER` / `POSTGRES_PASSWORD` / `POSTGRES_DB` only apply when the data volume
  is first initialised. Later `.env` edits do nothing — use `ALTER USER` instead, then
  update `.env` and recreate the consuming container.
- Major version bumps are not automatic; the data directory needs `pg_upgrade` or a
  dump/restore. Never change the major version in place.
- `postgres-backup` only dumps `POSTGRES_DB` (see [backup.sh](backup.sh)) — per-service
  databases need the manual `pg_dump` above.
