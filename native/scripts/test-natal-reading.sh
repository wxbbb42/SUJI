#!/bin/bash
set -euo pipefail

# Local synthetic data only. Does not run LiveReadingSessionTests or a model matrix.
if [[ $# -ne 1 ]]; then
  echo "Usage: bash native/scripts/test-natal-reading.sh <booted-iOS-simulator-UDID>" >&2
  exit 2
fi
suji_report_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$suji_report_root"
suji_report_artifacts="native/artifacts/natal-reading-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$suji_report_artifacts"

swift test --package-path native/Core --filter NatalReadingReportTests \
  > "$suji_report_artifacts/core.log" 2>&1
python3 native/scripts/generate-project.py
xcodebuild -project native/Suji.xcodeproj -scheme Suji \
  -destination "platform=iOS Simulator,id=$1" \
  -derivedDataPath native/DerivedData \
  -parallel-testing-enabled NO -collect-test-diagnostics never \
  -only-testing:SujiTests/NatalReadingStoreTests \
  -only-testing:SujiUITests/NatalReadingReportUITests \
  -resultBundlePath "$suji_report_artifacts/native.xcresult" test \
  > "$suji_report_artifacts/native.log" 2>&1
echo "Results: $suji_report_artifacts"
