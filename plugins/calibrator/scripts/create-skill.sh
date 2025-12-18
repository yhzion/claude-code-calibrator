#!/bin/bash
# Calibrator Skill Creation Script
# Creates a skill from a pattern and updates the database
#
# Usage: create-skill.sh <pattern_id> <situation> <instruction> <count>
#
# Environment Variables:
#   CLAUDE_PLUGIN_ROOT - Plugin installation directory (optional)
#   PROJECT_ROOT - Project root directory (auto-detected if not set)

set -euo pipefail
IFS=$'\n\t'

# Ensure UTF-8 locale
export LC_ALL=C.UTF-8 2>/dev/null || export LC_ALL=en_US.UTF-8 2>/dev/null || true

# Get script directory for sourcing utils
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source shared utilities
if [ -f "$SCRIPT_DIR/utils.sh" ]; then
  # shellcheck source=utils.sh
  source "$SCRIPT_DIR/utils.sh"
else
  echo "❌ Error: utils.sh not found in $SCRIPT_DIR"
  exit 1
fi

# ============================================================================
# Argument Parsing
# ============================================================================

if [ $# -lt 4 ]; then
  echo "Usage: create-skill.sh <pattern_id> <situation> <instruction> <count>"
  echo ""
  echo "Arguments:"
  echo "  pattern_id   - Database ID of the pattern"
  echo "  situation    - Error situation description"
  echo "  instruction  - Fix instruction"
  echo "  count        - Number of occurrences"
  exit 1
fi

PATTERN_ID="$1"
SITUATION="$2"
INSTRUCTION="$3"
COUNT="$4"

# ============================================================================
# Validation
# ============================================================================

# Validate pattern_id is numeric
if ! [[ "$PATTERN_ID" =~ ^[0-9]+$ ]]; then
  echo "❌ Error: Invalid pattern id '$PATTERN_ID'"
  exit 1
fi

# Setup project paths
PROJECT_ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
DB_PATH="$PROJECT_ROOT/.claude/calibrator/patterns.db"
SKILL_OUTPUT_PATH="$PROJECT_ROOT/.claude/skills"
TEMPLATE_PATH="${CLAUDE_PLUGIN_ROOT:-$PROJECT_ROOT/plugins/calibrator}/templates/skill-template.md"

# Check database exists
if [ ! -f "$DB_PATH" ]; then
  echo "❌ Error: Database not found at $DB_PATH"
  exit 1
fi

# Check template exists
if [ ! -f "$TEMPLATE_PATH" ]; then
  echo "❌ Error: Template file not found at $TEMPLATE_PATH"
  exit 1
fi

# Ensure schema is migrated
ensure_schema_version "$DB_PATH" || exit 1

# ============================================================================
# Get Pattern Details from Database
# ============================================================================

ROW=$(sqlite3 -separator $'\t' "$DB_PATH" \
  "SELECT first_seen, last_seen FROM patterns WHERE id = $PATTERN_ID;" \
  2>/dev/null) || ROW=""

if [ -z "$ROW" ]; then
  echo "❌ Error: Pattern not found (id=$PATTERN_ID)"
  exit 1
fi

IFS=$'\t' read -r FIRST_SEEN LAST_SEEN <<<"$ROW"

# ============================================================================
# Create Skill Directory
# ============================================================================

# Ensure skills directory exists
mkdir -p "$SKILL_OUTPUT_PATH"

# Generate skill name
SKILL_NAME=$(generate_skill_name "$SITUATION")

# Configurable max attempts (environment variable or default)
MAX_SKILL_NAME_ATTEMPTS="${CALIBRATOR_MAX_NAME_ATTEMPTS:-100}"

# Handle skill name collisions atomically using mkdir
BASE_SKILL_NAME="$SKILL_NAME"
SUFFIX=0
SKILL_DIR=""

while [ $SUFFIX -le $MAX_SKILL_NAME_ATTEMPTS ]; do
  if [ $SUFFIX -eq 0 ]; then
    CURRENT_NAME="$BASE_SKILL_NAME"
  else
    CURRENT_NAME="${BASE_SKILL_NAME}-${SUFFIX}"
  fi

  # Validate CURRENT path right before creation (prevents TOCTOU race condition)
  CURRENT_PATH="$SKILL_OUTPUT_PATH/$CURRENT_NAME"
  if ! validate_path_under "$CURRENT_PATH" "$SKILL_OUTPUT_PATH"; then
    echo "❌ Error: Invalid skill path detected (potential path traversal)"
    exit 1
  fi

  # mkdir (without -p) fails if directory exists - atomic check+create
  if mkdir "$CURRENT_PATH" 2>/dev/null; then
    SKILL_NAME="$CURRENT_NAME"
    SKILL_DIR="$CURRENT_PATH"
    break
  fi
  SUFFIX=$((SUFFIX + 1))
done

if [ -z "$SKILL_DIR" ]; then
  echo "❌ Error: Failed to generate unique skill name after $MAX_SKILL_NAME_ATTEMPTS attempts"
  exit 1
fi

# ============================================================================
# Generate Skill File
# ============================================================================

# Escape variables for sed substitution
SAFE_SKILL_NAME=$(escape_sed "$SKILL_NAME")
SAFE_INSTRUCTION=$(escape_sed "$INSTRUCTION")
SAFE_SITUATION=$(escape_sed "$SITUATION")

# Generate Skill using template file
if ! sed -e "s|{{SKILL_NAME}}|$SAFE_SKILL_NAME|g" \
    -e "s|{{INSTRUCTION}}|$SAFE_INSTRUCTION|g" \
    -e "s|{{SITUATION}}|$SAFE_SITUATION|g" \
    -e "s|{{COUNT}}|$COUNT|g" \
    -e "s|{{FIRST_SEEN}}|$FIRST_SEEN|g" \
    -e "s|{{LAST_SEEN}}|$LAST_SEEN|g" \
    "$TEMPLATE_PATH" > "$SKILL_DIR/SKILL.md"; then
  rm -rf "$SKILL_DIR"
  echo "❌ Error: Failed to generate skill file"
  exit 1
fi

# ============================================================================
# Update Database
# ============================================================================

# Escape skill path for SQL
SAFE_SKILL_PATH=$(escape_sql "$SKILL_DIR")

# Update database: mark as promoted, reset dismissed flag
if ! sqlite3 "$DB_PATH" "UPDATE patterns SET promoted = 1, dismissed = 0, skill_path = '$SAFE_SKILL_PATH' WHERE id = $PATTERN_ID;"; then
  echo "⚠️ Warning: Skill file created but database update failed"
  echo "   Skill path: $SKILL_DIR/SKILL.md"
fi

# ============================================================================
# Output Result
# ============================================================================

echo "SKILL_CREATED: $SKILL_DIR/SKILL.md"
