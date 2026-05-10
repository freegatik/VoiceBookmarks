#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

if [[ -n "${MD_APPLE_SDK_ROOT:-}" ]]; then
  export DEVELOPER_DIR="${MD_APPLE_SDK_ROOT%/}/Contents/Developer"
fi

DEST="${IOS_DESTINATION:-platform=iOS Simulator,name=iPhone 16,OS=18.2}"
PROJECT="VoiceBookmarks.xcodeproj"
SCHEME="VoiceBookmarks"

PHASE="${1:-all}"

xb_base() {
  xcodebuild test \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "$DEST" \
    "$@"
}

# Simulator discovery can stall; cap wait. Per-test caps avoid indefinite UI waits.
flags_unit=(
  -destination-timeout 300
  -test-timeouts-enabled YES
  -default-test-execution-time-allowance 60
  -maximum-test-execution-time-allowance 180
)

flags_ui=(
  -destination-timeout 300
  -parallel-testing-enabled NO
  -maximum-concurrent-test-simulator-destinations 1
  -test-timeouts-enabled YES
  -default-test-execution-time-allowance 120
  -maximum-test-execution-time-allowance 600
)

run_main_unit() {
  echo "==> VoiceBookmarksTests → TestResults-main.xcresult"
  rm -rf TestResults-main.xcresult
  xb_base \
    "${flags_unit[@]}" \
    -only-testing:VoiceBookmarksTests \
    -enableCodeCoverage YES \
    -resultBundlePath TestResults-main.xcresult
}

run_main_ui() {
  echo "==> VoiceBookmarksUITests → TestResults-main-ui.xcresult"
  rm -rf TestResults-main-ui.xcresult
  xb_base \
    "${flags_ui[@]}" \
    -only-testing:VoiceBookmarksUITests \
    -enableCodeCoverage NO \
    -resultBundlePath TestResults-main-ui.xcresult
}

run_share() {
  echo "==> Share extension tests → TestResults-share.xcresult"
  rm -rf TestResults-share.xcresult
  xb_base \
    "${flags_ui[@]}" \
    -only-testing:VoiceBookmarksShareExtensionTests \
    -only-testing:VoiceBookmarksShareExtensionUITests \
    -enableCodeCoverage YES \
    -resultBundlePath TestResults-share.xcresult
}

run_all() {
  run_main_unit
  run_main_ui
  run_share
}

case "$PHASE" in
  main-unit) run_main_unit ;;
  main-ui) run_main_ui ;;
  share) run_share ;;
  all) run_all ;;
  *)
    echo "Usage: $0 [all|main-unit|main-ui|share]" >&2
    exit 2
    ;;
esac
