#!/usr/bin/env bash
# Explicit operator recovery after cancellation; never bypass ownership checks.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib-postgresql.sh"
assert_owner
[[ "${1:-}" == --after-inspection ]] || {
  echo 'Inspect receipt, migration history and running writer images. Then pass --after-inspection with the owning BUILD_ID/SOURCE_COMMIT.' >&2
  exit 2
}
release_reservation
echo "Reservation $BUILD_ID released after operator inspection."
