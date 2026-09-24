#!/bin/sh
set -eu
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
cd "$repo_dir"
# Invented test profiles only. No account, network or model request is used.
SUJI_MODULE_SAMPLES_OUTPUT="$repo_dir/docs/product/2026-09-24-native-report-increment/synthetic-samples.md" \
  swift test --package-path native/Core \
  --filter NatalReadingReportTests.testReadableSyntheticSamplePackAndAdvancedCoverageRemainHonest
