#!/bin/bash
# run_uitests.sh — run XCUITest suite with video recording
#
# Usage:
#   cd ~/ios-mcp-app/AlfredChat/AlfredChat
#   bash ~/aishell/tests/run_uitests.sh
#
# Env vars:
#   ALFRED_HOST     (default: 192.168.1.40)
#   ALFRED_API_KEY  (default: change-me)
#   SIM_ID          (default: C9BC4133-902A-4BAD-9C11-CA042DCC8B96)
#
# Output: /tmp/uitest.mp4

set -e

SIM_ID="${SIM_ID:-C9BC4133-902A-4BAD-9C11-CA042DCC8B96}"
OUT="/tmp/uitest.mp4"
PROJECT_DIR="$HOME/ios-mcp-app/AlfredChat/AlfredChat"
PROJECT="$PROJECT_DIR/AlfredChat.xcodeproj"

# Ensure simulator is booted
xcrun simctl boot "$SIM_ID" 2>/dev/null || true
sleep 2

# Start recording
rm -f "$OUT"
xcrun simctl io "$SIM_ID" recordVideo "$OUT" &
RPID=$!
sleep 1

echo "=== Running AlfredChatUITests ==="

# Run tests
xcodebuild test \
  -project "$PROJECT" \
  -scheme AlfredChatUITests \
  -destination "id=$SIM_ID" \
  -resultBundlePath /tmp/uitest_results \
  ALFRED_HOST="${ALFRED_HOST:-192.168.1.40}" \
  ALFRED_API_KEY="${ALFRED_API_KEY:-change-me}" \
  2>&1 | tail -40

TEST_EXIT=${PIPESTATUS[0]}

# Stop recording
kill -INT "$RPID" 2>/dev/null || true
wait "$RPID" 2>/dev/null || true
sleep 1

echo ""
echo "Video: $OUT"
ls -lh "$OUT" 2>/dev/null || echo "(no video recorded)"
echo "Results: /tmp/uitest_results"

exit $TEST_EXIT
