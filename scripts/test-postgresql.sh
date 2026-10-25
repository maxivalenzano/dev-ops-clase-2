#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
for phase in P1 P2 P3; do
  docker build --build-arg "TASK_RELEASE=$phase" -t "devops-backend:test-$phase" -f backend/Containerfile backend
done
docker build -t devops-migrator:test -f backend/Containerfile.migrator .
python3 scripts/test-postgresql.py
