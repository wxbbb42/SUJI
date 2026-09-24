#!/usr/bin/env bash
set -euo pipefail

# No network, AI, user records, or synthetic tool receipts. Invented civil births
# travel through the bundled engine and the production deterministic compiler.
SUJI_TASK_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SUJI_THEME_OUTPUT="${1:-$SUJI_TASK_ROOT/docs/product/2026-09-23-bazi-theme-handoff/synthetic-samples.md}"
mkdir -p "$(dirname "$SUJI_THEME_OUTPUT")" "$SUJI_TASK_ROOT/native/artifacts"
SUJI_THEME_SAMPLES_OUTPUT="$SUJI_THEME_OUTPUT" swift test \
  --package-path "$SUJI_TASK_ROOT/native/Core" \
  --scratch-path "$SUJI_TASK_ROOT/native/artifacts/theme-sample-build" \
  --filter BaziLifeThemeTests/testRealCalendarSamplesHaveDifferentReasoningAndProduceReproducibleSamples
