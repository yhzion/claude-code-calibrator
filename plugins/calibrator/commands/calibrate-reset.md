---
name: calibrate reset
description: Reset Calibrator data (dangerous)
allowed-tools: Bash(sqlite3:*), Bash(test:*), Bash(rm:*), Bash(chmod:*), Bash(echo:*)
---

# /calibrate reset

⚠️ Deletes all Calibrator data.

## Pre-execution Setup

### Step 0: Dependency and DB Check
```bash
set -euo pipefail
IFS=$'\n\t'

DB_PATH=".claude/calibrator/patterns.db"

if ! command -v sqlite3 &> /dev/null; then
  echo "❌ Error: sqlite3 is required but not installed."
  exit 1
fi

if [ ! -f "$DB_PATH" ]; then
  echo "❌ No data to reset."
  exit 1
fi
```

## Flow

### Step 2: Display Current Status
```bash
TOTAL_OBS=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM observations;" 2>/dev/null || echo "0")
TOTAL_PATTERNS=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM patterns;" 2>/dev/null || echo "0")
```

### Step 3: Request Confirmation
English example:
```
⚠️ Calibrator Reset

Database file:
- {DB_PATH}

Data to delete:
- {TOTAL_OBS} observations
- {TOTAL_PATTERNS} patterns

Note: Generated Skills (.claude/skills/learned/) will be preserved.

Really reset? Type "reset" to confirm: _
```

### Step 4: User Input Validation
- If "reset" is entered: Proceed with deletion
- Otherwise: Print "Reset cancelled." and exit

### Step 5: Execute Data Deletion
```bash
# Delete existing DB
if ! rm "$DB_PATH" 2>/dev/null; then
  echo "❌ Error: Failed to delete database"
  exit 1
fi

# Create new DB using schema
if ! sqlite3 "$DB_PATH" < plugins/calibrator/schemas/schema.sql; then
  echo "❌ Error: Failed to recreate database"
  exit 1
fi

# Restore secure permissions
chmod 600 "$DB_PATH"
```

### Step 6: Completion Message
English example:
```
✅ Calibrator data has been reset

- Observations: all deleted
- Patterns: all deleted
- Skills: preserved (.claude/skills/learned/)

Start new records with /calibrate.
```
