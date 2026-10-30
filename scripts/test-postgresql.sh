#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
if [[ -z "${MIGRATION_MANIFEST:-}" ]]; then
  manifest="$(mktemp)"
  trap 'rm -f -- "$manifest"' EXIT
  python3 scripts/create-migration-manifest.py "$manifest"
  export MIGRATION_MANIFEST="$manifest"
fi
export BACKEND_TEST_IMAGE="${BACKEND_TEST_IMAGE:-devops-backend:test}"
export MIGRATOR_TEST_IMAGE="${MIGRATOR_TEST_IMAGE:-devops-migrator:test}"
if [[ "${BUILD_TEST_IMAGES:-true}" == true ]]; then
  docker build -t "$BACKEND_TEST_IMAGE" -f backend/Containerfile backend
  docker build -t "$MIGRATOR_TEST_IMAGE" -f backend/Containerfile.migrator .
fi
python3 scripts/test-postgresql.py
