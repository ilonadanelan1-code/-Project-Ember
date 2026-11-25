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

# Parse scripts from a normal project scene. A --check-only --script invocation
# does not register project autoload singletons, so it reports false errors for
# valid scripts that reference CampaignState, GameSettings, UiMetrics or Haptics.
parser_log="$LOG_ROOT/gdscript-parser.log"
parser_home="$(mktemp -d)"
set +e
timeout 120s env HOME="$parser_home" \
  XDG_CONFIG_HOME="$parser_home/.config" \
  XDG_DATA_HOME="$parser_home/.local/share" \
  GODOT_SILENCE_ROOT_WARNING=1 \
  "$GODOT_BIN" --headless --audio-driver Dummy --path "$PROJECT_ROOT" \
    res://tools/qa/parse_all_scripts.tscn 2>&1 | tee "$parser_log"
parser_status=${PIPESTATUS[0]}
set -e
rm -rf "$parser_home"
if [[ $parser_status -ne 0 ]] || grep -Eq 'SCRIPT ERROR:|Parse Error:|GDScript parser failed:' "$parser_log"; then
  echo "Project-context GDScript parser reported errors." >&2
  exit 1
fi
echo "PASS parser checks" | tee "$ARTIFACT_ROOT/smoke-test-summary.txt"

passed=0
failed=0
summary="$ARTIFACT_ROOT/smoke-test-summary.txt"

for test_file in "${TESTS[@]}"; do
  test_name="$(basename "$test_file" .gd)"
  resource_path="res://tests/$(basename "$test_file")"
  log_file="$LOG_ROOT/$test_name.log"
  test_home="$(mktemp -d)"
  echo "===== $test_name ====="

  set +e
  if [[ -f "$PROJECT_ROOT/tests/$test_name.tscn" ]]; then
    # Scene-based tests run with the real project Autoload singletons available.
    timeout 150s env HOME="$test_home" \
      XDG_CONFIG_HOME="$test_home/.config" \
      XDG_DATA_HOME="$test_home/.local/share" \
      GODOT_SILENCE_ROOT_WARNING=1 \
      "$GODOT_BIN" --headless --audio-driver Dummy --path "$PROJECT_ROOT" \
        "res://tests/$test_name.tscn" 2>&1 | tee "$log_file"
  else
    timeout 150s env HOME="$test_home" \
      XDG_CONFIG_HOME="$test_home/.config" \
      XDG_DATA_HOME="$test_home/.local/share" \
      GODOT_SILENCE_ROOT_WARNING=1 \
      "$GODOT_BIN" --headless --audio-driver Dummy --path "$PROJECT_ROOT" \
        --script "$resource_path" 2>&1 | tee "$log_file"
  fi
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
