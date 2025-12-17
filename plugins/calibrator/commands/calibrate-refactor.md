---
name: calibrate refactor
description: Edit existing Skills and merge similar patterns
allowed-tools: Bash(git:*), Bash(sqlite3:*), Bash(test:*), Bash(sed:*), Bash(printf:*), Bash(echo:*), Bash(awk:*)
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
```

## Flow

### Step 1: Mode Selection
```
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
```
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
  "SELECT situation, instruction, count, skill_path FROM patterns WHERE id = $SKILL_ID AND promoted = 1;" \
  2>/dev/null) || ROW=""

if [ -z "$ROW" ]; then
  echo "❌ Error: Skill not found or not promoted (id=$SKILL_ID)"
  exit 1
fi

IFS=$'\t' read -r SITUATION INSTRUCTION COUNT SKILL_PATH <<<"$ROW"
```

### Step 1-3: Display Current Values and Edit
```
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
```
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

# Update SKILL.md file if skill_path exists
if [ -n "$SKILL_PATH" ] && [ -f "$SKILL_PATH/SKILL.md" ]; then
  # Escape variables for sed substitution
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

  SAFE_SED_SITUATION=$(escape_sed "$NEW_SITUATION")
  SAFE_SED_INSTRUCTION=$(escape_sed "$NEW_INSTRUCTION")

  # Update SKILL.md - replace instruction and situation in frontmatter and body
  TEMP_FILE=$(mktemp)
  awk -v new_instruction="$NEW_INSTRUCTION" -v new_situation="$NEW_SITUATION" '
    BEGIN { in_frontmatter=0; after_frontmatter=0 }
    /^---$/ {
      if (in_frontmatter) {
        after_frontmatter=1
      }
      in_frontmatter=!in_frontmatter;
      print;
      next
    }
    in_frontmatter && /^description:/ {
      print "description: " new_instruction ". Auto-applied in " new_situation " situations."
      next
    }
    after_frontmatter && /^## Rules$/ {
      print
      getline
      if ($0 == "") print ""
      print new_instruction
      next
    }
    after_frontmatter && /^## Applies to$/ {
      print
      getline
      if ($0 == "") print ""
      print "- " new_situation
      next
    }
    { print }
  ' "$SKILL_PATH/SKILL.md" > "$TEMP_FILE"

  mv "$TEMP_FILE" "$SKILL_PATH/SKILL.md"
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
```
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
```
📝 Patterns for: {situation}

[id=10] Always use async/await (2 times)
[id=12] Include try-catch blocks (3 times)
[id=15] Use Promise.all for parallel operations (1 time)

Enter pattern ids to merge (comma-separated, e.g., 10,12,15):

Keep which instruction as primary? Enter pattern id:
```

### Step 2-2: Merge Patterns
```bash
# Validate all pattern ids
IFS=',' read -ra PATTERN_IDS <<< "$MERGE_IDS"
TOTAL_COUNT=0
PRIMARY_INSTRUCTION=""

for PID in "${PATTERN_IDS[@]}"; do
  PID=$(echo "$PID" | xargs)  # trim whitespace

  if ! [[ "$PID" =~ ^[0-9]+$ ]]; then
    echo "❌ Error: Invalid pattern id '$PID'"
    exit 1
  fi

  # Get count and instruction
  if [ "$PID" = "$PRIMARY_ID" ]; then
    ROW=$(sqlite3 -separator $'\t' "$DB_PATH" \
      "SELECT instruction, count FROM patterns WHERE id = $PID AND promoted = 0;" \
      2>/dev/null) || ROW=""

    if [ -z "$ROW" ]; then
      echo "❌ Error: Primary pattern not found (id=$PID)"
      exit 1
    fi

    IFS=$'\t' read -r PRIMARY_INSTRUCTION COUNT <<<"$ROW"
    TOTAL_COUNT=$((TOTAL_COUNT + COUNT))
  else
    COUNT=$(sqlite3 "$DB_PATH" \
      "SELECT count FROM patterns WHERE id = $PID AND promoted = 0;" \
      2>/dev/null) || COUNT=""

    if [ -z "$COUNT" ]; then
      echo "❌ Error: Pattern not found (id=$PID)"
      exit 1
    fi

    TOTAL_COUNT=$((TOTAL_COUNT + COUNT))
  fi
done

# Perform merge using transaction
SAFE_INSTRUCTION=$(escape_sql "$PRIMARY_INSTRUCTION")

sqlite3 "$DB_PATH" <<SQL
BEGIN IMMEDIATE;

-- Update primary pattern with merged count
UPDATE patterns
SET count = $TOTAL_COUNT,
    last_seen = CURRENT_TIMESTAMP
WHERE id = $PRIMARY_ID;

-- Delete other patterns
$(for PID in "${PATTERN_IDS[@]}"; do
  PID=$(echo "$PID" | xargs)
  if [ "$PID" != "$PRIMARY_ID" ]; then
    echo "DELETE FROM patterns WHERE id = $PID;"
  fi
done)

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
```
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
