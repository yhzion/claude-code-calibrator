---
name: calibrate review
description: Review accumulated patterns and promote to Skills
arguments:
  - name: mode
    description: "Review mode: default (pending patterns) or --dismissed (previously declined patterns)"
    required: false
allowed-tools: Bash(git:*), Bash(sqlite3:*), Bash(test:*), Bash(mkdir:*), Bash(sed:*), Bash(printf:*), Bash(tr:*), Bash(cut:*), Bash(date:*), Bash(echo:*), Bash(awk:*)
---

# /calibrate review [--dismissed]

Review repeated patterns and promote them to Skills.

## Usage

- `/calibrate review` - Review pending patterns (count >= 2, not promoted, not dismissed)
- `/calibrate review --dismissed` - Review previously dismissed patterns for manual promotion

## Pre-execution Setup

### Step 0: Dependency and DB Check
```bash
set -euo pipefail
IFS=$'\n\t'

# Ensure UTF-8 locale for proper character handling
export LC_ALL=C.UTF-8 2>/dev/null || export LC_ALL=en_US.UTF-8 2>/dev/null || true

# Get project root (Git root or current directory as fallback)
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
DB_PATH="$PROJECT_ROOT/.claude/calibrator/patterns.db"
# Configurable threshold (default: 2)
THRESHOLD="${CALIBRATOR_THRESHOLD:-2}"
SKILL_OUTPUT_PATH="$PROJECT_ROOT/.claude/skills"

# POSIX-compatible version comparison (returns 0 if $1 >= $2)
version_ge() {
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

if ! command -v sqlite3 &> /dev/null; then
  echo "❌ Error: sqlite3 is required but not installed."
  exit 1
fi

# SQLite 3.24.0+ required for UPSERT support
SQLITE_VERSION=$(sqlite3 --version 2>/dev/null | awk '{print $1}')
MIN_SQLITE_VERSION="3.24.0"
if ! version_ge "$SQLITE_VERSION" "$MIN_SQLITE_VERSION"; then
  echo "❌ Error: SQLite $MIN_SQLITE_VERSION or higher required. Found: ${SQLITE_VERSION:-unknown}"
  exit 1
fi

if [ ! -f "$DB_PATH" ]; then
  echo "❌ Calibrator is not initialized. Run /calibrate init first."
  exit 1
fi

# ============================================================================
# Schema Migration (auto-upgrade for backwards compatibility)
# ============================================================================

# Check and auto-migrate schema if needed
CURRENT_VERSION=$(sqlite3 "$DB_PATH" "SELECT version FROM schema_version ORDER BY applied_at DESC LIMIT 1;" 2>/dev/null || echo "")
if [ -z "$CURRENT_VERSION" ]; then
  CURRENT_VERSION="1.0"
fi

if [ "$CURRENT_VERSION" = "1.0" ]; then
  echo "🔄 Auto-migrating database schema from v1.0 to v1.1..."

  # Add dismissed column if it doesn't exist
  HAS_DISMISSED=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM pragma_table_info('patterns') WHERE name='dismissed';" 2>/dev/null || echo "0")

  if [ "$HAS_DISMISSED" = "0" ]; then
    if ! sqlite3 "$DB_PATH" "ALTER TABLE patterns ADD COLUMN dismissed INTEGER NOT NULL DEFAULT 0 CHECK(dismissed IN (0, 1));"; then
      echo "❌ Error: Failed to migrate database. Run /calibrate init to upgrade."
      exit 1
    fi
    sqlite3 "$DB_PATH" "CREATE INDEX IF NOT EXISTS idx_patterns_dismissed ON patterns(dismissed);" 2>/dev/null || true
  fi

  sqlite3 "$DB_PATH" "INSERT OR REPLACE INTO schema_version (version) VALUES ('1.1');" 2>/dev/null || true
  echo "✅ Database migrated to schema v1.1"
fi

# ============================================================================
# Path Validation
# ============================================================================

# Path traversal protection: validate that a path is under allowed directory
# (consistent with calibrate-delete.md and calibrate-refactor-skills.md)
validate_skill_path() {
  local path="$1"
  local resolved_path resolved_base

  # Resolve to absolute path and check it's under SKILL_OUTPUT_PATH
  # realpath -m handles non-existent paths and returns absolute path
  resolved_path=$(realpath -m "$path" 2>/dev/null || echo "")
  resolved_base=$(realpath -m "$SKILL_OUTPUT_PATH" 2>/dev/null || echo "")

  if [ -z "$resolved_path" ] || [ -z "$resolved_base" ]; then
    return 1
  fi

  # Check path starts with base directory
  case "$resolved_path" in
    "$resolved_base"/*) return 0 ;;
    *) return 1 ;;
  esac
}
```

## Flow

### Step 1: Determine Review Mode
Check if `--dismissed` argument was provided:
- If `--dismissed` → Query dismissed patterns
- Otherwise → Query pending patterns (default)

### Step 2: Query Promotion Candidates

**Default mode (pending patterns):**
```bash
# Query patterns meeting threshold that haven't been promoted or dismissed.
# Columns: id, situation, instruction, count, first_seen, last_seen
CANDIDATES=$(sqlite3 -separator $'\t' "$DB_PATH" \
  "SELECT id, situation, instruction, count, first_seen, last_seen FROM patterns WHERE count >= $THRESHOLD AND promoted = 0 AND (dismissed = 0 OR dismissed IS NULL) ORDER BY count DESC LIMIT 100;" \
  2>/dev/null) || CANDIDATES=""
```

**Dismissed mode (`--dismissed`):**
```bash
# Query dismissed patterns for manual review.
# Columns: id, situation, instruction, count, first_seen, last_seen
CANDIDATES=$(sqlite3 -separator $'\t' "$DB_PATH" \
  "SELECT id, situation, instruction, count, first_seen, last_seen FROM patterns WHERE dismissed = 1 AND promoted = 0 ORDER BY count DESC LIMIT 100;" \
  2>/dev/null) || CANDIDATES=""
```

### Step 3-A: No Candidates (Default Mode)
```
📊 No patterns available for promotion

Patterns need to repeat 2+ times to be promoted to a Skill.
Keep recording with /calibrate.
```

### Step 3-A: No Candidates (Dismissed Mode)
```
📋 No dismissed patterns found

Dismissed patterns are those you previously declined to promote.
Use `/calibrate review` to see pending patterns instead.
```

### Step 3-B: Candidates Found (Default Mode)

Display the candidates list with selection options:
```
📊 Skill Promotion Candidates (2+ repetitions)

[id=12] Model creation → Always include timestamp fields (3 times)
[id=15] API endpoint → Always include error handling (2 times)

Enter pattern id(s) to promote (comma-separated for multiple, or 'skip' to cancel):
Example: 12 or 12,15
```

### Step 3-B: Candidates Found (Dismissed Mode)

Display the dismissed patterns list:
```
📋 Previously Dismissed Patterns

These patterns were declined for automatic promotion.
You can manually promote them now.

[id=12] Model creation → Always include timestamp fields (3 times, dismissed)
[id=15] API endpoint → Always include error handling (2 times, dismissed)

Enter pattern id(s) to promote (comma-separated for multiple, or 'skip' to cancel):
Example: 12 or 12,15
```

Note: The list should be dynamically generated from the CANDIDATES query result.

Wait for user response:
- User responds with id(s) (e.g., "12" or "12,15") → Parse and process each PATTERN_ID
- User responds "skip" or "cancel" → Exit with message: "No patterns promoted."

### Step 4: Load Pattern Details
For each selected `PATTERN_ID`:
```bash
# Validate id defensively
if ! [[ "$PATTERN_ID" =~ ^[0-9]+$ ]]; then
  echo "❌ Error: Invalid pattern id '$PATTERN_ID'"
  exit 1
fi

ROW=$(sqlite3 -separator $'\t' "$DB_PATH" \
  "SELECT situation, instruction, count, first_seen, last_seen FROM patterns WHERE id = $PATTERN_ID AND promoted = 0;" \
  2>/dev/null) || ROW=""

if [ -z "$ROW" ]; then
  echo "❌ Error: Pattern not found or already promoted (id=$PATTERN_ID)"
  exit 1
fi

IFS=$'\t' read -r SITUATION INSTRUCTION COUNT FIRST_SEEN LAST_SEEN <<<"$ROW"
```

### Step 5: Skill Preview and Confirmation

Display the skill preview:
```
📝 Skill Preview: {situation}

---
name: {kebab-case situation}
description: {instruction}. Auto-applied in {situation} situations.
learned_from: calibrator ({count} repetitions, {first_seen} ~ {last_seen})
---

## Rules

{instruction}

## Applies to

- {situation}

## Learning History

This Skill was auto-generated by Calibrator.
- First detected: {first_seen}
- Last detected: {last_seen}
- Repetitions: {count}
```

Then ask the user for confirmation:

```
What would you like to do with this skill?

1. Save skill (Recommended) - Create the skill file and activate it
2. Edit first - Modify the instruction before saving
3. Skip - Don't create this skill

Select action (1/2/3):
```

Wait for user response:
- User responds "1" or "save" → Proceed to Step 5
- User responds "2" or "edit" → Ask "Enter the modified instruction:" and wait for response, then proceed to Step 5
- User responds "3" or "skip" → Skip this pattern and continue to next (if any)

### Step 6: Skill Creation
On save selection:
```bash
# Generate Skill name (kebab-case) - Path Traversal prevention
SKILL_NAME=$(printf '%s' "$SITUATION" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g')
# Collapse multiple consecutive hyphens and remove leading/trailing hyphens
SKILL_NAME=$(printf '%s' "$SKILL_NAME" | sed 's/-\{2,\}/-/g; s/^-//; s/-$//')
SKILL_NAME=$(printf '%s' "$SKILL_NAME" | cut -c1-50)
# Remove any trailing hyphen that might result from truncation
SKILL_NAME=$(printf '%s' "$SKILL_NAME" | sed 's/-$//')
if [ -z "$SKILL_NAME" ]; then
  SKILL_NAME="skill-$(date +%Y%m%d-%H%M%S)"
fi

# Handle skill name collisions atomically using mkdir (avoids TOCTOU race condition)
# First ensure parent directory exists
mkdir -p "$SKILL_OUTPUT_PATH"

# Configurable max attempts (environment variable or default)
MAX_SKILL_NAME_ATTEMPTS="${CALIBRATOR_MAX_NAME_ATTEMPTS:-100}"

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
  if ! validate_skill_path "$CURRENT_PATH"; then
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

# Escape variables for sed substitution (handles multi-line and special characters)
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
SAFE_SKILL_NAME=$(escape_sed "$SKILL_NAME")
SAFE_INSTRUCTION=$(escape_sed "$INSTRUCTION")
SAFE_SITUATION=$(escape_sed "$SITUATION")

# Verify template file exists
# Use CLAUDE_PLUGIN_ROOT if available (plugin installation), fallback to PROJECT_ROOT
TEMPLATE_PATH="${CLAUDE_PLUGIN_ROOT:-$PROJECT_ROOT/plugins/calibrator}/templates/skill-template.md"
if [ ! -f "$TEMPLATE_PATH" ]; then
  echo "❌ Error: Template file not found at $TEMPLATE_PATH"
  rmdir "$SKILL_DIR" 2>/dev/null  # Cleanup empty directory
  exit 1
fi

# Generate Skill using template file
if ! sed -e "s|{{SKILL_NAME}}|$SAFE_SKILL_NAME|g" \
    -e "s|{{INSTRUCTION}}|$SAFE_INSTRUCTION|g" \
    -e "s|{{SITUATION}}|$SAFE_SITUATION|g" \
    -e "s|{{COUNT}}|$COUNT|g" \
    -e "s|{{FIRST_SEEN}}|$FIRST_SEEN|g" \
    -e "s|{{LAST_SEEN}}|$LAST_SEEN|g" \
    "$TEMPLATE_PATH" > "$SKILL_OUTPUT_PATH/$SKILL_NAME/SKILL.md"; then
  echo "❌ Error: Failed to generate skill file"
  rm -rf "$SKILL_DIR"  # Cleanup on failure
  exit 1
fi

# SQL Injection prevention: escape single quotes
escape_sql() {
  printf '%s' "$1" | sed "s/'/''/g"
}
SAFE_SKILL_PATH=$(escape_sql "$SKILL_OUTPUT_PATH/$SKILL_NAME")

# Update database with error handling
# Also reset dismissed flag when promoting (for --dismissed mode)
if ! sqlite3 "$DB_PATH" "UPDATE patterns SET promoted = 1, dismissed = 0, skill_path = '$SAFE_SKILL_PATH' WHERE id = $PATTERN_ID;"; then
  echo "⚠️ Warning: Skill file created but database update failed"
  echo "   Skill path: $SKILL_OUTPUT_PATH/$SKILL_NAME/SKILL.md"
fi

# Output completion message (guaranteed to display)
printf '\n✅ Skill created\n\n- %s/%s/SKILL.md\n\n🔄 To activate this Skill, start a new Claude Code session.\n   (Skills are loaded at session start)\n\nClaude will then automatically apply this rule in "%s" situations.\n' "$SKILL_OUTPUT_PATH" "$SKILL_NAME" "$SITUATION"
```

## Reference: Skill Name Conversion Rules

- Space → hyphen
- Uppercase → lowercase
- Remove special characters
- Example: "Model creation" → "model-creation"
- Example: "API endpoint" → "api-endpoint"
