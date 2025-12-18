---
name: auto-calibrate
description: Analyzes error corrections and records learned patterns to the patterns table. Works with detect-errors.sh hook which tracks error frequency in observations. Triggers when Claude successfully fixes errors and understands the fix well enough to create a learnable instruction.
---

# Auto-Calibrate Skill

This skill analyzes error corrections and records learned patterns with meaningful instructions.

## Role Separation with Hook

| Component | Role | Records To |
|-----------|------|------------|
| **detect-errors.sh (Hook)** | Frequency tracking - captures WHAT failed | observations table |
| **auto-calibrate.md (Skill)** | Pattern learning - captures HOW to fix it | patterns table |

The hook automatically runs on every Bash error and logs the occurrence. This skill activates when Claude understands the fix and can articulate a learnable instruction.

## When This Skill Activates

Activate this skill when ALL of the following conditions are met:

1. **Error Detection**: You encountered an error or warning from:
   - Linting tools (ESLint, Prettier, Biome, etc.)
   - Type checking (TypeScript, Flow, etc.)
   - Build processes (Webpack, Vite, esbuild, etc.)
   - Test runners (Jest, Vitest, pytest, etc.)
   - Format checkers

2. **Error Resolution**: You successfully fixed the error

3. **Pattern Recognition**: The fix represents a learnable pattern that could apply to future similar situations

## What NOT to Record

Do NOT record patterns for:
- One-time typos or simple mistakes
- Project-specific configurations that won't recur
- User-requested changes (not error corrections)
- Obvious bugs with no learning value

## Automatic Recording Process

When conditions are met, execute the following steps:

### Step 1: Check Dependencies, Calibrator Initialization and Auto-Detection Setting

```bash
# Check sqlite3 dependency (silent exit for background skill)
if ! command -v sqlite3 &> /dev/null; then
  # sqlite3 not found, exit silently as this is a background skill.
  exit 0
fi

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

SQLITE_VERSION=$(sqlite3 --version 2>/dev/null | awk '{print $1}')
MIN_SQLITE_VERSION="3.24.0"
if ! version_ge "${SQLITE_VERSION:-0}" "$MIN_SQLITE_VERSION"; then
  # SQLite version too old, exit silently.
  exit 0
fi

set -euo pipefail

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
DB_PATH="$PROJECT_ROOT/.claude/calibrator/patterns.db"
FLAG_FILE="$PROJECT_ROOT/.claude/calibrator/auto-detect.enabled"

# Check if calibrator is initialized
if [ ! -f "$DB_PATH" ]; then
  echo "⚠️ Calibrator not initialized. Run /calibrate init first to enable auto-learning."
  exit 0
fi

# Check if auto-detection is enabled
if [ ! -f "$FLAG_FILE" ]; then
  # Auto-detection is disabled, skip recording
  exit 0
fi
```

### Step 2: Determine Category

Categorize the error correction:
- `missing`: Something was missing (missing import, missing type, missing config)
- `excess`: Something unnecessary was present (unused variable, redundant code)
- `style`: Different approach preferred (formatting, naming convention)
- `other`: Other type of correction

### Step 3: Extract Pattern Information

Identify and format:
- **SITUATION**: Brief description of when this error occurs (max 500 chars)
  - Example: "When using async/await in TypeScript"
- **EXPECTATION**: What was expected vs what happened (max 1000 chars)
  - Example: "Expected proper error handling with try-catch"
- **INSTRUCTION**: Imperative rule to prevent future occurrences (max 2000 chars)
  - Example: "Always wrap async/await calls in try-catch blocks with typed error handling"

### Step 4: Record to Database

Replace placeholders with actual values based on the error correction context:
- `{{CATEGORY}}` → one of: missing, excess, style, other
- `{{SITUATION}}` → Brief situation description (max 500 chars)
- `{{EXPECTATION}}` → What was expected (max 1000 chars)
- `{{INSTRUCTION}}` → Rule to learn (max 2000 chars)

```bash
set -euo pipefail

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
DB_PATH="$PROJECT_ROOT/.claude/calibrator/patterns.db"

# SQL Injection prevention
escape_sql() {
  printf '%s' "$1" | sed "s/'/''/g"
}

# Variables to be filled by Claude based on the error correction
CATEGORY="{{CATEGORY}}"        # missing|excess|style|other
SITUATION="{{SITUATION}}"      # Brief situation description
EXPECTATION="{{EXPECTATION}}"  # What was expected
INSTRUCTION="{{INSTRUCTION}}"  # Rule to learn

# Validate category
case "$CATEGORY" in
  missing|excess|style|other) ;;
  *) echo "❌ Error: Invalid category '$CATEGORY'"; exit 1 ;;
esac

SAFE_CATEGORY=$(escape_sql "$CATEGORY")
SAFE_SITUATION=$(escape_sql "$SITUATION")
SAFE_EXPECTATION=$(escape_sql "$EXPECTATION")
SAFE_INSTRUCTION=$(escape_sql "$INSTRUCTION")

# Record using transaction with error handling
if ! sqlite3 "$DB_PATH" <<SQL
BEGIN IMMEDIATE;

INSERT INTO observations (category, situation, expectation)
VALUES ('$SAFE_CATEGORY', '$SAFE_SITUATION', '$SAFE_EXPECTATION');

INSERT INTO patterns (situation, instruction, count)
VALUES ('$SAFE_SITUATION', '$SAFE_INSTRUCTION', 1)
ON CONFLICT(situation, instruction)
DO UPDATE SET count = count + 1, last_seen = CURRENT_TIMESTAMP;

COMMIT;
SQL
then
  echo "⚠️ Auto-calibrate: Failed to record pattern"
  exit 1
fi

# Get current pattern count
COUNT=$(sqlite3 "$DB_PATH" "SELECT count FROM patterns WHERE situation = '$SAFE_SITUATION' AND instruction = '$SAFE_INSTRUCTION';" 2>/dev/null || echo "1")

echo "COUNT=$COUNT"
```

### Step 5: Notify User

After successful recording, display the notification in the format specified in the Output Format section below.

## Output Format

When this skill activates, use this format to notify the user:

```
┌─ 🔄 Auto-Calibrate ──────────────────────────────┐
│ Learned: "{situation_summary}"                   │
│ Category: {category} | Occurrences: {count}      │
└──────────────────────────────────────────────────┘
```

If count >= CALIBRATOR_THRESHOLD (default 2), add promotion suggestion on a new line:
```
💡 Pattern repeated {count}x → /calibrate review to promote to skill
```

**Note:** The hook (detect-errors.sh) tracks error frequency in `observations` table.
This skill records the actual learned pattern with instruction to `patterns` table.

## Important Notes

- Only record genuinely learnable patterns
- Keep descriptions concise but informative
- The instruction should be actionable and specific
- Do not interrupt user workflow - record silently and report briefly
- If DB is not initialized, suggest `/calibrate init` once and continue without blocking
