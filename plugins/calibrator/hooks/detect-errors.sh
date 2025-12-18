#!/bin/bash
# PostToolUse Hook: Detect errors from Bash execution and record frequency
# Triggers on Bash tool use with non-zero exit code
#
# ROLE SEPARATION:
# - Hook (this file): Records error occurrences to observations table (frequency tracking)
# - Skill (auto-calibrate.md): Analyzes errors and records learned patterns to patterns table
#
# This hook captures WHAT failed, while the Skill captures HOW to fix it.

set -euo pipefail

# ============================================
# Step 1: Read hook input from stdin
# ============================================
input=$(cat)

# Check if jq is available
if ! command -v jq &> /dev/null; then
  exit 0
fi

# Extract relevant fields from hook input
command=$(echo "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
exit_code=$(echo "$input" | jq -r '.tool_result.exit_code // 0' 2>/dev/null)
stdout=$(echo "$input" | jq -r '.tool_result.stdout // empty' 2>/dev/null)
stderr=$(echo "$input" | jq -r '.tool_result.stderr // empty' 2>/dev/null)

# ============================================
# Step 2: Early exit conditions
# ============================================

# No command to analyze
if [ -z "$command" ]; then
  exit 0
fi

# Successful execution - no errors to detect
if [ "$exit_code" = "0" ] || [ "$exit_code" = "null" ]; then
  exit 0
fi

# ============================================
# Step 3: Check initialization and auto-detect flag
# ============================================

# Check sqlite3 availability
if ! command -v sqlite3 &> /dev/null; then
  exit 0
fi

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")
DB_PATH="$PROJECT_ROOT/.claude/calibrator/patterns.db"
FLAG_FILE="$PROJECT_ROOT/.claude/calibrator/auto-detect.enabled"

# Not initialized - skip silently
if [ ! -f "$DB_PATH" ]; then
  exit 0
fi

# Auto-detection disabled - skip silently
if [ ! -f "$FLAG_FILE" ]; then
  exit 0
fi

# ============================================
# Step 4: Classify command type
# ============================================
# Uses case statement for security (no command injection) and performance (no subprocess)
classify_command() {
  local cmd="$1"
  # Convert to lowercase for case-insensitive matching
  local cmd_lower
  cmd_lower=$(printf '%s' "$cmd" | tr '[:upper:]' '[:lower:]')

  case "$cmd_lower" in
    # Lint/Format
    *eslint*|*prettier*|*biome*|*stylelint*|*pylint*|*flake8*|*rubocop*|*golint*|*clippy*|*oxlint*)
      echo "lint" ;;
    # Type Check
    *tsc*|*typescript*|*mypy*|*flow*|*typecheck*)
      echo "typecheck" ;;
    # Build (check before test because some commands contain both)
    *webpack*|*vite*|*esbuild*|*rollup*|*turbo*|*"cargo build"*|*"go build"*|*make*)
      echo "build" ;;
    # Test
    *jest*|*vitest*|*pytest*|*mocha*|*"cargo test"*|*"go test"*|*test*)
      echo "test" ;;
    # Package
    *npm*|*yarn*|*pnpm*|*pip*|*cargo*|*"go mod"*)
      echo "package" ;;
    # Git
    "git "*|*" git "*)
      echo "git" ;;
    *)
      echo "other" ;;
  esac
}

ERROR_TYPE=$(classify_command "$command")

# ============================================
# Step 5: Extract situation from error (frequency tracking only)
# ============================================
output="$stdout$stderr"

# Extract first meaningful error line as situation
# Uses printf '%s' for safe string handling (no command injection)
extract_situation() {
  local cmd="$1"
  local out="$2"
  local err_type="$3"

  # Get first error/warning line (max 200 chars)
  local first_error
  first_error=$(printf '%s' "$out" | grep -iE '(error|Error|ERROR|warning|Warning|WARN|fail|FAIL)' | head -1 | cut -c1-200)

  if [ -z "$first_error" ]; then
    # Fallback: first non-empty line
    first_error=$(printf '%s' "$out" | grep -v '^$' | head -1 | cut -c1-200)
  fi

  # Create situation description
  printf '%s' "${err_type}: ${first_error:-Unknown error}" | cut -c1-500
}

SITUATION=$(extract_situation "$command" "$output" "$ERROR_TYPE")

# Skip if we couldn't extract meaningful information
if [ -z "$SITUATION" ]; then
  exit 0
fi

# ============================================
# Step 6: SQL Injection prevention and DB record (observations only)
# ============================================
escape_sql() {
  printf '%s' "$1" | sed "s/'/''/g"
}

# Map ERROR_TYPE to observation category for consistency with calibrate.md
map_category() {
  case "$1" in
    lint)      echo "style" ;;
    typecheck) echo "missing" ;;
    build)     echo "other" ;;
    test)      echo "other" ;;
    package)   echo "missing" ;;
    git)       echo "other" ;;
    *)         echo "other" ;;
  esac
}

CATEGORY=$(map_category "$ERROR_TYPE")
SAFE_CATEGORY=$(escape_sql "$CATEGORY")
SAFE_SITUATION=$(escape_sql "$SITUATION")

# Record to observations table only (frequency tracking)
# NOTE: patterns table is managed by auto-calibrate.md skill which has
# better understanding of the actual fix and can generate meaningful instructions
DB_ERROR=""
if ! DB_ERROR=$(sqlite3 "$DB_PATH" <<SQL 2>&1
INSERT INTO observations (category, situation, expectation)
VALUES ('$SAFE_CATEGORY', '$SAFE_SITUATION', 'Detected by hook - see auto-calibrate skill for learned pattern');
SQL
); then
  # Log DB error to stderr for debugging (hook will still succeed)
  echo "[calibrator-hook] Warning: Failed to record observation: $DB_ERROR" >&2
  exit 0
fi

# Hook's job is done - frequency recorded
# Pattern learning and skill promotion are handled by auto-calibrate.md skill
exit 0
