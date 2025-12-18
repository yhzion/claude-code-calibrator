---
name: calibrate reset
description: Reset Calibrator data (dangerous)
arguments:
  - name: mode
    description: "Reset mode: default (data only) or --all (data + skills + DB file)"
    required: false
allowed-tools: Bash(git:*), Bash(sqlite3:*), Bash(test:*), Bash(echo:*), Bash(rm:*), Bash(rmdir:*), Bash(ls:*)
---

# /calibrate reset [--all]

⚠️ Deletes Calibrator data.

## Usage

- `/calibrate reset` - Delete database records only (skills preserved)
- `/calibrate reset --all` - Delete everything: database, skills, and all Calibrator files

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

### Step 1: Display Current Status
```bash
TOTAL_OBS=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM observations;" 2>/dev/null || echo "0")
TOTAL_PATTERNS=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM patterns;" 2>/dev/null || echo "0")
```

### Step 2: Determine Reset Mode and Count Skills

Check if `--all` argument was provided and count generated skills:
```bash
SKILL_COUNT=$(ls -1 "$PROJECT_ROOT/.claude/skills/calibrator-"* 2>/dev/null | wc -l | tr -d ' ') || SKILL_COUNT=0

# Count promoted skills (will become orphaned if data is reset without --all)
PROMOTED_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM patterns WHERE promoted = 1;" 2>/dev/null || echo "0")
```

### Step 3: Request Confirmation

**Default mode (data only):**
Display the warning message:
```
⚠️ Calibrator Reset (Data Only)

Database file:
- {DB_PATH}

Data to delete:
- {TOTAL_OBS} observations
- {TOTAL_PATTERNS} patterns

Note: Generated Skills (.claude/skills/) will be preserved.
```

If `PROMOTED_COUNT > 0`, also display an orphan skills warning:
```
⚠️ Orphan Skills Warning

{PROMOTED_COUNT} promoted Skill(s) will become orphaned:
- Skill files in .claude/skills/ will remain but lose their DB connection
- These skills will still work but cannot be managed via /calibrate commands

To completely remove everything including skills, use: /calibrate reset --all
```

Then ask the user for confirmation:
```
⚠️ Are you sure you want to delete all Calibrator data?
This action cannot be undone.

1. Yes, reset data - Delete all observations and patterns permanently
2. Cancel - Keep all data and exit

Confirm (1/2):
```

**--all mode (complete reset):**
Display the warning message:
```
⚠️ Calibrator Complete Reset

This will delete EVERYTHING:
- Database file: {DB_PATH}
- {TOTAL_OBS} observations
- {TOTAL_PATTERNS} patterns
- {SKILL_COUNT} generated skills (.claude/skills/calibrator-*.md)
- Auto-detect flag file
- Calibrator directory

⚠️ This action cannot be undone!
```

Then ask the user for confirmation:
```
Are you sure you want to completely remove all Calibrator data and skills?

1. Yes, delete everything - Remove all data, skills, and files
2. Reset data only - Keep skills, delete database records
3. Cancel - Keep everything and exit

Confirm (1/2/3):
```

### Step 4: User Choice Handling

**Default mode:**
- User responds "1" or "yes" → Proceed to Step 5 (data deletion)
- User responds "2" or "cancel" → Print "Reset cancelled." and exit

**--all mode:**
- User responds "1" → Proceed to Step 5 (complete deletion)
- User responds "2" → Proceed to Step 5 (data only deletion)
- User responds "3" or "cancel" → Print "Reset cancelled." and exit

### Step 5: Execute Deletion

**Data only deletion:**
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

**Complete deletion (--all mode, option 1):**
```bash
# Remove generated skills
rm -rf "$PROJECT_ROOT/.claude/skills/calibrator-"* 2>/dev/null || true

# Remove database file
rm -f "$DB_PATH"

# Remove auto-detect flag
rm -f "$PROJECT_ROOT/.claude/calibrator/auto-detect.enabled"

# Remove calibrator directory if empty
rmdir "$PROJECT_ROOT/.claude/calibrator" 2>/dev/null || true
```

### Step 6: Completion Message

**Data only:**
```
✅ Calibrator data has been reset

- Observations: all deleted
- Patterns: all deleted
- Skills: preserved (.claude/skills/)

Start new records with /calibrate.
```

**Complete reset:**
```
✅ Calibrator completely removed

- Database: deleted
- Observations: deleted
- Patterns: deleted
- Skills: {SKILL_COUNT} files deleted
- Auto-detect: disabled

Run /calibrate init to start fresh.
```
