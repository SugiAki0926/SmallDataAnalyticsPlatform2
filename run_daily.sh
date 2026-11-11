#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
DOCKER="/Applications/Docker.app/Contents/Resources/bin/docker"
LOG_FILE="$ROOT/logs/dap2-generator.log"

cd "$ROOT"
mkdir -p "$ROOT/logs"

set +e
{
  printf '[start]%s start\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')"
  "$DOCKER" compose -p dap2 -f "$ROOT/docker-compose.yml" run --rm generator
  status=$?
  printf '[ end ]%s exit=%s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$status"
} >> "$LOG_FILE" 2>&1
exit "$status"
