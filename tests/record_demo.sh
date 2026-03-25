#!/bin/bash
# record_demo.sh — record a video of the full iOS simulator test suite
#
# Usage:
#   bash tests/record_demo.sh
#   bash tests/record_demo.sh 1 7 18   # specific test IDs
#
# Output: /tmp/sim_tests.mp4
# Requires: booted simulator, AlfredChat installed, Alfred running on localhost:8422

set -e

SIM_ID="${SIM_ID:-C9BC4133-902A-4BAD-9C11-CA042DCC8B96}"
OUT="/tmp/sim_tests.mp4"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

rm -f "$OUT"

echo "Starting recording..."
xcrun simctl io "$SIM_ID" recordVideo "$OUT" &
RPID=$!
sleep 1

source ~/llm/.venv/bin/activate
python3 "$SCRIPT_DIR/sim_tests.py" "$@"

kill -INT "$RPID"
wait "$RPID" 2>/dev/null || true
sleep 1

echo "Done: $OUT"
ls -lh "$OUT"
