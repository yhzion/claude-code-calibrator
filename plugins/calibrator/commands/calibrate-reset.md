---
name: calibrate reset
description: Reset Calibrator data (dangerous)
allowed-tools: Bash(git:*), Bash(sqlite3:*), Bash(test:*), Bash(echo:*)
---

# /calibrate reset

⚠️ Deletes all Calibrator data.

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
# Clear data using transaction (safer than rm + recreate)
# Transaction ensures atomicity: on failure, data is preserved via rollback
if ! sqlite3 "$DB_PATH" <<SQL
BEGIN IMMEDIATE;
DELETE FROM observations;
DELETE FROM patterns;
COMMIT;
SQL
then
  echo "❌ Error: Failed to reset database"
  exit 1
fi
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
