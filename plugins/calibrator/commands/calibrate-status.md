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
# Configurable threshold (default: 2)
THRESHOLD="${CALIBRATOR_THRESHOLD:-2}"

if ! command -v sqlite3 &> /dev/null; then
  echo "❌ Error: sqlite3 is required but not installed."
  exit 1
fi

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

### Step 1: Execute Statistics Queries
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

### Step 2: Output Format
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

### Step 3: Pending Promotion Notice
If PENDING is greater than 0, add:
```
💡 Run /calibrate review to promote pending patterns to Skills.
```

### Step 4: No Data Case
If TOTAL_OBS is 0 (English example):
```
📊 Calibrator Status

No data recorded yet.
Record your first mismatch with /calibrate.
```
