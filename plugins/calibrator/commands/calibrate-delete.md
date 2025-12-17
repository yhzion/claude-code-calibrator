---
name: calibrate delete
description: Delete promoted Skills (multi-select)
allowed-tools: Bash(git:*), Bash(sqlite3:*), Bash(test:*), Bash(echo:*), Bash(rm:*), Bash(printf:*), Bash(realpath:*), Bash(tr:*)
---

# /calibrate delete

Delete promoted Skills with multi-select support.

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

if ! command -v sqlite3 &> /dev/null; then
  echo "❌ Error: sqlite3 is required but not installed."
  exit 1
fi

if [ ! -f "$DB_PATH" ]; then
  echo "❌ Calibrator is not initialized. Run /calibrate init first."
  exit 1
fi

# Skill output directory for path validation
SKILL_OUTPUT_PATH="$PROJECT_ROOT/.claude/skills"

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

### Step 1: Query Promoted Skills
```bash
# Query all promoted skills
SKILLS=$(sqlite3 -separator $'\t' "$DB_PATH" \
  "SELECT id, situation, instruction, count, skill_path FROM patterns WHERE promoted = 1 ORDER BY last_seen DESC LIMIT 100;" \
  2>/dev/null) || SKILLS=""
```

### Step 2-A: No Promoted Skills
```text
📊 No promoted Skills found

Nothing to delete. Promote patterns with /calibrate review first.
```

### Step 2-B: Skills Found

Display the skills list with selection options:
```text
🗑️ Delete Promoted Skills

Select Skills to delete (pattern data will be preserved, only SKILL.md files will be removed):

[id=1] Creating React components → Always define TypeScript interface (3 times)
       Path: .claude/skills/creating-react-components
[id=5] API endpoints → Always include error handling (5 times)
       Path: .claude/skills/api-endpoints

Enter skill id(s) to delete (comma-separated for multiple, or 'skip' to cancel):
Example: 1 or 1,5
```

Note: The list should be dynamically generated from the SKILLS query result.

Wait for user response:
- User responds with id(s) (e.g., "1" or "1,5") → Store as DELETE_IDS and proceed to Step 3
- User responds "skip" or "cancel" → Exit with message: "Deletion cancelled."

```bash
# Store user input for later use in Step 5
# DELETE_IDS should contain the user's response (e.g., "1" or "1,5")
DELETE_IDS="$USER_INPUT"
```

### Step 3: Validate and Load Selected Skills

For each selected `SKILL_ID`:
```bash
# Validate id defensively
if ! [[ "$SKILL_ID" =~ ^[0-9]+$ ]]; then
  echo "❌ Error: Invalid skill id '$SKILL_ID'"
  exit 1
fi

ROW=$(sqlite3 -separator $'\t' "$DB_PATH" \
  "SELECT situation, instruction, skill_path FROM patterns WHERE id = $SKILL_ID AND promoted = 1;" \
  2>/dev/null) || ROW=""

if [ -z "$ROW" ]; then
  echo "❌ Error: Skill not found or not promoted (id=$SKILL_ID)"
  exit 1
fi

IFS=$'\t' read -r SITUATION INSTRUCTION SKILL_PATH <<<"$ROW"
```

### Step 4: Confirmation

Display selected skills and request confirmation:
```text
⚠️ Skills to Delete

The following Skills will be deleted:

[id=1] Creating React components → Always define TypeScript interface
       File: .claude/skills/creating-react-components/SKILL.md

[id=5] API endpoints → Always include error handling
       File: .claude/skills/api-endpoints/SKILL.md

Note:
- Only SKILL.md files will be removed
- Pattern data in database will be preserved (promoted = 0)
- Patterns can be re-promoted later with /calibrate review

⚠️ Are you sure you want to delete these Skills?

1. Yes, delete selected Skills - Remove SKILL.md files and unpromote patterns
2. Cancel - Keep all Skills and exit

Confirm (1/2):
```

Wait for user response:
- User responds "1" or "yes" → Proceed to Step 5
- User responds "2" or "cancel" → Print "Deletion cancelled." and exit

### Step 5: Execute Deletion

For each selected skill:
```bash
# SQL Injection prevention: escape single quotes
escape_sql() {
  printf '%s' "$1" | sed "s/'/''/g"
}

# DELETE_IDS: User input from Step 2-B (e.g., "1" or "1,5")
# This variable should be set from the user's response before this step executes.
# Example: DELETE_IDS="1,5"

# Input sanitization: remove non-numeric and non-comma characters to prevent IFS injection
# Using printf instead of echo for safer handling (echo may interpret -n, -e options)
SANITIZED_IDS=$(printf '%s' "$DELETE_IDS" | tr -cd '0-9,')
IFS=',' read -ra SKILL_IDS <<< "$SANITIZED_IDS"

# Track results
DELETED_COUNT=0
FAILED_COUNT=0

# N+1 Optimization: Batch fetch all skill info in single query
# This avoids executing a separate SELECT for each SKILL_ID
ALL_SKILLS=$(sqlite3 -separator $'\t' "$DB_PATH" \
  "SELECT id, situation, skill_path FROM patterns WHERE id IN ($SANITIZED_IDS) AND promoted = 1;" \
  2>/dev/null) || ALL_SKILLS=""

# Process each skill
for SKILL_ID in "${SKILL_IDS[@]}"; do
  # Trim whitespace using bash built-in (safer than xargs which may execute commands)
  SKILL_ID="${SKILL_ID//[[:space:]]/}"

  if ! [[ "$SKILL_ID" =~ ^[0-9]+$ ]]; then
    echo "⚠️ Skipping invalid id: $SKILL_ID"
    FAILED_COUNT=$((FAILED_COUNT + 1))
    continue
  fi

  # Get skill info from pre-fetched data (avoids N+1 queries)
  ROW=$(printf '%s\n' "$ALL_SKILLS" | grep "^${SKILL_ID}"$'\t' | head -1)

  if [ -z "$ROW" ]; then
    echo "⚠️ Skill not found or already unpromoted (id=$SKILL_ID)"
    FAILED_COUNT=$((FAILED_COUNT + 1))
    continue
  fi

  # Skip the id field (first column) when reading
  IFS=$'\t' read -r _ID SITUATION SKILL_PATH <<<"$ROW"

  # Path traversal protection: ensure SKILL_PATH is under SKILL_OUTPUT_PATH
  if [ -n "$SKILL_PATH" ] && ! validate_skill_path "$SKILL_PATH"; then
    echo "⚠️ Skipping id=$SKILL_ID: Invalid skill path detected (potential path traversal)"
    FAILED_COUNT=$((FAILED_COUNT + 1))
    continue
  fi

  # DB-first approach for better consistency:
  # 1. Update DB first (if fails, file remains intact)
  # 2. Delete file second (if fails, DB already updated but orphan file is non-critical)

  # Update database: unpromote and clear skill_path
  if ! sqlite3 "$DB_PATH" <<SQL
BEGIN IMMEDIATE;
UPDATE patterns SET promoted = 0, skill_path = NULL WHERE id = $SKILL_ID;
COMMIT;
SQL
  then
    echo "⚠️ Skipping id=$SKILL_ID: Database update failed"
    FAILED_COUNT=$((FAILED_COUNT + 1))
    continue
  fi

  # Delete SKILL.md file (preserve directory)
  # File deletion failure is non-critical since DB is already updated
  if [ -n "$SKILL_PATH" ] && [ -f "$SKILL_PATH/SKILL.md" ]; then
    if ! rm "$SKILL_PATH/SKILL.md" 2>/dev/null; then
      echo "⚠️ Warning: File deletion failed for $SKILL_PATH/SKILL.md (DB already updated)"
    fi
  fi

  printf '  ✓ Deleted: %s (id=%d)\n' "$SITUATION" "$SKILL_ID"
  DELETED_COUNT=$((DELETED_COUNT + 1))
done
```

### Step 6: Completion Message

```text
✅ Skill deletion complete

- Deleted: {DELETED_COUNT} skill(s)
- Failed: {FAILED_COUNT} skill(s)

Pattern data has been preserved. You can re-promote patterns with /calibrate review.

🔄 Restart Claude Code session to apply changes.
```

## Error Handling

All operations use:
- Input validation for skill IDs (numeric check)
- Existence checks before file deletion
- Database transactions for atomic updates
- Graceful handling of partial failures
- Clear error messages with context

## Reference

**Deletion Behavior:**
- SKILL.md file: Deleted
- Skill directory: Preserved (empty directory remains)
- Database pattern: Preserved with `promoted = 0`, `skill_path = NULL`
- Pattern count: Preserved (can be re-promoted)

**Safety:**
- Confirmation required before deletion
- Multi-select support for batch operations
- Partial failure handling (continues with other skills)
- Rollback-safe database operations
