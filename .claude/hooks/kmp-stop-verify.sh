#!/bin/bash
# Runs at the end of Claude's turn.
# If any shared/src/ file was modified this turn, runs Detekt on the shared module.
# iOS compile and unit tests are gated explicitly in build-feature Gate 6 — not run here
# to avoid blocking every turn with multi-minute Gradle tasks.

REPO_ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel 2>/dev/null)"
if [ -z "$REPO_ROOT" ]; then
  exit 0
fi

CHANGED=$(git -C "$REPO_ROOT" diff --name-only HEAD 2>/dev/null | grep "^shared/src/")
if [ -z "$CHANGED" ]; then
  exit 0
fi

echo "=== KMP hook: shared/src/ changes detected — running Detekt ==="
cd "$REPO_ROOT" || exit 0

./gradlew :shared:detekt --console=plain -q 2>&1
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
  echo "HOOK FAILURE: Detekt violations found. Fix before proceeding."
  exit 1
fi

echo "Detekt PASSED"
exit 0
