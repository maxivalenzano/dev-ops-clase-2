#!/usr/bin/env bash
# Extract the exact bundle and SQL published in the release image.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
rm -rf -- migration-artifacts
mkdir -p migration-artifacts
container=$(docker create "${MIGRATOR_IMAGE:-ghcr.io/maxivalenzano/dev-ops-migrator}:${RELEASE_TAG:?}")
trap 'docker rm "$container" >/dev/null' EXIT
docker cp "$container:/app/efbundle" migration-artifacts/efbundle
docker cp "$container:/artifacts/." migration-artifacts/
python3 scripts/create-migration-manifest.py migration-artifacts/migrations.json
