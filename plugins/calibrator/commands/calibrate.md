---
name: calibrate
description: Record LLM expectation mismatches. Guide to initialize if not initialized.
allowed-tools: Bash(git:*), Bash(sqlite3:*), Bash(test:*), Bash(sed:*), Bash(printf:*), Bash(echo:*)
---

# /calibrate

Record patterns when Claude generates something different from expectations.

## Notes

This command is English-only (no locale/i18n).

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
THRESHOLD=2

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

## Recording Flow

### Step 2: Category Selection

Ask the user to select a category with a clear message:

```
📝 Recording Pattern Mismatch

What kind of mismatch just happened?

1. Something was missing - Expected output was not included
2. Something unnecessary - Output included unwanted content
3. Different approach - Wanted a different style or method
4. Other - Let me explain in detail

Select category (1/2/3/4):
```

Wait for user response and map to category:
- User responds "1" → `CATEGORY="missing"`
- User responds "2" → `CATEGORY="excess"`
- User responds "3" → `CATEGORY="style"`
- User responds "4" → `CATEGORY="other"`

### Step 3: Situation and Expectation Input

Ask the user three questions sequentially:

**Question 1: Situation**
```
In what situation did this happen?
Example: "When creating a model", "When writing API endpoints"

Situation:
```
Wait for user response → Save as `SITUATION`

**Question 2: Expected**
```
What did you expect?
Example: "Include timestamp field", "Use TypeScript interfaces"

Expected:
```
Wait for user response → Save as `EXPECTATION`

**Question 3: Instruction**
```
What rule should Claude learn? (imperative form)
Example: "Always include timestamp fields", "Never use var in JavaScript"

Instruction:
```
Wait for user response → Save as `INSTRUCTION`

### Step 4: Input Validation
```bash
# Validate category defensively
case "$CATEGORY" in
  missing|excess|style|other) ;;
  *) echo "❌ Error: Invalid category '$CATEGORY'"; exit 1 ;;
esac

# Basic length checks (match DB CHECK constraints)
if [ ${#SITUATION} -eq 0 ] || [ ${#SITUATION} -gt 500 ]; then
  echo "❌ Error: Situation must be 1-500 characters."
  exit 1
fi

if [ ${#EXPECTATION} -eq 0 ] || [ ${#EXPECTATION} -gt 1000 ]; then
  echo "❌ Error: Expected must be 1-1000 characters."
  exit 1
fi

if [ ${#INSTRUCTION} -eq 0 ] || [ ${#INSTRUCTION} -gt 2000 ]; then
  echo "❌ Error: Instruction must be 1-2000 characters."
  exit 1
fi
```

### Step 5: Database Recording

**Input Escaping** (SQL Injection Prevention):
```bash
# SQL Injection prevention: escape single quotes
escape_sql() {
  printf '%s' "$1" | sed "s/'/''/g"
}

SAFE_CATEGORY=$(escape_sql "$CATEGORY")
SAFE_SITUATION=$(escape_sql "$SITUATION")
SAFE_EXPECTATION=$(escape_sql "$EXPECTATION")
SAFE_INSTRUCTION=$(escape_sql "$INSTRUCTION")
```

Record to both tables using transaction (prevents race conditions):
```bash
# Use BEGIN IMMEDIATE for write lock, ensuring atomic operation
sqlite3 "$DB_PATH" <<SQL
BEGIN IMMEDIATE;

-- Record observation
INSERT INTO observations (category, situation, expectation)
VALUES ('$SAFE_CATEGORY', '$SAFE_SITUATION', '$SAFE_EXPECTATION');

-- Upsert pattern (composite unique: situation + instruction)
INSERT INTO patterns (situation, instruction, count)
VALUES ('$SAFE_SITUATION', '$SAFE_INSTRUCTION', 1)
ON CONFLICT(situation, instruction)
DO UPDATE SET count = count + 1, last_seen = CURRENT_TIMESTAMP;

COMMIT;
SQL

if [ $? -ne 0 ]; then
  echo "❌ Error: Failed to record pattern"
  exit 1
fi
```

Get current pattern count:
```bash
COUNT=$(sqlite3 "$DB_PATH" "SELECT count FROM patterns WHERE situation = '$SAFE_SITUATION' AND instruction = '$SAFE_INSTRUCTION';" 2>/dev/null || echo "1")
```

### Step 6: Output Result
English example:
```
✅ Record complete

Situation: {situation}
Expected: {expectation}
Instruction: {instruction}

Same pattern accumulated {count} times
```

If count is >= 2, add:
```
💡 You can promote this to a Skill with /calibrate review.
```
