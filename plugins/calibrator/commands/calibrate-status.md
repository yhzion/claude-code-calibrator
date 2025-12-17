---
name: calibrate status
description: View Calibrator statistics
allowed-tools: Bash(git:*), Bash(sqlite3:*), Bash(test:*), Bash(echo:*)
---

# /calibrate status

View currently recorded patterns and statistics.

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

if ! command -v sqlite3 &> /dev/null; then
  echo "❌ Error: sqlite3 is required but not installed."
  exit 1
fi

if [ ! -f "$DB_PATH" ]; then
  echo "❌ Calibrator is not initialized. Run /calibrate init first."
  exit 1
fi
```

## Flow

### Step 2: Execute Statistics Queries
```bash
# Query execution function (with error handling)
run_query() {
  result=$(sqlite3 "$DB_PATH" "$1" 2>/dev/null)
  if [ $? -ne 0 ]; then
    echo "0"
  else
    echo "${result:-0}"
  fi
}

# Total observation count
TOTAL_OBS=$(run_query "SELECT COUNT(*) FROM observations;")

# Total pattern count
TOTAL_PATTERNS=$(run_query "SELECT COUNT(*) FROM patterns;")

# Count of patterns promoted to Skills
PROMOTED=$(run_query "SELECT COUNT(*) FROM patterns WHERE promoted = 1;")

# Count of patterns pending promotion (uses configurable threshold)
PENDING=$(run_query "SELECT COUNT(*) FROM patterns WHERE count >= $THRESHOLD AND promoted = 0;")

# Recent 3 observation records (uses timestamp index for performance)
RECENT=$(sqlite3 "$DB_PATH" \
  "SELECT timestamp, category, situation FROM observations ORDER BY timestamp DESC LIMIT 3;" \
  2>/dev/null)
```

### Step 3: Output Format
English example:
```
📊 Calibrator Status

Total observations: {TOTAL_OBS}
Detected patterns: {TOTAL_PATTERNS}
├─ Promoted to Skills: {PROMOTED}
└─ Pending promotion ({THRESHOLD}+): {PENDING}

Recent records:
- [{timestamp}] {category}: {situation}
- [{timestamp}] {category}: {situation}
- [{timestamp}] {category}: {situation}
```

### Step 4: Pending Promotion Notice
If PENDING is greater than 0, add:
```
💡 Run /calibrate review to promote pending patterns to Skills.
```

### Step 5: No Data Case
If TOTAL_OBS is 0 (English example):
```
📊 Calibrator Status

No data recorded yet.
Record your first mismatch with /calibrate.
```
