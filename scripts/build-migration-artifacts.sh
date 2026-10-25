#!/usr/bin/env bash
# Extract the exact bundle and SQL tested and published in the release image.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
mkdir -p migration-artifacts
container=$(docker create "${MIGRATOR_IMAGE:-ghcr.io/maxivalenzano/dev-ops-migrator}:${RELEASE_TAG:?}")
trap 'docker rm "$container" >/dev/null' EXIT
docker cp "$container:/app/efbundle" migration-artifacts/efbundle
docker cp "$container:/artifacts/." migration-artifacts/
cp backend/schema-compatibility.json migration-artifacts/
