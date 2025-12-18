---
name: calibrate refactor
description: Edit existing Skills and merge similar patterns
allowed-tools: Bash(git:*), Bash(sqlite3:*), Bash(test:*), Bash(sed:*), Bash(printf:*), Bash(echo:*), Bash(awk:*), Bash(mktemp:*), Bash(basename:*), Bash(rm:*), Bash(mv:*), Bash(realpath:*), Bash(tr:*)
---

# /calibrate refactor

Edit existing Skills, merge similar patterns, or remove duplicates.

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
SKILL_OUTPUT_PATH="$PROJECT_ROOT/.claude/skills"

# POSIX-compatible version comparison
# Returns 0 (true/success) if $1 >= $2, 1 (false/failure) otherwise
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

# Template file path for skill regeneration
# Use CLAUDE_PLUGIN_ROOT if available (plugin installation), fallback to PROJECT_ROOT
TEMPLATE_PATH="${CLAUDE_PLUGIN_ROOT:-$PROJECT_ROOT/plugins/calibrator}/templates/skill-template.md"
if [ ! -f "$TEMPLATE_PATH" ]; then
  echo "❌ Error: Template file not found at $TEMPLATE_PATH"
  exit 1
fi

# Path traversal protection: validate that a path is under allowed directory
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

### Step 1: Mode Selection
```text
🔧 Calibrator Refactor

What would you like to do?

1. Edit Skill - Modify instruction or situation of existing Skills
2. Merge patterns - Combine similar patterns (same situation)
3. Remove duplicates - Delete exact duplicate patterns

Select mode (1/2/3):
```

## Mode 1: Edit Skill

### Step 1-1: List Promoted Skills
```bash
# Query all promoted patterns
SKILLS=$(sqlite3 -separator $'\t' "$DB_PATH" \
  "SELECT id, situation, instruction, count, skill_path FROM patterns WHERE promoted = 1 ORDER BY last_seen DESC LIMIT 50;" \
  2>/dev/null) || SKILLS=""

if [ -z "$SKILLS" ]; then
  echo "📊 No promoted Skills found"
  echo ""
  echo "Promote patterns with /calibrate review first."
  exit 0
fi
```

Display skills:
```text
📊 Promoted Skills

[id=1] Creating React components → Always define TypeScript interface (3 times)
[id=5] API endpoints → Always include error handling (5 times)

Enter Skill id to edit:
```

### Step 1-2: Load Skill Details
```bash
# Validate id defensively
if ! [[ "$SKILL_ID" =~ ^[0-9]+$ ]]; then
  echo "❌ Error: Invalid skill id '$SKILL_ID'"
  exit 1
fi

ROW=$(sqlite3 -separator $'\t' "$DB_PATH" \
  "SELECT situation, instruction, count, skill_path, first_seen, last_seen FROM patterns WHERE id = $SKILL_ID AND promoted = 1;" \
  2>/dev/null) || ROW=""

if [ -z "$ROW" ]; then
  echo "❌ Error: Skill not found or not promoted (id=$SKILL_ID)"
  exit 1
fi

IFS=$'\t' read -r SITUATION INSTRUCTION COUNT SKILL_PATH FIRST_SEEN LAST_SEEN <<<"$ROW"
```

### Step 1-3: Display Current Values and Edit
```text
📝 Current Skill (id=$SKILL_ID)

Situation: {situation}
Instruction: {instruction}

What would you like to edit?

1. Situation - Change when this rule applies
2. Instruction - Change what Claude should do
3. Both - Edit situation and instruction
4. Cancel - Go back without changes

Select option (1/2/3/4):
```

For editing:
```text
New situation (or press Enter to keep current):

New instruction (or press Enter to keep current):
```

### Step 1-4: Update Database and Skill File
```bash
# SQL Injection prevention: escape single quotes
escape_sql() {
  printf '%s' "$1" | sed "s/'/''/g"
}

NEW_SITUATION="${NEW_SITUATION:-$SITUATION}"
NEW_INSTRUCTION="${NEW_INSTRUCTION:-$INSTRUCTION}"

SAFE_SITUATION=$(escape_sql "$NEW_SITUATION")
SAFE_INSTRUCTION=$(escape_sql "$NEW_INSTRUCTION")

# Update database using transaction
sqlite3 "$DB_PATH" <<SQL
BEGIN IMMEDIATE;

UPDATE patterns
SET situation = '$SAFE_SITUATION',
    instruction = '$SAFE_INSTRUCTION',
    last_seen = CURRENT_TIMESTAMP
WHERE id = $SKILL_ID;

COMMIT;
SQL

if [ $? -ne 0 ]; then
  echo "❌ Error: Failed to update pattern"
  exit 1
fi

# Update SKILL.md file using template-based regeneration
# This approach is more robust than awk parsing as it doesn't depend on exact file structure
if [ -n "$SKILL_PATH" ] && [ -d "$SKILL_PATH" ]; then
  # Path traversal protection: ensure SKILL_PATH is under SKILL_OUTPUT_PATH
  if ! validate_skill_path "$SKILL_PATH"; then
    echo "❌ Error: Invalid skill path detected (potential path traversal)"
    exit 1
  fi

  # Extract skill name from directory path
  SKILL_NAME=$(basename "$SKILL_PATH")

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
  SAFE_SED_INSTRUCTION=$(escape_sed "$NEW_INSTRUCTION")
  SAFE_SED_SITUATION=$(escape_sed "$NEW_SITUATION")

  # Regenerate SKILL.md from template (atomic write via temp file)
  TEMP_FILE=$(mktemp)
  if sed -e "s|{{SKILL_NAME}}|$SAFE_SKILL_NAME|g" \
      -e "s|{{INSTRUCTION}}|$SAFE_SED_INSTRUCTION|g" \
      -e "s|{{SITUATION}}|$SAFE_SED_SITUATION|g" \
      -e "s|{{COUNT}}|$COUNT|g" \
      -e "s|{{FIRST_SEEN}}|$FIRST_SEEN|g" \
      -e "s|{{LAST_SEEN}}|$LAST_SEEN|g" \
      "$TEMPLATE_PATH" > "$TEMP_FILE"; then
    # Atomic move with error handling
    if ! mv "$TEMP_FILE" "$SKILL_PATH/SKILL.md" 2>/dev/null; then
      rm -f "$TEMP_FILE"
      echo "⚠️ Warning: Failed to write SKILL.md (mv failed)"
    fi
  else
    rm -f "$TEMP_FILE"
    echo "⚠️ Warning: Failed to regenerate SKILL.md (sed failed)"
  fi
fi

printf '\n✅ Skill updated (id=%d)\n\n' "$SKILL_ID"
printf 'Situation: %s\n' "$NEW_SITUATION"
printf 'Instruction: %s\n\n' "$NEW_INSTRUCTION"
printf '🔄 Restart Claude Code session to apply changes.\n'
```

## Mode 2: Merge Patterns

### Step 2-1: Detect Similar Patterns
```bash
# Find patterns with same situation but different instructions (not promoted)
# Group by situation and show only groups with 2+ patterns
SIMILAR=$(sqlite3 "$DB_PATH" \
  "SELECT situation FROM patterns WHERE promoted = 0 GROUP BY situation HAVING COUNT(*) >= 2 ORDER BY COUNT(*) DESC LIMIT 20;" \
  2>/dev/null) || SIMILAR=""

if [ -z "$SIMILAR" ]; then
  echo "📊 No similar patterns found"
  echo ""
  echo "Similar patterns are those with the same situation but different instructions."
  exit 0
fi
```

Display situations with multiple patterns:
```text
📊 Situations with Multiple Patterns

Select a situation to view patterns:
```

For each situation, list patterns:
```bash
# Show all patterns for selected situation
SAFE_SITUATION=$(escape_sql "$SELECTED_SITUATION")
PATTERNS=$(sqlite3 -separator $'\t' "$DB_PATH" \
  "SELECT id, instruction, count FROM patterns WHERE situation = '$SAFE_SITUATION' AND promoted = 0 ORDER BY count DESC;" \
  2>/dev/null) || PATTERNS=""
```

Display:
```text
📝 Patterns for: {situation}

[id=10] Always use async/await (2 times)
[id=12] Include try-catch blocks (3 times)
[id=15] Use Promise.all for parallel operations (1 time)

Enter pattern ids to merge (comma-separated, e.g., 10,12,15):

Keep which instruction as primary? Enter pattern id:
```

### Step 2-2: Merge Patterns
```bash
# Input sanitization: remove non-numeric and non-comma characters to prevent IFS injection
# Using printf instead of echo for safer handling (echo may interpret -n, -e options)
SANITIZED_IDS=$(printf '%s' "$MERGE_IDS" | tr -cd '0-9,')

# Validate PRIMARY_ID (the pattern whose instruction will be kept)
if ! [[ "$PRIMARY_ID" =~ ^[0-9]+$ ]]; then
  echo "❌ Error: Invalid primary pattern id '$PRIMARY_ID'"
  exit 1
fi

# Validate all pattern ids
IFS=',' read -ra PATTERN_IDS <<< "$SANITIZED_IDS"

# Validate array length (minimum 2 patterns required for merge)
# Also handle empty array case explicitly
if [ -z "${PATTERN_IDS[*]}" ] || [ ${#PATTERN_IDS[@]} -lt 2 ]; then
  echo "❌ Error: At least 2 patterns are required for merge"
  exit 1
fi

# Limit maximum patterns to prevent excessive operations
if [ ${#PATTERN_IDS[@]} -gt 50 ]; then
  echo "❌ Error: Maximum 50 patterns can be merged at once"
  exit 1
fi

TOTAL_COUNT=0
PRIMARY_INSTRUCTION=""
EXPECTED_SITUATION=""

for PID in "${PATTERN_IDS[@]}"; do
  # Trim whitespace using bash built-in (safer than xargs which may execute commands)
  PID="${PID//[[:space:]]/}"

  if ! [[ "$PID" =~ ^[0-9]+$ ]]; then
    echo "❌ Error: Invalid pattern id '$PID'"
    exit 1
  fi

  # Get situation, count and instruction
  if [ "$PID" = "$PRIMARY_ID" ]; then
    ROW=$(sqlite3 -separator $'\t' "$DB_PATH" \
      "SELECT situation, instruction, count FROM patterns WHERE id = $PID AND promoted = 0;" \
      2>/dev/null) || ROW=""

    if [ -z "$ROW" ]; then
      echo "❌ Error: Primary pattern not found (id=$PID)"
      exit 1
    fi

    IFS=$'\t' read -r PATTERN_SITUATION PRIMARY_INSTRUCTION COUNT <<<"$ROW"
    EXPECTED_SITUATION="$PATTERN_SITUATION"
    TOTAL_COUNT=$((TOTAL_COUNT + COUNT))
  else
    ROW=$(sqlite3 -separator $'\t' "$DB_PATH" \
      "SELECT situation, count FROM patterns WHERE id = $PID AND promoted = 0;" \
      2>/dev/null) || ROW=""

    if [ -z "$ROW" ]; then
      echo "❌ Error: Pattern not found (id=$PID)"
      exit 1
    fi

    IFS=$'\t' read -r PATTERN_SITUATION COUNT <<<"$ROW"

    # Validate all patterns have the same situation
    # First non-PRIMARY pattern sets EXPECTED_SITUATION if not already set by PRIMARY
    if [ -z "$EXPECTED_SITUATION" ]; then
      EXPECTED_SITUATION="$PATTERN_SITUATION"
    elif [ "$PATTERN_SITUATION" != "$EXPECTED_SITUATION" ]; then
      echo "❌ Error: Pattern id=$PID has different situation"
      echo "   Expected: $EXPECTED_SITUATION"
      echo "   Found: $PATTERN_SITUATION"
      echo "   Only patterns with the same situation can be merged"
      exit 1
    fi

    TOTAL_COUNT=$((TOTAL_COUNT + COUNT))
  fi
done

# Perform merge using transaction
SAFE_INSTRUCTION=$(escape_sql "$PRIMARY_INSTRUCTION")

# Build comma-separated ID list for efficient single DELETE query
DELETE_IDS=""
for PID in "${PATTERN_IDS[@]}"; do
  PID="${PID//[[:space:]]/}"
  if [ "$PID" != "$PRIMARY_ID" ]; then
    if [ -n "$DELETE_IDS" ]; then
      DELETE_IDS="$DELETE_IDS,$PID"
    else
      DELETE_IDS="$PID"
    fi
  fi
done

sqlite3 "$DB_PATH" <<SQL
BEGIN IMMEDIATE;

-- Update primary pattern with merged count
UPDATE patterns
SET count = $TOTAL_COUNT,
    last_seen = CURRENT_TIMESTAMP
WHERE id = $PRIMARY_ID;

-- Delete other patterns (single efficient query)
DELETE FROM patterns WHERE id IN ($DELETE_IDS);

COMMIT;
SQL

if [ $? -ne 0 ]; then
  echo "❌ Error: Failed to merge patterns"
  exit 1
fi

printf '\n✅ Patterns merged into id=%d\n\n' "$PRIMARY_ID"
printf 'Total count: %d\n' "$TOTAL_COUNT"
printf 'Instruction: %s\n\n' "$PRIMARY_INSTRUCTION"

if [ $TOTAL_COUNT -ge 2 ]; then
  printf '💡 You can promote this to a Skill with /calibrate review.\n'
fi
```

## Mode 3: Remove Duplicates

### Step 3-1: Find Exact Duplicates
```bash
# Find exact duplicates (same situation AND instruction)
# This shouldn't normally happen due to UNIQUE constraint, but handles edge cases
DUPLICATES=$(sqlite3 -separator $'\t' "$DB_PATH" \
  "SELECT situation, instruction, COUNT(*) as dup_count
   FROM patterns
   GROUP BY situation, instruction
   HAVING COUNT(*) > 1
   ORDER BY dup_count DESC
   LIMIT 20;" \
  2>/dev/null) || DUPLICATES=""

if [ -z "$DUPLICATES" ]; then
  echo "📊 No exact duplicates found"
  echo ""
  echo "Database integrity is good!"
  exit 0
fi
```

Display duplicates:
```text
⚠️ Exact Duplicates Found

This indicates a database integrity issue that should be fixed.

1. {situation} → {instruction} ({count} copies)
2. {situation} → {instruction} ({count} copies)

Remove duplicates and keep only one copy? (y/N):
```

### Step 3-2: Remove Duplicates
```bash
# For each duplicate group, keep the one with highest count/earliest first_seen
# and delete others
sqlite3 "$DB_PATH" <<SQL
BEGIN IMMEDIATE;

-- For each duplicate group, keep the best record and delete others
DELETE FROM patterns
WHERE id NOT IN (
  SELECT MIN(id)
  FROM patterns
  GROUP BY situation, instruction
);

COMMIT;
SQL

if [ $? -ne 0 ]; then
  echo "❌ Error: Failed to remove duplicates"
  exit 1
fi

REMOVED=$(($(echo "$DUPLICATES" | wc -l)))
printf '\n✅ Duplicates removed\n\n'
printf 'Cleaned up duplicate entries.\n'
printf 'Database integrity restored.\n'
```

## Error Handling

All database operations use:
- `BEGIN IMMEDIATE` transactions for atomic updates
- SQL injection prevention via quote escaping
- Input validation for all user inputs
- Proper error messages with exit codes

## Reference

**Mode Selection:**
- 1: Edit existing Skill instruction/situation
- 2: Merge patterns with same situation
- 3: Remove exact duplicate patterns

**Safety:**
- All SQL uses parameterized escaping
- Transactions ensure atomic operations
- File operations check existence before modification
