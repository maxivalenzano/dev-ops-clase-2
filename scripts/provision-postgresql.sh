#!/usr/bin/env bash
# Explicit, repeatable role provisioning; not an initdb migration mechanism.
set -euo pipefail
docker exec -i lab-postgres bash -c '
  export PGPASSWORD="$(cat /run/secrets/postgres_password)"
  exec psql -X -q -v ON_ERROR_STOP=1 -h 127.0.0.1 -U postgres -d devops \
    -v migrator_password="$(cat /run/secrets/migrator_password)" \
    -v app_password="$(cat /run/secrets/app_password)"
' <<'SQL'
SELECT 'CREATE ROLE devops_migrator LOGIN' WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname='devops_migrator') \gexec
SELECT 'CREATE ROLE devops_app LOGIN' WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname='devops_app') \gexec
ALTER ROLE devops_migrator WITH PASSWORD :'migrator_password' NOSUPERUSER NOCREATEDB NOCREATEROLE;
ALTER ROLE devops_app WITH PASSWORD :'app_password' NOSUPERUSER NOCREATEDB NOCREATEROLE;
ALTER DATABASE devops OWNER TO devops_migrator;
REVOKE ALL ON DATABASE devops FROM PUBLIC;
GRANT CONNECT ON DATABASE devops TO devops_app;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
ALTER SCHEMA public OWNER TO devops_migrator;
GRANT USAGE ON SCHEMA public TO devops_app;
ALTER DEFAULT PRIVILEGES FOR ROLE devops_migrator IN SCHEMA public GRANT SELECT,INSERT,UPDATE,DELETE ON TABLES TO devops_app;
ALTER DEFAULT PRIVILEGES FOR ROLE devops_migrator IN SCHEMA public GRANT USAGE,SELECT ON SEQUENCES TO devops_app;
GRANT SELECT,INSERT,UPDATE,DELETE ON ALL TABLES IN SCHEMA public TO devops_app;
GRANT USAGE,SELECT ON ALL SEQUENCES IN SCHEMA public TO devops_app;
SELECT 'REVOKE INSERT,UPDATE,DELETE ON "__EFMigrationsHistory" FROM devops_app' WHERE to_regclass('public."__EFMigrationsHistory"') IS NOT NULL \gexec
SQL
