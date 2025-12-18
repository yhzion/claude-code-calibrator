#!/bin/bash
# Calibrator Shared Utilities
# Source this file in command scripts: source "${CLAUDE_PLUGIN_ROOT:-$PROJECT_ROOT/plugins/calibrator}/scripts/utils.sh"

# ============================================================================
# Version Comparison
# ============================================================================

# POSIX-compatible semantic version comparison
# Compares two version strings (e.g., "3.24.0" vs "3.20.0")
#
# Arguments:
#   $1 - Version to check (e.g., "3.24.0")
#   $2 - Minimum required version (e.g., "3.20.0")
#
# Returns:
#   0 (success/true)  - if $1 >= $2
#   1 (failure/false) - if $1 < $2
#
# Examples:
#   version_ge "3.24.0" "3.20.0"  # returns 0 (true: 3.24.0 >= 3.20.0)
#   version_ge "3.24.0" "3.24.0"  # returns 0 (true: equal versions)
#   version_ge "3.20.0" "3.24.0"  # returns 1 (false: 3.20.0 < 3.24.0)
#
# Usage in conditionals:
#   if version_ge "$VERSION" "3.24.0"; then echo "OK"; fi
#
version_ge() {
  # Note: Arguments are swapped in awk to simplify comparison logic
  # awk reads $2 first (min version), then $1 (actual version)
  printf '%s\n%s' "$2" "$1" | awk -F. '
    NR==1 { split($0,a,"."); next }
    NR==2 { split($0,b,".")
      for(i=1; i<=3; i++) {
        if((b[i]+0) > (a[i]+0)) exit 0
        if((b[i]+0) < (a[i]+0)) exit 1
      }
      exit 0
    }'
}

# ============================================================================
# SQLite Checks
# ============================================================================

# Check if sqlite3 is installed and meets minimum version requirement
# Usage: check_sqlite_version || exit 1
check_sqlite_version() {
  if ! command -v sqlite3 &> /dev/null; then
    echo "❌ Error: sqlite3 is required but not installed."
    return 1
  fi

  local sqlite_version min_version="3.24.0"
  sqlite_version=$(sqlite3 --version 2>/dev/null | awk '{print $1}')

  if ! version_ge "$sqlite_version" "$min_version"; then
    echo "❌ Error: SQLite $min_version or higher required. Found: ${sqlite_version:-unknown}"
    return 1
  fi

  return 0
}

# ============================================================================
# Schema Migration
# ============================================================================

# Check schema version and migrate if needed
# Usage: ensure_schema_version "$DB_PATH" || exit 1
ensure_schema_version() {
  local db_path="$1"
  local current_version target_version="1.1"

  if [ ! -f "$db_path" ]; then
    return 0  # No DB, nothing to migrate
  fi

  # Get current schema version
  current_version=$(sqlite3 "$db_path" "SELECT version FROM schema_version ORDER BY applied_at DESC LIMIT 1;" 2>/dev/null || echo "")

  # If no version found, assume 1.0 (pre-versioning)
  if [ -z "$current_version" ]; then
    current_version="1.0"
  fi

  # Already at target version
  if [ "$current_version" = "$target_version" ]; then
    return 0
  fi

  # Migrate from 1.0 to 1.1
  if [ "$current_version" = "1.0" ]; then
    echo "🔄 Migrating database schema from v1.0 to v1.1..."

    # Add dismissed column if it doesn't exist
    # SQLite doesn't have IF NOT EXISTS for ADD COLUMN, so we check first
    local has_dismissed
    has_dismissed=$(sqlite3 "$db_path" "SELECT COUNT(*) FROM pragma_table_info('patterns') WHERE name='dismissed';" 2>/dev/null || echo "0")

    if [ "$has_dismissed" = "0" ]; then
      if ! sqlite3 "$db_path" "ALTER TABLE patterns ADD COLUMN dismissed INTEGER NOT NULL DEFAULT 0 CHECK(dismissed IN (0, 1));"; then
        echo "❌ Error: Failed to add dismissed column"
        return 1
      fi

      # Add index for dismissed column
      sqlite3 "$db_path" "CREATE INDEX IF NOT EXISTS idx_patterns_dismissed ON patterns(dismissed);" 2>/dev/null || true
    fi

    # Update schema version
    sqlite3 "$db_path" "INSERT OR REPLACE INTO schema_version (version) VALUES ('1.1');" 2>/dev/null || true

    echo "✅ Database migrated to schema v1.1"
  fi

  return 0
}

# ============================================================================
# String Escaping
# ============================================================================

# Escape string for SQL (prevents SQL injection)
# Usage: SAFE_VALUE=$(escape_sql "$VALUE")
escape_sql() {
  printf '%s' "$1" | sed "s/'/''/g"
}

# Escape string for sed substitution (handles special characters)
# Usage: SAFE_VALUE=$(escape_sed "$VALUE")
escape_sed() {
  printf '%s' "$1" | awk '
    BEGIN { ORS="" }
    {
      gsub(/\\/, "\\\\")
      gsub(/&/, "\\\\&")
      gsub(/\|/, "\\|")
      if (NR > 1) printf "\\n"
      print
    }
  '
}

# ============================================================================
# Path Validation
# ============================================================================

# Validate that a path is under an allowed base directory (path traversal protection)
# Usage: validate_path_under "$path" "$base_dir" || exit 1
validate_path_under() {
  local path="$1"
  local base_dir="$2"
  local resolved_path resolved_base

  # Try realpath first (GNU coreutils), fall back to manual resolution
  if command -v realpath &> /dev/null; then
    resolved_path=$(realpath -m "$path" 2>/dev/null || echo "")
    resolved_base=$(realpath -m "$base_dir" 2>/dev/null || echo "")
  else
    # Fallback: use cd/pwd for existing paths, basic sanitization for new paths
    if [ -e "$path" ]; then
      resolved_path=$(cd "$(dirname "$path")" 2>/dev/null && pwd)/$(basename "$path")
    else
      # For non-existent paths, resolve parent and append basename
      local parent_dir
      parent_dir=$(dirname "$path")
      if [ -d "$parent_dir" ]; then
        resolved_path=$(cd "$parent_dir" 2>/dev/null && pwd)/$(basename "$path")
      else
        # Can't resolve, reject for safety
        return 1
      fi
    fi

    if [ -d "$base_dir" ]; then
      resolved_base=$(cd "$base_dir" 2>/dev/null && pwd)
    else
      return 1
    fi
  fi

  if [ -z "$resolved_path" ] || [ -z "$resolved_base" ]; then
    return 1
  fi

  # Check path starts with base directory
  case "$resolved_path" in
    "$resolved_base"/*) return 0 ;;
    *) return 1 ;;
  esac
}

# ============================================================================
# Skill Name Generation
# ============================================================================

# Generate kebab-case skill name from situation text
# Usage: SKILL_NAME=$(generate_skill_name "$SITUATION")
generate_skill_name() {
  local situation="$1"
  local skill_name

  # Convert to kebab-case: lowercase, spaces to hyphens, remove special chars
  skill_name=$(printf '%s' "$situation" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g')
  # Collapse multiple consecutive hyphens and remove leading/trailing hyphens
  skill_name=$(printf '%s' "$skill_name" | sed 's/-\{2,\}/-/g; s/^-//; s/-$//')
  # Truncate to 50 characters and remove any trailing hyphen from truncation
  skill_name=$(printf '%s' "$skill_name" | cut -c1-50 | sed 's/-$//')

  # Fallback if empty
  if [ -z "$skill_name" ]; then
    skill_name="skill-$(date +%Y%m%d-%H%M%S)"
  fi

  printf '%s' "$skill_name"
}

# ============================================================================
# Common Setup
# ============================================================================

# Standard setup for all calibrator commands
# Sets: PROJECT_ROOT, DB_PATH, SKILL_OUTPUT_PATH, THRESHOLD
# Usage: calibrator_setup || exit 1
calibrator_setup() {
  # Bash strict mode
  set -euo pipefail
  IFS=$'\n\t'

  # Ensure UTF-8 locale
  export LC_ALL=C.UTF-8 2>/dev/null || export LC_ALL=en_US.UTF-8 2>/dev/null || true

  # Get project root (Git root or current directory as fallback)
  PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
  DB_PATH="$PROJECT_ROOT/.claude/calibrator/patterns.db"
  SKILL_OUTPUT_PATH="$PROJECT_ROOT/.claude/skills"

  # Configurable threshold (default: 2)
  THRESHOLD="${CALIBRATOR_THRESHOLD:-2}"

  # Export for use in calling script
  export PROJECT_ROOT DB_PATH SKILL_OUTPUT_PATH THRESHOLD
}
