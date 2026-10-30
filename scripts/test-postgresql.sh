#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
manifest="$(mktemp)"
trap 'rm -f -- "$manifest"' EXIT
python3 scripts/create-migration-manifest.py "$manifest"
export MIGRATION_MANIFEST="$manifest"
docker build -t devops-backend:test -f backend/Containerfile backend
docker build -t devops-migrator:test -f backend/Containerfile.migrator .
python3 scripts/test-postgresql.py
