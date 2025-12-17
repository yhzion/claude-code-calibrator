---
name: calibrate
description: Record LLM expectation mismatches. Guide to initialize if not initialized.
allowed-tools: Bash(sqlite3:*), Bash(test:*), Bash(sed:*), Bash(printf:*), Bash(echo:*)
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

DB_PATH=".claude/calibrator/patterns.db"
THRESHOLD=2

if ! command -v sqlite3 &> /dev/null; then
  echo "❌ Error: sqlite3 is required but not installed."
  exit 1
fi

if [ ! -f "$DB_PATH" ]; then
  echo "❌ Calibrator is not initialized. Run /calibrate init first."
  exit 1
fi
```

## Recording Flow

### Step 2: Category Selection
English example:
```
What kind of mismatch just happened?

1. Something was missing
2. There was something unnecessary
3. I wanted a different approach
4. Let me explain
```

Category mapping:
- 1 → `missing`
- 2 → `excess`
- 3 → `style`
- 4 → `other`

### Step 3: Situation and Expectation Input
English example:
```
In what situation, and what did you expect?
Example: "When creating a model, include timestamp field"

Situation: [user input]
Expected: [user input]
Instruction (imperative rule to learn): [user input]
```

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
# Single quote escaping: ' → ''
SAFE_CATEGORY=$(printf '%s' "$CATEGORY" | sed "s/'/''/g")
SAFE_SITUATION=$(printf '%s' "$SITUATION" | sed "s/'/''/g")
SAFE_EXPECTATION=$(printf '%s' "$EXPECTATION" | sed "s/'/''/g")
SAFE_INSTRUCTION=$(printf '%s' "$INSTRUCTION" | sed "s/'/''/g")
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
