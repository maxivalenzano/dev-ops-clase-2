#!/bin/sh
set -eu
# The design-time factory reads the mounted secret. Never put credentials in argv/logs.
if [ -n "${DATABASE_CONNECTION_FILE:-}" ]; then
    test -r "$DATABASE_CONNECTION_FILE" || { echo 'Migrator connection file is not readable' >&2; exit 1; }
fi
exec /app/efbundle "$@"
