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

rm -rf TestResults-main.xcresult TestResults-share.xcresult

echo "==> VoiceBookmarksTests + VoiceBookmarksUITests → TestResults-main.xcresult"
xcodebuild test \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "$DEST" \
  -only-testing:VoiceBookmarksTests \
  -only-testing:VoiceBookmarksUITests \
  -enableCodeCoverage YES \
  -resultBundlePath TestResults-main.xcresult

echo "==> Share extension tests → TestResults-share.xcresult"
xcodebuild test \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "$DEST" \
  -only-testing:VoiceBookmarksShareExtensionTests \
  -only-testing:VoiceBookmarksShareExtensionUITests \
  -enableCodeCoverage YES \
  -resultBundlePath TestResults-share.xcresult
