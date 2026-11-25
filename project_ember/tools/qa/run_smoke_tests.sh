#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "${1:-$(dirname "$0")/../..}" && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
ARTIFACT_ROOT="${EMBER_QA_ARTIFACTS:-$PROJECT_ROOT/artifacts/qa}"
LOG_ROOT="$ARTIFACT_ROOT/logs"
mkdir -p "$LOG_ROOT"

if ! command -v "$GODOT_BIN" >/dev/null 2>&1 && [[ ! -x "$GODOT_BIN" ]]; then
  echo "Godot executable not found: $GODOT_BIN" >&2
  exit 2
fi

mapfile -t TESTS < <(find "$PROJECT_ROOT/tests" -maxdepth 1 -type f -name '*_smoke_test.gd' | sort)
if [[ ${#TESTS[@]} -eq 0 ]]; then
  echo "No smoke tests found under $PROJECT_ROOT/tests" >&2
  exit 2
fi

passed=0
failed=0
summary="$ARTIFACT_ROOT/smoke-test-summary.txt"
: > "$summary"

# Parse every GDScript file independently before executing behavioral tests.
while IFS= read -r source_file; do
  rel_path="${source_file#"$PROJECT_ROOT/"}"
  resource_path="res://${rel_path}"
  parse_log="$LOG_ROOT/parse-${rel_path//\//_}.log"
  parse_home="$(mktemp -d)"
  set +e
  timeout 90s env HOME="$parse_home" \
    XDG_CONFIG_HOME="$parse_home/.config" \
    XDG_DATA_HOME="$parse_home/.local/share" \
    GODOT_SILENCE_ROOT_WARNING=1 \
    "$GODOT_BIN" --headless --audio-driver Dummy --path "$PROJECT_ROOT" \
      --check-only --script "$resource_path" 2>&1 | tee "$parse_log"
  parse_status=${PIPESTATUS[0]}
  set -e
  rm -rf "$parse_home"
  if [[ $parse_status -ne 0 ]] || grep -Eq 'SCRIPT ERROR:|Parse Error:' "$parse_log"; then
    echo "FAIL parser $rel_path" | tee -a "$summary"
    exit 1
  fi
done < <(find "$PROJECT_ROOT/scripts" "$PROJECT_ROOT/tests" "$PROJECT_ROOT/tools/qa" -maxdepth 1 -type f -name '*.gd' | sort)

echo "PASS parser checks" | tee -a "$summary"

for test_file in "${TESTS[@]}"; do
  test_name="$(basename "$test_file" .gd)"
  resource_path="res://tests/$(basename "$test_file")"
  log_file="$LOG_ROOT/$test_name.log"
  test_home="$(mktemp -d)"
  echo "===== $test_name ====="

  set +e
  timeout 150s env HOME="$test_home" \
    XDG_CONFIG_HOME="$test_home/.config" \
    XDG_DATA_HOME="$test_home/.local/share" \
    GODOT_SILENCE_ROOT_WARNING=1 \
    "$GODOT_BIN" --headless --audio-driver Dummy --path "$PROJECT_ROOT" \
      --script "$resource_path" 2>&1 | tee "$log_file"
  status=${PIPESTATUS[0]}
  set -e

  if [[ $status -eq 0 ]] \
    && ! grep -Eq 'SCRIPT ERROR:|Parse Error:|TEST FAILED:|ERROR: Failed to load|ERROR: Cannot open file' "$log_file" \
    && grep -Eq 'All .* passed\.' "$log_file"; then
    ((passed+=1))
    echo "PASS $test_name" | tee -a "$summary"
  else
    ((failed+=1))
    echo "FAIL $test_name (exit=$status)" | tee -a "$summary"
  fi
  rm -rf "$test_home"
done

echo "Smoke tests: $passed passed / $failed failed / ${#TESTS[@]} total" | tee -a "$summary"
if [[ $failed -ne 0 ]]; then
  exit 1
fi
