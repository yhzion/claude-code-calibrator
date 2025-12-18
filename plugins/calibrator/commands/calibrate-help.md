---
name: calibrate help
description: Show available commands and usage guide
allowed-tools: Bash(git:*), Bash(sqlite3:*), Bash(echo:*)
---

# /calibrate help

Show available Calibrator commands and current status.

## Pre-execution Setup

### Step 0: Environment Setup
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
```

## Flow

### Step 1: Check Initialization Status

```bash
if [ ! -f "$DB_PATH" ]; then
  INITIALIZED=false
else
  INITIALIZED=true
fi
```

### Step 2-A: Not Initialized Case

If `INITIALIZED=false`, display:

```text
📚 Calibrator Help

Status: ⚠️ Not initialized

Commands:
  /calibrate init      Initialize Calibrator
  /calibrate help      Show this help

Quick Start:
  Run /calibrate init to get started.
```

Exit after displaying this message.

### Step 2-B: Initialized Case

If `INITIALIZED=true`, query statistics:

```bash
# Query statistics
run_query() {
  result=$(sqlite3 "$DB_PATH" "$1" 2>/dev/null)
  if [ $? -ne 0 ]; then
    echo "0"
  else
    echo "${result:-0}"
  fi
}

TOTAL_PATTERNS=$(run_query "SELECT COUNT(*) FROM patterns;")
PROMOTED=$(run_query "SELECT COUNT(*) FROM patterns WHERE promoted = 1;")
PENDING=$(run_query "SELECT COUNT(*) FROM patterns WHERE count >= 2 AND promoted = 0;")
```

### Step 3: Display Full Help

```text
📚 Calibrator Help

Status: ✅ Initialized | Patterns: {TOTAL_PATTERNS} | Skills: {PROMOTED} | Pending: {PENDING}

Commands:
  /calibrate init      Initialize Calibrator
  /calibrate           Record an expectation mismatch
  /calibrate status    View statistics
  /calibrate review    Promote patterns to Skills
  /calibrate refactor-skills  Edit Skills and merge patterns
  /calibrate delete    Delete promoted Skills
  /calibrate reset     Delete all data
  /calibrate help      Show this help

Quick Start:
  1. /calibrate init → 2. /calibrate → 3. /calibrate review

💡 When Claude's output differs from your expectations, use /calibrate
   to record the mismatch. After 2+ repetitions, promote it to a Skill
   with /calibrate review.
```

## Notes

- This command is English-only (no locale/i18n)
- Status information is only shown when initialized
- Quick Start guide provides a simple workflow for new users
